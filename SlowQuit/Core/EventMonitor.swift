//
//  EventMonitor.swift
//  SlowQuit
//
//  Created by Claude on 2025-10-12.
//

import Cocoa
import Carbon

private enum ProtectedAction: String {
    case quit
    case close

    var shortcutKey: String {
        switch self {
        case .quit:
            return "q"
        case .close:
            return "w"
        }
    }

    var displayName: String {
        switch self {
        case .quit:
            return "Cmd+Q"
        case .close:
            return "Cmd+W"
        }
    }

    var overlayMessage: String {
        switch self {
        case .quit:
            return L10n.overlayHoldToQuit
        case .close:
            return L10n.overlayHoldToClose
        }
    }

    var overlayIcon: String {
        switch self {
        case .quit:
            return "power"
        case .close:
            return "xmark"
        }
    }

    var requiresSameFrontmostApp: Bool {
        switch self {
        case .quit:
            return false
        case .close:
            return true
        }
    }
}

class EventMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var pressTimer: Timer?
    private var overlayWindow: OverlayWindow
    private var isCommandPressed = false
    private var waitingAction: ProtectedAction?
    private var waitingKeyCode: CGKeyCode?
    private var isSendingProtectedEvent = false
    private var hasExecutedAction = false  // 防止长按 Command 时连续执行多个应用/窗口
    private var targetApp: NSRunningApplication?

    private(set) var isRunning = false
    var onSecureInputDetected: (() -> Void)?

    init(overlayWindow: OverlayWindow) {
        self.overlayWindow = overlayWindow
    }

    /// 检查 CGEventTap 是否真正有效
    func isEventTapEnabled() -> Bool {
        guard let eventTap = eventTap else { return false }
        return CGEvent.tapIsEnabled(tap: eventTap)
    }

    /// 检查安全输入状态，返回占用进程名称
    func checkSecureInputState() -> String? {
        if IsSecureEventInputEnabled() {
            return "loginwindow"
        }
        return nil
    }

    func start() {
        guard !isRunning else { return }

        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<EventMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            Logger.shared.log("无法创建事件监听", level: .error)
            return
        }

        self.eventTap = eventTap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)

        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        isRunning = true
        Logger.shared.log("事件监听器已启动", level: .info)
    }

    func stop() {
        guard isRunning else { return }

        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }

        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }

        pressTimer?.invalidate()
        pressTimer = nil
        overlayWindow.hide()

        eventTap = nil
        runLoopSource = nil
        isRunning = false

        Logger.shared.log("事件监听器已停止", level: .info)
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .flagsChanged {
            let flags = event.flags
            let wasCommandPressed = isCommandPressed
            isCommandPressed = flags.contains(.maskCommand)

            if wasCommandPressed && !isCommandPressed {
                Logger.shared.log("Command键释放，重置状态", level: .debug)
                resetState()
                hasExecutedAction = false
            }
            return Unmanaged.passUnretained(event)
        }

        if !isCommandPressed && waitingAction == nil && !event.flags.contains(.maskCommand) {
            return Unmanaged.passUnretained(event)
        }

        if type == .keyDown {
            return handleKeyDown(event)
        }

        if type == .keyUp {
            return handleKeyUp(event)
        }

        return Unmanaged.passUnretained(event)
    }

    private func handleKeyDown(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        guard isPureCommandShortcut(event) else {
            return Unmanaged.passUnretained(event)
        }

        if isSendingProtectedEvent {
            return Unmanaged.passUnretained(event)
        }

        guard let action = protectedAction(for: event) else {
            return Unmanaged.passUnretained(event)
        }

        if action == .close && !SettingsManager.shared.slowCloseEnabled {
            return Unmanaged.passUnretained(event)
        }

        let frontApp = NSWorkspace.shared.frontmostApplication
        let shouldDelay = AppListManager.shared.shouldApplyDelay(for: frontApp?.bundleIdentifier)

        if !shouldDelay {
            Logger.shared.log("应用 \(frontApp?.localizedName ?? "未知") 不在保护列表中，直接放行 \(action.displayName)", level: .debug)
            return Unmanaged.passUnretained(event)
        }

        if hasExecutedAction {
            Logger.shared.log("本次按键已执行过动作，忽略重复触发（请松开Command键后重试）", level: .debug)
            return nil
        }

        if waitingAction != nil {
            Logger.shared.log("忽略重复的\(action.displayName)按键事件", level: .debug)
            return nil
        }

        waitingAction = action
        waitingKeyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        Logger.shared.log("检测到 \(action.displayName) 按键", level: .debug)
        startTimer(for: action)

        return nil
    }

    private func handleKeyUp(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        guard let action = waitingAction,
              let waitingKeyCode = waitingKeyCode else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        if keyCode == waitingKeyCode {
            Logger.shared.log("\(action.displayName) 提前释放，取消操作", level: .debug)
            resetState()
            return nil
        }

        return Unmanaged.passUnretained(event)
    }

    private func startTimer(for action: ProtectedAction) {
        pressTimer?.invalidate()

        let delay = SettingsManager.shared.quitDelay
        targetApp = NSWorkspace.shared.frontmostApplication
        let appName = targetApp?.localizedName ?? "未知应用"
        let overlayTitle = action == .close ? L10n.settingsSlowCloseTitle : appName
        let bundleId = targetApp?.bundleIdentifier ?? "unknown"

        Logger.shared.log("启动\(action.displayName)计时器 (\(delay)秒) - 应用: \(appName) (\(bundleId))", level: .debug)

        overlayWindow.show(
            duration: delay,
            appName: overlayTitle,
            message: action.overlayMessage,
            iconName: action.overlayIcon
        )

        pressTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.executeWaitingAction()
        }
    }

    private func executeWaitingAction() {
        guard let action = waitingAction,
              let keyCode = waitingKeyCode,
              let targetApp = self.targetApp else {
            Logger.shared.log("无法获取目标操作或应用", level: .warning)
            resetState()
            return
        }

        let appName = targetApp.localizedName ?? "未知应用"
        let currentFrontmost = NSWorkspace.shared.frontmostApplication
        let currentName = currentFrontmost?.localizedName ?? "未知"

        Logger.shared.log("执行\(action.displayName): \(appName) (当前前台: \(currentName))", level: .debug)

        if targetApp.isTerminated {
            Logger.shared.log("目标应用已退出，取消操作", level: .warning)
            hasExecutedAction = true
        } else if action.requiresSameFrontmostApp && currentFrontmost?.processIdentifier != targetApp.processIdentifier {
            Logger.shared.log("目标应用已不在前台，取消\(action.displayName)", level: .warning)
            hasExecutedAction = true
        } else {
            sendProtectedShortcut(action: action, keyCode: keyCode, to: targetApp)
            hasExecutedAction = true
            Logger.shared.log("已标记本次按键已执行操作，需要松开Command键才能再次触发", level: .debug)
        }

        resetState()
    }

    private func sendProtectedShortcut(action: ProtectedAction, keyCode: CGKeyCode, to app: NSRunningApplication) {
        isSendingProtectedEvent = true

        if !action.requiresSameFrontmostApp {
            app.activate(options: [.activateIgnoringOtherApps])
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self else { return }

            if action.requiresSameFrontmostApp,
               NSWorkspace.shared.frontmostApplication?.processIdentifier != app.processIdentifier {
                Logger.shared.log("发送前目标应用已不在前台，取消\(action.displayName)", level: .warning)
                self.isSendingProtectedEvent = false
                return
            }

            guard let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
                  let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
                Logger.shared.log("无法创建键盘事件", level: .error)
                self.isSendingProtectedEvent = false
                return
            }

            keyDownEvent.flags = .maskCommand
            keyUpEvent.flags = .maskCommand
            keyDownEvent.post(tap: .cghidEventTap)
            keyUpEvent.post(tap: .cghidEventTap)

            Logger.shared.log("已发送\(action.displayName)事件给目标应用", level: .debug)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.isSendingProtectedEvent = false
            }
        }
    }

    private func isPureCommandShortcut(_ event: CGEvent) -> Bool {
        let flags = event.flags
        return flags.contains(.maskCommand)
            && !flags.contains(.maskShift)
            && !flags.contains(.maskAlternate)
            && !flags.contains(.maskControl)
    }

    private func protectedAction(for event: CGEvent) -> ProtectedAction? {
        guard let key = keyString(for: event)?.lowercased() else {
            return nil
        }

        return [.quit, .close].first { $0.shortcutKey == key }
    }

    private func keyString(for event: CGEvent) -> String? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        guard let keyboardLayoutData = currentKeyboardLayoutData(),
              let keyboardLayout = CFDataGetBytePtr(keyboardLayoutData) else {
            return fallbackKeyString(for: keyCode)
        }

        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        let status = UCKeyTranslate(
            keyboardLayout.withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) { $0 },
            UInt16(keyCode),
            UInt16(kUCKeyActionDown),
            0,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            chars.count,
            &length,
            &chars
        )

        guard status == noErr, length > 0 else {
            return fallbackKeyString(for: keyCode)
        }

        return String(utf16CodeUnits: chars, count: length)
    }

    private func currentKeyboardLayoutData() -> CFData? {
        let currentInputSource = TISCopyCurrentKeyboardLayoutInputSource().takeRetainedValue()
        guard let layoutDataPointer = TISGetInputSourceProperty(
            currentInputSource,
            kTISPropertyUnicodeKeyLayoutData
        ) else {
            return nil
        }

        return unsafeBitCast(layoutDataPointer, to: CFData.self)
    }

    private func fallbackKeyString(for keyCode: Int64) -> String? {
        switch keyCode {
        case 12:
            return "q"
        case 13:
            return "w"
        default:
            return nil
        }
    }

    private func resetState() {
        pressTimer?.invalidate()
        pressTimer = nil
        overlayWindow.hide()
        waitingAction = nil
        waitingKeyCode = nil
        targetApp = nil
    }
}
