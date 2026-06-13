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

**Ein natives macOS-Tool zur Analyse und Optimierung deiner Wi-Fi-Netzwerke.**

---

## Was ist WiFi Lens?

WiFi Lens ist ein kostenloser, open-source Wi-Fi- und Bluetooth-Analysator, der vollständig mit nativen macOS-Frameworks — SwiftUI, CoreWLAN und CoreBluetooth — gebaut wurde. Es bietet dir eine Echtzeit-visuelle Karte aller drahtlosen Netzwerke und BLE-Geräte um dich herum, sodass du Verbindungsprobleme diagnostizieren, den am wenigsten überlasteten Kanal auswählen und das Roaming-Verhalten zwischen Access Points überprüfen kannst.

Im Gegensatz zu webbasierten Scannern oder plattformübergreifenden Electron-Apps läuft WiFi Lens mit null Overhead, respektiert deine Privatsphäre und passt sich perfekt in dein Mac-Ökosystem ein.

**Typische Anwendungsfälle:**
- 🏠 **Heimnetzwerk-Tuning** — Finde heraus, welchen Kanal deine Nachbarn überlasten und verschiebe deinen Router auf einen ruhigeren.
- 🏢 **Büro-Wi-Fi-Audit** — Scanne alle drei Bänder (2.4, 5 und 6 GHz), um tote Zonen oder falsch konfigurierte APs zu finden.
- 🚶 **Roaming-Validierung** — Laufe durch ein Gebäude und protokolliere jeden AP-Handover mit einem Zeitstrahl-Diagramm, um nahtlose Übergänge zu überprüfen.
- 🎧 **BLE-Geräte-Fehlersuche** — Verfolge RSSI-Trends von Bluetooth-Peripheriegeräten und identifiziere Reichweiten- oder Interferenzprobleme.

---

## Funktionen

| Kategorie | Fähigkeit |
|----------|-----------|
| 📡 **Wi-Fi-Scanning** | Echtzeit-Scan über 2.4, 5 und 6 GHz Bänder mit Signalstärke pro Netzwerk |
| 📊 **Spektrum-Ansicht** | Gauß-Glockenkurven-Diagramme zeigen Kanalbelegung auf einen Blick |
| 🎯 **Kanalqualität** | Überlastungspunktzahlen mit region-basierten Empfehlungen, angepasst an dein Regulatory Domain |
| 🔍 **Netzwerkdetails** | PHY-Generation, Kanalbreite, 802.11k/r/v Roaming, WPA3, versteckter SSID |
| 📶 **Verbindungsinformationen** | IP, Gateway, DNS, MAC, Kanal, Tx-Rate und Sicherheitszusammenfassung |
| 📈 **Trend-Diagramme** | Signalverlauf pro Netzwerk über die Zeit mit konfigurierbarem Scan-Intervall |
| 🔄 **Roaming-Test** | AP-Übergangsüberwachung mit Zeitstrahl-Diagramm, Bereichsselector und Session-Save/Load |
| 🗺️ **Kanal-Wärme-Karte** | Band-bezogene Belegungswärme-Karte zur sofortigen Erkennung von Überlastungsmustern |
| 🎧 **BLE-Scanner** | Bluetooth LE-Geräte-Erkennung, RSSI-Analyse, Trend-Diagramme und Gerätetracking |
| 🎨 **Intelligente Farbgebung** | Deterministische SSID-basierte Farbzuteilung — dasselbe Netzwerk erhält immer dieselbe Farbe |
| 🔒 **Privatsphäre zuerst** | Keine Telemetrie, keine Analysen, keine Datenerfassung — alles bleibt auf deinem Mac |
| 🌐 **MCP-Server** | Eingebetteter HTTP-API auf `127.0.0.1:19840` für externe Tool-Integration |
| 🔄 **Auto-Updates** | Integrierter Sparkle-Update-Support, damit du immer die neueste Version ausführst |
| 📤 **Exportieren** | Speichere Band-Diagramme als PNG-Bilder oder CSV-Daten |
| 🌍 **Lokalisiert** | Vollständige Unterstützung für Englisch, 日本語，简体中文 und Deutsch |

---

## Was macht WiFi Lens anders?

**Native Performance, kein Web-Wrapper.** CoreWLAN spricht direkt mit der Wi-Fi-Hardware — kein Middleware, keine JavaScript-Bridge, keine verschwendeten CPU-Zyklen. Hunderte von Netzwerken pro Durchlauf auf modernem Apple Silicon sind mühelos.

