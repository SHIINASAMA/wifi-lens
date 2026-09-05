# Neu in Version 1.6.0

WiFi Lens 1.6.0 erweitert den Live-WLAN-Arbeitsbereich für OSS und Pro um AP Radar, einen komponentisierten Spektrum-Arbeitsbereich und eine neue aggregierte Heatmap. Pro führt den Weg von der Live-Diagnose zu Verlauf, Berichten und Analyse weiter.

## Der Community beitreten

Fragen, Feedback oder einfach Lust, über WiFi Lens zu sprechen?

**Auf Discord beitreten:** https://discord.gg/gH6sTCYaJ7

## Highlights

### AP Radar (Preview)

* Wähle einen Access Point aus und verfolge seine empfangene Signalstärke, während du dich bewegst.
* Sieh, ob das Signal stärker, schwächer oder stabil bleibt. Wenn das Ziel verschwindet, wird der Signalverlust klar angezeigt.
* Die optionale Pulston-Wiedergabe verändert sich mit der Signalstärke; Sound-Steuerung und Klangvoreinstellungen sind in den Einstellungen verfügbar.
* AP Radar bietet eine Orientierung auf Basis der RSSI-Werte. Die genaue Richtung oder Entfernung eines Access Points kann nicht bestimmt werden.

### Komponentenbasierter Spektrum-Arbeitsbereich

* Spektrum-Panels sind jetzt komponentenbasiert. Jedes Panel kann zwischen Spektrum, Trend, Tabelle und Heatmap wechseln.
* Die bestehende Netzwerktabelle lässt sich besser anpassen: Wähle die Spalten aus, die neben den wichtigen Netzwerkdetails sichtbar bleiben sollen.
* Bandauswahl und ansichtsspezifische Steuerungen bleiben zusammen, damit du den Arbeitsbereich leichter an deine aktuelle Aufgabe anpassen kannst.

### Aggregierte Spektrum-Heatmap

* Sieh, wo sich die WLAN-Aktivität über Frequenz und Signalstärke konzentriert.
* Vergleiche die aktuelle Umgebung als Gesamtansicht, statt immer nur einem Access Point zu folgen.
* Wechsle zwischen den unterstützten Bändern 2,4 GHz, 5 GHz und 6 GHz.

### WiFi Lens Pro

* Die Timeline kann anonymisierte Markdown-Berichte exportieren und bietet ausführlichere lokalisierte Ereignisdetails.
* Statistics und Insights haben klarere lokalisierte Aktionen und Feedback-Einstiege.
* Pro verbindet die Live-Beobachtung mit Aufzeichnung, Ereignisverlauf, Analyse wiederkehrender Muster, Menüleisten-Zugriff und erweiterten Exporten.

## Zuverlässigkeit, Lokalisierung und Barrierefreiheit

* Die Heatmap nutzt, wenn verfügbar, Hardwarebeschleunigung und wechselt andernfalls sicher auf eine alternative Berechnung.
* Stabileres Rendering bei gleichzeitigen Aktualisierungen, wechselnden Scan-Ergebnissen und Lücken im Kanalplan.
* Erweiterte Lokalisierungs- und Barrierefreiheitsunterstützung für AP Radar und den neuen Spektrum-Arbeitsbereich.

## Verfügbarkeit nach Edition

Der komponentenbasierte Spektrum-Arbeitsbereich, die aggregierte Heatmap, die AP-Radar-Vorschau und die grundlegende Live-WLAN-Analyse sind in der Open-Source-Version (OSS) und in Pro verfügbar.

WiFi Lens Pro bietet zusätzlich Aufzeichnung, Timeline-Verlauf, Statistics, Insights, Menüleisten-Zugriff und erweiterte Exportfunktionen für längerfristige Beobachtung und Analyse.

**Vollständiges Changelog:** [v1.5.1...v1.6.0](https://github.com/SHIINASAMA/wifi-lens/compare/v1.5.1...v1.6.0)
