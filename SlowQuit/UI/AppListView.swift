//
//  AppListView.swift
//  SlowQuit
//
//  Created by Claude on 2025-10-19.
//

import SwiftUI

struct AppListView: View {
    @State private var listMode: ListMode
    @State private var appList: [AppInfo]
    @State private var showingAppPicker = false

    private let appListManager = AppListManager.shared

    init() {
        _listMode = State(initialValue: AppListManager.shared.listMode)
        _appList = State(initialValue: AppListManager.shared.currentList)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 模式选择
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.appListModeLabel)
                    .font(.system(size: 14, weight: .medium))

                Picker("", selection: $listMode) {
                    Text(L10n.appListModeGlobal).tag(ListMode.global)
                    Text(L10n.appListModeWhitelist).tag(ListMode.whitelist)
                    Text(L10n.appListModeBlacklist).tag(ListMode.blacklist)
                }
                .pickerStyle(.radioGroup)
                .horizontalRadioGroupLayout()
                .onChange(of: listMode) { newMode in
                    appListManager.listMode = newMode
                }

                Text(getModeDescription())
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // 应用列表（仅在白名单/黑名单模式显示）
            if listMode != .global {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
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
                        VStack(spacing: 8) {
                            Image(systemName: "tray")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary)
                            Text(L10n.appListEmpty)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                    } else {
                        // 应用列表
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(appList) { app in
                                    AppListRow(app: app) {
                                        removeApp(app)
                                    }
                                    if app.id != appList.last?.id {
                                        Divider()
                                            .padding(.leading, 44)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 150)
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
            }
        }
        .sheet(isPresented: $showingAppPicker) {
            AppPickerView { app in
                addApp(app)
            }
        }
    }

    private func getModeDescription() -> String {
        switch listMode {
        case .global:
            return L10n.appListModeGlobalDesc
        case .whitelist:
            return L10n.appListModeWhitelistDesc
        case .blacklist:
            return L10n.appListModeBlacklistDesc
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

struct AppListRow: View {
    let app: AppInfo
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // 应用图标
            if let icon = getAppIcon(for: app.id) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "app")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
            }

            // 应用名称
            Text(app.name)
                .font(.system(size: 12))

            Spacer()

            // 删除按钮
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help(L10n.appListRemove)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private func getAppIcon(for bundleId: String) -> NSImage? {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }
        return nil
    }
}

#Preview {
    AppListView()
        .padding()
        .frame(width: 400)
}
