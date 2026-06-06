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

🇺🇸 [English](README.md) | 🇩🇪 [Deutsch](README.de.md) | 🇪🇸 [Español](README.es-ES.md) | 🇨🇳 [简体中文](README.zh-Hans.md) | 🇯🇵 [日本語](README.ja.md)

**A native macOS tool to analyze and optimize your Wi-Fi networks.**

---

## What is WiFi Lens?

WiFi Lens is a free, open-source Wi-Fi and Bluetooth analyzer built entirely with native macOS frameworks — SwiftUI, CoreWLAN, and CoreBluetooth. It gives you a real-time, visual map of every wireless network and BLE device around you, so you can diagnose connectivity problems, pick the least crowded channel, and verify roaming behavior across access points.

Unlike web-based scanners or cross-platform electron apps, WiFi Lens runs with zero overhead, respects your privacy, and looks right at home on your Mac.

**Typical use cases:**
- 🏠 **Home network tuning** — Find which channel your neighbors are saturating and move your router to a quieter one.
- 🏢 **Office Wi-Fi audit** — Scan all three bands (2.4, 5, and 6 GHz) to spot dead zones or misconfigured APs.
- 🚶 **Roaming validation** — Walk through a building and record every AP handoff with a timeline chart to verify seamless transition.
- 🎧 **BLE device troubleshooting** — Track RSSI trends of Bluetooth peripherals and identify range or interference issues.

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
| 🎨 **Smart Coloring** | Deterministic SSID-based color assignment — same network always gets the same color |
| 🔒 **Privacy First** | No telemetry, no analytics, no data collection — everything stays on your Mac |
| 🌐 **MCP Server** | Embedded HTTP API on `127.0.0.1:19840` for external tool integration |
| 🔄 **Auto-Updates** | Built-in Sparkle update support so you always run the latest version |
| 📤 **Export** | Save per-band charts as PNG images or CSV data |
| 🌍 **Localized** | Full support for English, 日本語, and 简体中文 |

---

## What makes WiFi Lens different?

**Native performance, not a web wrapper.** CoreWLAN talks directly to the Wi-Fi hardware — no middleware, no JavaScript bridge, no wasted CPU cycles. Scanning hundreds of networks per pass on modern Apple Silicon is effortless.

**Regulatory intelligence built in.** Most tools show raw channel numbers and call it a day. WiFi Lens infers your regulatory domain from system locale, hardware capability, and nearby AP country codes, then recommends channels you're actually allowed to use — respecting DFS, indoor-only, and 6 GHz AFC rules.

**Everything is connected.** Click a network in the table and it highlights on every chart. Hover a bell curve and see the SSID pop up. Freeze one band while the others keep scanning. It's designed like a cockpit, not a dashboard.

**Room for power users.** Export PNG/CSV, run a roaming test with session save/load, or integrate with your own tools via the built-in MCP HTTP server — all without hidden paywalls.

---

## Download

[![Download latest release](https://img.shields.io/github/v/release/SHIINASAMA/wifi-lens?label=Latest&color=2563eb)](https://github.com/SHIINASAMA/wifi-lens/releases/latest/)

Requires macOS 14 (Sonoma) or later. Works on both Intel and Apple Silicon Macs.

> [!IMPORTANT]
> On macOS 14+, **Location Services** must be enabled for the app to read Wi-Fi SSID names.
> Go to **System Settings → Privacy & Security → Location Services** and enable WiFi Lens when prompted.

### Gatekeeper workaround

The app is fully signed and notarized by Apple.

- **Right-click** the app → **Open** → confirm in the dialog; or
- Run in Terminal:
  ```sh
  xattr -d com.apple.quarantine /Applications/WiFi\ Lens.app
  ```

---

## Privacy

WiFi Lens collects **nothing**. No usage analytics, no crash telemetry, no network traffic to external servers.

- **Location Services** — Required by macOS to expose Wi-Fi SSID names. WiFi Lens never reads your GPS position.
- **Region detection** — Uses system locale, hardware-reported channel list, and nearby AP country codes. Runs entirely on-device.
- **MCP server** — Bound to `127.0.0.1` only. No scan data leaves your machine unless you route it elsewhere.

---

## Develop

```sh
git clone https://github.com/SHIINASAMA/wifi-lens
cd wifi-lens/WiFiLens

# Build
xcodebuild -project WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build

# Run tests
xcodebuild -project WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' test

# Open in Xcode
xed WiFiLens.xcodeproj
```

The product name is `WiFi Lens.app` (with space).

### Website

The landing page is built with Vite and Tailwind CSS, outputting to `_site/`.

```sh
cd wifi-lens          # repo root
npm ci
npm run dev           # dev server at localhost:5173/wifi-lens/
npm run build         # production build
npm run preview       # preview production build
```

Architecture, testing, and roadmap docs live in [docs/](docs/).

---

## Contributing

Bug reports and feature ideas are welcome — open an [issue](https://github.com/SHIINASAMA/wifi-lens/issues) or start a [discussion](https://github.com/SHIINASAMA/wifi-lens/discussions).

Pull requests should follow the conventions in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and include test coverage where practical. See [docs/COLLABORATION_RULES.md](docs/COLLABORATION_RULES.md) for AI assistant guidelines if you use coding agents.

---

## Acknowledgments

Forked from [tiny-wifi-analyzer](https://github.com/nolze/tiny-wifi-analyzer) by [nolze](https://github.com/nolze), who built the original Python-based Wi-Fi scanner. Since then the app has been fully rewritten in Swift with SwiftUI and CoreWLAN, evolving into the native macOS application it is today.

---

## License

Apache License 2.0 © 2020 nolze, 2026 SHIINASAMA. See [LICENSE](LICENSE) for full text.

---

**Topics:** `macos` `wifi` `network` `tool` `swift` `bluetooth` `analyzer` `swiftui` `corewlan` `corebluetooth` `open-source` `mcp`
