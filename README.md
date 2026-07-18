<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/screenshot-swiftui.png">
  <img alt="WiFi Lens macOS Wi-Fi spectrum analyzer" src="assets/screenshot-swiftui.png" width="800">
</picture>

# WiFi Lens

[![Swift CI](https://github.com/SHIINASAMA/wifi-lens/workflows/Swift%20CI/badge.svg)](https://github.com/SHIINASAMA/wifi-lens/actions?query=workflow%3A%22Swift+CI%22)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey)](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
[![X](https://img.shields.io/badge/X-@WiFiLens-1d9bf0)](https://x.com/WiFiLens)
[![Email](https://img.shields.io/badge/email-wifi--lens@outlook.com-0078d4)](mailto:wifi-lens@outlook.com)
[![Website](https://img.shields.io/badge/website-wifi--lens.shiinalabs.com-2563eb)](https://wifi-lens.shiinalabs.com)

🇺🇸 [English](README.md) | 🇩🇪 [Deutsch](README.de.md) | 🇪🇸 [Español](README.es-ES.md) | 🇨🇳 [简体中文](README.zh-Hans.md) | 🇯🇵 [日本語](README.ja.md)

**A native macOS tool to analyze and optimize your Wi-Fi networks.**

<p align="center">
  <a href="https://apps.apple.com/app/wifi-lens-pro/id6776590746">
    <img src="assets/appstore-badge-en.svg" alt="Download WiFi Lens Pro on the Mac App Store" width="240">
  </a>
</p>

---

## About WiFi Lens

WiFi Lens is a native macOS Wi-Fi and Bluetooth analyzer built with SwiftUI, CoreWLAN, and CoreBluetooth. It maps nearby wireless networks and BLE devices in real time, helping you diagnose connectivity problems, choose a less congested channel, and verify roaming behavior across access points.

This repository contains the free, open-source edition. WiFi Lens Pro is a separate paid edition with additional features.

**Typical use cases:**

- 🏠 **Home network tuning:** Find which channel your neighbors are saturating and move your router to a quieter one.
- 🏢 **Office Wi-Fi audit:** Scan all three bands (2.4, 5, and 6 GHz) to spot dead zones or misconfigured APs.
- 🚶 **Roaming validation:** Walk through a building and record every AP handoff with a timeline chart to verify seamless transition.
- 🎧 **BLE device troubleshooting:** Track RSSI trends of Bluetooth peripherals and identify range or interference issues.

---

## Features

| Category | Capability |
|----------|-----------|
| 📡 **Wi-Fi Scanning** | Real-time scan across 2.4, 5, and 6 GHz bands with per-network signal strength |
| 📊 **Spectrum View** | Gaussian bell-curve charts showing channel occupancy at a glance |
| 🎯 **Channel Quality** | Congestion scores with regulatory-aware recommendations tuned to your region |
| 🔍 **Network Details** | PHY generation, channel width, 802.11k/r/v roaming, WPA3, hidden SSID |
| 📶 **Connection Info** | IP, gateway, DNS, MAC, channel, Tx rate, and security summary |
| 📈 **Trend Charts** | Signal history over time per network with configurable scan interval |
| 🔄 **Roaming Test** | AP transition monitoring with timeline chart, range selector, and session save/load |
| 🗺️ **Channel Heatmap** | Per-band occupancy heatmap to spot congestion patterns instantly |
| 🎧 **BLE Scanner** | Bluetooth LE device discovery, RSSI analysis, trend charts, and device tracking |
| 🎨 **Smart Coloring** | Deterministic SSID-based color assignment; the same network keeps the same color |
| 🔒 **Privacy First** | No telemetry or analytics; Wi-Fi scan data stays on your Mac |
| 🌐 **MCP Server** | Embedded HTTP API on `127.0.0.1:19840` for external tool integration |
| 🔄 **Auto-Updates** | Optional Sparkle update checks in the GitHub edition |
| 📤 **Export** | Save per-band charts as PNG images or CSV data |
| 🌍 **Localized** | English, German, Spanish, Japanese, and Simplified Chinese |

---

## Design

**Native macOS UI.** CoreWLAN talks directly to Wi-Fi hardware, and SwiftUI provides Mac-native controls and window behavior.

**Regulatory-aware recommendations.** WiFi Lens infers your regulatory domain from system locale, hardware capability, and nearby AP country codes. It filters recommendations using DFS, indoor-only, and 6 GHz AFC requirements.

**Linked views.** Select a network in the table to highlight it on each chart. Hover over a bell curve to identify its SSID.

**Tools in the open-source edition.** Export PNG and CSV files or save and load roaming sessions. The local MCP server connects WiFi Lens to your own tools.

---

## Download

[![Download latest release](https://img.shields.io/github/v/release/SHIINASAMA/wifi-lens?label=Latest&color=2563eb)](https://github.com/SHIINASAMA/wifi-lens/releases/latest/)
[![Download WiFi Lens Pro on the Mac App Store](https://img.shields.io/badge/Download-Mac%20App%20Store-black?logo=apple)](https://apps.apple.com/app/wifi-lens-pro/id6776590746)

GitHub Releases provide the open-source edition. WiFi Lens Pro is available on the Mac App Store in supported regions.

Requires macOS 14 (Sonoma) or later. Works on both Intel and Apple Silicon Macs.

> 🌐 **Official website:** [wifi-lens.shiinalabs.com](https://wifi-lens.shiinalabs.com) provides screenshots, a feature tour, AI/MCP workflows, and an FAQ.

> [!IMPORTANT]
> On macOS 14+, **Location Services** must be enabled for the app to read Wi-Fi SSID names.
> Go to **System Settings → Privacy & Security → Location Services** and enable WiFi Lens when prompted.

## Privacy

WiFi Lens does not collect usage analytics, crash telemetry, or Wi-Fi scan data.

- **Location Services:** macOS requires this permission to expose Wi-Fi SSID names. WiFi Lens does not read your GPS position.
- **Region detection:** WiFi Lens uses the system locale, hardware-reported channel list, and nearby AP country codes on-device.
- **Network Self-Check:** When you run it, WiFi Lens resolves `example.com` and may test reachability of your configured proxy endpoints.
- **MCP server:** The optional server binds to `127.0.0.1`. Local tools can access scan data only after you enable it.
- **Update checks:** The GitHub edition contacts GitHub when you request an update check or enable automatic checks.

---

## Develop

```sh
git clone https://github.com/SHIINASAMA/wifi-lens
cd wifi-lens
git submodule update --init ChartLens
cd WiFiLens

# Build
xcodebuild -project WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build

# Run tests
xcodebuild -project WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests

# Open in Xcode
xed WiFiLens.xcodeproj
```

The product name is `WiFi Lens.app` (with space).

Architecture, testing, and roadmap docs live in [docs/](docs/).

---

## Contributing

Bug reports and feature ideas are welcome. Open an [issue](https://github.com/SHIINASAMA/wifi-lens/issues) or start a [discussion](https://github.com/SHIINASAMA/wifi-lens/discussions).

Pull requests should follow the conventions in [.agents/references/project/ARCHITECTURE.md](.agents/references/project/ARCHITECTURE.md) and include test coverage where practical. See [.agents/references/collaboration-rules.md](.agents/references/collaboration-rules.md) for AI assistant guidelines if you use coding agents.

---

## Acknowledgments

Forked from [tiny-wifi-analyzer](https://github.com/nolze/tiny-wifi-analyzer) by [nolze](https://github.com/nolze), who built the original Python-based Wi-Fi scanner. Since then the app has been fully rewritten in Swift with SwiftUI and CoreWLAN, evolving into the native macOS application it is today.

---

## License

Apache License 2.0 © 2020 nolze, 2026 SHIINASAMA. See [LICENSE](LICENSE) for full text.

---

**Topics:** `macos` `wifi` `network` `tool` `swift` `bluetooth` `analyzer` `swiftui` `corewlan` `corebluetooth` `open-source` `mcp`
