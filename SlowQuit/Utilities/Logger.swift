//
//  Logger.swift
//  SlowQuit
//
//  Created by Claude on 2025-10-12.
//

import Foundation

enum LogLevel: Int, Comparable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3

    var displayString: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        }
    }

    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

class Logger {
    static let shared = Logger()

    private let logDirectory: URL
    private var currentLogFileURL: URL
    private let dateFormatter: DateFormatter
    private let fileDateFormatter: DateFormatter
    private let maxLogFileSize: Int = 1 * 1024 * 1024 // 1MB
    private let maxLogAge: TimeInterval = 30 * 24 * 60 * 60 // 30天

    // 日志级别控制：只记录此级别及以上的日志
    // 生产环境建议设置为 .warning，开发环境使用 .debug
    var minimumLogLevel: LogLevel = .warning

    // 异步日志队列
    private let logQueue = DispatchQueue(label: "com.slowquit.logger", qos: .utility)
    private var logBuffer: [String] = []
    private let bufferSize = 10  // 缓冲10条日志后批量写入
    private var flushTimer: Timer?
    private var lastRotationCheck: Date = Date()

    private init() {
        // 获取应用支持目录
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        logDirectory = appSupport.appendingPathComponent("SlowQuit", isDirectory: true)

        // 创建目录（如果不存在）
        try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)

        // 日志消息时间戳格式化器
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        // 日志文件名日期格式化器
        fileDateFormatter = DateFormatter()
        fileDateFormatter.dateFormat = "yyyy-MM-dd"

        // 当前日志文件路径（使用当前日期）
        let todayString = fileDateFormatter.string(from: Date())
        currentLogFileURL = logDirectory.appendingPathComponent("app-\(todayString).log")

        // 清理过期日志文件
        cleanupOldLogs()

        // 检查并轮转日志文件
        rotateLogFileIfNeeded()

        // 启动定期刷新计时器（每5秒刷新一次缓冲）
        DispatchQueue.main.async { [weak self] in
            self?.flushTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
                self?.flush()
            }
            // 添加容差,允许系统合并定时器唤醒以降低功耗
            self?.flushTimer?.tolerance = 1.0
        }
    }

    /// 记录日志
    func log(_ message: String, level: LogLevel = .info) {
        // 过滤低于最小级别的日志
        guard level >= minimumLogLevel else { return }

        let timestamp = dateFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] \(level.displayString): \(message)\n"

        // 输出到控制台
        print(logMessage, terminator: "")

        // 异步写入缓冲
        logQueue.async { [weak self] in
            self?.addToBuffer(logMessage)
        }
    }

    /// 添加到缓冲区
    private func addToBuffer(_ message: String) {
        logBuffer.append(message)

        // 如果缓冲区达到大小限制，立即刷新
        if logBuffer.count >= bufferSize {
            flushBuffer()
        }
    }

    /// 刷新缓冲区到磁盘（公共接口）
    func flush() {
        logQueue.async { [weak self] in
            self?.flushBuffer()
        }
    }

    /// 刷新缓冲区到磁盘（内部实现，必须在 logQueue 中调用）
    private func flushBuffer() {
        guard !logBuffer.isEmpty else { return }

        // 检查是否需要切换到新的日志文件（跨天）
        updateCurrentLogFile()

        let messages = logBuffer.joined()
        logBuffer.removeAll(keepingCapacity: true)

        guard let data = messages.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: currentLogFileURL.path) {
            // 追加到现有文件
            if let fileHandle = try? FileHandle(forWritingTo: currentLogFileURL) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
        } else {
            // 创建新文件
            try? data.write(to: currentLogFileURL)
        }

        // 定期检查文件大小并轮转（每小时检查一次，避免频繁检查）
        let now = Date()
        if now.timeIntervalSince(lastRotationCheck) > 3600 {
            lastRotationCheck = now
            rotateLogFileIfNeeded()
            cleanupOldLogs()
        }
    }

    /// 更新当前日志文件（处理跨天情况）
    private func updateCurrentLogFile() {
        let todayString = fileDateFormatter.string(from: Date())
        let expectedURL = logDirectory.appendingPathComponent("app-\(todayString).log")

        if expectedURL != currentLogFileURL {
            currentLogFileURL = expectedURL
        }
    }

    /// 轮转日志文件（如果超过大小限制）
    private func rotateLogFileIfNeeded() {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: currentLogFileURL.path),
              let fileSize = attributes[.size] as? Int,
              fileSize > maxLogFileSize else {
            return
        }

        // 生成带时间戳的备份文件名
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = currentLogFileURL.deletingPathExtension().lastPathComponent
        let backupURL = logDirectory.appendingPathComponent("\(fileName)-\(timestamp).log")

        // 移动当前文件到备份
        try? FileManager.default.moveItem(at: currentLogFileURL, to: backupURL)

        // 创建新的日志文件
        let message = "[\(dateFormatter.string(from: Date()))] INFO: 日志文件已轮转（超过\(maxLogFileSize / 1024 / 1024)MB限制）\n"
        if let data = message.data(using: .utf8) {
            try? data.write(to: currentLogFileURL)
        }
    }

    /// 清理超过30天的旧日志文件
    private func cleanupOldLogs() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: logDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        let now = Date()
        let fileManager = FileManager.default

        for fileURL in files {
            // 只处理 .log 文件
            guard fileURL.pathExtension == "log" else { continue }

            // 获取文件创建时间
            guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                  let creationDate = attributes[.creationDate] as? Date else {
                continue
            }

            // 如果文件超过30天，删除它
            if now.timeIntervalSince(creationDate) > maxLogAge {
                try? fileManager.removeItem(at: fileURL)
                print("已删除过期日志文件: \(fileURL.lastPathComponent)")
            }
        }
    }

    /// 获取当前日志内容
    func getLogContents() -> String? {
        return try? String(contentsOf: currentLogFileURL, encoding: .utf8)
    }

    /// 获取所有日志文件内容（按日期排序）
    func getAllLogContents() -> String? {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: logDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        // 过滤并排序日志文件
        let logFiles = files
            .filter { $0.pathExtension == "log" }
            .sorted { file1, file2 in
                let date1 = (try? FileManager.default.attributesOfItem(atPath: file1.path))?[.creationDate] as? Date ?? Date.distantPast
                let date2 = (try? FileManager.default.attributesOfItem(atPath: file2.path))?[.creationDate] as? Date ?? Date.distantPast
                return date1 < date2
            }

        // 合并所有日志内容
        var allContents = ""
        for fileURL in logFiles {
            if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                allContents += "=== \(fileURL.lastPathComponent) ===\n"
                allContents += content
                allContents += "\n\n"
            }
        }

        return allContents.isEmpty ? nil : allContents
    }

    /// 获取日志文件夹路径
    func getLogFolderURL() -> URL {
        return logDirectory
    }

    /// 清空所有日志
    func clearLogs() {
        logQueue.async { [weak self] in
            guard let self = self else { return }

            // 获取所有日志文件
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: self.logDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else {
                return
            }

            // 删除所有 .log 文件
            for fileURL in files where fileURL.pathExtension == "log" {
                try? FileManager.default.removeItem(at: fileURL)
            }

            // 记录清空操作
            self.log("所有日志已清空", level: .info)
        }
    }

    deinit {
        flushTimer?.invalidate()
        flush()  // 确保所有日志都被写入
    }
}
