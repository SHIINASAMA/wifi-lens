export const de = {
  nav: {
    features: 'Funktionen',
    mcp: 'MCP',
    download: 'Download',
    privacy: 'Privatsphäre',
    docs: 'Dokumentation',
  },
  hero: {
    badge: 'macOS 14+ · Native · Local-first',
    title: 'WiFi Lens',
    subtitle: 'Ein natives Wi‑Fi Analyzer für macOS, das dir hilft, Überlastung zu erkennen, Verbindungsqualität zu diagnostizieren und Roaming-Verhalten in Echtzeit zu überprüfen.',
    cta: {
      oss: 'Download',
      secondary: 'Für AI-Workflows',
      proSoon: 'Mac App Store jetzt verfügbar',
    },
    hint: 'Local-first · Open Source · Kein Tracking',
  },
  features: {
    title: 'Tiefe Einblicke in deine drahtlose Umgebung',
    scanning: {
      title: 'Tri-Band Spektrum-Scanning',
      desc: 'Siehe nahe 2.4 GHz, 5 GHz und 6 GHz Netzwerke in Echtzeit aktualisieren. Zoom, friere ein und vergleiche Kanalüberlappung ohne das große Bild zu verlieren.',
    },
    table: {
      title: 'Umfassende Netzwerk-Tabelle',
      desc: 'Untersuche RSSI, Kanal, Band, Sicherheit, Anbieter und Fähigkeiten für jedes sichtbare Netzwerk. Sortiere, filtere und kreuzreferenziere Zeilen mit der Spektrum-Ansicht während der Untersuchung.',
    },
    roaming: {
      title: 'Roaming-Test mit Zeitstrahl',
      desc: 'Verfolge Access-Point-Übergänge beim Bewegen durch einen Raum. Überprüfe Übergänge, Signaländerungen und gespeicherte Sitzungen um Roaming-Verhalten zu bestätigen.',
    },
    quality: {
      title: 'Kanal-Qualitäts-Bewertung',
      desc: 'Finde sauberere Kanäle über alle Wi‑Fi Bände auf einen Blick. Punktzahlen, Stufen und Empfehlungen helfen dir zu entscheiden wo du als nächstes wechseln sollst.',
    },
    overview: {
      title: 'Diagnose-Dashboard für Verbindung',
      desc: 'Starte mit der Verbindung die du gerade verwendest. WiFi Lens hebt Signalgesundheit, Kanalqualität, Sicherheit und die wahrscheinlichste Ursache des Problems hervor.',
    },
    privacy: {
      title: 'Standardmäßig Privat',
      desc: 'Keine Analytics, keine Telemetrie und keine Cloud-Abhängigkeit. Deine Scans bleiben auf deinem Mac, und sogar MCP-Zugriff bleibt lokal an deiner Maschine.',
    },
  },
  demo: {
    title: 'Siehe die App in Aktion',
    subtitle: 'Sechs fokussierte Ansichten zur Fehlerbehebung von Wi‑Fi-Leistung, Abdeckung und Kanalnutzung.',
    items: [
      {
        title: 'Diagnose-Dashboard',
        alt: 'Diagnose-Dashboard mit aktueller Wi‑Fi-Gesundheit, Signalstärke und Kanal-Empfehlungen',
        desc: 'Prüfe zuerst die Gesundheit deiner aktuellen Verbindung. Die Übersicht hebt Signalstärke, Kanalqualität, Sicherheit und den nützlichsten nächsten Schritt hervor.',
        bullets: ['Aktuelle Verbindungsgesundheit auf einen Blick', 'Umsetzbare Kanal-Empfehlungen', 'Siehe welches Band am stärksten belegt ist'],
        image: '/screenshots/overview.png',
      },
      {
        title: 'Spektrum-Scanner',
        alt: 'Tri-Band Spektrum-Scanner mit Netzwerkkurven und Kanalbelegung über Wi‑Fi-Bänder',
        desc: 'Sieh zu wie nahe Netzwerke in Live-Spektrum-Diagrammen über alle Haupt-Wi‑Fi-Bänder erscheinen. Nutze es um Überlappung, Überlastung und laute Kanalgruppen schnell zu erkennen.',
        bullets: ['Live Tri-Band Spektrum-Ansicht', 'Überlastete Kanäle schnell erkennen', 'Zoom, einfrieren und Details prüfen'],
        image: '/screenshots/spectrum.png',
      },
      {
        title: 'Kanal-Qualitäts-Analyse',
        alt: 'Kanal-Qualitäts-Analyse mit regionsbasierter Bewertung, DFS-Erkennung und Gerätekompatibilitätsfilter',
        desc: 'Vergleiche Kanal-Bewertungen bevor du dein Netzwerk-Setup änderst. WiFi Lens zeigt sauberere Optionen mit regionsbasierter Filterung, Überlappungskontext und Gerätekompatibilitätsprüfungen.',
        bullets: ['Pro-Kanal Qualitätsbewertungen', 'Regionsbasierte Empfehlungen', 'Vorschläge für sauberere Kanäle'],
        image: '/screenshots/channels.png',
      },
      {
        title: 'Netzwerk-Tabelle',
        alt: 'Sortierbare Netzwerk-Tabelle mit Wi‑Fi-Details inklusive RSSI, Kanal, Sicherheit, Anbieter und Fähigkeiten',
        desc: 'Durchsuche die vollständige Liste sichtbarer Netzwerke mit einer kompakten, nativen Tabelle. Jede Zeile zeigt Signalstärke, Kanal, Band, Sicherheitstyp, Anbieter-OUI und 802.11-Fähigkeiten.',
        bullets: ['RSSI, Kanal, Band und Sicherheitstyp', 'Anbieter-OUI und Fähigkeits-Flags', 'Schnell nach SSID oder BSSID filtern'],
        image: '/screenshots/table.png',
      },
      {
        title: 'Roaming-Test',
        alt: 'Roaming-Test-Zeitstrahl mit Access-Point-Übergängen, Signalverlauf und Handoff-Details',
        desc: 'Validiere Roaming-Verhalten beim Durchlaufen eines Raums mit einem Laptop. Überprüfe Handoffs, Signalverlauf und gespeicherte Sitzungen um zu verstehen wie Clients zwischen APs wechseln.',
        bullets: ['AP-Übergänge über die Zeit erkennen', 'Signalabfälle während Bewegung visualisieren', 'Roaming-Sitzungen speichern und neu laden'],
        image: '/screenshots/roaming.png',
      },
      {
        title: 'Netzwerk-Schnittstellen',
        alt: 'Netzwerk-Schnittstellen-Ansicht mit Verbindungsdetails und Live-Durchsatz-Überwachung',
        desc: 'Untersuche Wi‑Fi und nicht-Wi‑Fi Schnittstellen von einem Ort aus. Wechsle zwischen High-Level-Status, detaillierter Link-Information und Live-Durchsatz-Monitoring.',
        bullets: ['Wechsle zwischen schnellem Status und tiefem Detail', 'Beobachte Live-Durchsatz über die Zeit', 'Untersuche Wi‑Fi, Ethernet, VPN und virtuelle Links'],
        image: '/screenshots/interfaces.png',
      },
    ],
  },
  specs: {
    title: 'Was es nützlich macht',
    items: [
      { label: 'Live-Scanning', value: 'Echtzeit-Updates über 2.4, 5 und 6 GHz — wähle jedes Intervall von 1 bis 10 Sekunden' },
      { label: 'Spektrum-Diagramme', value: 'Glatte, responsive Visualisierungen die Kanalüberlappung und Überlastung leicht erkennbar machen' },
      { label: 'Exportieren', value: 'Speichere Spektrum-Screenshots als hochauflösende PNGs oder exportiere Netzwerkdaten als CSV-Tabellen' },
      { label: 'AI-Integration', value: 'Lass kompatible AI-Tools deine lokale Wi‑Fi-Umgebung untersuchen ohne Daten in die Cloud zu senden' },
      { label: 'Kanal-Bewertung', value: 'Intelligente Empfehlungen die Signalstärke, Überlappung und Bandbreite zusammen gewichten' },
      { label: 'Sitzungs-Speicherung', value: 'Speichere Roaming-Tests und öffne sie später um Vorher-Nachher-Ergebnisse zu vergleichen' },
    ],
  },
  mcp: {
    title: 'Lass AI deine lokale Wi‑Fi-Umgebung untersuchen',
    subtitle: 'WiFi Lens kann Live-Scandaten zu Tools wie Claude Desktop über MCP exponieren, sodass du Fragen zu nahen Netzwerken und Kanalnutzung stellen kannst ohne Daten in die Cloud zu senden.',
    endpoints: {
      title: 'Drei JSON-Endpoints',
      networks: 'Durchsuche nahe Netzwerke mit Signal, Band, Kanal, Sicherheit und Fähigkeitsdetails.',
      detail: 'Untersuche ein Netzwerk vertieft nach BSSID, einschließlich Kanal-Breiten-Information.',
      occupancy: 'Prüfe pro-Kanal Belegung um Überlastung über jedes Wi‑Fi Band zu verstehen.',
    },
    config: {
      title: 'Eine Konfiguration zum Verbinden',
      desc: 'Aktiviere den MCP-Server in WiFi Lens, füge diese Konfiguration in Claude Desktop hinzu, dann stelle Fragen wie "Welcher Kanal sieht am wenigsten überlastet aus?" oder "Was sticht in nahen Netzwerken hervor?"',
    },
    cta: {
      docs: 'Dokumentation lesen',
      github: 'Auf GitHub ansehen',
    },
  },
  download: {
    title: 'Starte mit WiFi Lens',
    oss: {
      title: 'WiFi Lens OSS',
      badge: 'Kostenlos & Open Source',
      desc: 'Lade die neueste Version von GitHub Releases herunter, bereit zum Ausführen auf macOS 14 oder später.',
      features: [
        'Live Tri-Band Spektrum-Scanning',
        'Detaillierte Netzwerk-Tabelle und Filterung',
        'Kanal-Qualitäts-Bewertung und Empfehlungen',
        'Roaming-Zeitstrahl-Analyse',
        'Diagnose-Dashboard für Verbindung',
        'Lokaler MCP-Server für AI-Workflows',
      ],
      cta: 'Von GitHub Downloaden',
      url: 'https://github.com/SHIINASAMA/wifi-lens/releases/latest',
    },
    pro: {
      title: 'WiFi Lens PRO',
      badge: 'Im Mac App Store verfügbar',
      desc: 'Holen Sie sich WiFi Lens PRO direkt aus dem Mac App Store für einfachere Installation und automatische Updates.',
      features: [
        'Gleiche zentrale Analyzer-Erfahrung',
        'Einfacherer Installationsfluss',
        'Mac App Store-Verteilung mit automatischen Updates',
      ],
      cta: 'Im Mac App Store herunterladen',
      url: 'https://apps.apple.com/app/id6776590746',
    },
  },
  privacy: {
    title: 'Deine Daten bleiben auf deinem Mac. Immer.',
    subtitle: 'WiFi Lens verarbeitet alles lokal. Keine Konten, keine Cloud, kein Tracking.',
    noCollection: {
      heading: 'Keine Persönliche Datenerfassung',
      body: 'WiFi Lens sammelt, speichert oder überträgt keine persönlich identifizierbaren Informationen. Die App enthält keine Benutzerkonten, keine Analytics-SDKs, keine Werbenetzwerke und keine Telemetrie-Frameworks. Wir betreiben keine Backend-Server um deine Daten zu empfangen — weil wir kein Interesse daran haben sie zu besitzen.',
    },
    permissions: {
      heading: 'Warum Wir Berechtigungen Anfordern',
      body: 'Wi‑Fi — Kernfunktionalität: Scanning und Analysieren naher drahtloser Netzwerke.\n\nBluetooth — Optional verwendet um nahe BLE-Geräte für Koeistenz-Analyse zu entdecken. Diese Funktion ist standardmäßig deaktiviert und kann in Einstellungen aktiviert werden. Alle Entdeckung läuft lokal auf deiner Maschine.\n\nLocation Services — macOS erfordert diese Berechtigung für jede App die Wi‑Fi-Netzwerknamen (SSIDs) liest. WiFi Lens greift nie deine GPS-Koordinaten zu und registriert nie deine Position.\n\nLokales Netzwerk — Optional verwendet wenn du den MCP-Server in Einstellungen aktivierst. Der Server hört nur auf localhost (127.0.0.1) sodass lokale Tools wie Claude Desktop Wi‑Fi-Scandaten lesen können. Es ist standardmäßig aus, und keine Daten verlassen deinen Mac.',
    },
    localOnly: {
      heading: 'Alles Bleibt Auf Deiner Maschine',
      body: 'Alle Wi‑Fi-Scenergebnisse, Bluetooth-Entdeckungsdaten, Kanal-Empfehlungen und Regulatory-Domain-Erkennung laufen vollständig on-device. Keine Scandaten werden jemals auf einen Remote-Server hochgeladen.\n\nCrash-Berichte und Diagnose-Logs werden auf Dateien auf deiner eigenen Festplatte geschrieben. Nichts wird übertragen es sei denn du wählst explizit es zu teilen.\n\nDer MCP-Server bindet an 127.0.0.1 (nur localhost). Keine Scandaten verlassen deine Maschine durch MCP es sei denn du routest sie absichtlich woandershin.',
    },
    distribution: {
      heading: 'Verteilungsunterschiede',
      body: 'WiFi Lens ist über zwei Kanäle verfügbar. Sie unterscheiden sich nur darin wie Updates geprüft werden:\n\nMac App Store — Nutzt Apples eingebaute Update-Mechanik. Die App kontaktiert nie einen Third-Party-Server für Versionsprüfungen oder Updates.\n\nGitHub / Direkt-Download — Nutzt das Sparkle-Framework um neue Versionen zu prüfen. Sparkle ruft eine einzige appcast-Datei (ein Versionsdeskriptor) von unserem Release-Server ab. Diese Anfrage überträgt keine persönlichen Daten, keine Nutzungs-Analytics und keine Diagnose-Informationen — es ist rein ein Versionsvergleich.',
    },
    openSource: {
      heading: 'Open Source & Überprüfbar',
      body: 'Der vollständige Quellcode ist unter der Apache 2.0 Lizenz verfügbar. Jede Behauptung auf dieser Seite kann unabhängig von jedem überprüft werden der den Code liest.',
    },
    lastUpdated: 'Letzte Aktualisierung: 27. Mai 2026',
    contact: 'Fragen? Öffne ein GitHub Issue oder erreiche uns unter wifi-lens@outlook.com',
  },
  footer: {
    copyright: '© 2026 WiFi Lens. Verstehe dein Wi‑Fi.',
    x: '@WiFiLens',
    email: 'wifi-lens@outlook.com',
    privacy: 'Privatsphäre',
    support: 'Support',
    oss: 'GitHub',
    license: 'Apache 2.0',
  },
} as const
