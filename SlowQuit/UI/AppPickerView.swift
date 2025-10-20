//
//  AppPickerView.swift
//  SlowQuit
//
//  Created by Claude on 2025-10-19.
//

import SwiftUI

struct AppPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var allApps: [AppInfo] = []
    @State private var searchText = ""
    @State private var isLoading = true

    let onSelect: (AppInfo) -> Void

    var filteredApps: [AppInfo] {
        if searchText.isEmpty {
            return allApps
        }
        return allApps.filter { app in
            app.name.localizedCaseInsensitiveContains(searchText) ||
            app.id.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text(L10n.appPickerTitle)
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField(L10n.appPickerSearch, text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 应用列表
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(L10n.appPickerLoading)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredApps.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "app.dashed")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text(searchText.isEmpty ? L10n.appPickerNoApps : L10n.appPickerNoResults)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredApps) { app in
                            AppPickerRow(app: app) {
                                onSelect(app)
                                // 从列表中移除已添加的应用
                                allApps.removeAll { $0.id == app.id }
                            }
                            if app.id != filteredApps.last?.id {
                                Divider()
                                    .padding(.leading, 52)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 500, height: 400)
        .onAppear {
            loadInstalledApps()
        }
    }

    private func loadInstalledApps() {
        isLoading = true
        // 在后台线程加载应用列表
        DispatchQueue.global(qos: .userInitiated).async {
            let apps = AppListManager.shared.getInstalledApps()
            DispatchQueue.main.async {
                self.allApps = apps
                self.isLoading = false
            }
        }
    }
}

struct AppPickerRow: View {
    let app: AppInfo
    let onTap: () -> Void
    @State private var isAdded = false

    var body: some View {
        Button(action: {
            onTap()
            // 显示已添加状态
            withAnimation {
                isAdded = true
            }
        }) {
            HStack(spacing: 12) {
                // 应用图标
                if let icon = getAppIcon(for: app.id) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 32, height: 32)
                } else {
                    Image(systemName: "app")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                }

                // 应用信息
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.system(size: 13))
                        .foregroundColor(isAdded ? .secondary : .primary)
                    Text(app.id)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // 添加按钮/已添加标识
                if isAdded {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(L10n.appPickerAdded)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                        .imageScale(.large)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isAdded)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.0))
        .onHover { hovering in
            if hovering && !isAdded {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    private func getAppIcon(for bundleId: String) -> NSImage? {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }
        return nil
    }
}

#Preview {
    AppPickerView { _ in }
}
