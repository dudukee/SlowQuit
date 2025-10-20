//
//  HealthMonitor.swift
//  SlowQuit
//
//  Created by Claude on 2025-10-12.
//

import Foundation

class HealthMonitor {
    private let eventMonitor: EventMonitor
    private var healthCheckTimer: Timer?
    private let checkInterval: TimeInterval = 30.0  // 改为每 30 秒检查一次（降低功耗）
    private var consecutiveFailures = 0  // 连续失败计数

    init(eventMonitor: EventMonitor) {
        self.eventMonitor = eventMonitor
    }

    func start() {
        Logger.shared.log("健康监控已启动 (间隔: \(checkInterval)秒)", level: .info)

        healthCheckTimer = Timer.scheduledTimer(
            withTimeInterval: checkInterval,
            repeats: true
        ) { [weak self] _ in
            self?.performHealthCheck()
        }

        // 设置 timer 为低优先级，降低功耗
        healthCheckTimer?.tolerance = checkInterval * 0.1  // 允许 10% 的延迟容差
    }

    func stop() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
        consecutiveFailures = 0
        Logger.shared.log("健康监控已停止", level: .info)
    }

    private func performHealthCheck() {
        // 检查事件监听器是否正常运行
        if !eventMonitor.isRunning {
            consecutiveFailures += 1
            Logger.shared.log("检测到事件监听器未运行 (连续失败: \(consecutiveFailures)次)", level: .warning)

            // 只在确认问题后才重启，避免误报
            if consecutiveFailures >= 2 {
                restartEventMonitor()
                consecutiveFailures = 0
            }
        } else {
            // 重置失败计数
            if consecutiveFailures > 0 {
                consecutiveFailures = 0
                Logger.shared.log("事件监听器恢复正常", level: .info)
            }
        }
    }

    private func restartEventMonitor() {
        Logger.shared.log("尝试重启事件监听器...", level: .warning)
        eventMonitor.stop()

        // 短暂延迟后重启
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.eventMonitor.start()

            if self?.eventMonitor.isRunning == true {
                Logger.shared.log("事件监听器重启成功", level: .info)
            } else {
                Logger.shared.log("事件监听器重启失败", level: .error)
            }
        }
    }

    /// 手动触发健康检查（用于响应特定事件）
    func triggerHealthCheck() {
        performHealthCheck()
    }
}
