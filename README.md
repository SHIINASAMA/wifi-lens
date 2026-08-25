# WiFi Lens

**A native open-source network diagnostics app for macOS with built-in Wi-Fi analysis.**

Diagnose connectivity issues, analyze Wi-Fi channel congestion, and validate roaming behavior — with results processed locally on your Mac.

[![Latest release](https://img.shields.io/github/v/release/SHIINASAMA/wifi-lens?label=Latest&color=2563eb)](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
[![macOS](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey)](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue)](LICENSE)
[![Swift CI](https://github.com/SHIINASAMA/wifi-lens/workflows/Swift%20CI/badge.svg)](https://github.com/SHIINASAMA/wifi-lens/actions?query=workflow%3A%22Swift+CI%22)

<p align="center"><img alt="WiFi Lens showing Wi-Fi spectrum analysis on macOS" src="assets/screenshot-hero.webp" width="800"></p>

<p align="center">
  <a href="https://github.com/SHIINASAMA/wifi-lens/releases/latest"><strong>Download Open-Source Edition</strong></a>
  &nbsp;·&nbsp;
  <a href="https://apps.apple.com/app/wifi-lens-pro/id6776590746"><strong>Get WiFi Lens Pro</strong></a>
  &nbsp;·&nbsp;
  <a href="https://wifi-lens.shiinalabs.com">Official Website</a>
</p>

<p align="center">macOS 14+ &nbsp;·&nbsp; Intel &amp; Apple Silicon &nbsp;·&nbsp; No telemetry</p>

<p align="center">
  🔒 <strong>Local-first privacy</strong> — No accounts, no cloud, no telemetry<br>
  🩺 <strong>Evidence-based diagnostics</strong> — Explainable path, DNS, HTTPS, and proxy checks<br>
  🤖 <strong>MCP for AI workflows</strong> — Connect Claude Desktop to live Wi-Fi data
</p>

---

<p align="center">
  🇺🇸 English · <a href="README.de.md">🇩🇪 Deutsch</a> · <a href="README.es-ES.md">🇪🇸 Español</a> · <a href="README.fr.md">🇫🇷 Français</a> · <a href="README.zh-Hans.md">🇨🇳 简体中文</a> · <a href="README.ja.md">🇯🇵 日本語</a>
</p>
<p align="center">
  <a href="#features">Features</a> · <a href="#editions">Editions</a> · <a href="#ai--mcp-integration">AI / MCP</a> · <a href="#privacy">Privacy</a> · <a href="#installation">Installation</a> · <a href="#development">Development</a> · <a href="#contributing">Contributing</a> · <a href="#license">License</a>
</p>

---

## Features

### Core · OSS & Pro

| Feature | Description | Status |
|---------|-------------|--------|
| 📡 Wi-Fi Scanning | Real-time scan across 2.4 / 5 / 6 GHz bands | Stable |
| 📊 Spectrum View | Gaussian channel occupancy charts | Stable |
| 🎯 Channel Quality | Congestion scores with regional recommendations | Stable |
| 🔍 Network Details | PHY generation, channel width, 802.11k/r/v, WPA3 | Stable |
| 📶 Connection Info | IP, gateway, DNS, MAC, Tx rate, security summary | Stable |
| 🚶 Roaming Test | AP handoff monitoring with session save/load | Stable |
| 🗺️ Channel Heatmap | Per-band occupancy heatmap | Stable |
| 🎧 BLE Scanner | Bluetooth LE discovery, RSSI analysis, tracking | Stable |
| 🎨 Smart Coloring | Deterministic SSID-based color assignment | Stable |
| 🌐 MCP Server | Embedded HTTP API for AI tool integration | Stable |
| 📤 Export | Save charts as PNG or CSV | Stable |
| 🔒 Privacy First | No telemetry; scan data stays on your Mac | Stable |
| ⬆️ Auto-Updates | Sparkle (GitHub) or Mac App Store | Stable |
| 🌍 Localized | English, German, Spanish, Japanese, Chinese | Stable |
| 🩺 Network Self-Check | One-click path, DNS, HTTPS, proxy diagnostics | Preview |
| 📻 AP Radar | Track a selected AP with audio pulse feedback | Preview |

### Pro Exclusive

| Feature | Description | Status |
|---------|-------------|--------|
| 📈 Event Timeline | Connection event history — roaming, drops, signal changes | Preview |
| 📋 Statistics | Analyze Timeline history with period comparison | Preview |
| 💡 Insights | Explainable findings linked to evidence | Preview |
| 🎬 Spectrum Recording | Capture and replay spectrum changes over time | Stable |
| 📱 Menu Bar | Quick access from the macOS menu bar | Stable |

---

## Editions

| | Open Source | WiFi Lens Pro |
|--|------------|--------------|
| Price | Free | One-time purchase |
| Source | [GitHub Releases](https://github.com/SHIINASAMA/wifi-lens/releases/latest) | [Mac App Store](https://apps.apple.com/app/wifi-lens-pro/id6776590746) |
| Core analysis | ✅ All features above | ✅ Everything in OSS |
| Exclusive tools | — | Timeline · Statistics · Insights · Recording · Menu Bar |
| Updates | Sparkle auto-update | Mac App Store |

> Both editions share the same core analysis engine. Pro adds professional monitoring workflows built on top.

---

## AI / MCP Integration

WiFi Lens includes an embedded MCP server that lets AI assistants read your local Wi-Fi data. Enable it in Settings, then add to Claude Desktop:

```json
{
  "mcpServers": {
    "wifi-lens": {
      "url": "http://127.0.0.1:19840"
    }
  }
}
```

Once connected, ask Claude things like *"What channels are congested near me?"* or *"Is my gateway reachable?"*. The server binds to `127.0.0.1` only — nothing leaves your machine unless you deliberately route it elsewhere.

See the [AI Workflows guide](https://wifi-lens.shiinalabs.com/ai-mcp/) for more examples.

---

<table>
<tr>
<td width="50%" align="center"><img alt="Network Self-Check diagnostics view" src="assets/screenshot-selfcheck.webp" width="100%"><sub>Network Self-Check</sub></td>
<td width="50%" align="center"><img alt="Event Timeline showing connection history" src="assets/screenshot-timeline.webp" width="100%"><sub>Event Timeline (Pro)</sub></td>
</tr>
</table>

---

## Privacy

WiFi Lens does not collect usage analytics, crash telemetry, or Wi-Fi scan data.

- **Location Services:** macOS requires this permission to expose Wi-Fi SSID names. WiFi Lens does not read GPS position.
- **Region detection:** Uses system locale, hardware-reported channel list, and nearby AP country codes on-device.
- **Network Self-Check:** Resolves public endpoints (`www.apple.com`, `www.msftconnecttest.com`) and may test reachability of configured proxy endpoints.
- **MCP server:** Binds to `127.0.0.1` only. Local tools access data only after you enable it.
- **Update checks:** The GitHub edition contacts GitHub when you request an update check or enable automatic checks.

📋 [Security Policy](SECURITY.md) · 📝 [Changelog](https://github.com/SHIINASAMA/wifi-lens/releases) · 🌐 [Full privacy policy](https://wifi-lens.shiinalabs.com/privacy/)

---

## Installation

Requires **macOS 14 (Sonoma) or later**. Works on both Intel and Apple Silicon. 6 GHz scanning requires Wi-Fi 6E/7 hardware.

- **Open-source edition** — [GitHub Releases](https://github.com/SHIINASAMA/wifi-lens/releases/latest) (free, Sparkle auto-updates)
- **WiFi Lens Pro** — [Mac App Store](https://apps.apple.com/app/wifi-lens-pro/id6776590746)

> [!IMPORTANT]
> On macOS 14+, **Location Services** must be enabled for the app to read Wi-Fi SSID names. Go to **System Settings → Privacy & Security → Location Services** and enable WiFi Lens when prompted.

---

## Development

```sh
git clone https://github.com/SHIINASAMA/wifi-lens
cd wifi-lens
git submodule update --init ChartLens
cd WiFiLens

# Build
xcodebuild -project WiFiLens.xcodeproj -scheme "WiFi Lens" \
  -configuration Debug -destination 'platform=macOS' build

# Run unit tests
xcodebuild -project WiFiLens.xcodeproj -scheme "WiFi Lens" \
  -configuration Debug -destination 'platform=macOS' \
  -skipPackageUpdates test -only-testing:WiFiLensTests
```

Architecture docs live in [docs/](docs/).

---

## Contributing

Bug reports and feature ideas are welcome. See [Contributing Guidelines](.github/CONTRIBUTING.md) for setup, PR conventions, and localization requirements. Substantial contributors may receive a Pro promo code — see [Contributor Recognition](.github/CONTRIBUTING.md#contributor-recognition).

**Contact:** [@WiFiLens on X](https://x.com/WiFiLens) · [wifi-lens@shiinalabs.com](mailto:wifi-lens@shiinalabs.com)

---

Forked from [tiny-wifi-analyzer](https://github.com/nolze/tiny-wifi-analyzer). MAC vendor data from the [IEEE Registration Authority](https://standards.ieee.org/products-programs/regauth/) — see [Third-Party Notices](docs/THIRD-PARTY-NOTICES.md).

Apache License 2.0 © 2020 nolze, 2026 SHIINASAMA — see [LICENSE](LICENSE).
