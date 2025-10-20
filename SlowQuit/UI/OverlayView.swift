//
//  OverlayView.swift
//  SlowQuit
//
//  Created by Claude on 2025-10-12.
//

import SwiftUI
import Combine

// 可观察的视图模型，用于视图复用
class OverlayViewModel: ObservableObject {
    @Published var progress: Double = 0.0
    @Published var duration: TimeInterval = 1.0
    @Published var appName: String = ""
    @Published var isVisible: Bool = false

    func show(duration: TimeInterval, appName: String) {
        self.duration = duration
        self.appName = appName
        self.progress = 0.0
        self.isVisible = true

        // 启动进度动画
        withAnimation(.linear(duration: duration)) {
            self.progress = 1.0
        }
    }

    func hide() {
        self.isVisible = false
        self.progress = 0.0
    }
}

struct OverlayView: View {
    @ObservedObject var viewModel: OverlayViewModel
    @Environment(\.colorScheme) var colorScheme  // 检测系统颜色模式

    var body: some View {
        // 使用完全透明的背景填充整个屏幕，内容在中央
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                ZStack {
                    // 自适应半透明背景
                    RoundedRectangle(cornerRadius: 20)
                        .fill(overlayBackgroundColor)
                        .frame(width: 240, height: 240)
                        .shadow(color: shadowColor, radius: 20, x: 0, y: 10)

                    VStack(spacing: 16) {
                        // 应用名称
                        Text(viewModel.appName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(primaryTextColor)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: 200)

                        // 圆形进度指示器
                        ZStack {
                            // 背景圆环
                            Circle()
                                .stroke(ringBackgroundColor, lineWidth: 8)
                                .frame(width: 100, height: 100)

                            // 进度圆环
                            Circle()
                                .trim(from: 0, to: viewModel.progress)
                                .stroke(
                                    ringProgressColor,
                                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                )
                                .frame(width: 100, height: 100)
                                .rotationEffect(.degrees(-90))

                            // 中心图标
                            Image(systemName: "power")
                                .font(.system(size: 40))
                                .foregroundColor(iconColor)
                        }
                        .padding(.vertical, 8)

                        // 提示文字
                        Text(L10n.overlayHoldToQuit)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(secondaryTextColor)
                    }
                    .padding(.vertical, 16)
                }
                .opacity(viewModel.isVisible ? 1 : 0)
            )
    }

    // MARK: - 自适应颜色计算属性

    /// 叠加层背景色（根据系统外观自动调整）
    private var overlayBackgroundColor: Color {
        colorScheme == .dark
            ? Color(white: 0.15).opacity(0.92)  // 深色模式：深灰色，更高不透明度
            : Color.black.opacity(0.75)         // 浅色模式：半透明黑色
    }

    /// 阴影颜色
    private var shadowColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.5)
            : Color.black.opacity(0.3)
    }

    /// 主文字颜色（应用名称）
    private var primaryTextColor: Color {
        colorScheme == .dark
            ? Color.white                       // 深色模式：纯白色
            : Color.white                       // 浅色模式：纯白色
    }

    /// 次要文字颜色（提示文字）
    private var secondaryTextColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.95)         // 深色模式：略微透明的白色
            : Color.white.opacity(0.9)          // 浅色模式：半透明白色
    }

    /// 圆环背景色
    private var ringBackgroundColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.25)         // 深色模式：稍亮的背景圆环
            : Color.white.opacity(0.3)          // 浅色模式：半透明白色
    }

    /// 圆环进度色
    private var ringProgressColor: Color {
        colorScheme == .dark
            ? Color.white                       // 深色模式：纯白色
            : Color.white                       // 浅色模式：纯白色
    }

    /// 图标颜色
    private var iconColor: Color {
        colorScheme == .dark
            ? Color.white                       // 深色模式：纯白色
            : Color.white                       // 浅色模式：纯白色
    }
}

#Preview {
    let viewModel = OverlayViewModel()
    viewModel.show(duration: 1.0, appName: "Safari")

    return OverlayView(viewModel: viewModel)
        .frame(width: 400, height: 400)
        .background(Color.gray.opacity(0.3))
}
