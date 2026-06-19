# Localization Terminology Guide

Standardized terms for `en`, `ja`, `zh-Hans`, `de`, `es` translations in `Localizable.xcstrings`.

## zh-Hans (简体中文)

| English | Use | Do NOT use | Notes |
|---------|-----|------------|-------|
| channel | 信道 | ~~频道~~, ~~通路~~ | Consistent with existing 38+ strings |
| Wi-Fi (technology) | Wi-Fi | ~~WIFI~~, ~~Wifi~~ | Hyphenated, per Apple convention |
| WiFi Lens (product) | WiFi Lens | ~~Wifi Lens~~, ~~Wi-Fi Lens~~ | Product name, no hyphen |
| AP | AP | ~~接入点~~, ~~热点~~ | Abbreviation kept as-is, per industry standard |
| network | 网络 | ~~网络连接~~ | |
| Bluetooth | 蓝牙 | ~~蓝牙技术~~ | |
| signal | 信号 | ~~讯号~~ | |
| scan / scanning | 扫描 | ~~探测~~, ~~侦测~~ | |
| System Settings | 系统设置 | ~~系统偏好设置~~ | macOS 13+ uses "系统设置" |
| Preferences (pane) | 偏好设置 | ~~偏好设定~~ | For specific preference panes |
| device | 设备 | ~~装置~~ | |
| interface | 接口 | ~~界面~~ (for network interfaces) | "界面" reserved for UI context |
| recommendation | 推荐 | ~~建议~~ (for channel recommendations) | "建议" used for advice/diagnosis |
| you (informal) | 你 | ~~您~~ | App uses informal tone throughout |
| open (verb) | 打开 | ~~开启~~ | For opening settings/apps |
| enable (verb) | 开启 | ~~启用~~ | For toggling features on |
| disabled | 已关闭 | ~~已禁用~~, ~~已停用~~ | For feature toggles |
| granted | 已授予 | ~~已允许~~ | For permission states |
| denied | 被拒绝 | ~~被拒~~ | For permission states |
| excellent | 优秀 | ~~极佳~~ | Quality tier |
| good | 良好 | ~~好~~ | Quality tier |
| moderate | 一般 | ~~中等~~ | Quality tier |
| busy | 繁忙 | ~~忙碌~~ | Quality tier |
| congested | 拥堵 | ~~拥塞~~ | Quality tier |
| low (overlap) | 低 | — | Overlap level |
| moderate (overlap) | 中等 | — | Overlap level |
| high (overlap) | 高 | — | Overlap level |

## ja (日本語)

| English | Use | Do NOT use | Notes |
|---------|-----|------------|-------|
| channel | チャンネル | ~~周波数~~ | "周波数帯" acceptable for "frequency band" |
| Wi-Fi | Wi-Fi | — | |
| WiFi Lens | WiFi Lens | — | Product name |
| AP | AP | ~~アクセスポイント~~ | Abbreviation kept as-is |
| scan | スキャン | ~~探査~~ | |
| System Settings | システム設定 | — | |
| recommendation | 推奨 | ~~勧め~~ | |
| permission (noun) | 権限 | — | "許可" reserved for verb "allow/grant" |

## de (Deutsch)

| English | Use | Do NOT use | Notes |
|---------|-----|------------|-------|
| channel | Kanal | ~~Frequenz~~ | |
| Wi-Fi | Wi-Fi | — | |
| WiFi Lens | WiFi Lens | — | Product name |
| AP | AP | ~~Zugangspunkt~~ | Abbreviation kept as-is |
| scan | Scan | ~~Abtastung~~ | |
| System Settings | Systemeinstellungen | — | |
| recommendation | Empfehlung | ~~Rat~~ | |

## es (Español)

| English | Use | Do NOT use | Notes |
|---------|-----|------------|-------|
| channel | canal | ~~frecuencia~~ | |
| Wi-Fi | Wi-Fi | — | |
| WiFi Lens | WiFi Lens | — | Product name |
| AP | AP | ~~punto de acceso~~ | Abbreviation kept as-is |
| scan | escaneo | ~~barrido~~ | |
| System Settings | Ajustes del Sistema | — | macOS Spanish localization |
| recommendation | recomendación | ~~sugerencia~~ | |

## General Rules

1. **Product name "WiFi Lens"** — never translate, never hyphenate, always exactly `WiFi Lens`
2. **Technical abbreviations** (AP, RSSI, MCS, NSS, BSSID, SSID, DFS, EMA) — keep as-is in all languages
3. **Apple terminology** — follow Apple's own localization for the target platform (e.g., macOS "System Settings" / "系统設定" / "Systemeinstellungen")
4. **Parameterized strings** — use `%@`, `%lld`, `%1$@` etc. exactly as in English; do not reorder placeholders in translation
5. **Punctuation** — follow target language conventions (e.g., `…` not `...` in ja/zh-Hans, `«»` in fr)
6. **Tone** — use informal "你" (zh-Hans), not formal "您"
