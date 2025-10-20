//
//  SettingsWindow.swift
//  SlowQuit
//
//  Created by Claude on 2025-10-19.
//

import Cocoa
import SwiftUI

class SettingsWindow: NSWindow, NSWindowDelegate {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 450),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.title = ""  // 标题在 SwiftUI 视图中显示
        self.titlebarAppearsTransparent = true
        self.isReleasedWhenClosed = false
        self.center()

        // 设置为非活动时自动隐藏
        self.hidesOnDeactivate = true

        // 托管 SwiftUI 视图
        let settingsView = SettingsView()
        let hostingView = NSHostingView(rootView: settingsView)
        self.contentView = hostingView

        // 设置窗口层级
        self.level = .floating

        // 设置窗口的外观样式（跟随系统自动切换深色/浅色模式）
        self.appearance = nil  // nil 表示自动跟随系统

        // 设置窗口代理以监听窗口事件
        self.delegate = self
    }

    func showWindow() {
        // 显示窗口时显示 Dock 图标
        DockIconManager.shared.showDockIcon()

        self.center()
        self.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        // 窗口关闭时隐藏 Dock 图标
        DockIconManager.shared.hideDockIcon()
    }
}
