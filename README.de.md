# WiFi Lens

**Eine native Open-Source-Netzwerkdiagnose-App für macOS mit integrierter Wi-Fi-Analyse.**

Diagnostiziere Verbindungsprobleme, analysiere die Kanalauslastung und validiere Roaming-Verhalten — alle Ergebnisse werden lokal auf deinem Mac verarbeitet.

[![Latest release](https://img.shields.io/github/v/release/SHIINASAMA/wifi-lens?label=Latest&color=2563eb)](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
[![macOS](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey)](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue)](LICENSE)
[![Swift CI](https://github.com/SHIINASAMA/wifi-lens/workflows/Swift%20CI/badge.svg)](https://github.com/SHIINASAMA/wifi-lens/actions?query=workflow%3A%22Swift+CI%22)

<p align="center"><img alt="WiFi Lens Spektrum-Analyse auf macOS" src="assets/screenshot-hero.webp" width="800"></p>

<p align="center">
  <a href="https://github.com/SHIINASAMA/wifi-lens/releases/latest"><strong>Open-Source-Edition herunterladen</strong></a>
  &nbsp;·&nbsp;
  <a href="https://apps.apple.com/app/wifi-lens-pro/id6776590746"><strong>WiFi Lens Pro holen</strong></a>
  &nbsp;·&nbsp;
  <a href="https://wifi-lens.shiinalabs.com">Offizielle Website</a>
</p>

<p align="center">macOS 14+ &nbsp;·&nbsp; Intel &amp; Apple Silicon &nbsp;·&nbsp; Keine Telemetrie</p>

<p align="center">
  🔒 <strong>Local-first privacy</strong> — Keine Konten, keine Cloud, keine Telemetrie<br>
  🩺 <strong>Evidenzbasierte Diagnose</strong> — Pfad-, DNS-, HTTPS- und Proxy-Prüfungen<br>
  🤖 <strong>MCP für KI-Workflows</strong> — Claude Desktop mit Live-Wi-Fi-Daten verbinden
</p>

---

<p align="center">
  <a href="README.md">🇺🇸 English</a> · 🇩🇪 Deutsch · <a href="README.es-ES.md">🇪🇸 Español</a> · <a href="README.fr.md">🇫🇷 Français</a> · <a href="README.zh-Hans.md">🇨🇳 简体中文</a> · <a href="README.ja.md">🇯🇵 日本語</a>
</p>
<p align="center">
  <a href="#funktionen">Funktionen</a> · <a href="#editionen">Editionen</a> · <a href="#ki--mcp-integration">KI / MCP</a> · <a href="#privatsphäre">Privatsphäre</a> · <a href="#installation">Installation</a> · <a href="#entwicklung">Entwicklung</a> · <a href="#mitwirken">Mitwirken</a> · <a href="#lizenz">Lizenz</a>
</p>

---

## Funktionen

### Kern · OSS & Pro

| Funktion | Beschreibung | Status |
|----------|-------------|--------|
| 📡 Wi-Fi-Scanning | Echtzeit-Scan über 2,4 / 5 / 6 GHz | Stabil |
| 📊 Spektrum-Ansicht | Gauß-Kanalbelegungsdiagramme | Stabil |
| 🎯 Kanalqualität | Auslastungsbewertungen mit regionalen Empfehlungen | Stabil |
| 🔍 Netzwerkdetails | PHY-Generation, Kanalbreite, 802.11k/r/v, WPA3 | Stabil |
| 📶 Verbindungsinformationen | IP, Gateway, DNS, MAC, Tx-Rate, Sicherheit | Stabil |
| 🚶 Roaming-Test | AP-Wechsel-Überwachung mit Sitzungsverwaltung | Stabil |
| 🗺️ Kanal-Heatmap | Belegungsübersicht pro Band | Stabil |
| 🎧 BLE-Scanner | Bluetooth LE-Erkennung, RSSI-Analyse, Tracking | Stabil |
| 🎨 Intelligente Farbgebung | Deterministische SSID-Farbzuordnung | Stabil |
| 🌐 MCP-Server | Eingebettete HTTP-API für KI-Tools | Stabil |
| 📤 Exportieren | Diagramme als PNG oder CSV speichern | Stabil |
| 🔒 Privatsphäre zuerst | Keine Telemetrie; Scandaten bleiben lokal | Stabil |
| ⬆️ Auto-Updates | Sparkle (GitHub) oder Mac App Store | Stabil |
| 🌍 Lokalisiert | Englisch, Deutsch, Spanisch, Japanisch, Chinesisch | Stabil |
| 🩺 Netzwerk-Selbsttest | Ein-Klick-Diagnose: Pfad, DNS, HTTPS, Proxy | Vorschau |
| 📻 AP-Radar | Zugangspunkt mit Audio-Puls-Feedback verfolgen | Vorschau |

### Pro exklusiv

| Funktion | Beschreibung | Status |
|----------|-------------|--------|
| 📈 Ereignis-Zeitachse | Verbindungsereignis-Verlauf — Roaming, Abbrüche, Signalwechsel | Vorschau |
| 📋 Statistiken | Timeline-Verlauf mit Periodenvergleich analysieren | Vorschau |
| 💡 Erkenntnisse | Nachvollziehbare Erkenntnisse mit Evidenz-Links | Vorschau |
| 🎬 Spektrum-Aufzeichnung | Spektrumsänderungen über Zeit aufzeichnen | Stabil |
| 📱 Menüleiste | Schnellzugriff über die macOS-Menüleiste | Stabil |

---

## Editionen

| | Open Source | WiFi Lens Pro |
|--|------------|--------------|
| Preis | Kostenlos | Einmalkauf |
| Quelle | [GitHub Releases](https://github.com/SHIINASAMA/wifi-lens/releases/latest) | [Mac App Store](https://apps.apple.com/app/wifi-lens-pro/id6776590746) |
| Kernanalyse | ✅ Alle oben genannten Funktionen | ✅ Alles aus OSS |
| Exklusive Tools | — | Zeitachse · Statistiken · Erkenntnisse · Aufzeichnung · Menüleiste |
| Updates | Sparkle Auto-Update | Mac App Store |

> Beide Editionen teilen sich dieselbe Analyse-Engine. Pro ergänzt professionelle Monitoring-Workflows.

---

## KI / MCP Integration

WiFi Lens enthält einen eingebetteten MCP-Server, der KI-Assistenten den Zugriff auf lokale Wi-Fi-Daten ermöglicht. Aktiviere ihn in den Einstellungen und füge ihn zu Claude Desktop hinzu:

```json
{
  "mcpServers": {
    "wifi-lens": {
      "url": "http://127.0.0.1:19840"
    }
  }
}
```

Nach der Verbindung kannst du Claude Fragen stellen wie _„Welche Kanäle sind bei mir überlastet?"_ oder _„Ist mein Gateway erreichbar?"_. Der Server bindet nur an `127.0.0.1` — nichts verlässt deine Maschine, außer du leitest es bewusst woandershin.

Siehe den [KI-Workflows-Leitfaden](https://wifi-lens.shiinalabs.com/ai-mcp/) für weitere Beispiele.

---

<table>
<tr>
<td width="50%" align="center"><img alt="Netzwerk-Selbsttest Diagnoseansicht" src="assets/screenshot-selfcheck.webp" width="100%"><sub>Netzwerk-Selbsttest</sub></td>
<td width="50%" align="center"><img alt="Ereignis-Zeitachse mit Verbindungshistorie" src="assets/screenshot-timeline.webp" width="100%"><sub>Ereignis-Zeitachse (Pro)</sub></td>
</tr>
</table>

---

## Privatsphäre

WiFi Lens sammelt keine Nutzungsanalysen, Crash-Telemetrie oder Wi-Fi-Scandaten.

- **Standortdienste:** macOS erfordert diese Berechtigung zum Auslesen von Wi-Fi-SSID-Namen. WiFi Lens liest keine GPS-Position.
- **Regionserkennung:** Nutzt Systemsprache, hardwaregemeldete Kanalliste und Ländercodes benachbarter APs auf dem Gerät.
- **Netzwerk-Selbsttest:** Löst öffentliche Endpunkte auf (`www.apple.com`, `www.msftconnecttest.com`) und prüft ggf. die Erreichbarkeit konfigurierter Proxy-Endpunkte.
- **MCP-Server:** Bindet nur an `127.0.0.1`. Lokale Tools greifen erst nach Aktivierung auf Daten zu.
- **Update-Prüfungen:** Die GitHub-Edition kontaktiert GitHub bei Update-Anfragen.

📋 [Sicherheitsrichtlinie](SECURITY.md) · 📝 [Changelog](https://github.com/SHIINASAMA/wifi-lens/releases) · ❓ [FAQ](https://wifi-lens.shiinalabs.com/faq/) · 🌐 [Vollständige Datenschutzerklärung](https://wifi-lens.shiinalabs.com/privacy/)

---

## Installation

Erfordert **macOS 14 (Sonoma) oder höher**. Funktioniert auf Intel- und Apple Silicon-Macs. 6-GHz-Scanning erfordert Wi-Fi-6E/7-Hardware.

- **Open-Source-Edition** — [GitHub Releases](https://github.com/SHIINASAMA/wifi-lens/releases/latest) (kostenlos, Sparkle Auto-Updates)
- **WiFi Lens Pro** — [Mac App Store](https://apps.apple.com/app/wifi-lens-pro/id6776590746)

> [!IMPORTANT]
> Unter macOS 14+ müssen die **Standortdienste** aktiviert sein, damit die App Wi-Fi-SSIDs lesen kann. Gehe zu **Systemeinstellungen → Datenschutz & Sicherheit → Standortdienste**.

---

## Entwicklung

```sh
git clone https://github.com/SHIINASAMA/wifi-lens
cd wifi-lens
git submodule update --init ChartLens
cd WiFiLens

xcodebuild -project WiFiLens.xcodeproj -scheme "WiFi Lens" \
  -configuration Debug -destination 'platform=macOS' build
```

Architekturdocs findest du in [docs/](docs/).

---

## Mitwirken

Fehlerberichte und Feature-Ideen sind willkommen. Siehe [Contributing Guidelines](.github/CONTRIBUTING.md) für Setup und Konventionen. Wesentliche Beitragende können einen Pro-Promo-Code erhalten — siehe [Contributor Recognition](.github/CONTRIBUTING.md#contributor-recognition).

**Kontakt:** [@WiFiLens auf X](https://x.com/WiFiLens) · [wifi-lens@shiinalabs.com](mailto:wifi-lens@shiinalabs.com)

---

Forked from [tiny-wifi-analyzer](https://github.com/nolze/tiny-wifi-analyzer). MAC-Vendor-Daten von der [IEEE Registration Authority](https://standards.ieee.org/products-programs/regauth/) — siehe [Third-Party Notices](docs/THIRD-PARTY-NOTICES.md).

Apache License 2.0 © 2020 nolze, 2026 SHIINASAMA — siehe [LICENSE](LICENSE).
