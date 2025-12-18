//
//  EventMonitor.swift
//  SlowQuit
//
//  Created by Claude on 2025-10-12.
//

import Cocoa
import Carbon

class EventMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var pressTimer: Timer?
    private var overlayWindow: OverlayWindow
    private var isCommandPressed = false
    private var isQPressed = false
    private var isWaitingToQuit = false  // 是否正在等待退出
    private var isSendingQuitEvent = false  // 是否正在发送退出事件
    private var hasExecutedQuit = false  // 是否已经执行过一次退出（防止连续退出多个应用）
    private var targetApp: NSRunningApplication?  // 锁定目标应用（按下Cmd+Q时的前台应用）

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
        // 处理修饰键变化（Command 键）
        if type == .flagsChanged {
            let flags = event.flags
            let wasCommandPressed = isCommandPressed
            isCommandPressed = flags.contains(.maskCommand)

            // Command 键释放时，重置所有状态（包括冷却期）
            if wasCommandPressed && !isCommandPressed {
                Logger.shared.log("Command键释放，重置状态", level: .debug)
                resetState()
                hasExecutedQuit = false  // 允许下一次 Cmd+Q
            }
            // 早期返回：修饰键事件处理完毕
            return Unmanaged.passUnretained(event)
        }

        // 优化：如果 Command 键未按下，直接放行所有按键事件（最重要的优化）
        // 这可以避免处理绝大多数无关的键盘事件
        if !isCommandPressed && !isQPressed {
            return Unmanaged.passUnretained(event)
        }

        // 处理按键按下
        if type == .keyDown {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

            // 检测 Q 键（keyCode = 12）
            if keyCode == 12 {
                let flags = event.flags

                // 检测 Cmd+Q 组合键(仅 Command,不包含 Shift/Option/Control)
                let hasCommand = flags.contains(.maskCommand)
                let hasShift = flags.contains(.maskShift)
                let hasOption = flags.contains(.maskAlternate)
                let hasControl = flags.contains(.maskControl)

                // 只拦截纯粹的 Cmd+Q(不带其他修饰键)
                if hasCommand && !hasShift && !hasOption && !hasControl {
                    // 如果是我们自己发送的退出事件，直接放行
                    if isSendingQuitEvent {
                        return Unmanaged.passUnretained(event)
                    }

                    // 检查是否应对当前应用应用延迟
                    let frontApp = NSWorkspace.shared.frontmostApplication
                    let shouldDelay = AppListManager.shared.shouldApplyDelay(for: frontApp?.bundleIdentifier)

                    // 如果不需要延迟，直接放行原始事件
                    if !shouldDelay {
                        Logger.shared.log("应用 \(frontApp?.localizedName ?? "未知") 不在延迟列表中，直接退出", level: .debug)
                        return Unmanaged.passUnretained(event)
                    }

                    // 如果本次按键已经执行过一次退出，忽略后续的 Cmd+Q（防止连续退出多个应用）
                    if hasExecutedQuit {
                        Logger.shared.log("本次按键已执行过退出，忽略重复触发（请松开Command键后重试）", level: .debug)
                        return nil
                    }

                    // 如果已经在等待退出，忽略重复的按键事件
                    if isWaitingToQuit {
                        Logger.shared.log("忽略重复的Cmd+Q按键事件", level: .debug)
                        return nil
                    }

                    isQPressed = true
                    isWaitingToQuit = true
                    Logger.shared.log("检测到 Cmd+Q 按键", level: .debug)

                    // 开始计时器和显示叠加层
                    startQuitTimer()

                    // 阻止立即退出
                    return nil
                }
            }
            // 早期返回：非Q键的按键事件不需要进一步处理
            return Unmanaged.passUnretained(event)
        }

        // 处理按键释放
        if type == .keyUp {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

            // Q 键释放
            if keyCode == 12 {
                if isQPressed {
                    // 如果在延迟时间内释放，取消退出
                    Logger.shared.log("Q键提前释放，取消退出", level: .debug)
                    resetState()
                    return nil
                }
            }
        }

        return Unmanaged.passUnretained(event)
    }

    private func startQuitTimer() {
        // 取消之前的计时器
        pressTimer?.invalidate()

        // 获取当前配置的延迟时长
        let quitDelay = SettingsManager.shared.quitDelay

        // 锁定目标应用（按下Cmd+Q时的前台应用）
        targetApp = NSWorkspace.shared.frontmostApplication
        let appName = targetApp?.localizedName ?? "未知应用"
        let bundleId = targetApp?.bundleIdentifier ?? "unknown"

        Logger.shared.log("启动退出计时器 (\(quitDelay)秒) - 应用: \(appName) (\(bundleId))", level: .debug)

        // 显示叠加层并开始进度动画，传入应用名称
        overlayWindow.show(duration: quitDelay, appName: appName)

        // 启动计时器
        pressTimer = Timer.scheduledTimer(withTimeInterval: quitDelay, repeats: false) { [weak self] _ in
            self?.executeQuit()
        }
    }

    private func executeQuit() {
        // 使用锁定的目标应用，而不是当前前台应用
        guard let targetApp = self.targetApp else {
            Logger.shared.log("无法获取目标应用", level: .warning)
            resetState()
            return
        }

        let appName = targetApp.localizedName ?? "未知应用"
        let currentFrontmost = NSWorkspace.shared.frontmostApplication?.localizedName ?? "未知"

        Logger.shared.log("执行退出应用: \(appName) (当前前台: \(currentFrontmost))", level: .debug)

        // 如果目标应用仍在运行，发送退出命令
        if targetApp.isTerminated {
            Logger.shared.log("目标应用已退出，取消操作", level: .warning)
        } else {
            // 使用CGEvent发送真实的Cmd+Q事件给目标应用
            sendCmdQEvent(to: targetApp)

            // 标记已执行过退出，防止长按时连续退出多个应用
            hasExecutedQuit = true
            Logger.shared.log("已标记本次按键已执行退出，需要松开Command键才能再次触发", level: .debug)
        }

        // resetState() 已经会调用 hide()，所以这里不需要重复调用
        resetState()
    }

    /// 发送真实的Cmd+Q键盘事件给指定应用
    private func sendCmdQEvent(to app: NSRunningApplication) {
        // 设置标志，避免我们自己捕获这个事件
        isSendingQuitEvent = true

        // 先激活目标应用（确保焦点在目标应用上）
        app.activate(options: [.activateIgnoringOtherApps])

        // 短暂延迟，确保应用激活完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self else { return }

            // 创建Q键按下事件 (keyCode 12)
            guard let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: 12, keyDown: true) else {
                Logger.shared.log("无法创建键盘事件", level: .error)
                self.isSendingQuitEvent = false
                return
            }

            // 创建Q键释放事件
            guard let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 12, keyDown: false) else {
                Logger.shared.log("无法创建键盘事件", level: .error)
                self.isSendingQuitEvent = false
                return
            }

            // 添加Command修饰键
            keyDownEvent.flags = .maskCommand
            keyUpEvent.flags = .maskCommand

            // 发送事件到前台应用
            keyDownEvent.post(tap: .cghidEventTap)
            keyUpEvent.post(tap: .cghidEventTap)

            Logger.shared.log("已发送Cmd+Q事件给目标应用", level: .debug)

            // 延迟重置标志，确保事件已经处理完
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.isSendingQuitEvent = false
            }
        }
    }

    private func resetState() {
        pressTimer?.invalidate()
        pressTimer = nil
        overlayWindow.hide()
        isQPressed = false
        isWaitingToQuit = false
        targetApp = nil  // 清除目标应用
    }
}
