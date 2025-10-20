//
//  UpdateChecker.swift
//  SlowQuit
//
//  Created by Claude on 2025-10-19.
//

import Foundation
import AppKit

// MARK: - Update Response Model

struct UpdateResponse: Codable {
    let latestVersion: String
    let latestBuild: String
    let downloadURL: String
    let releaseNotes: String
    let releaseNotesEn: String
    let forceUpdate: Bool
    
    enum CodingKeys: String, CodingKey {
        case latestVersion = "latest_version"
        case latestBuild = "latest_build"
        case downloadURL = "download_url"
        case releaseNotes = "release_notes"
        case releaseNotesEn = "release_notes_en"
        case forceUpdate = "force_update"
    }
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 依次解码每个属性
        self.latestVersion = try container.decode(String.self, forKey: .latestVersion)
        self.latestBuild = try container.decode(String.self, forKey: .latestBuild)
        self.downloadURL = try container.decode(String.self, forKey: .downloadURL)
        self.releaseNotes = try container.decode(String.self, forKey: .releaseNotes)
        self.releaseNotesEn = try container.decode(String.self, forKey: .releaseNotesEn)
        self.forceUpdate = try container.decode(Bool.self, forKey: .forceUpdate)
    }
}

// MARK: - Update Checker

class UpdateChecker {
    static let shared = UpdateChecker()
    
    // 配置更新检查的URL
    private let updateCheckURL = "https://raw.githubusercontent.com/dudukee/slowquit-releases/refs/heads/main/update.json"
    
    private let lastCheckKey = "LastUpdateCheckDate"
    private let skipVersionKey = "SkipUpdateVersion"
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 检查是否需要进行更新检查(每天只检查一次)
    func shouldCheckForUpdate() -> Bool {
        guard let lastCheckDate = UserDefaults.standard.object(forKey: lastCheckKey) as? Date else {
            return true
        }
        
        let calendar = Calendar.current
        let now = Date()
        
        // 检查是否已经过了一天
        if let daysDifference = calendar.dateComponents([.day], from: lastCheckDate, to: now).day,
           daysDifference >= 1 {
            return true
        }
        
        return false
    }
    
