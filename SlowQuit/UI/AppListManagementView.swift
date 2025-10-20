//
//  AppListManagementView.swift
//  SlowQuit
//
//  Created by Claude on 2025-10-19.
//

import SwiftUI

struct AppListManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var appList: [AppInfo]
    @State private var showingAppPicker = false
    @State private var listMode: ListMode

    private let appListManager = AppListManager.shared

    init() {
        let mode = AppListManager.shared.listMode
        _listMode = State(initialValue: mode)
        _appList = State(initialValue: AppListManager.shared.currentList)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // 标题栏
            HStack {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12))
                        Text(L10n.commonBack)
                            .font(.system(size: 13))
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)

                Spacer()

                VStack(spacing: 4) {
                    Text(getCurrentListTitle())
                        .font(.system(size: 20, weight: .semibold))
                    Text(getCurrentListSubtitle())
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // 占位保持居中
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12))
                        Text(L10n.commonBack)
                            .font(.system(size: 13))
                    }
                }
                .buttonStyle(.plain)
                .opacity(0)
            }

            Divider()

            // 应用列表区域
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(L10n.appListTitle)
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                    Text("(\(appList.count))")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                // 列表容器
                if appList.isEmpty {
                    // 空状态
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text(getCurrentEmptyMessage())
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                } else {
                    // 应用列表
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(appList) { app in
                                AppListManagementRow(app: app) {
                                    removeApp(app)
                                }
                                if app.id != appList.last?.id {
                                    Divider()
                                        .padding(.leading, 44)
                                }
                            }
                        }
                    }
                    .frame(height: 200)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                }

                // 添加按钮
                Button(action: { showingAppPicker = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text(L10n.appListAddButton)
                    }
                    .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }

            Spacer()
        }
        .padding(24)
        .frame(width: 450, height: 400)
        .sheet(isPresented: $showingAppPicker) {
            AppPickerView { app in
                addApp(app)
            }
        }
    }

    private func getCurrentListTitle() -> String {
        switch listMode {
        case .whitelist:
            return L10n.appListWhitelistTitle
        case .blacklist:
            return L10n.appListBlacklistTitle
        case .global:
            return L10n.appListManageTitle
        }
    }

    private func getCurrentListSubtitle() -> String {
        switch listMode {
        case .whitelist:
            return L10n.appListWhitelistSubtitle
        case .blacklist:
            return L10n.appListBlacklistSubtitle
        case .global:
            return ""
        }
    }

    private func getCurrentEmptyMessage() -> String {
        switch listMode {
        case .whitelist:
            return L10n.appListWhitelistEmpty
        case .blacklist:
            return L10n.appListBlacklistEmpty
        case .global:
            return L10n.appListEmpty
        }
    }

    private func addApp(_ app: AppInfo) {
        appListManager.addApp(app)
        appList = appListManager.currentList
    }

    private func removeApp(_ app: AppInfo) {
        appListManager.removeApp(app)
        appList = appListManager.currentList
    }
}

struct AppListManagementRow: View {
    let app: AppInfo
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // 应用图标
            if let icon = getAppIcon(for: app.id) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 28, height: 28)
            } else {
                Image(systemName: "app")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
            }

            // 应用信息
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 12))
                Text(app.id)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 删除按钮
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help(L10n.appListRemove)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private func getAppIcon(for bundleId: String) -> NSImage? {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }
        return nil
    }
}

#Preview {
    AppListManagementView()
}
