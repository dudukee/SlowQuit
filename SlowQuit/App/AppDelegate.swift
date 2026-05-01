//
//  AppDelegate.swift
//  SlowQuit
//
//  Created by Claude on 2025-10-12.
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarManager: MenuBarManager?
    private var eventMonitor: EventMonitor?
    private var overlayWindow: OverlayWindow?
    private var settingsWindow: SettingsWindow?
    private var permissionGuideWindow: PermissionGuideWindow?
    private var healthMonitor: HealthMonitor?
    private var permissionManager: PermissionManager?
    private var shouldShowSettingsWhenPermissionsReady = false
    private let initialSettingsShownKey = "initialSettingsShownAfterPermissionGrant"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 初始化时隐藏程序坞图标
        DockIconManager.shared.hideDockIcon()

        // 配置日志级别
        // 开发环境使用 .debug，生产环境使用 .warning 以降低功耗
        #if DEBUG
        Logger.shared.minimumLogLevel = .debug
        #else
        Logger.shared.minimumLogLevel = .warning
        #endif

        Logger.shared.log("应用启动", level: .info)

        // 检查更新(每天只检查一次)
        if UpdateChecker.shared.shouldCheckForUpdate() {
            // 延迟5秒后检查更新,避免阻塞启动并降低启动时的资源竞争
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                UpdateChecker.shared.checkForUpdate()
            }
        }

        // 初始化权限管理器
        permissionManager = PermissionManager()

        // 初始化叠加层窗口
        overlayWindow = OverlayWindow()

        // 初始化事件监听器
        eventMonitor = EventMonitor(overlayWindow: overlayWindow!)

        // 初始化健康监控
        healthMonitor = HealthMonitor(eventMonitor: eventMonitor!)

        // 初始化菜单栏管理器
        menuBarManager = MenuBarManager(
            eventMonitor: eventMonitor!,
            onToggleEnabled: { [weak self] enabled in
                if enabled {
                    self?.startProtectionIfPermitted(showPromptIfNeeded: true)
                } else {
                    self?.eventMonitor?.stop()
                    self?.healthMonitor?.stop()
                }
            },
            onCheckPermissions: { [weak self] in
                self?.showPermissionGuide()
            },
            onShowSettings: { [weak self] in
                self?.showSettings()
            }
        )

        startProtectionIfPermitted(showPromptIfNeeded: true)

        Logger.shared.log("应用初始化完成", level: .info)
    }

    private func startProtectionIfPermitted(showPromptIfNeeded: Bool) {
        guard let permissionManager = permissionManager,
              let eventMonitor = eventMonitor,
              let healthMonitor = healthMonitor else { return }

        let status = permissionManager.checkEventPermissions()
        guard status.isFullyGranted else {
            Logger.shared.log("事件权限不足，暂不启动快捷键保护", level: .warning)
            eventMonitor.stop()
            healthMonitor.stop()

            if showPromptIfNeeded {
                showPermissionGuide(showSettingsWhenReady: shouldShowSettingsAfterInitialPermissionGrant())
            }
            return
        }

        eventMonitor.start()
        healthMonitor.start()
    }

    private func showSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindow()
        }
        settingsWindow?.showWindow()
    }

    private func showPermissionGuide(showSettingsWhenReady: Bool = false) {
        guard let permissionManager = permissionManager else { return }

        shouldShowSettingsWhenPermissionsReady = shouldShowSettingsWhenPermissionsReady || showSettingsWhenReady
        if permissionGuideWindow == nil {
            permissionGuideWindow = PermissionGuideWindow(
                permissionManager: permissionManager,
                onPermissionsReady: { [weak self] in
                    self?.startProtectionIfPermitted(showPromptIfNeeded: false)
                    self?.showInitialSettingsIfNeeded()
                }
            )
        }
        permissionGuideWindow?.showWindow()
    }

    private func shouldShowSettingsAfterInitialPermissionGrant() -> Bool {
        !UserDefaults.standard.bool(forKey: initialSettingsShownKey)
    }

    private func markInitialSettingsShown() {
        UserDefaults.standard.set(true, forKey: initialSettingsShownKey)
    }

    private func showInitialSettingsIfNeeded() {
        guard shouldShowSettingsWhenPermissionsReady else { return }
        shouldShowSettingsWhenPermissionsReady = false
        markInitialSettingsShown()
        showSettings()
    }

    func applicationWillTerminate(_ notification: Notification) {
        eventMonitor?.stop()
        healthMonitor?.stop()
        Logger.shared.log("应用退出", level: .info)
        Logger.shared.flush()  // 确保所有日志都被写入
    }
}