    /// 执行更新检查
    func checkForUpdate(completion: ((UpdateResponse?, Error?) -> Void)? = nil) {
        guard let url = URL(string: updateCheckURL) else {
            Logger.shared.log("无效的更新检查URL", level: .error)
            completion?(nil, NSError(domain: "UpdateChecker", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        Logger.shared.log("开始检查更新", level: .info)
        
        // 配置请求超时和缓存策略
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0 // 10秒超时
        request.cachePolicy = .reloadIgnoringLocalCacheData // 不使用缓存,确保获取最新版本信息
        
        // 配置 URLSession 以降低网络耗电
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 15.0
        config.waitsForConnectivity = false // 无网络时立即失败,避免长时间等待
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        let session = URLSession(configuration: config)
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                Logger.shared.log("更新检查失败: \(error.localizedDescription)", level: .error)
                DispatchQueue.main.async {
                    completion?(nil, error)
                }
                return
            }
            
            guard let data = data else {
                Logger.shared.log("更新检查返回空数据", level: .error)
                DispatchQueue.main.async {
                    completion?(nil, NSError(domain: "UpdateChecker", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data"]))
                }
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let updateInfo = try decoder.decode(UpdateResponse.self, from: data)
                
                Logger.shared.log("更新检查成功: 最新版本 \(updateInfo.latestVersion)", level: .info)
                
                // 更新最后检查时间
                UserDefaults.standard.set(Date(), forKey: self.lastCheckKey)
                
                DispatchQueue.main.async {
                    // 如果有completion回调，让调用方处理更新响应
                    // 否则使用自动更新逻辑
                    if completion != nil {
                        completion?(updateInfo, nil)
                    } else {
                        self.handleUpdateResponse(updateInfo)
                        completion?(updateInfo, nil)
                    }
                }
            } catch {
                Logger.shared.log("解析更新数据失败: \(error.localizedDescription)", level: .error)
                DispatchQueue.main.async {
                    completion?(nil, error)
                }
            }
        }
        
        task.resume()
    }
    
    /// 比较构建号（数字比较）
    func compareBuilds(_ build1: String, _ build2: String) -> ComparisonResult {
        // 将构建号转换为整数进行比较
        guard let buildNum1 = Int(build1), let buildNum2 = Int(build2) else {
            // 如果无法转换为整数，使用字符串数字比较
            return build1.compare(build2, options: .numeric)
        }
        
        if buildNum1 < buildNum2 {
            return .orderedAscending
        } else if buildNum1 > buildNum2 {
            return .orderedDescending
        } else {
            return .orderedSame
        }
    }
    
    // MARK: - Private Methods
    
    /// 根据用户系统语言获取合适的发布说明
    private func getLocalizedReleaseNotes(_ updateInfo: UpdateResponse) -> String {
        // 获取应用当前使用的语言
        let currentLanguage = getCurrentAppLanguage()
        
        // 检查应用当前语言是否为中文
        if currentLanguage.hasPrefix("zh") {
            // 中文用户，优先使用中文发布说明
            return updateInfo.releaseNotes
        } else {
            return updateInfo.releaseNotesEn
        }
    }
    
    /// 获取应用当前使用的语言
    private func getCurrentAppLanguage() -> String {
        // 方法1: 通过获取本地化字符串来确定当前语言
        let testKey = "about.version_label" // 使用一个已知的本地化键
        
        // 获取英文和中文的本地化字符串
        let enString = NSLocalizedString(testKey, tableName: "Localizable", bundle: Bundle(path: Bundle.main.path(forResource: "en", ofType: "lproj")!) ?? Bundle.main, value: "", comment: "")
        let zhHansString = NSLocalizedString(testKey, tableName: "Localizable", bundle: Bundle(path: Bundle.main.path(forResource: "zh-Hans", ofType: "lproj")!) ?? Bundle.main, value: "", comment: "")
        
        // 获取当前应用的本地化字符串
        let currentString = NSLocalizedString(testKey, comment: "")
        
        // 比较确定当前语言
        if currentString == zhHansString && currentString != enString {
            return "zh-Hans"
        } else {
            return "en"
        }
    }
    
    private func handleUpdateResponse(_ updateInfo: UpdateResponse) {
        let currentBuild = getCurrentBuild()
        let currentVersion = getCurrentVersion()
        
        Logger.shared.log("当前版本: \(currentVersion) (Build \(currentBuild)), 最新版本: \(updateInfo.latestVersion) (Build \(updateInfo.latestBuild))", level: .debug)
        
        // 检查是否有新版本（按照构建号比较）
        if compareBuilds(updateInfo.latestBuild, currentBuild) == .orderedDescending {
            // 检查是否是强制更新
            if updateInfo.forceUpdate {
                showForceUpdateAlert(updateInfo: updateInfo)
            } else {
                // 检查用户是否选择跳过此版本（使用构建号作为标识）
                let skippedBuild = UserDefaults.standard.string(forKey: skipVersionKey)
                if skippedBuild != updateInfo.latestBuild {
                    showOptionalUpdateAlert(updateInfo: updateInfo)
                } else {
                    Logger.shared.log("用户已跳过版本 \(updateInfo.latestVersion) (Build \(updateInfo.latestBuild))", level: .debug)
                }
            }
        } else {
            Logger.shared.log("当前已是最新版本", level: .info)
        }
    }
    
    /// 处理更新响应并返回是否有更新
    func handleUpdateResponseWithCallback(_ updateInfo: UpdateResponse, completion: @escaping (Bool) -> Void) {
        let currentBuild = getCurrentBuild()
        let currentVersion = getCurrentVersion()
        
        Logger.shared.log("当前版本: \(currentVersion) (Build \(currentBuild)), 最新版本: \(updateInfo.latestVersion) (Build \(updateInfo.latestBuild))", level: .debug)
        
        // 检查是否有新版本（按照构建号比较）
        if compareBuilds(updateInfo.latestBuild, currentBuild) == .orderedDescending {
            // 检查是否是强制更新
            if updateInfo.forceUpdate {
                showForceUpdateAlert(updateInfo: updateInfo)
                completion(true)
            } else {
                // 检查用户是否选择跳过此版本（使用构建号作为标识）
                let skippedBuild = UserDefaults.standard.string(forKey: skipVersionKey)
                if skippedBuild != updateInfo.latestBuild {
                    showOptionalUpdateAlert(updateInfo: updateInfo)
                    completion(true)
                } else {
                    Logger.shared.log("用户已跳过版本 \(updateInfo.latestVersion) (Build \(updateInfo.latestBuild))", level: .debug)
                    completion(false)
                }
            }
        } else {
            Logger.shared.log("当前已是最新版本", level: .info)
            completion(false)
        }
    }
    
    private func showForceUpdateAlert(updateInfo: UpdateResponse) {
        let alert = NSAlert()
        alert.messageText = L10n.updateAvailableTitle
        
        let localizedReleaseNotes = getLocalizedReleaseNotes(updateInfo)
        
        alert.informativeText = """
        \(L10n.updateNewVersion) \(updateInfo.latestVersion)
        
        \(localizedReleaseNotes)
        
        \(L10n.updateForceRequired)
        """
        alert.alertStyle = .critical
        alert.addButton(withTitle: L10n.updateNow)
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openDownloadURL(updateInfo.downloadURL)
        }
    }
    
    private func showOptionalUpdateAlert(updateInfo: UpdateResponse) {
        let alert = NSAlert()
        alert.messageText = L10n.updateAvailableTitle
        
        let localizedReleaseNotes = getLocalizedReleaseNotes(updateInfo)
        
        alert.informativeText = """
        \(L10n.updateNewVersion) \(updateInfo.latestVersion)
        
        \(localizedReleaseNotes)
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.updateNow)
        alert.addButton(withTitle: L10n.updateLater)
        alert.addButton(withTitle: L10n.updateSkip)
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:
            // 立即更新
            openDownloadURL(updateInfo.downloadURL)
            
        case .alertSecondButtonReturn:
            // 稍后提醒
            Logger.shared.log("用户选择稍后更新", level: .debug)
            
        case .alertThirdButtonReturn:
            // 跳过此版本（保存构建号）
            UserDefaults.standard.set(updateInfo.latestBuild, forKey: skipVersionKey)
            Logger.shared.log("用户跳过版本 \(updateInfo.latestVersion) (Build \(updateInfo.latestBuild))", level: .debug)
            
        default:
            break
        }
    }
    
    private func openDownloadURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            Logger.shared.log("无效的下载URL: \(urlString)", level: .error)
            return
        }
        
        NSWorkspace.shared.open(url)
        Logger.shared.log("打开下载URL: \(urlString)", level: .info)
    }
    
    private func getCurrentVersion() -> String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        return "1.0"
    }
    
    private func getCurrentBuild() -> String {
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return build
        }
        return "1"
    }
}
