//
//  PermissionGuideView.swift
//  SlowQuit
//

import SwiftUI

struct PermissionGuideView: View {
    @State private var status: EventPermissionStatus

    private let permissionManager: PermissionManager
    private let onPermissionsReady: () -> Void
    private let onClose: () -> Void

    init(
        permissionManager: PermissionManager,
        onPermissionsReady: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.permissionManager = permissionManager
        self.onPermissionsReady = onPermissionsReady
        self.onClose = onClose
        _status = State(initialValue: permissionManager.checkEventPermissions())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.permissionGuideTitle)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.primary)

                Text(L10n.permissionGuideSubtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 28)
            .padding(.horizontal, 28)

            VStack(spacing: 12) {
                PermissionGuideRow(
                    iconName: "accessibility",
                    title: L10n.permissionAccessibilityTitle,
                    description: L10n.permissionAccessibilityDescription,
                    isGranted: status.canUseAccessibility,
                    buttonTitle: L10n.permissionOpenAccessibility,
                    action: {
                        permissionManager.requestAccessibilityPermission()
                        permissionManager.openAccessibilitySettings()
                        refreshStatus()
                    }
                )
            }
            .padding(.top, 22)
            .padding(.horizontal, 28)

            Text(L10n.permissionGuideFootnote)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
                .padding(.horizontal, 28)

            Spacer(minLength: 18)

            Divider()

            HStack(spacing: 10) {
                Button(L10n.permissionLater) {
                    onClose()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(L10n.permissionRecheck) {
                    refreshStatus()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
        }
        .frame(width: 520, height: 320)
        .onAppear {
            refreshStatus(closeWhenReady: false)
        }
    }

    private func refreshStatus(closeWhenReady: Bool = true) {
        status = permissionManager.checkEventPermissions()
        if status.isFullyGranted {
            if closeWhenReady {
                onClose()
            }
            onPermissionsReady()
        }
    }
}

private struct PermissionGuideRow: View {
    let iconName: String
    let title: String
    let description: String
    let isGranted: Bool
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(statusColor.opacity(0.12))
                    .frame(width: 42, height: 42)

                Image(systemName: iconName)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundColor(statusColor)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)

                    Label(
                        isGranted ? L10n.permissionGranted : L10n.permissionNotGranted,
                        systemImage: isGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
                    )
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(statusColor)
                    .labelStyle(.titleAndIcon)
                }

                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Button(buttonTitle) {
                action()
            }
            .disabled(isGranted)
            .controlSize(.small)
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    private var statusColor: Color {
        isGranted ? .green : .orange
    }
}

#Preview {
    PermissionGuideView(
        permissionManager: PermissionManager(),
        onPermissionsReady: {},
        onClose: {}
    )
}
