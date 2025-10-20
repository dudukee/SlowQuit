//
//  LaunchAtLoginManager.swift
//  SlowQuit
//
//  Created by Claude on 2025-10-12.
//

import Foundation
import ServiceManagement
import Cocoa

class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()

    private init() {}

    /// 检查是否已启用开机自启动
    var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            // macOS 13+ 使用新 API
            return SMAppService.mainApp.status == .enabled
        } else {
            // macOS 12.0 - 从 UserDefaults 读取（因为 SMLoginItemSetEnabled 不可靠）
            return UserDefaults.standard.bool(forKey: "launchAtLoginManuallySet")
        }
    }

    /// 检查是否支持自动设置开机自启动
    var isAutoSetupSupported: Bool {
        if #available(macOS 13.0, *) {
            return true
        } else {
            return false
        }
    }

    /// 启用开机自启动
    func enable() throws {
        if #available(macOS 13.0, *) {
            // macOS 13+ 使用新 API
            try SMAppService.mainApp.register()
            Logger.shared.log("开机自启动已启用 (SMAppService)", level: .info)
        } else {
            // macOS 12.0 - 打开系统设置让用户手动添加
            openLoginItemsSettings()
            // 标记为已设置（假设用户会按指引操作）
            UserDefaults.standard.set(true, forKey: "launchAtLoginManuallySet")
            throw LaunchAtLoginError.manualSetupRequired
        }
    }

    /// 禁用开机自启动
    func disable() throws {
        if #available(macOS 13.0, *) {
            // macOS 13+ 使用新 API
            try SMAppService.mainApp.unregister()
            Logger.shared.log("开机自启动已禁用 (SMAppService)", level: .info)
        } else {
            // macOS 12.0 - 打开系统设置让用户手动移除
            openLoginItemsSettings()
            // 标记为未设置
            UserDefaults.standard.set(false, forKey: "launchAtLoginManuallySet")
            throw LaunchAtLoginError.manualSetupRequired
        }
    }

    /// 打开系统设置的登录项页面
    private func openLoginItemsSettings() {
        // macOS 12 的登录项设置路径
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.users") {
            NSWorkspace.shared.open(url)
            Logger.shared.log("已打开系统设置 - 用户与群组", level: .info)
        }
    }
}

enum LaunchAtLoginError: Error {
    case enableFailed
    case disableFailed
    case manualSetupRequired

    var localizedDescription: String {
        switch self {
        case .enableFailed:
            return L10n.errorLaunchAtLoginEnable
        case .disableFailed:
            return L10n.errorLaunchAtLoginDisable
        case .manualSetupRequired:
            return L10n.errorLaunchAtLoginManualSetup
        }
    }
}
