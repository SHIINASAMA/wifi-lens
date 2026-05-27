# WiFi Lens

[![Swift CI](https://github.com/SHIINASAMA/wifi-lens/workflows/Build%20&%20Release/badge.svg)](https://github.com/SHIINASAMA/wifi-lens/actions?query=workflow%3A%22Build+%26+Release%22)
[![X](https://img.shields.io/badge/X-@WiFiLens-1d9bf0)](https://x.com/WiFiLens)
[![Email](https://img.shields.io/badge/email-wifi--lens@outlook.com-0078d4)](mailto:wifi-lens@outlook.com)

一款简单的开源 macOS Wi-Fi 频道与信号强度分析工具。
基于 SwiftUI、CoreWLAN 和 Sparkle 构建。

![screenshot](assets/screenshot-swiftui.png)

🇺🇸 [English](README.md) | 🇨🇳 [简体中文](README.zh-Hans.md) | 🇯🇵 [日本語](README.ja.md)

## 功能

- 跨 2.4 GHz、5 GHz、6 GHz 频段的实时 Wi-Fi 扫描
- 每频段高斯钟形曲线图，支持动态 Y 轴缩放
- 每频段独立冻结与拖拽缩放
- 基于 SSID 的确定性颜色分配
- 整合网络表格，支持原生列排序、行选择和图表高亮
- 跨所有频段按 SSID 或 BSSID 过滤网络
- 802.11 能力详情：PHY 代际、信道宽度、802.11k/r/v 漫游、WPA3、隐藏 SSID
- 已连接网络状态：IP、网关、DNS、MAC、信道、发送速率、安全
- 连接质量评分与信道拥堵分析
- 每网络信号历史趋势图
- 漫游测试：AP 切换监控，含时间线图、范围选择器和会话保存/加载
- 每频段信道占用热力图
- 可配置扫描间隔（1–10 秒）
- 将每频段图表导出为 PNG 或 CSV
- MCP（模型上下文协议）HTTP 服务器，用于外部工具集成
- 内置 Sparkle 自动更新支持
- 崩溃报告与结构化日志
- 英语、简体中文、日语本地化

## 系统要求

- macOS 14.0 (Sonoma) 或更高版本

> [!IMPORTANT]
> 在 macOS 14 及以上版本中，读取 Wi-Fi SSID 需要定位服务权限。
> 打开 **系统设置 → 隐私与安全性 → 定位服务**，在提示时为应用启用权限。

## 隐私

WiFi Lens 不会收集、存储或传输任何个人信息、使用分析或遥测数据。所有数据均保留在你的 Mac 上。

- **定位服务** — macOS 要求此权限才能暴露 Wi-Fi SSID 名称。WiFi Lens 绝不会访问你的 GPS 坐标。
- **区域检测** — 信道推荐使用系统区域设置、硬件报告的信道列表以及附近 AP 的国家代码来推断监管域。此推断完全在设备上运行。
- **MCP 服务器** — 绑定到 `127.0.0.1`。除非你明确将数据路由到其他地方，否则扫描数据不会离开你的机器。

## 下载

[访问最新版本](https://github.com/SHIINASAMA/wifi-lens/releases/latest/)

### Gatekeeper 解决方法

由于应用未签名，macOS Gatekeeper 可能会阻止其运行。

- **右键点击**应用图标 → **打开** → 在对话框中确认；或
- 在终端中运行：
  ```sh
  xattr -d com.apple.quarantine /Applications/WiFi\ Lens.app
  ```

## 开发

```sh
git clone https://github.com/SHIINASAMA/wifi-lens
cd wifi-lens/WiFiLens

# 构建
xcodebuild -project WiFiLens.xcodeproj -scheme WiFiLens -configuration "Debug-OSS" -destination 'platform=macOS' build

# 运行测试
xcodebuild -project WiFiLens.xcodeproj -scheme WiFiLens -configuration "Debug-OSS" -destination 'platform=macOS' test

# 在 Xcode 中打开
xed WiFiLens.xcodeproj
```

有关架构、路线图和已知问题的文档，请参阅 [docs/](docs/) 目录。

## 致谢

本项目最初是 [nolze](https://github.com/nolze) 创建的 [tiny-wifi-analyzer](https://github.com/nolze/tiny-wifi-analyzer) 的一个分支，nolze 构建了原始的基于 Python 的 Wi-Fi 扫描器。此后，应用已完全用 Swift 与 SwiftUI、CoreWLAN 重写，演变为一个全新名称的原生 macOS 应用。

## 许可证

```
Copyright 2020 nolze
Copyright 2026 SHIINASAMA

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
