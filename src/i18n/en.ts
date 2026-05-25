export const en = {
  nav: {
    features: 'Features',
    mcp: 'MCP',
    download: 'Download',
    privacy: 'Privacy',
    docs: 'Docs',
  },
  hero: {
    badge: 'macOS 14+  ·  SwiftUI + CoreWLAN',
    title: 'WiFi Lens',
    subtitle: 'A native Wi‑Fi analyzer for macOS that helps you spot congestion, diagnose connection quality, and verify roaming behavior in real time.',
    cta: {
      oss: 'Download Free',
      secondary: 'For AI workflows',
      proSoon: 'Mac App Store coming soon',
    },
    hint: 'Local-first  ·  Open source  ·  No tracking',
  },
  features: {
    title: 'Deep visibility into your wireless environment',
    scanning: {
      title: 'Tri-Band Spectrum Scanning',
      desc: 'See nearby 2.4 GHz, 5 GHz, and 6 GHz networks update in real time. Zoom, freeze, and compare channel overlap without losing the big picture.',
    },
    table: {
      title: '18-Column Network Table',
      desc: 'Inspect every visible network in a dense, sortable table. Filter quickly and jump between table rows and spectrum curves to investigate issues faster.',
    },
    roaming: {
      title: 'Roaming Test with Timeline',
      desc: 'Track access point handoffs while moving through a space. Review transitions, signal changes, and saved sessions to confirm roaming behavior.',
    },
    quality: {
      title: 'Channel Quality Scoring',
      desc: 'Find cleaner channels across all Wi‑Fi bands at a glance. Scores, tiers, and recommendations help you decide where to move next.',
    },
    overview: {
      title: 'Connection Diagnostics Dashboard',
      desc: 'Start with the connection you are using right now. WiFi Lens highlights signal health, channel quality, security, and the most likely cause of trouble.',
    },
    privacy: {
      title: 'Private by Default',
      desc: 'No analytics, no telemetry, and no cloud dependency. Your scans stay on your Mac, and even MCP access remains local to your machine.',
    },
  },
  demo: {
    title: 'See the app in action',
    subtitle: 'Six focused views for troubleshooting Wi‑Fi performance, coverage, and channel usage.',
    items: [
      {
        title: 'Overview Dashboard',
        alt: 'Overview dashboard showing current Wi-Fi health, signal strength, and channel recommendations',
        desc: 'Check the health of your current connection first. The overview highlights signal strength, channel quality, security, and the most useful next step.',
        bullets: ['Current connection health at a glance', 'Actionable channel recommendations', 'See which band looks busiest'],
        image: '/screenshots/overview.png',
      },
      {
        title: 'Spectrum Scanner',
        alt: 'Tri-band spectrum scanner showing network curves and channel occupancy across Wi-Fi bands',
        desc: 'Watch nearby networks populate live spectrum charts across all major Wi‑Fi bands. Use it to spot overlap, congestion, and noisy channel groups quickly.',
        bullets: ['Live tri-band spectrum view', 'Spot crowded channels quickly', 'Zoom, freeze, and inspect details'],
        image: '/screenshots/spectrum.png',
      },
      {
        title: 'Channel Quality Analyzer',
        alt: 'Channel quality analyzer with region-aware scoring, DFS detection, and device compatibility filtering',
        desc: 'Compare channel scores before changing your network setup. WiFi Lens surfaces cleaner options with region-aware filtering, overlap context, and device compatibility checks.',
        bullets: ['Per-channel quality scores', 'Region-aware recommendations', 'Cleaner-channel suggestions'],
        image: '/screenshots/channels.png',
      },
      {
        title: '18-Column Network Table',
        alt: 'Sortable network table with Wi-Fi details including RSSI, channel, security, and capabilities',
        desc: 'Drill into the full list of visible networks with a dense, native table. Sort, filter, and cross-reference rows with the spectrum view while investigating.',
        bullets: ['18 sortable network columns', 'Match table rows to spectrum curves', 'Filter fast by SSID or BSSID'],
        image: '/screenshots/table.png',
      },
      {
        title: 'Roaming Test',
        alt: 'Roaming test timeline showing access point transitions, signal history, and handoff details',
        desc: 'Validate roaming behavior while walking a space with a laptop. Review handoffs, signal history, and saved sessions to understand how clients move between APs.',
        bullets: ['Detect AP transitions over time', 'Visualize signal drops during movement', 'Save and reload roaming sessions'],
        image: '/screenshots/roaming.png',
      },
      {
        title: 'Network Interfaces',
        alt: 'Network interfaces view showing connection details and live throughput monitoring',
        desc: 'Inspect Wi‑Fi and non-Wi‑Fi interfaces from one place. Switch between high-level status, detailed link information, and live throughput monitoring.',
        bullets: ['Switch between quick status and deep detail', 'Watch live throughput over time', 'Inspect Wi‑Fi, Ethernet, VPN, and virtual links'],
        image: '/screenshots/interfaces.png',
      },
    ],
  },
  specs: {
    title: 'Technical highlights',
    items: [
      { label: 'Scan engine', value: 'CoreWLAN · 1–10 s interval · tri-band' },
      { label: 'Charts', value: 'SwiftUI Canvas · Gaussian curves · Catmull-Rom splines' },
      { label: 'Export', value: 'PNG (2x ImageRenderer) · CSV (12 columns)' },
      { label: 'MCP server', value: 'HTTP on localhost · 3 endpoints · configurable port' },
      { label: 'Quality model', value: 'Overlap factor × RSSI × width × band · hysteresis' },
      { label: 'Session format', value: '.wifi-roam JSON · versioned schema' },
    ],
  },
  mcp: {
    title: 'Let AI inspect your local Wi‑Fi environment',
    subtitle: 'WiFi Lens can expose live scan data to tools like Claude Desktop over MCP, so you can ask questions about nearby networks and channel usage without sending data to the cloud.',
    endpoints: {
      title: 'Three JSON endpoints',
      networks: 'Browse nearby networks with signal, band, channel, security, and capability details.',
      detail: 'Inspect one network in depth by BSSID, including channel-width information.',
      occupancy: 'Check per-channel occupancy to understand congestion across each Wi‑Fi band.',
    },
    config: {
      title: 'One config to connect',
      desc: 'Enable the MCP server in WiFi Lens, add this config in Claude Desktop, then ask questions like “Which channel looks least congested?” or “What stands out in nearby networks?”',
    },
    cta: {
      docs: 'Read the docs',
      github: 'View on GitHub',
    },
  },
  download: {
    title: 'Get started with WiFi Lens',
    oss: {
      title: 'WiFi Lens OSS',
      badge: 'Free & Open Source',
      desc: 'Download the open source build from GitHub Releases, or build it yourself with one xcodebuild command.',
      features: [
        'Live tri-band spectrum scanning',
        'Detailed network table and filtering',
        'Channel quality scoring and recommendations',
        'Roaming timeline analysis',
        'Connection diagnostics dashboard',
        'Local MCP server for AI workflows',
      ],
      cta: 'Download from GitHub',
      url: 'https://github.com/SHIINASAMA/wifi-lens/releases/latest',
    },
    pro: {
      title: 'WiFi Lens PRO',
      badge: 'Planned for Mac App Store',
      desc: 'A future Mac App Store release is planned for people who want a simpler installation path.',
      features: [
        'Same core analyzer experience',
        'Simpler installation flow',
        'Mac App Store distribution when available',
      ],
      cta: 'Planned',
    },
  },
  privacy: {
    title: 'Your data stays on your Mac',
    subtitle: 'WiFi Lens is built to be local-first from the ground up. No accounts, no cloud, no surprises.',
    bullets: [
      'WiFi Lens does not collect, store, or transmit any personal information, usage analytics, or telemetry. There are no third-party analytics, ad networks, or tracking SDKs in the app.',
      'Location Services: macOS requires this permission for CoreWLAN to expose Wi‑Fi SSID names. WiFi Lens never accesses your coordinates and never logs your location.',
      'Region detection: channel recommendations use your system locale, hardware-reported channel list, and nearby AP country codes to infer your regulatory domain. This inference runs entirely on-device — no region data is collected or transmitted.',
      'All Wi‑Fi scan results, crash reports, and diagnostic logs remain in files on your own disk. Nothing is uploaded or shared automatically — you control whether to share them.',
    ],
    mcp: 'MCP server is bound to 127.0.0.1. No scan data leaves your machine through MCP unless you explicitly route it elsewhere.',
    oss: 'Source code is open (Apache 2.0). Every data-handling claim above is independently verifiable.',
  },
  footer: {
    copyright: 'WiFi Lens. Built with SwiftUI, CoreWLAN, and Sparkle.',
    x: '@WiFiLens',
    email: 'wifi-lens@outlook.com',
    privacy: 'Privacy',
    support: 'Support',
    oss: 'GitHub',
    license: 'Apache 2.0',
  },
} as const
