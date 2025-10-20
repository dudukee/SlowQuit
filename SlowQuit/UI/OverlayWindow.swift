//
//  OverlayWindow.swift
//  SlowQuit
//
//  Created by Claude on 2025-10-12.
//

import Cocoa
import SwiftUI

class OverlayWindow: NSWindow {
    private var hostingView: NSHostingView<OverlayView>?
    private let viewModel = OverlayViewModel()  // 复用同一个 ViewModel
    private var isInitialized = false

    init() {
        // 获取主屏幕尺寸
        let screenRect = NSScreen.main?.frame ?? .zero

        // 创建无边框、透明窗口
        super.init(
            contentRect: screenRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // 配置窗口属性
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .screenSaver  // 使用更高的层级，确保在全屏应用上方显示
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        self.isReleasedWhenClosed = false
        self.ignoresMouseEvents = true  // 不响应鼠标事件

        // 初始隐藏
        self.orderOut(nil)

        // 初始化视图（只创建一次）
        initializeViewIfNeeded()
    }

    private func initializeViewIfNeeded() {
        guard !isInitialized else { return }

        // 创建 SwiftUI 视图和 HostingView（只创建一次）
        let overlayView = OverlayView(viewModel: viewModel)
        let hostingView = NSHostingView(rootView: overlayView)

        // 让 hostingView 填充整个窗口
        hostingView.frame = self.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]

        // 设置内容视图
        self.contentView = hostingView
        self.hostingView = hostingView

        isInitialized = true
        Logger.shared.log("叠加层视图已初始化（复用模式）", level: .debug)
    }

    func show(duration: TimeInterval, appName: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // 确保视图已初始化
            self.initializeViewIfNeeded()

            // 更新窗口尺寸为当前屏幕
            if let screen = NSScreen.main {
                self.setFrame(screen.frame, display: true)
            }

            // 恢复窗口层级到最高优先级
            self.level = .screenSaver

            // 更新 ViewModel 数据（复用视图，只更新数据）
            self.viewModel.show(duration: duration, appName: appName)

            // 显示窗口
            self.orderFrontRegardless()
            Logger.shared.log("显示叠加层 - 应用: \(appName)", level: .debug)
        }
    }

    func hide() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // 隐藏视图内容（通过 ViewModel）
            self.viewModel.hide()

            // 隐藏窗口
            self.orderOut(nil)

            // 降低窗口层级,释放高优先级资源
            self.level = .normal

            Logger.shared.log("隐藏叠加层", level: .debug)
        }
    }
}
