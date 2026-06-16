<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/screenshot-swiftui.png">
  <img alt="WiFi Lens — macOS Wi-Fi spectrum analyzer" src="assets/screenshot-swiftui.png" width="800">
</picture>

# WiFi Lens

[![Swift CI](https://github.com/SHIINASAMA/wifi-lens/workflows/Build%20&%20Release/badge.svg)](https://github.com/SHIINASAMA/wifi-lens/actions?query=workflow%3A%22Build+%26+Release%22)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey)](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
[![X](https://img.shields.io/badge/X-@WiFiLens-1d9bf0)](https://x.com/WiFiLens)
[![Email](https://img.shields.io/badge/email-wifi--lens@outlook.com-0078d4)](mailto:wifi-lens@outlook.com)

**一款原生 macOS 工具，用于分析和优化你的 Wi-Fi 网络。**

---

## WiFi Lens 是什么？

WiFi Lens 是一款免费开源的 Wi-Fi 和蓝牙分析器，完全使用 macOS 原生框架（SwiftUI、CoreWLAN、CoreBluetooth）构建。它为周围每一个无线网络和 BLE 设备提供实时可视化地图，让你能够诊断连接问题、选择最空闲的信道，并验证跨接入点的漫游行为。

与基于网页的扫描器或跨平台的 Electron 应用不同，WiFi Lens 零开销运行，尊重你的隐私，并且完美融入 macOS 生态。

**典型使用场景：**
- 🏠 **家庭网络调优** — 找出邻居占用了哪个信道，然后把路由器移到更安静的频道上。
- 🏢 **办公室 Wi-Fi 审计** — 扫描全部三个频段（2.4、5 和 6 GHz），发现信号死角或配置错误的 AP。
- 🚶 **漫游验证** — 穿过一栋建筑时记录每一次 AP 切换，用时间线图验证无缝过渡是否正常工作。
- 🎧 **BLE 设备排障** — 追踪蓝牙外设的 RSSI 趋势，识别范围或干扰问题。

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
| 🎨 **智能着色** | 基于 SSID 的确定性颜色分配 — 同一网络始终显示相同颜色 |
| 🔒 **隐私优先** | 无遥测、无分析、无数据收集 — 所有数据保留在你的 Mac 上 |
| 🌐 **MCP 服务器** | 内嵌 HTTP API（`127.0.0.1:19840`），支持外部工具集成 |
| 🔄 **自动更新** | 内置 Sparkle 更新支持，随时运行最新版本 |
| 📤 **导出** | 保存各频段图表为 PNG 图片或 CSV 数据 |
| 🌍 **本地化** | 完整支持英语、日本語和简体中文 |

---

## 差异化亮点

**原生性能，而非网页包装。** CoreWLAN 直接与 Wi-Fi 硬件对话 — 没有中间层、没有 JavaScript 桥接、不浪费 CPU 周期。在现代 Apple Silicon 上每秒扫描数百个网络毫无压力。

**内置法规智能。** 大多数工具只显示原始信道编号就完事了。WiFi Lens 从系统区域设置、硬件能力和附近 AP 的国家代码推断你的监管域，然后推荐你真正允许使用的信道 — 尊重 DFS、室内专用和 6 GHz AFC 规则。

**一切互联互通。** 点击表格中的网络，它在所有图表中高亮显示；悬停在钟形曲线上，SSID 立即弹出；冻结一个频段而其他频段继续扫描。它的设计像驾驶舱，而非仪表盘。

**为高级用户预留空间。** 导出 PNG/CSV、运行带会话保存/加载的漫游测试，或通过内嵌 MCP HTTP 服务器与自己的工具集成 — 没有隐藏的付费墙。

---

## 下载

[![下载最新版本](https://img.shields.io/github/v/release/SHIINASAMA/wifi-lens?label=Latest&color=2563eb)](https://github.com/SHIINASAMA/wifi-lens/releases/latest/)
[![在 Mac App Store 下载](https://img.shields.io/badge/Download-Mac%20App%20Store-black?logo=apple)](https://apps.apple.com/app/id6776590746)

需要 macOS 14 (Sonoma) 或更高版本。兼容 Intel 和 Apple Silicon Mac。

> [!IMPORTANT]
> 在 macOS 14+ 上，**定位服务**必须启用才能读取 Wi-Fi SSID 名称。
> 前往 **系统设置 → 隐私与安全性 → 定位服务**，在提示时启用 WiFi Lens。

### Gatekeeper 解决方法

该应用已完整签名并经过 Apple 公证。

- **右键点击**应用 → **打开** → 在对话框中确认；或
- 在终端运行：
  ```sh
  xattr -d com.apple.quarantine /Applications/WiFi\ Lens.app
  ```

---

## 隐私

WiFi Lens **什么都不收集**。无使用分析、无崩溃遥测、无外部服务器网络流量。

- **定位服务** — macOS 要求此权限以暴露 Wi-Fi SSID 名称。WiFi Lens 从不读取你的 GPS 位置。
- **区域检测** — 使用系统区域设置、硬件报告的信道列表和附近 AP 国家代码。完全在设备上运行。
- **MCP 服务器** — 仅绑定到 `127.0.0.1`。除非你明确将数据路由到其他地方，否则扫描数据不会离开你的机器。

---

## 开发

```sh
git clone https://github.com/SHIINASAMA/wifi-lens
cd wifi-lens/WiFiLens

# 构建
xcodebuild -project WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build

# 运行测试
xcodebuild -project WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' test

# 在 Xcode 中打开
xed WiFiLens.xcodeproj
```

产品名为 `WiFi Lens.app`（带空格）。

### Website

Landing page 使用 Vite + Tailwind CSS 构建，输出到 `_site/`。

```sh
cd wifi-lens          # repo root
npm ci
npm run dev           # dev server at localhost:5173/wifi-lens/
npm run build         # production build
npm run preview       # preview production build
```

架构、测试和路线图文档位于 [docs/](docs/)。

---

## 贡献

欢迎提交 Bug 报告和功能建议 — 打开 [issue](https://github.com/SHIINASAMA/wifi-lens/issues) 或发起 [discussion](https://github.com/SHIINASAMA/wifi-lens/discussions)。

Pull request 应遵循 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) 中的约定，并在可行时包含测试覆盖。如果使用代码助手，请查看 [docs/COLLABORATION_RULES.md](docs/COLLABORATION_RULES.md)。

---

## 致谢

本项目最初是 [nolze](https://github.com/nolze) 的 [tiny-wifi-analyzer](https://github.com/nolze/tiny-wifi-analyzer) 的一个分支，nolze 构建了原始的基于 Python 的 Wi-Fi 扫描器。此后应用已完全用 Swift + SwiftUI + CoreWLAN 重写，演变为今天的原生 macOS 应用。

---

## 许可证

Apache License 2.0 © 2020 nolze, 2026 SHIINASAMA。详见 [LICENSE](LICENSE)。

---

**Topics:** `macos` `wifi` `network` `tool` `swift` `bluetooth` `analyzer` `swiftui` `corewlan` `corebluetooth` `open-source` `mcp`
