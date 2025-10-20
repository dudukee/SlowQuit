//
//  AppListManager.swift
//  SlowQuit
//
//  Created by Claude on 2025-10-19.
//

import Foundation
import Cocoa

/// 应用信息模型
struct AppInfo: Codable, Identifiable, Hashable {
    let id: String // bundle identifier
    let name: String

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    init(from app: NSRunningApplication) {
        self.id = app.bundleIdentifier ?? "unknown"
        self.name = app.localizedName ?? "Unknown"
    }
}

/// 列表模式
enum ListMode: String, Codable {
    case global = "global"       // 全局模式 (所有应用)
    case whitelist = "whitelist" // 白名单模式 (仅列表中的应用)
    case blacklist = "blacklist" // 黑名单模式 (排除列表中的应用)
}

/// 管理应用白名单/黑名单
class AppListManager {
    static let shared = AppListManager()

    // UserDefaults keys
    private enum Keys {
        static let listMode = "listMode"
        static let whitelist = "whitelist"
        static let blacklist = "blacklist"
    }

    // 通知名称
    static let listDidChangeNotification = Notification.Name("appListDidChange")
    static let modeDidChangeNotification = Notification.Name("listModeDidChange")

    private let userDefaults: UserDefaults

    // 列表模式
    var listMode: ListMode {
        get {
            guard let rawValue = userDefaults.string(forKey: Keys.listMode),
                  let mode = ListMode(rawValue: rawValue) else {
                return .global // 默认全局模式
            }
            return mode
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: Keys.listMode)
            NotificationCenter.default.post(name: Self.modeDidChangeNotification, object: self)
            Logger.shared.log("列表模式已更新: \(newValue.rawValue)", level: .info)
        }
    }

    // 白名单
    var whitelist: [AppInfo] {
        get {
            guard let data = userDefaults.data(forKey: Keys.whitelist),
                  let list = try? JSONDecoder().decode([AppInfo].self, from: data) else {
                return []
            }
            return list
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                userDefaults.set(data, forKey: Keys.whitelist)
                NotificationCenter.default.post(name: Self.listDidChangeNotification, object: self)
                Logger.shared.log("白名单已更新，共 \(newValue.count) 个应用", level: .info)
            }
        }
    }

    // 黑名单
    var blacklist: [AppInfo] {
        get {
            guard let data = userDefaults.data(forKey: Keys.blacklist),
                  let list = try? JSONDecoder().decode([AppInfo].self, from: data) else {
                return []
            }
            return list
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                userDefaults.set(data, forKey: Keys.blacklist)
                NotificationCenter.default.post(name: Self.listDidChangeNotification, object: self)
                Logger.shared.log("黑名单已更新，共 \(newValue.count) 个应用", level: .info)
            }
        }
    }

    // 获取当前激活的列表（根据模式）
    var currentList: [AppInfo] {
        get {
            switch listMode {
            case .global:
                return []
            case .whitelist:
                return whitelist
            case .blacklist:
                return blacklist
            }
        }
    }

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - 列表操作

    /// 添加应用到当前列表
    func addApp(_ app: AppInfo) {
        switch listMode {
        case .whitelist:
            var list = whitelist
            if !list.contains(where: { $0.id == app.id }) {
                list.append(app)
                whitelist = list
            }
        case .blacklist:
            var list = blacklist
            if !list.contains(where: { $0.id == app.id }) {
                list.append(app)
                blacklist = list
            }
        case .global:
            break // 全局模式不需要列表
        }
    }

    /// 从当前列表移除应用
    func removeApp(_ app: AppInfo) {
        switch listMode {
        case .whitelist:
            var list = whitelist
            list.removeAll { $0.id == app.id }
            whitelist = list
        case .blacklist:
            var list = blacklist
            list.removeAll { $0.id == app.id }
            blacklist = list
        case .global:
            break // 全局模式不需要列表
        }
    }

    /// 检查应用是否在白名单中
    func isInWhitelist(_ bundleId: String) -> Bool {
        return whitelist.contains { $0.id == bundleId }
    }

    /// 检查应用是否在黑名单中
    func isInBlacklist(_ bundleId: String) -> Bool {
        return blacklist.contains { $0.id == bundleId }
    }

    // MARK: - 判断逻辑

    /// 判断是否应对指定应用应用延迟退出
    /// - Parameter bundleId: 应用的 Bundle Identifier
    /// - Returns: true 表示应用延迟，false 表示直接放行
    func shouldApplyDelay(for bundleId: String?) -> Bool {
        guard let bundleId = bundleId else {
            return false // 无法获取 bundleId，不应用延迟
        }

        switch listMode {
        case .global:
            // 全局模式：所有应用都应用延迟
            return true

        case .whitelist:
            // 白名单模式：只对白名单中的应用应用延迟
            return isInWhitelist(bundleId)

        case .blacklist:
            // 黑名单模式：对黑名单中的应用不应用延迟
            return !isInBlacklist(bundleId)
        }
    }

    // MARK: - 获取应用

    /// 获取所有已安装的应用（排除已在当前列表中的应用）
    func getInstalledApps() -> [AppInfo] {
        let fileManager = FileManager.default
        let applicationsPaths = [
            "/Applications",
            "/System/Applications",
            NSHomeDirectory() + "/Applications"
        ]

        var apps: [AppInfo] = []
        let currentListIds = Set(currentList.map { $0.id })

        for path in applicationsPaths {
            guard let appURLs = try? fileManager.contentsOfDirectory(
                at: URL(fileURLWithPath: path),
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for appURL in appURLs {
                // 只处理 .app 文件
                guard appURL.pathExtension == "app" else { continue }

                // 获取 Bundle
                guard let bundle = Bundle(url: appURL),
                      let bundleId = bundle.bundleIdentifier,
                      let appName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ??
                                   bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String else {
                    continue
                }

                // 排除 SlowQuit 本身
                if bundleId == Bundle.main.bundleIdentifier {
                    continue
                }

                // 排除已在列表中的
                if currentListIds.contains(bundleId) {
                    continue
                }

                // 避免重复
                if !apps.contains(where: { $0.id == bundleId }) {
                    apps.append(AppInfo(id: bundleId, name: appName))
                }
            }
        }

        return apps.sorted { $0.name < $1.name }
    }

    /// 获取所有正在运行的应用（排除已在当前列表中的应用）
    func getRunningApps() -> [AppInfo] {
        let runningApps = NSWorkspace.shared.runningApplications
        let currentListIds = Set(currentList.map { $0.id })

        return runningApps.compactMap { app -> AppInfo? in
            // 过滤条件：
            // 1. 有 bundleIdentifier
            // 2. 有本地化名称
            // 3. 不在当前列表中
            guard let bundleId = app.bundleIdentifier,
                  let appName = app.localizedName,
                  app.activationPolicy == .regular,
                  !currentListIds.contains(bundleId) else {
                return nil
            }

            // 排除 SlowQuit 本身
            if bundleId == Bundle.main.bundleIdentifier {
                return nil
            }

            return AppInfo(id: bundleId, name: appName)
        }
        .sorted { $0.name < $1.name } // 按名称排序
    }
}
