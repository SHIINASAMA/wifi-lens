export const de = {
  a11y: {
    skipLink: 'Zum Hauptinhalt springen',
    menu: 'Menü',
    backToTop: 'Zurück nach oben',
    selectLanguage: 'Sprache auswählen',
  },
  meta: {
    title: 'WiFi Lens — macOS Wi‑Fi Spektrum-Analysator',
    description: 'WiFi Lens — Ein nativer macOS Wi‑Fi Spektrum-Analysator. Scannen, diagnostizieren und roamen mit Vertrauen.',
  },
  nav: {
    home: 'Startseite',
    features: 'Funktionen',
    mcp: 'AI Workflows',
    download: 'Download',
    changelog: 'Änderungsprotokoll',
    faq: 'FAQ',
    privacy: 'Privatsphäre',
    docs: 'Dokumentation',
  },
  hero: {
    badge: 'macOS 14+ · Native · Local-first',
    title: 'WiFi Lens',
    subtitle: 'Ein nativer Wi‑Fi Analyzer für macOS, der dir zeigt, wo dein WLAN Probleme hat, ob Kanäle überlastet sind und ob deine Geräte richtig roamen.',
    cta: {
      oss: 'Download',
      secondary: 'AI-Workflows',
      proSoon: 'Mac App Store jetzt verfügbar',
    },
    hint: 'Local-first · Open Source · Kein Tracking',
    tagline: 'Native Wi‑Fi Transparenz für macOS.',
  },
  stats: [
    { value: 'Alle Bänder', label: '2.4/5/6 GHz' },
    { value: 'Echtzeit', label: 'Scanning' },
    { value: 'macOS', label: 'Native App' },
    { value: 'Vollständig', label: 'Lokal & Offline' },
  ],
  features: {
    title: 'Tiefe Einblicke in deine drahtlose Umgebung',
    scanning: {
      title: 'Tri-Band Spektrum-Scanning',
      desc: 'Sieh alle nahen Wi‑Fi Netzwerke auf 2,4 GHz, 5 GHz und 6 GHz auf einen Blick. Zoome, friere ein und entdecke die überlastetsten Kanäle sofort.',
    },
    table: {
      title: 'Umfassende Netzwerk-Tabelle',
      desc: 'Liste alle umliegenden Wi‑Fi Netzwerke in einer Tabelle auf – Signalstärke, Kanal, Sicherheitstyp und Hersteller auf einen Blick. Schnell filtern, um Probleme zu finden.',
    },
    roaming: {
      title: 'Roaming-Test mit Zeitstrahl',
      desc: 'Geh in deiner Wohnung umher und sieh, wo das Signal schwächer wird und wann dein Gerät den Router wechselt. Speichere Sitzungen, um später Änderungen nachzuvollziehen.',
    },
    quality: {
      title: 'Kanal-Qualitäts-Bewertung',
      desc: 'Bewerte deine Wi‑Fi Kanäle. Welcher Kanal ist am saubersten und hat die wenigsten Störungen – Bewertungen und Empfehlungen helfen dir, den besten auszuwählen.',
    },
    overview: {
      title: 'Diagnose-Dashboard für Verbindung',
      desc: 'Beginne mit dem Netzwerk, das du gerade nutzt. WiFi Lens prüft Signalqualität, Kanalüberlastung und Sicherheitseinstellungen und gibt klare Verbesserungsvorschläge.',
    },
    privacy: {
      title: 'Standardmäßig Privat',
      desc: 'Keine Sammlung von Privatsphäre, kein Cloud-Upload. Alle Daten werden lokal auf deinem Mac verarbeitet – selbst KI-Funktionen greifen nur auf deine lokale Maschine zu.',
    },
  },
  demo: {
    title: 'Siehe die App in Aktion',
    subtitle: 'Fokussierte Ansichten zur Fehlerbehebung von Wi‑Fi-Leistung, Abdeckung und Kanalnutzung.',
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
        desc: 'Sieh die Live-Aktivität aller nahen Netzwerke über alle Wi‑Fi-Bänder. Finde schnell heraus, wo es am vollsten ist und welche Kanäle überlastet sind.',
        bullets: ['Live Tri-Band Spektrum-Ansicht', 'Überlastete Kanäle schnell erkennen', 'Zoom, einfrieren und Details prüfen'],
        image: '/screenshots/spectrum.png',
      },
      {
        title: 'Kanal-Qualitäts-Analyse',
        alt: 'Kanal-Qualitäts-Analyse mit regionsbasierter Bewertung, DFS-Erkennung und Gerätekompatibilitätsfilter',
        desc: 'Vergleiche Kanalbewertungen, bevor du deine Router-Einstellungen änderst. WiFi Lens gibt passendere Empfehlungen basierend auf deiner Region und Umgebung und prüft die Gerätekompatibilität.',
        bullets: ['Pro-Kanal Qualitätsbewertungen', 'Regionsbasierte Empfehlungen', 'Vorschläge für sauberere Kanäle'],
        image: '/screenshots/channels.png',
      },
      {
        title: 'Netzwerk-Tabelle',
        alt: 'Sortierbare Netzwerk-Tabelle mit Wi‑Fi-Details inklusive RSSI, Kanal, Sicherheit, Anbieter und Fähigkeiten',
        desc: 'Tauche in die vollständige Liste aller sichtbaren Netzwerke mit detaillierten Parametern ein. Jede Zeile zeigt Signalstärke, Kanal, Band, Sicherheitstyp und Hersteller – für alle, die genauer hinsehen wollen.',
        bullets: ['Signalstärke, Kanal, Band, Sicherheitstyp', 'Hersteller- und Fähigkeitsangaben', 'Schnell nach Netzwerknamen oder Geräteadresse filtern'],
        image: '/screenshots/table.png',
      },
      {
        title: 'Roaming-Test',
        alt: 'Roaming-Test-Zeitstrahl mit Access-Point-Übergängen, Signalverlauf und Handoff-Details',
        desc: 'Geh mit deinem Laptop in der Wohnung umher und sieh, wie deine Geräte zwischen Zugangspunkten wechseln. Überprüfe Handoffs, Signalverlauf und gespeicherte Sitzungen, um die tatsächliche Wi‑Fi-Abdeckung zu verstehen.',
        bullets: ['Erkenne, wann Geräte zu einem anderen AP wechseln', 'Sieh Signaländerungen während der Bewegung', 'Speichere und lade Roaming-Sitzungen erneut'],
        image: '/screenshots/roaming.png',
      },
      {
        title: 'Netzwerk-Schnittstellen',
        alt: 'Netzwerk-Schnittstellen-Ansicht mit Verbindungsdetails und Live-Durchsatz-Überwachung',
        desc: 'Alle Netzwerkschnittstellen auf einer Seite – Wi‑Fi, Kabel, VPN und mehr. Sieh detaillierte Verbindungsinformationen und überwache die Live-Geschwindigkeit.',
        bullets: ['Schnellstatus und Tiefendetails mit einem Klick', 'Überwache Live-Geschwindigkeit', 'Zeige Wi‑Fi, Ethernet, VPN und mehr'],
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
    title: 'Mit deinem Wi‑Fi chatten wie im Gespräch',
    subtitle: 'WiFi Lens kann Live-Scandaten zu Tools wie Claude Desktop über MCP exponieren, sodass du Fragen zu nahen Netzwerken und Kanalnutzung stellen kannst ohne Daten in die Cloud zu senden.',
    metaDescription: 'Verbinde WiFi Lens mit KI-Tools über MCP. Claude Desktop liest lokale Wi‑Fi-Scandaten — Netzwerke, Kanäle und Belegung — ohne Upload.',
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
    subtitle: 'Wähle die Version, die zu deinen Bedürfnissen passt. Beide bieten dieselben grundlegenden Wi‑Fi-Analysefunktionen.',
    metaDescription: 'WiFi Lens für macOS 14+ herunterladen. Kostenlose Open-Source-Version auf GitHub oder Pro-Version im Mac App Store mit Spektrumsaufzeichnung.',
    oss: {
      title: 'WiFi Lens OSS',
      badge: 'Kostenlos & Open Source',
      desc: 'Lade die neueste Version von GitHub Releases herunter, bereit zum Ausführen auf macOS 14 oder später.',
      cta: 'Von GitHub Downloaden',
      url: 'https://github.com/SHIINASAMA/wifi-lens/releases/latest',
    },
    pro: {
      title: 'WiFi Lens unterstützen',
      badge: 'Sponsoring & Upgrade',
      desc: 'WiFi Lens wird hauptsächlich von einem einzelnen Entwickler gewartet. Mit dem Kauf der Pro-Version im App Store unterstützt du die Weiterentwicklung und schaltest erweiterte Funktionen wie Spektrum-Sitzungsaufzeichnung frei.',
      cta: 'Im Mac App Store herunterladen',
      url: 'https://apps.apple.com/app/id6776590746',
    },
    comparison: {
      rows: [
        { feature: 'Live Tri-Band Spektrum-Scanning', oss: true, pro: true },
        { feature: 'Detaillierte Netzwerk-Tabelle und Filterung', oss: true, pro: true },
        { feature: 'Kanal-Qualitäts-Bewertung und Empfehlungen', oss: true, pro: true },
        { feature: 'Roaming-Zeitstrahl-Analyse', oss: true, pro: true },
        { feature: 'Diagnose-Dashboard für Verbindung', oss: true, pro: true },
        { feature: 'Lokaler MCP-Server für AI-Workflows', oss: true, pro: true },
        { feature: 'Spektrum-Sitzungsaufzeichnung und -wiedergabe', oss: false, pro: true },
        { feature: 'Nebeneinander-Spektrumvergleich über Zeiträume', oss: false, pro: true },
        { feature: 'Aufzeichnungen für Offline-Analyse exportieren', oss: false, pro: true },
        { feature: 'Einfache Installation mit automatischen Updates', oss: false, pro: true },
        { feature: 'Unterstützt die kontinuierliche Wartung durch den Indie-Entwickler', oss: false, pro: true },
      ],
    },
  },
  changelog: {
    title: 'Änderungsprotokoll',
    subtitle: 'Eine Übersicht über Änderungen, Verbesserungen und Fehlerbehebungen in WiFi Lens.',
    metaDescription: 'Versionshistorie von WiFi Lens — neue Funktionen wie MCP-Integration und Spektrumsaufzeichnung, Fehlerbehebungen und Änderungen.',
    categories: {
      added: 'Neu',
      improved: 'Verbessert',
      fixed: 'Behoben',
      changed: 'Geändert',
    },
    releases: [
      {
        version: 'v1.4.3',
        date: '2026-06-29',
        sections: [
          { type: 'improved' as const, items: ['OSS-Version an die aktuelle App Store-Version angeglichen', 'UI-Verfeinerungen und Verhaltensaktualisierungen'] },
          { type: 'fixed' as const, items: ['Kleinere Fehlerbehebungen und Stabilitätsverbesserungen'] },
        ],
      },
      {
        version: 'v1.4.2',
        date: '2026-06-21',
        sections: [
          { type: 'added' as const, items: ['Gegenfaktische Kanalempfehlung', 'Mac App Store-Link in der App'] },
          { type: 'improved' as const, items: ['Spektrums-Debug-Diagramm in separate Navigation aufgeteilt', 'Sekundäre Navigation in Fenster-Symbolleiste verschoben'] },
          { type: 'fixed' as const, items: ['Diagramm-Annotationen Rendering', 'Spektrumsabschnitt-Grenzerkennung'] },
        ],
      },
      {
        version: 'v1.4.1',
        date: '2026-06-14',
        sections: [
          { type: 'improved' as const, items: ['Barrierefreiheitsverbesserungen für App Store-Bereitschaft'] },
        ],
      },
      {
        version: 'v1.4.0',
        date: '2026-06-05',
        sections: [
          { type: 'added' as const, items: ['Spektrum-Sitzungsaufzeichnung und Wiedergabe', 'Seitenweiser Spektrumsvergleich über Zeiträume'] },
          { type: 'improved' as const, items: ['Spektrumanalyseator UI und Steuerung'] },
        ],
      },
      {
        version: 'v1.3.0',
        date: '2026-05-28',
        sections: [
          { type: 'added' as const, items: ['MCP-Server für KI-Tool-Integration', 'Lokale JSON-Endpunkte für Netzwerkdaten, Details und Belegung'] },
          { type: 'improved' as const, items: ['Kanalqualitäts-Bewertungsalgorithmus'] },
        ],
      },
      {
        version: 'v1.2.0',
        date: '2026-05-24',
        sections: [
          { type: 'added' as const, items: ['Roaming-Test mit Zeitlinien-Visualisierung', 'Sitzungsspeicherung und Wiedergabe für Roaming-Tests'] },
          { type: 'improved' as const, items: ['Netzwerktabelle Sortierung und Filterung'] },
        ],
      },
      {
        version: 'v1.1.0',
        date: '2026-05-20',
        sections: [
          { type: 'added' as const, items: ['Verbindungsdiagnose-Dashboard', 'Kanalqualitäts-Bewertung und Empfehlungen'] },
          { type: 'improved' as const, items: ['Tri-Band Spektrum-Scanner Leistung'] },
        ],
      },
      {
        version: 'v1.0.0',
        date: '2026-05-18',
        sections: [
          { type: 'added' as const, items: ['Tri-Band Spektrum-Scanning (2,4 / 5 / 6 GHz)', 'Detaillierte Netzwerktabelle mit Filterung', 'Hochauflösende Spektrum-Screenshot-Export', 'CSV-Export für Netzwerkdaten'] },
        ],
      },
    ],
  },
  faq: {
    title: 'Häufig gestellte Fragen',
    metaDescription: 'Häufig gestellte Fragen zu WiFi Lens — Preis, macOS-Anforderungen, Datenschutz, Pro vs. OSS und 6-GHz-Unterstützung.',
    items: [
      { q: 'Ist WiFi Lens kostenlos?', a: 'Absolut. WiFi Lens OSS ist Open Source und vollständig kostenlos — du kannst es ohne Einschränkungen von GitHub herunterladen und nutzen. Die Pro-Version ist ein einmaliges Sponsoring über den App Store, das einige aufnahme-bezogene erweiterte Funktionen freischaltet. Die Kernfunktionen der Wi‑Fi-Analyse sind in beiden Versionen identisch.' },
      { q: 'Was ist der Unterschied zwischen Pro und OSS?', a: 'Die OSS-Version deckt alle Kernfunktionen ab: Spektrum-Scanning, Netzwerktabelle, Kanal-Bewertung, Roaming-Tests und MCP-KI-Integration. Die Pro-Version fügt Spektrum-Sitzungsaufzeichnung (Erfassen und Wiedergeben von Spektrumänderungen über die Zeit) und nebeneinander Spektrumvergleich über Zeiträume hinzu. Wenn du keine Aufnahme und Wiedergabe benötigst, hat die OSS-Version alles, was du brauchst.' },
      { q: 'Werden meine Daten in die Cloud hochgeladen?', a: 'Absolut nicht. WiFi Lens hat keinerlei Backend-Server. Alle Daten werden lokal auf deinem Mac verarbeitet. Selbst die MCP-KI-Integration kommuniziert nur über die lokale Schnittstelle deines Rechners — nichts wird an einen entfernten Server gesendet. Um es klar zu sagen: Wir sammeln nichts.' },
      { q: 'Welche macOS-Version benötige ich?', a: 'WiFi Lens erfordert macOS 14 (Sonoma) oder neuer. Es unterstützt sowohl Apple Silicon als auch Intel Macs. Ein kurzer Hinweis: Das Scannen des 6-GHz-Bandes erfordert, dass deine Mac-Hardware Wi‑Fi 6E oder Wi‑Fi 7 unterstützt (verfügbar bei neueren Apple Silicon Modellen). Ältere Intel Macs oder nicht-6E-Modelle können weiterhin alle 2,4-GHz- und 5-GHz-Funktionen ohne Einschränkung nutzen.' },
      { q: 'Warum zeigen einige 6-GHz-Netzwerke kein 6-GHz-Label?', a: 'Dies ist eine Einschränkung auf macOS-Systemebene. Die drahtlosen Scan-APIs, die macOS den Apps bereitstellt, kennzeichnen ein Netzwerk nicht immer explizit als zum 6-GHz-Band gehörend. Bei Wi‑Fi 6E-Netzwerken kodiert das System die Bandinformationen typischerweise über die Kanalnummer oder die Mittenfrequenz, anstatt direkt ein "6 GHz"-Label zurückzugeben. Infolgedessen können einige 6-GHz-Netzwerke in den Scanergebnissen als 5 GHz oder ohne spezifisches Bandlabel erscheinen. Dies ist Systemverhalten, kein Fehler — es bedeutet nicht, dass das Gerät kein 6-GHz-Netzwerk verwendet.' },
      { q: 'Funktioniert es unter Windows oder Linux?', a: 'WiFi Lens ist eine macOS-native App und unterstützt Windows oder Linux nicht. Es nutzt das CoreWLAN-Framework von macOS zum Auslesen von Wi‑Fi-Daten, und es gibt kein äquivalentes Framework auf anderen Betriebssystemen.' },
      { q: 'Warum verlangt es eine Standortberechtigung?', a: 'Das ist nicht unsere Anforderung — es ist eine macOS-Richtlinie. Apple schreibt vor, dass jede App, die Wi‑Fi-Netzwerknamen (SSIDs) lesen kann, eine Standortberechtigung einholen muss. WiFi Lens greift niemals auf deine GPS-Koordinaten zu und zeichnet niemals deinen Standort auf.' },
    ],
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
      body: 'Wi‑Fi — Kernfunktion: Scannen und Analysieren naher drahtloser Netzwerke.\n\nBluetooth — Optional: Erkennt nahe Bluetooth-Geräte für Koexistenz-Analyse. Standardmäßig deaktiviert, in den Einstellungen aktivierbar. Alle Erkennung läuft lokal auf deinem Gerät.\n\nOrtungsdienste — macOS verlangt diese Berechtigung für jede App, die Wi‑Fi-Netzwerknamen (SSIDs) liest. WiFi Lens greift nie auf deine GPS-Koordinaten zu und zeichnet nie deinen Standort auf.\n\nLokales Netzwerk — Nur verwendet, wenn du den MCP-Server in den Einstellungen aktivierst. Der Server horcht nur auf localhost (127.0.0.1), damit lokale Tools wie Claude Desktop Wi‑Fi-Scandaten lesen können. Standardmäßig deaktiviert – keine Daten verlassen deinen Mac.',
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
  home: {
    exploreFeatures: 'Funktionen entdecken',
    featuresTitle: 'Eine klarere Startseite. Eine klarere Produktgeschichte.',
    featuresSub: 'Beginne mit dem Produkt selbst und gehe nur dort tiefer, wo du es brauchst.',
    exploreLabel: 'Entdecken',
    exploreTitle: 'Beginne auf der Seite, die zu deiner Frage passt',
    exploreSub: 'Halte die Startseite kurz. Nutze die tieferen Seiten, wenn du specifics brauchst.',
    viewPage: 'Seite ansehen',
  },
  notFound: {
    title: '404 — Seite nicht gefunden',
    heading: 'Diese Seite existiert nicht.',
    desc: 'Die gesuchte Seite wurde möglicherweise verschoben oder existiert nicht mehr.',
    backHome: 'Zur Startseite',
  },
  footer: {
    copyright: '© 2026 WiFi Lens — Durchschaue dein Wi‑Fi.',
    x: '@WiFiLens',
    email: 'wifi-lens@outlook.com',
    privacy: 'Privatsphäre',
    support: 'Support',
    oss: 'GitHub',
    license: 'Apache 2.0',
  },
} as const
