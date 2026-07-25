# WiFi Lens

**一款原生、开源的 macOS Wi-Fi 分析与网络诊断应用。**

可视化信道拥堵、排查连接问题、验证 Wi-Fi 漫游——全部在你的 Mac 上本地完成。

[![最新版本](https://img.shields.io/github/v/release/SHIINASAMA/wifi-lens?label=Latest&color=2563eb)](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
[![macOS](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey)](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
[![许可证](https://img.shields.io/badge/license-Apache%202.0-blue)](LICENSE)
[![Swift CI](https://github.com/SHIINASAMA/wifi-lens/workflows/Swift%20CI/badge.svg)](https://github.com/SHIINASAMA/wifi-lens/actions?query=workflow%3A%22Swift+CI%22)

<p align="center">
  <a href="https://github.com/SHIINASAMA/wifi-lens/releases/latest"><strong>下载开源版</strong></a>
  ·
  <a href="https://apps.apple.com/app/wifi-lens-pro/id6776590746"><strong>获取 WiFi Lens Pro</strong></a>
  ·
  <a href="https://wifi-lens.shiinalabs.com">官方网站</a>
</p>

macOS 14+ · Intel 与 Apple Silicon · 无遥测

<img alt="WiFi Lens 在 macOS 上进行 Wi-Fi 频谱分析" src="assets/screenshot-swiftui.png" width="800">

## 开源版还是 Pro？

| 开源版 | WiFi Lens Pro |
|---|---|
| 免费、开源 — [GitHub Releases](https://github.com/SHIINASAMA/wifi-lens/releases/latest) | 一次性付费 Mac App Store 版本 — [Mac App Store](https://apps.apple.com/app/wifi-lens-pro/id6776590746) |
| 三频 Wi-Fi 扫描与频谱分析 | 基于同一核心分析引擎的专业监控工作流 |
| 信道质量、网络详情、漫游测试 | 频谱会话录制——随时间捕获与回放 |
| 网络自检、BLE 扫描器、MCP 服务器 | 更多专业工作流 |
| 导出 PNG/CSV · Sparkle 更新 | 常驻菜单栏 · 事件时间线 · Mac App Store 更新 |

> 两版共享相同的核心 Wi-Fi 分析能力。Pro 增加频谱录制、常驻菜单栏与事件时间线，面向专业工作流。

🇺🇸 [English](README.md) | 🇩🇪 [Deutsch](README.de.md) | 🇪🇸 [Español](README.es-ES.md) | 🇨🇳 [简体中文](README.zh-Hans.md) | 🇯🇵 [日本語](README.ja.md)

---

## 关于 WiFi Lens

WiFi Lens 是一款使用 SwiftUI、CoreWLAN 和 CoreBluetooth 开发的原生 macOS Wi-Fi 与蓝牙分析器。它实时呈现附近的无线网络和 BLE 设备，帮助你诊断连接问题、选择拥堵较少的信道，并验证接入点之间的漫游行为。

本仓库提供免费开源版。WiFi Lens Pro 是独立付费版，增加频谱录制、常驻菜单栏与事件时间线功能。

**典型使用场景：**

- 🏠 **家庭网络调优：** 找出邻居占用的信道，然后将路由器切换到较空闲的信道。
- 🏢 **办公室 Wi-Fi 审计：** 扫描 2.4、5 和 6 GHz 三个频段，发现信号死角或配置错误的 AP。
- 🚶 **漫游验证：** 在建筑内移动时记录每次 AP 切换，通过时间线图验证漫游是否顺畅。
- 🎧 **BLE 设备排障：** 追踪蓝牙外设的 RSSI 趋势，识别覆盖范围或干扰问题。

---

## 功能

| 类别 | 能力 | 版本 |
|----------|-----------|---------|
| 📡 **Wi-Fi 扫描** | 跨 2.4、5 和 6 GHz 频段的实时扫描，显示每网络信号强度 | OSS & Pro |
| 📊 **频谱视图** | 高斯钟形曲线图直观展示各频段信道占用情况 | OSS & Pro |
| 🎯 **信道质量** | 拥堵评分 + 基于区域规则的推荐，适配你的监管域 | OSS & Pro |
| 🔍 **网络详情** | PHY 代际、信道宽度、802.11k/r/v 漫游、WPA3、隐藏 SSID | OSS & Pro |
| 📶 **连接信息** | IP、网关、DNS、MAC、信道、发送速率和安全摘要 | OSS & Pro |
| 🩺 **网络自检** | 一键连接诊断——路径、DNS、HTTPS 与代理可达性，基于证据给出结论 | OSS & Pro |
| 📈 **事件时间线** | 连接事件历史——漫游、信道变更、断连与信号下降 | 仅 Pro |
| 🔄 **漫游测试** | AP 切换监控，含时间线图、范围选择器和会话保存/加载 | OSS & Pro |
| 🗺️ **信道热力图** | 各频段占用热力图，瞬间发现拥堵模式 | OSS & Pro |
| 🎬 **频谱录制** | 随时间捕获并回放频谱变化 | 仅 Pro |
| 🎧 **BLE 扫描器** | Bluetooth LE 设备发现、RSSI 分析、趋势图表和设备追踪 | OSS & Pro |
| 🎨 **智能着色** | 基于 SSID 确定颜色；同一网络始终保持相同颜色 | OSS & Pro |
| 📍 **菜单栏** | 常驻菜单栏——点击图标即可随时打开分析器 | 仅 Pro |
| 🔒 **隐私优先** | 无遥测或使用分析；Wi-Fi 扫描数据保留在你的 Mac 上 | OSS & Pro |
| 🌐 **MCP 服务器** | 内嵌 HTTP API（`127.0.0.1:19840`），支持外部工具集成 | OSS & Pro |
| 🔄 **自动更新** | GitHub 版使用 Sparkle 更新；Pro 使用 Mac App Store 更新 | OSS & Pro |
| 📤 **导出** | 保存各频段图表为 PNG 图片或 CSV 数据 | OSS & Pro |
| 🌍 **本地化** | 英语、德语、西班牙语、日语和简体中文 | OSS & Pro |

除标注 **仅 Pro** 的功能外，其余功能均包含在开源版中。Pro 包含开源版的全部功能，并额外提供录制、常驻菜单栏与事件时间线工具。

---

## 设计

**原生 macOS 界面。** CoreWLAN 直接与 Wi-Fi 硬件通信，SwiftUI 提供原生 Mac 控件和窗口行为。

**结合地区法规的信道推荐。** WiFi Lens 根据系统地区、硬件能力和附近 AP 的国家代码推断监管域，并按照 DFS、室内使用和 6 GHz AFC 要求筛选推荐结果。

**联动视图。** 在表格中选择网络后，各图表会同时高亮该网络。将指针悬停在钟形曲线上即可查看 SSID。

**开源版工具。** 导出 PNG 和 CSV 文件，或保存并加载漫游会话。本地 MCP 服务器可将 WiFi Lens 连接到你的工具。

---

## 下载

需要 **macOS 14 (Sonoma) 或更高版本**。兼容 Intel 和 Apple Silicon Mac。6 GHz 频段扫描需要 Wi-Fi 6E/7 硬件。

- **开源版** — [GitHub Releases](https://github.com/SHIINASAMA/wifi-lens/releases/latest)（免费，提供可选的 Sparkle 自动更新）
- **WiFi Lens Pro** — [Mac App Store](https://apps.apple.com/app/wifi-lens-pro/id6776590746)（支持地区）

> [!IMPORTANT]
> 在 macOS 14+ 上，**定位服务**必须启用才能读取 Wi-Fi SSID 名称。
> 前往 **系统设置 → 隐私与安全性 → 定位服务**，在提示时启用 WiFi Lens。

> 🌐 **官方网站：** [wifi-lens.shiinalabs.com](https://wifi-lens.shiinalabs.com) 提供截图、功能导览、AI/MCP 工作流和常见问题。

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

**联系方式：** [X 上的 @WiFiLens](https://x.com/WiFiLens) · [wifi-lens@shiinalabs.com](mailto:wifi-lens@shiinalabs.com)

---

## 致谢

本项目最初是 [nolze](https://github.com/nolze) 的 [tiny-wifi-analyzer](https://github.com/nolze/tiny-wifi-analyzer) 的一个分支，nolze 构建了原始的基于 Python 的 Wi-Fi 扫描器。此后应用已完全用 Swift + SwiftUI + CoreWLAN 重写，演变为今天的原生 macOS 应用。

---

## 许可证

Apache License 2.0 © 2020 nolze, 2026 SHIINASAMA。详见 [LICENSE](LICENSE)。
