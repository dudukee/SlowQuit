//
//  PermissionGuideWindow.swift
//  SlowQuit
//

import Cocoa
import SwiftUI

class PermissionGuideWindow: NSWindow, NSWindowDelegate {
    private let permissionManager: PermissionManager
    private let onPermissionsReady: () -> Void

    init(permissionManager: PermissionManager, onPermissionsReady: @escaping () -> Void) {
        self.permissionManager = permissionManager
        self.onPermissionsReady = onPermissionsReady

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 320),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.title = ""
        self.titlebarAppearsTransparent = true
        self.isReleasedWhenClosed = false
        self.center()
        self.level = .floating
        self.appearance = nil
        self.delegate = self

        let guideView = PermissionGuideView(
            permissionManager: permissionManager,
            onPermissionsReady: onPermissionsReady,
            onClose: { [weak self] in
                self?.close()
            }
        )
        self.contentView = NSHostingView(rootView: guideView)
    }

    func showWindow() {
        DockIconManager.shared.showDockIcon()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.center()
            self.makeKeyAndOrderFront(nil)
            self.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func windowWillClose(_ notification: Notification) {
        DockIconManager.shared.hideDockIcon()
    }
}
