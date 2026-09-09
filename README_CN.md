# SlowQuit

<div align="center">

![macOS](https://img.shields.io/badge/macOS-12.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

**一款 macOS 菜单栏应用，通过为受保护快捷键添加延迟来防止意外退出和关闭**

[功能特性](#功能特性) • [安装说明](#安装说明) • [使用方法](#使用方法) • [English](README.md)

</div>

---

## 概述

SlowQuit 为 macOS 上的受保护快捷键添加可自定义的延迟。Cmd-Q 默认受保护，用于防止意外退出应用。可选的 SlowClose 功能可以保护 Cmd-W，防止意外关闭窗口或标签页。

## 功能特性

- **全局 Cmd-Q 保护** - 适用于所有应用程序
- **可选 SlowClose** - 为 Cmd-W 添加同样的防误触保护
- **可自定义延迟** - 调整延迟时间从 0.5 到 3.0 秒
- **应用列表管理** - 白名单/黑名单特定应用
- **视觉进度指示器** - 圆形覆盖层显示剩余时间
- **轻量级原生应用** - 使用 Swift 和 SwiftUI 构建
- **隐私保护** - 本地运行，无数据收集
- **多语言支持** - 支持英文和简体中文

## 安装说明

### 下载发布版本

1. **下载** 最新的 `.dmg` 文件，访问 [发布页面](https://github.com/dudukee/SlowQuit/releases)
2. **打开 .dmg** 文件
3. **将 SlowQuit 拖拽** 到您的应用程序文件夹
4. **从应用程序文件夹启动**

### 首次启动设置

当您首次启动 SlowQuit 时，macOS 会显示安全警告：

1. **Gatekeeper 警告**："SlowQuit"无法打开，因为来自身份不明的开发者
   - 点击 **"取消"**
   - 打开 **系统设置 → 隐私与安全性**
   - 滚动到安全性部分，点击 **"仍要打开"**
   - 在确认对话框中点击 **"打开"**

2. **辅助功能权限**：键盘监控所需
   - 在提示时点击 **"打开系统设置"**
   - 在 **隐私与安全性 → 辅助功能** 中启用 SlowQuit
   - 重启 SlowQuit

**替代方法**：右键点击 SlowQuit.app → 打开 → 打开（在确认对话框中）

## 使用方法

### 基本使用

1. 在任何应用程序中按下并**按住** Cmd-Q
2. 屏幕上出现圆形进度指示器
3. 持续按住直到进度完成（默认：1 秒）
4. 提前松开以取消退出操作

在设置中启用 **SlowClose** 后，Cmd-W 也会使用同样的长按确认行为。

### 菜单栏选项

- **启用/禁用** - 切换快捷键保护
- **设置** - 配置延迟时间、SlowClose 和应用列表
- **开机自启** - 开机时自动启动
- **检查更新** - 手动更新检查
- **关于** - 查看版本信息
- **退出** - 退出 SlowQuit

### 设置配置

**延迟时间**：调整按住时间从 0.5 到 3.0 秒

**SlowClose**：可选的 Cmd-W 保护。默认关闭，避免更新后改变现有关闭行为。

**应用列表模式**：
- **全局**：对所有应用启用快捷键保护（默认）
- **白名单**：仅对选定应用启用快捷键保护
- **黑名单**：对选定应用禁用快捷键保护

**管理应用列表**：
1. 选择白名单或黑名单模式
2. 点击"管理应用列表"
3. 从运行中的应用添加或浏览已安装的应用
4. 使用 × 按钮移除应用

## 从源码构建

### 系统要求
- macOS 12.0+
- Xcode 14.0+
- Swift 5.9+

### 构建步骤

1. **克隆并打开**：
   ```bash
   git clone https://github.com/dudukee/slowquit.git
   cd slowquit
   open SlowQuit.xcodeproj
   ```

2. **配置签名**：
   - 选择项目 → Signing & Capabilities
   - 选择您的签名团队或"Sign to Run Locally"

3. **构建并运行**：
   ```bash
   xcodebuild -project SlowQuit.xcodeproj -scheme SlowQuit -configuration Release build
   ```
   或在 Xcode 中按 Cmd+R。

4. **在提示时授予辅助功能权限**并重启应用。

## 故障排除

### 应用无法打开
- 打开系统设置 → 隐私与安全性
- 在 SlowQuit 消息旁边点击"仍要打开"
- 或者：右键点击应用 → 打开 → 打开

### Cmd-Q 不工作
- 在系统设置中检查辅助功能权限
- 确保在隐私与安全性 → 辅助功能中启用了 SlowQuit
- 重启应用

### 开机自启问题
- macOS 13+：系统设置 → 通用 → 登录项
- 移除并重新添加 SlowQuit 到登录项列表

## 隐私与安全

- **本地运行**：所有处理都在您的 Mac 上进行
- **无遥测**：零分析或使用跟踪
- **开源**：完整的源代码可供审计
- **最少权限**：仅需键盘监控的辅助功能权限

**为什么需要辅助功能权限？**
需要使用 CGEventTap 监控全局键盘事件 - 这是在 Cmd-Q 到达应用程序之前拦截它的唯一方法。

## 许可证

MIT 许可证 - 详情请参见 [LICENSE](LICENSE) 文件。

## 维护政策

SlowQuit 主要根据作者的个人使用需求进行维护。

欢迎提交问题反馈，但修复工作将视时间和精力而定。无法在维护者设备上复现的问题可能会被关闭，或作为已知限制保留。项目不保证回复时间或修复计划。

欢迎提交经过测试的修复代码。

## 支持

- **问题反馈**：[GitHub Issues](https://github.com/dudukee/SlowQuit/issues)
- **更新下载**：[发布页面](https://github.com/dudukee/SlowQuit/releases)

---

**为讨厌意外退出的 macOS 用户制作**
