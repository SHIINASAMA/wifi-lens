<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/screenshot-swiftui.png">
  <img alt="WiFi Lens macOS Wi-Fi-Spektrumanalysator" src="assets/screenshot-swiftui.png" width="800">
</picture>

# WiFi Lens

[![Swift CI](https://github.com/SHIINASAMA/wifi-lens/workflows/Swift%20CI/badge.svg)](https://github.com/SHIINASAMA/wifi-lens/actions?query=workflow%3A%22Swift+CI%22)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey)](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
[![X](https://img.shields.io/badge/X-@WiFiLens-1d9bf0)](https://x.com/WiFiLens)
[![Email](https://img.shields.io/badge/email-wifi--lens@outlook.com-0078d4)](mailto:wifi-lens@outlook.com)
[![Website](https://img.shields.io/badge/website-wifi--lens.shiinalabs.com-2563eb)](https://wifi-lens.shiinalabs.com)

🇺🇸 [English](README.md) | 🇩🇪 [Deutsch](README.de.md) | 🇪🇸 [Español](README.es-ES.md) | 🇨🇳 [简体中文](README.zh-Hans.md) | 🇯🇵 [日本語](README.ja.md)

**Ein natives macOS-Tool zur Analyse und Optimierung deiner Wi-Fi-Netzwerke.**

<p align="center">
  <a href="https://apps.apple.com/app/wifi-lens-pro/id6776590746">
    <img src="assets/appstore-badge-en.svg" alt="WiFi Lens Pro im Mac App Store herunterladen" width="240">
  </a>
</p>

---

## Über WiFi Lens

WiFi Lens ist ein nativer Wi-Fi- und Bluetooth-Analysator für macOS, entwickelt mit SwiftUI, CoreWLAN und CoreBluetooth. Die App erfasst drahtlose Netzwerke und BLE-Geräte in deiner Umgebung in Echtzeit. So kannst du Verbindungsprobleme untersuchen, einen weniger ausgelasteten Kanal wählen und das Roaming zwischen Access Points prüfen.

Dieses Repository enthält die kostenlose Open-Source-Edition. WiFi Lens Pro ist eine separate kostenpflichtige Edition mit zusätzlichen Funktionen.

**Typische Anwendungsfälle:**

- 🏠 **Heimnetzwerk optimieren:** Finde überlastete Kanäle und stelle deinen Router auf einen ruhigeren Kanal um.
- 🏢 **Büro-Wi-Fi prüfen:** Scanne die Bänder 2,4, 5 und 6 GHz, um Funklöcher oder falsch konfigurierte APs zu finden.
- 🚶 **Roaming validieren:** Zeichne AP-Wechsel auf einem Zeitdiagramm auf, während du dich durch ein Gebäude bewegst.
- 🎧 **BLE-Geräte untersuchen:** Verfolge RSSI-Verläufe von Bluetooth-Peripheriegeräten und erkenne Reichweiten- oder Interferenzprobleme.

---

## Funktionen

| Kategorie | Fähigkeit |
|----------|-----------|
| 📡 **Wi-Fi-Scanning** | Echtzeit-Scan über die Bänder 2,4, 5 und 6 GHz mit Signalstärke pro Netzwerk |
| 📊 **Spektrum-Ansicht** | Gauß-Glockenkurven-Diagramme zeigen Kanalbelegung auf einen Blick |
| 🎯 **Kanalqualität** | Auslastungsbewertungen mit regulatorisch passenden Empfehlungen für deine Region |
| 🔍 **Netzwerkdetails** | PHY-Generation, Kanalbreite, 802.11k/r/v-Roaming, WPA3, versteckte SSIDs |
| 📶 **Verbindungsinformationen** | IP, Gateway, DNS, MAC, Kanal, Tx-Rate und Sicherheitszusammenfassung |
| 📈 **Trend-Diagramme** | Signalverlauf pro Netzwerk über die Zeit mit konfigurierbarem Scan-Intervall |
| 🔄 **Roaming-Test** | Überwachung von AP-Wechseln mit Zeitdiagramm, Bereichsauswahl sowie Speichern und Laden von Sitzungen |
| 🗺️ **Kanal-Heatmap** | Belegungsübersicht pro Band zur schnellen Erkennung von Überlastungsmustern |
| 🎧 **BLE-Scanner** | Bluetooth LE-Geräte-Erkennung, RSSI-Analyse, Trend-Diagramme und Gerätetracking |
| 🎨 **Intelligente Farbgebung** | Deterministische Farbzuordnung anhand der SSID; dasselbe Netzwerk behält dieselbe Farbe |
| 🔒 **Privatsphäre zuerst** | Keine Telemetrie oder Nutzungsanalyse; Wi-Fi-Scandaten bleiben auf deinem Mac |
| 🌐 **MCP-Server** | Eingebettete HTTP-API auf `127.0.0.1:19840` für externe Tools |
| 🔄 **Auto-Updates** | Optionale Sparkle-Updateprüfungen in der GitHub-Edition |
| 📤 **Exportieren** | Speichere Band-Diagramme als PNG-Bilder oder CSV-Daten |
| 🌍 **Lokalisiert** | Englisch, Deutsch, Spanisch, Japanisch und vereinfachtes Chinesisch |

---

## Design

**Native macOS-Oberfläche.** CoreWLAN kommuniziert direkt mit der Wi-Fi-Hardware. SwiftUI stellt native Mac-Steuerelemente und Fensterverhalten bereit.

**Empfehlungen mit regulatorischem Kontext.** WiFi Lens ermittelt die Regulierungsregion anhand der Systemregion, der Hardwarefähigkeiten und der Ländercodes naher APs. Die App filtert Empfehlungen nach DFS-, Indoor- und 6-GHz-AFC-Vorgaben.

**Verknüpfte Ansichten.** Wähle ein Netzwerk in der Tabelle aus, um es in jedem Diagramm hervorzuheben. Bewege den Mauszeiger über eine Glockenkurve, um die SSID zu sehen.

**Werkzeuge der Open-Source-Edition.** Exportiere PNG- und CSV-Dateien oder speichere und lade Roaming-Sitzungen. Der lokale MCP-Server verbindet WiFi Lens mit deinen eigenen Tools.

---

## Download

[![Letzte Version herunterladen](https://img.shields.io/github/v/release/SHIINASAMA/wifi-lens?label=Latest&color=2563eb)](https://github.com/SHIINASAMA/wifi-lens/releases/latest/)
[![WiFi Lens Pro im Mac App Store herunterladen](https://img.shields.io/badge/Download-Mac%20App%20Store-black?logo=apple)](https://apps.apple.com/app/wifi-lens-pro/id6776590746)

GitHub Releases stellt die Open-Source-Edition bereit. WiFi Lens Pro ist im Mac App Store in unterstützten Regionen erhältlich.

Erfordert macOS 14 (Sonoma) oder später. Funktioniert auf Intel und Apple Silicon Macs.

> 🌐 **Offizielle Website:** [wifi-lens.shiinalabs.com](https://wifi-lens.shiinalabs.com) bietet Screenshots, eine Funktionsübersicht, KI/MCP-Workflows und häufige Fragen.

> [!IMPORTANT]
> Unter macOS 14+ müssen die **Ortungsdienste** aktiviert sein, damit die App Wi-Fi-SSID-Namen lesen kann.
> Öffne **Systemeinstellungen → Datenschutz & Sicherheit → Ortungsdienste** und aktiviere WiFi Lens, wenn du dazu aufgefordert wirst.

## Privatsphäre

WiFi Lens erfasst keine Nutzungsanalysen, Absturztelemetrie oder Wi-Fi-Scandaten.

- **Ortungsdienste:** macOS benötigt diese Berechtigung, um Wi-Fi-SSID-Namen bereitzustellen. WiFi Lens liest deine GPS-Position nicht aus.
- **Regionserkennung:** WiFi Lens nutzt die Systemregion, die von der Hardware gemeldete Kanalliste und Ländercodes naher APs auf dem Gerät.
- **Netzwerk-Selbsttest:** Wenn du ihn startest, löst WiFi Lens `example.com` auf und kann die Erreichbarkeit deiner konfigurierten Proxy-Endpunkte prüfen.
- **MCP-Server:** Der optionale Server bindet sich an `127.0.0.1`. Lokale Tools erhalten erst nach deiner Aktivierung Zugriff auf Scandaten.
- **Updateprüfungen:** Die GitHub-Edition kontaktiert GitHub, wenn du eine Updateprüfung startest oder automatische Prüfungen aktivierst.

---

## Entwickeln

```sh
git clone https://github.com/SHIINASAMA/wifi-lens
cd wifi-lens
git submodule update --init ChartLens
cd WiFiLens

# Builden
xcodebuild -project WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build

# Tests ausführen
xcodebuild -project WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests

# In Xcode öffnen
xed WiFiLens.xcodeproj
```

Der Produktname ist `WiFi Lens.app` (mit Leerzeichen).

Dokumente zu Architektur, Tests und Roadmap liegen unter [docs/](docs/).

---

## Mitwirken

Fehlerberichte und Funktionsvorschläge sind willkommen. Öffne ein [Issue](https://github.com/SHIINASAMA/wifi-lens/issues) oder starte eine [Diskussion](https://github.com/SHIINASAMA/wifi-lens/discussions).

Pull Requests sollten den Konventionen in [.agents/references/project/ARCHITECTURE.md](.agents/references/project/ARCHITECTURE.md) folgen und nach Möglichkeit Tests enthalten. Wenn du Coding-Agenten verwendest, beachte die Hinweise in [.agents/references/collaboration-rules.md](.agents/references/collaboration-rules.md).

---

## Danksagungen

Dieses Projekt basiert auf [tiny-wifi-analyzer](https://github.com/nolze/tiny-wifi-analyzer) von [nolze](https://github.com/nolze), dem Entwickler des ursprünglichen Python-basierten Wi-Fi-Scanners. Seitdem wurde die App vollständig mit Swift, SwiftUI und CoreWLAN neu geschrieben und zu einer nativen macOS-Anwendung weiterentwickelt.

---

## Lizenz

Apache License 2.0 © 2020 nolze, 2026 SHIINASAMA. Siehe [LICENSE](LICENSE) für vollständigen Text.

---

**Topics:** `macos` `wifi` `network` `tool` `swift` `bluetooth` `analyzer` `swiftui` `corewlan` `corebluetooth` `open-source` `mcp`
