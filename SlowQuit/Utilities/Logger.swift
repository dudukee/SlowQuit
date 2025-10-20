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

    private let logFileURL: URL
    private let dateFormatter: DateFormatter
    private let maxLogFileSize: Int = 1024 * 1024 // 1MB

    // 日志级别控制：只记录此级别及以上的日志
    // 生产环境建议设置为 .warning，开发环境使用 .debug
    var minimumLogLevel: LogLevel = .warning

    // 异步日志队列
    private let logQueue = DispatchQueue(label: "com.slowquit.logger", qos: .utility)
    private var logBuffer: [String] = []
    private let bufferSize = 10  // 缓冲10条日志后批量写入
    private var flushTimer: Timer?

    private init() {
        // 获取应用支持目录
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("SlowQuit", isDirectory: true)

        // 创建目录（如果不存在）
        try? FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)

        // 日志文件路径
        logFileURL = appDirectory.appendingPathComponent("app.log")

        // 日期格式化器
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

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

        let messages = logBuffer.joined()
        logBuffer.removeAll(keepingCapacity: true)

        guard let data = messages.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: logFileURL.path) {
            // 追加到现有文件
            if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
        } else {
            // 创建新文件
            try? data.write(to: logFileURL)
        }

        // 检查文件大小并轮转（降低检查频率）
        rotateLogFileIfNeeded()
    }

    /// 轮转日志文件（如果超过大小限制）
    private func rotateLogFileIfNeeded() {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: logFileURL.path),
              let fileSize = attributes[.size] as? Int,
              fileSize > maxLogFileSize else {
            return
        }

        // 备份旧日志
        let backupURL = logFileURL.deletingPathExtension().appendingPathExtension("old.log")
        try? FileManager.default.removeItem(at: backupURL)
        try? FileManager.default.moveItem(at: logFileURL, to: backupURL)

        // 注意：这里不能调用 log() 避免循环
        let message = "日志文件已轮转\n"
        if let data = message.data(using: .utf8) {
            try? data.write(to: logFileURL)
        }
    }

    /// 获取日志内容
    func getLogContents() -> String? {
        return try? String(contentsOf: logFileURL, encoding: .utf8)
    }

    /// 清空日志
    func clearLogs() {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            try? FileManager.default.removeItem(at: self.logFileURL)
            self.log("日志已清空", level: .info)
        }
    }

    deinit {
        flushTimer?.invalidate()
        flush()  // 确保所有日志都被写入
    }
}
