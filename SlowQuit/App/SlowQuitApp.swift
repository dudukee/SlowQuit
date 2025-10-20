//
//  SlowQuitApp.swift
//  SlowQuit
//
//  Created by Claude on 2025-10-12.
//

import SwiftUI

@main
struct SlowQuitApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // 不需要任何场景，因为是 Menu Bar App
        Settings {
            EmptyView()
        }
    }
}
