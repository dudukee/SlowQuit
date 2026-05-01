//
//  PermissionManager.swift
//  SlowQuit
//
//  Created by Claude on 2025-10-12.
//

import Cocoa
import ApplicationServices

struct EventPermissionStatus {
    let canUseAccessibility: Bool

    var isFullyGranted: Bool {
        canUseAccessibility
    }
}

class PermissionManager {

    /// 检查是否已授予辅助功能权限。不触发系统授权弹窗。
    func checkEventPermissions() -> EventPermissionStatus {
        return EventPermissionStatus(
            canUseAccessibility: AXIsProcessTrusted()
        )
    }

    /// 兼容旧调用：辅助功能权限可用才视为可用。
    func checkAccessibilityPermission() -> Bool {
        return checkEventPermissions().isFullyGranted
    }

    /// 由用户明确操作触发缺失权限请求。
    @discardableResult
    func requestMissingEventPermissions() -> EventPermissionStatus {
        let status = checkEventPermissions()

        if !status.canUseAccessibility {
            requestAccessibilityPermission()
        }

        return checkEventPermissions()
    }

    @discardableResult
    func requestAccessibilityPermission() -> EventPermissionStatus {
        Logger.shared.log("请求辅助功能权限", level: .info)
        promptForAccessibilityPermission()
        return checkEventPermissions()
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