**Eingebaute Regulatory Intelligence.** Die meisten Tools zeigen rohe Kanalnummern und nennen es ein Tag. WiFi Lens leitet dein Regulatory Domain aus System-Locale, Hardware-Fähigkeit und nahen AP-Ländercodes ab und empfiehlt dann Kanäle, die du tatsächlich verwenden darfst — DFS, indoor-only und 6 GHz AFC-Regeln respektierend.

**Alles ist verbunden.** Klicke ein Netzwerk in der Tabelle an und es wird in allen Diagrammen hervorgehoben. Fahre mit der Maus über eine Glockenkurve und der SSID poppt auf. Einfriere ein Band während die anderen weiter scannen. Es ist wie ein Cockpit designed, nicht wie ein Dashboard.

**Platz für Power-User.** Exportiere PNG/CSV, führe einen Roaming-Test mit Session-Save/Load aus oder integriere deine eigenen Tools über den eingebetteten MCP HTTP Server — alles ohne versteckte Paywalls.

---

## Download

[![Letzte Version herunterladen](https://img.shields.io/github/v/release/SHIINASAMA/wifi-lens?label=Latest&color=2563eb)](https://github.com/SHIINASAMA/wifi-lens/releases/latest/)
[![Im Mac App Store herunterladen](https://img.shields.io/badge/Download-Mac%20App%20Store-black?logo=apple)](https://apps.apple.com/app/id6776590746)

Erfordert macOS 14 (Sonoma) oder später. Funktioniert auf Intel und Apple Silicon Macs.

> [!IMPORTANT]
> Auf macOS 14+ muss **Location Services** aktiviert sein, damit die App Wi-Fi SSID-Namen lesen kann.
> Gehe zu **System Settings → Privacy & Security → Location Services** und aktiviere WiFi Lens wenn gefragt.

### Gatekeeper-Arbeit

Die App ist vollständig signiert und von Apple notarized.

- Normalerweise direkt öffnbar; oder
- Wenn ein Blocker erscheint: **Rechtsklick** auf die App → **Open** → im Dialog bestätigen

---

## Privatsphäre

WiFi Lens **sammelt nichts**. Keine Nutzungsanalysen, keine Crash-Telemetrie, kein Netzwerkverkehr zu externen Servern.

- **Location Services** — Von macOS erforderlich um Wi-Fi SSID-Namen freizugeben. WiFi Lens liest nie deine GPS-Position.
- **Region-Erkennung** — Nutzt System-Locale, hardware-gemeldete Kanalliste und nahe AP-Ländercodes. Läuft vollständig auf dem Gerät.
- **MCP-Server** — Gebunden an `127.0.0.1` nur. Scan-Daten verlassen deine Maschine nicht es sei denn du routest sie explizit anderswohin.

---

## Entwickeln

```sh
git clone https://github.com/SHIINASAMA/wifi-lens
cd wifi-lens/WiFiLens

# Builden
xcodebuild -project WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build

# Tests ausführen
xcodebuild -project WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' test

# In Xcode öffnen
xed WiFiLens.xcodeproj
```

Der Produktname ist `WiFi Lens.app` (mit Leerzeichen).

### Website

Die Landingpage wurde mit Vite und Tailwind CSS gebaut, outputting zu `_site/`.

```sh
cd wifi-lens          # repo root
npm ci
npm run dev           # dev server at localhost:5173/wifi-lens/
npm run build         # production build
npm run preview       # preview production build
```

Architektur, Testing und Roadmap Docs leben in [docs/](docs/).

---

## Contributing

Bug-Reports und Feature-Ideen sind willkommen — öffne ein [issue](https://github.com/SHIINASAMA/wifi-lens/issues) oder starte eine [discussion](https://github.com/SHIINASAMA/wifi-lens/discussions).

Pull Requests sollten die Konventionen in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) folgen und Testabdeckung wo praktisch enthalten. Siehe [docs/COLLABORATION_RULES.md](docs/COLLABORATION_RULES.md) für KI-Assistent-Richtlinien wenn du Coding-Agents verwendest.

---

## Danksagungen

Geforkt von [tiny-wifi-analyzer](https://github.com/nolze/tiny-wifi-analyzer) von [nolze](https://github.com/nolze), der den ursprünglichen Python-basierten Wi-Fi-Scanner baute. Seitdem wurde die App vollständig in Swift mit SwiftUI und CoreWLAN neu geschrieben und entwickelte sich zur nativen macOS-Anwendung, die sie heute ist.

---

## Lizenz

Apache License 2.0 © 2020 nolze, 2026 SHIINASAMA. Siehe [LICENSE](LICENSE) für vollständigen Text.

---

**Topics:** `macos` `wifi` `network` `tool` `swift` `bluetooth` `analyzer` `swiftui` `corewlan` `corebluetooth` `open-source` `mcp`
