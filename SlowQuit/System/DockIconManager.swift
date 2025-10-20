//
//  DockIconManager.swift
//  SlowQuit
//
//  Created by Claude on 2025-10-19.
//

import Cocoa

class DockIconManager {
    static let shared = DockIconManager()

    private init() {}

    /// 显示 Dock 图标
    func showDockIcon() {
        NSApp.setActivationPolicy(.regular)
        Logger.shared.log("程序坞图标已显示", level: .debug)
    }

    /// 隐藏 Dock 图标
    func hideDockIcon() {
        NSApp.setActivationPolicy(.accessory)
        Logger.shared.log("程序坞图标已隐藏", level: .debug)
    }
}
