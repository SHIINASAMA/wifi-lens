<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/screenshot-swiftui.png">
  <img alt="WiFi Lens macOS Wi-Fi 频谱分析器" src="assets/screenshot-swiftui.png" width="800">
</picture>

# WiFi Lens

[![Swift CI](https://github.com/SHIINASAMA/wifi-lens/workflows/Swift%20CI/badge.svg)](https://github.com/SHIINASAMA/wifi-lens/actions?query=workflow%3A%22Swift+CI%22)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey)](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
[![X](https://img.shields.io/badge/X-@WiFiLens-1d9bf0)](https://x.com/WiFiLens)
[![Email](https://img.shields.io/badge/email-wifi--lens@outlook.com-0078d4)](mailto:wifi-lens@outlook.com)
[![Website](https://img.shields.io/badge/website-wifi--lens.shiinalabs.com-2563eb)](https://wifi-lens.shiinalabs.com)

🇺🇸 [English](README.md) | 🇩🇪 [Deutsch](README.de.md) | 🇪🇸 [Español](README.es-ES.md) | 🇨🇳 [简体中文](README.zh-Hans.md) | 🇯🇵 [日本語](README.ja.md)

**一款原生 macOS 工具，用于分析和优化你的 Wi-Fi 网络。**

<p align="center">
  <a href="https://apps.apple.com/app/wifi-lens-pro/id6776590746">
    <img src="assets/appstore-badge-en.svg" alt="在 Mac App Store 下载 WiFi Lens Pro" width="240">
  </a>
</p>

---

## 关于 WiFi Lens

WiFi Lens 是一款使用 SwiftUI、CoreWLAN 和 CoreBluetooth 开发的原生 macOS Wi-Fi 与蓝牙分析器。它实时呈现附近的无线网络和 BLE 设备，帮助你诊断连接问题、选择拥堵较少的信道，并验证接入点之间的漫游行为。

本仓库提供免费开源版。WiFi Lens Pro 是包含更多功能的独立付费版本。

**典型使用场景：**

- 🏠 **家庭网络调优：** 找出邻居占用的信道，然后将路由器切换到较空闲的信道。
- 🏢 **办公室 Wi-Fi 审计：** 扫描 2.4、5 和 6 GHz 三个频段，发现信号死角或配置错误的 AP。
- 🚶 **漫游验证：** 在建筑内移动时记录每次 AP 切换，通过时间线图验证漫游是否顺畅。
- 🎧 **BLE 设备排障：** 追踪蓝牙外设的 RSSI 趋势，识别覆盖范围或干扰问题。

---

## 功能

| 类别 | 能力 |
|----------|-----------|
| 📡 **Wi-Fi 扫描** | 跨 2.4、5 和 6 GHz 频段的实时扫描，显示每网络信号强度 |
| 📊 **频谱视图** | 高斯钟形曲线图直观展示各频段信道占用情况 |
| 🎯 **信道质量** | 拥堵评分 + 基于区域规则的推荐，适配你的监管域 |
| 🔍 **网络详情** | PHY 代际、信道宽度、802.11k/r/v 漫游、WPA3、隐藏 SSID |
| 📶 **连接信息** | IP、网关、DNS、MAC、信道、发送速率和安全摘要 |
| 📈 **趋势图表** | 每网络信号历史随时间变化，支持可配置扫描间隔 |
| 🔄 **漫游测试** | AP 切换监控，含时间线图、范围选择器和会话保存/加载 |
| 🗺️ **信道热力图** | 各频段占用热力图，瞬间发现拥堵模式 |
| 🎧 **BLE 扫描器** | Bluetooth LE 设备发现、RSSI 分析、趋势图表和设备追踪 |
| 🎨 **智能着色** | 基于 SSID 确定颜色；同一网络始终保持相同颜色 |
| 🔒 **隐私优先** | 无遥测或使用分析；Wi-Fi 扫描数据保留在你的 Mac 上 |
| 🌐 **MCP 服务器** | 内嵌 HTTP API（`127.0.0.1:19840`），支持外部工具集成 |
| 🔄 **自动更新** | GitHub 版本提供可选的 Sparkle 更新检查 |
| 📤 **导出** | 保存各频段图表为 PNG 图片或 CSV 数据 |
| 🌍 **本地化** | 英语、德语、西班牙语、日语和简体中文 |

---

## 设计

**原生 macOS 界面。** CoreWLAN 直接与 Wi-Fi 硬件通信，SwiftUI 提供原生 Mac 控件和窗口行为。

**结合地区法规的信道推荐。** WiFi Lens 根据系统地区、硬件能力和附近 AP 的国家代码推断监管域，并按照 DFS、室内使用和 6 GHz AFC 要求筛选推荐结果。

**联动视图。** 在表格中选择网络后，各图表会同时高亮该网络。将指针悬停在钟形曲线上即可查看 SSID。

**开源版工具。** 导出 PNG 和 CSV 文件，或保存并加载漫游会话。本地 MCP 服务器可将 WiFi Lens 连接到你的工具。

---

## 下载

[![下载最新版本](https://img.shields.io/github/v/release/SHIINASAMA/wifi-lens?label=Latest&color=2563eb)](https://github.com/SHIINASAMA/wifi-lens/releases/latest/)
[![在 Mac App Store 下载 WiFi Lens Pro](https://img.shields.io/badge/Download-Mac%20App%20Store-black?logo=apple)](https://apps.apple.com/app/wifi-lens-pro/id6776590746)

GitHub Releases 提供开源版。WiFi Lens Pro 可在支持地区的 Mac App Store 下载。

需要 macOS 14 (Sonoma) 或更高版本。兼容 Intel 和 Apple Silicon Mac。

> 🌐 **官方网站：** [wifi-lens.shiinalabs.com](https://wifi-lens.shiinalabs.com) 提供截图、功能导览、AI/MCP 工作流和常见问题。

> [!IMPORTANT]
> 在 macOS 14+ 上，**定位服务**必须启用才能读取 Wi-Fi SSID 名称。
> 前往 **系统设置 → 隐私与安全性 → 定位服务**，在提示时启用 WiFi Lens。

## 隐私

WiFi Lens 不收集使用分析、崩溃遥测或 Wi-Fi 扫描数据。

- **定位服务：** macOS 需要此权限才能提供 Wi-Fi SSID 名称。WiFi Lens 不会读取你的 GPS 位置。
- **区域检测：** WiFi Lens 在设备上使用系统地区、硬件报告的信道列表和附近 AP 的国家代码。
- **网络自检：** 运行自检时，WiFi Lens 会解析 `example.com`，并可能测试你配置的代理端点是否可达。
- **MCP 服务器：** 可选服务器绑定到 `127.0.0.1`。只有在你启用后，本地工具才能访问扫描数据。
- **更新检查：** 当你手动检查更新或启用自动检查时，GitHub 版本会连接 GitHub。

---

## 开发

```sh
git clone https://github.com/SHIINASAMA/wifi-lens
cd wifi-lens
git submodule update --init ChartLens
cd WiFiLens

# 构建
xcodebuild -project WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build

# 运行测试
xcodebuild -project WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests

# 在 Xcode 中打开
xed WiFiLens.xcodeproj
```

产品名为 `WiFi Lens.app`（带空格）。

架构、测试和路线图文档位于 [docs/](docs/)。

---

## 贡献

欢迎提交 Bug 报告和功能建议。你可以创建 [issue](https://github.com/SHIINASAMA/wifi-lens/issues) 或发起 [discussion](https://github.com/SHIINASAMA/wifi-lens/discussions)。

Pull request 应遵循 [.agents/references/project/ARCHITECTURE.md](.agents/references/project/ARCHITECTURE.md) 中的约定，并在可行时包含测试覆盖。如果使用代码助手，请查看 [.agents/references/collaboration-rules.md](.agents/references/collaboration-rules.md)。

---

## 致谢

本项目最初是 [nolze](https://github.com/nolze) 的 [tiny-wifi-analyzer](https://github.com/nolze/tiny-wifi-analyzer) 的一个分支，nolze 构建了原始的基于 Python 的 Wi-Fi 扫描器。此后应用已完全用 Swift + SwiftUI + CoreWLAN 重写，演变为今天的原生 macOS 应用。

---

## 许可证

Apache License 2.0 © 2020 nolze, 2026 SHIINASAMA。详见 [LICENSE](LICENSE)。

---

**Topics:** `macos` `wifi` `network` `tool` `swift` `bluetooth` `analyzer` `swiftui` `corewlan` `corebluetooth` `open-source` `mcp`
