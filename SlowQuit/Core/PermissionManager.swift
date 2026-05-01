//
//  PermissionManager.swift
//  SlowQuit
//
//  Created by Claude on 2025-10-12.
//

import Cocoa
import ApplicationServices
import CoreGraphics

struct EventPermissionStatus {
    let canListenEvents: Bool
    let canPostEvents: Bool

    var isFullyGranted: Bool {
        canListenEvents && canPostEvents
    }
}

class PermissionManager {

    /// 检查是否已授予事件监听和事件发送权限。不触发系统授权弹窗。
    func checkEventPermissions() -> EventPermissionStatus {
        return EventPermissionStatus(
            canListenEvents: CGPreflightListenEventAccess(),
            canPostEvents: AXIsProcessTrusted()
        )
    }

    /// 兼容旧调用：完整事件权限才视为可用。
    func checkAccessibilityPermission() -> Bool {
        return checkEventPermissions().isFullyGranted
    }

    /// 由用户明确操作触发缺失权限请求。
    @discardableResult
    func requestMissingEventPermissions() -> EventPermissionStatus {
        let status = checkEventPermissions()

        if !status.canListenEvents {
            requestListenEventAccess()
        }

        if !status.canPostEvents {
            requestPostEventAccess()
        }

        return checkEventPermissions()
    }

    @discardableResult
    func requestListenEventAccess() -> EventPermissionStatus {
        Logger.shared.log("请求事件监听权限", level: .info)
        _ = CGRequestListenEventAccess()
        return checkEventPermissions()
    }

    @discardableResult
    func requestPostEventAccess() -> EventPermissionStatus {
        Logger.shared.log("请求辅助功能权限", level: .info)
        promptForAccessibilityPermission()
        return checkEventPermissions()
    }

    func openInputMonitoringSettings() {
        openPrivacyPreferences(anchor: "Privacy_ListenEvent")
    }

    func showInputMonitoringGuide() {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)

            let alert = NSAlert()
            alert.messageText = L10n.permissionInputMonitoringGuideTitle
            alert.informativeText = L10n.permissionInputMonitoringGuideMessage
            alert.alertStyle = .informational
            alert.addButton(withTitle: L10n.alertOk)
            alert.runModal()
        }
    }

    func openAccessibilitySettings() {
        openPrivacyPreferences(anchor: "Privacy_Accessibility")
    }

    private func openPrivacyPreferences(anchor: String) {
        let prefpaneURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)")!
        NSWorkspace.shared.open(prefpaneURL)
    }

    private func promptForAccessibilityPermission() {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
