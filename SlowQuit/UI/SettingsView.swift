//
//  SettingsView.swift
//  SlowQuit
//
//  Created by Claude on 2025-10-19.
//

import SwiftUI

struct SettingsView: View {
    @State private var quitDelay: Double
    @State private var listMode: ListMode
    @State private var showingAppListManagement = false
    @State private var isUpdatingMode = false // 防止快速切换
    @State private var appListCount = 0 // 用于刷新显示

    private let settings = SettingsManager.shared
    private let appListManager = AppListManager.shared

    init() {
        _quitDelay = State(initialValue: SettingsManager.shared.quitDelay)
        _listMode = State(initialValue: AppListManager.shared.listMode)
        _appListCount = State(initialValue: AppListManager.shared.currentList.count)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            VStack(spacing: 0) {
                Text(L10n.settingsTitle)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)

                Divider()
            }

            // 内容区域
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 延迟时长设置
                    VStack(alignment: .leading, spacing: 14) {
                        // 标题
                        Text(L10n.settingsDelayLabel)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)

                        // 当前值显示卡片
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n.settingsDelayDescription)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.1f %@", quitDelay, L10n.settingsDelayUnit))
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.accentColor)
                            }
                            Spacer()
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(Color.clear)
                        .cornerRadius(8)

                        // 滑块
                        VStack(spacing: 8) {
                            Slider(
                                value: $quitDelay,
                                in: settings.minDelay...settings.maxDelay,
                                step: 0.1
                            )
                            .onChange(of: quitDelay) { newValue in
                                settings.quitDelay = newValue
                            }

                            HStack {
                                Text("0.5")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("3.0")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Divider()

                    // 应用列表模式
                    VStack(alignment: .leading, spacing: 14) {
                        // 标题和管理按钮
                        HStack(alignment: .center) {
                            Text(L10n.appListModeLabel)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)

                            Spacer()

                            // 管理按钮占位区域（固定高度避免跳动）
                            Group {
                                if listMode != .global {
                                    Button(action: {
                                        showingAppListManagement = true
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "list.bullet.rectangle")
                                                .font(.system(size: 12))
                                            Text(getManageButtonText())
                                                .font(.system(size: 12, weight: .medium))
                                            Text("(\(appListCount))")
                                                .font(.system(size: 11))
                                                .foregroundColor(.secondary)
                                        }
                                        .foregroundColor(.accentColor)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.accentColor.opacity(0.1))
                                        .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    // 占位空间，保持布局稳定
                                    Color.clear
                                        .frame(height: 28)
                                }
                            }
                            .animation(.easeInOut(duration: 0.2), value: listMode)
                        }
                        .frame(height: 28) // 固定高度

                        // 分段选择器
                        Picker("", selection: $listMode) {
                            Text(L10n.appListModeGlobal).tag(ListMode.global)
                            Text(L10n.appListModeBlacklist).tag(ListMode.blacklist)
                            Text(L10n.appListModeWhitelist).tag(ListMode.whitelist)
                        }
                        .pickerStyle(.segmented)
                        .disabled(isUpdatingMode)
                        .onChange(of: listMode) { newMode in
                            // 防抖：避免快速切换
                            guard !isUpdatingMode else { return }
                            isUpdatingMode = true

                            appListManager.listMode = newMode

                            // 延迟重置，防止快速连续点击
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                isUpdatingMode = false
                            }
                        }

                        // 模式说明卡片
                        HStack(alignment: .center, spacing: 10) {
                            Image(systemName: getModeIcon())
                                .font(.system(size: 16))
                                .foregroundColor(.accentColor)
                                .frame(width: 20, height: 20)

                            Text(getModeDescription())
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.clear)
                        .cornerRadius(8)
                    }

                }
                .padding(24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showingAppListManagement) {
            // Sheet 关闭后刷新列表计数
            appListCount = appListManager.currentList.count
        } content: {
            AppListManagementView()
        }
        .onAppear {
            // 页面出现时同步状态
            appListCount = appListManager.currentList.count
        }
        .onChange(of: listMode) { _ in
            // 切换模式时更新列表计数
            appListCount = appListManager.currentList.count
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

    private func getModeIcon() -> String {
        switch listMode {
        case .global:
            return "globe"
        case .whitelist:
            return "checkmark.shield"
        case .blacklist:
            return "xmark.shield"
        }
    }

    private func getManageButtonText() -> String {
        switch listMode {
        case .whitelist:
            return L10n.appListManageWhitelist
        case .blacklist:
            return L10n.appListManageBlacklist
        case .global:
            return L10n.appListManageButton
        }
    }
}

#Preview {
    SettingsView()
}
