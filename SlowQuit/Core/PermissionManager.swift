//
//  PermissionManager.swift
//  SlowQuit
//
//  Created by Claude on 2025-10-12.
//

import Cocoa
import ApplicationServices

class PermissionManager {

    /// 检查是否已授予辅助功能权限
    func checkAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }

    /// 请求辅助功能权限
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)

        // 显示友好提示
        showPermissionAlert()
    }

    /// 显示权限请求提示对话框
    private func showPermissionAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = L10n.permissionTitle
            alert.informativeText = L10n.permissionMessage
            alert.alertStyle = .informational
            alert.addButton(withTitle: L10n.permissionOpenSettings)
            alert.addButton(withTitle: L10n.permissionLater)

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                self.openAccessibilityPreferences()
            }
        }
    }

    /// 打开系统辅助功能设置
    private func openAccessibilityPreferences() {
        let prefpaneURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(prefpaneURL)
    }
}
