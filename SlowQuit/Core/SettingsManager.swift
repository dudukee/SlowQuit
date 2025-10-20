//
//  SettingsManager.swift
//  SlowQuit
//
//  Created by Claude on 2025-10-19.
//

import Foundation

class SettingsManager {
    static let shared = SettingsManager()

    // UserDefaults keys
    private enum Keys {
        static let quitDelay = "quitDelay"
    }

    // 通知名称
    static let quitDelayDidChangeNotification = Notification.Name("quitDelayDidChange")

    // 延迟时长范围
    let minDelay: TimeInterval = 0.5
    let maxDelay: TimeInterval = 3.0
    let defaultDelay: TimeInterval = 1.0

    private let userDefaults: UserDefaults

    // 退出延迟时长 (0.5 - 3.0 秒)
    var quitDelay: TimeInterval {
        get {
            let value = userDefaults.double(forKey: Keys.quitDelay)
            // 如果是首次启动或值无效,返回默认值
            if value == 0 {
                return defaultDelay
            }
            // 确保值在有效范围内
            return max(minDelay, min(maxDelay, value))
        }
        set {
            // 限制在有效范围内
            let clampedValue = max(minDelay, min(maxDelay, newValue))
            userDefaults.set(clampedValue, forKey: Keys.quitDelay)

            // 发送通知
            NotificationCenter.default.post(
                name: Self.quitDelayDidChangeNotification,
                object: self,
                userInfo: ["quitDelay": clampedValue]
            )

            Logger.shared.log(String(format: "延迟时长已更新: %.1f秒", clampedValue), level: .info)
        }
    }

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // 重置为默认值
    func resetToDefault() {
        quitDelay = defaultDelay
    }
}
