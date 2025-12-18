//
//  MenuBarManager.swift
//  SlowQuit
//
//  Created by Claude on 2025-10-12.
//

import Cocoa

class MenuBarManager {
    private var statusItem: NSStatusItem?
    private let eventMonitor: EventMonitor
    private let onToggleEnabled: (Bool) -> Void
    private let onShowSettings: () -> Void

    private var isEnabled = true

    init(eventMonitor: EventMonitor, onToggleEnabled: @escaping (Bool) -> Void, onShowSettings: @escaping () -> Void) {
        self.eventMonitor = eventMonitor
        self.onToggleEnabled = onToggleEnabled
        self.onShowSettings = onShowSettings

        setupMenuBar()
    }

    private func setupMenuBar() {
        // 创建菜单栏项
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            // 使用系统图标，配置更大的尺寸和权重
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
                .applying(.init(scale: .medium))

            button.image = NSImage(
                systemSymbolName: "q.square.fill",
                accessibilityDescription: "SlowQuit"
            )?.withSymbolConfiguration(config)

            button.image?.isTemplate = true  // 自动适配深色/浅色模式
        }

        // 创建菜单
        let menu = NSMenu()

        // 应用名称（标题）
        let titleItem = NSMenuItem(title: "SlowQuit", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

        // 启用/禁用开关
        let toggleItem = NSMenuItem(
            title: L10n.menuEnable,
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        toggleItem.target = self
        toggleItem.state = isEnabled ? .on : .off
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        // 设置
        let settingsItem = NSMenuItem(
            title: L10n.menuSettings,
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // 开机自启动
        let launchAtLoginItem = NSMenuItem(
            title: L10n.menuLaunchAtLogin,
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLoginItem.target = self
        launchAtLoginItem.state = LaunchAtLoginManager.shared.isEnabled ? .on : .off
        menu.addItem(launchAtLoginItem)

        menu.addItem(NSMenuItem.separator())

        // 关于
        let aboutItem = NSMenuItem(
            title: L10n.menuAbout,
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        // 检查更新
        let checkUpdateItem = NSMenuItem(
            title: L10n.menuCheckUpdate,
            action: #selector(checkForUpdate),
            keyEquivalent: ""
        )
        checkUpdateItem.target = self
        menu.addItem(checkUpdateItem)

        menu.addItem(NSMenuItem.separator())

        // 打开日志文件夹
        let openLogsItem = NSMenuItem(
            title: L10n.menuOpenLogs,
            action: #selector(openLogFolder),
            keyEquivalent: ""
        )
        openLogsItem.target = self
        menu.addItem(openLogsItem)

        menu.addItem(NSMenuItem.separator())

        // 退出
        let quitItem = NSMenuItem(
            title: L10n.menuQuit,
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func toggleEnabled(_ sender: NSMenuItem) {
        isEnabled.toggle()
        sender.state = isEnabled ? .on : .off
        onToggleEnabled(isEnabled)

        Logger.shared.log("功能\(isEnabled ? L10n.logEnabled : L10n.logDisabled)")
    }

    @objc private func showSettings() {
        onShowSettings()
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        do {
            if LaunchAtLoginManager.shared.isEnabled {
                try LaunchAtLoginManager.shared.disable()
                sender.state = .off
            } else {
                try LaunchAtLoginManager.shared.enable()
                sender.state = .on
            }
        } catch LaunchAtLoginError.manualSetupRequired {
            // macOS 12.0 需要手动设置
            Logger.shared.log("macOS 12 需要手动设置开机自启动", level: .info)
            showInfo(message: L10n.errorLaunchAtLoginManualSetup)
            // 切换菜单项状态（假设用户会按照指引操作）
            sender.state = sender.state == .on ? .off : .on
        } catch {
            Logger.shared.log("切换开机自启动失败: \(error)", level: .error)
            showError(message: error.localizedDescription)
        }
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "SlowQuit"
        alert.informativeText = """
        \(L10n.aboutVersion)

        \(L10n.aboutDescription)
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.alertOk)
        alert.runModal()
    }

    @objc private func checkForUpdate() {
        Logger.shared.log("用户手动检查更新", level: .info)
        UpdateChecker.shared.checkForUpdate { updateInfo, error in
            if let error = error {
                self.showError(message: String(format: L10n.updateCheckFailed, error.localizedDescription))
            } else if let updateInfo = updateInfo {
                // 使用回调处理更新响应
                UpdateChecker.shared.handleUpdateResponseWithCallback(updateInfo) { hasUpdate in
                    if !hasUpdate {
                        let alert = NSAlert()
                        alert.messageText = L10n.updateNoNewVersion
                        alert.informativeText = L10n.updateAlreadyLatest
                        alert.alertStyle = .informational
                        alert.addButton(withTitle: L10n.alertOk)
                        alert.runModal()
                    }
                }
            }
        }
    }

    @objc private func openLogFolder() {
        let logFolderURL = Logger.shared.getLogFolderURL()
        NSWorkspace.shared.open(logFolderURL)
        Logger.shared.log("用户打开日志文件夹", level: .info)
    }

    @objc private func quitApp() {
        Logger.shared.log("用户手动退出应用")
        NSApplication.shared.terminate(nil)
    }

    private func showError(message: String) {
        let alert = NSAlert()
        alert.messageText = L10n.alertError
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.alertConfirm)
        alert.runModal()
    }

    private func showInfo(message: String) {
        let alert = NSAlert()
        alert.messageText = "SlowQuit"
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.alertOk)
        alert.runModal()
    }
}
