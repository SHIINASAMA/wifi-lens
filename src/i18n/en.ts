export const en = {
  nav: {
    features: 'Features',
    mcp: 'MCP',
    download: 'Download',
    privacy: 'Privacy',
    docs: 'Docs',
  },
  hero: {
    badge: 'macOS 14+  ·  Native  ·  Local-first',
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
      title: 'Comprehensive Network Table',
      desc: 'Inspect RSSI, channel, band, security, vendor, and capabilities for every visible network. Sort, filter, and cross-reference rows with the spectrum view while investigating.',
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
        title: 'Comprehensive Network Table',
        alt: 'Sortable network table with Wi-Fi details including RSSI, channel, security, vendor, and capabilities',
        desc: 'Drill into the full list of visible networks with a dense, native table. Every row exposes signal strength, channel, band, security type, vendor OUI, and 802.11 capabilities.',
        bullets: ['RSSI, channel, band, and security type', 'Vendor OUI and capability flags', 'Filter fast by SSID or BSSID'],
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
    title: 'What makes it useful',
    items: [
      { label: 'Live scanning', value: 'Real-time updates across 2.4, 5, and 6 GHz — pick any interval from 1 to 10 seconds' },
      { label: 'Spectrum charts', value: 'Smooth, responsive visualizations that make channel overlap and congestion easy to spot' },
      { label: 'Export', value: 'Save spectrum screenshots as high-resolution PNGs or export network data as CSV spreadsheets' },
      { label: 'AI integration', value: 'Let compatible AI tools inspect your local Wi‑Fi environment without sending data to the cloud' },
      { label: 'Channel scoring', value: 'Smart recommendations that weigh signal strength, overlap, and band width together' },
      { label: 'Session saving', value: 'Save roaming tests and reopen them later to compare before-and-after results' },
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
      desc: 'Download the latest version from GitHub Releases, ready to run on macOS 14 or later.',
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
    title: 'Your data stays on your Mac. Always.',
    subtitle: 'WiFi Lens processes everything locally. No accounts, no cloud, no tracking.',
    noCollection: {
      heading: 'No Personal Data Collection',
      body: 'WiFi Lens does not collect, store, or transmit any personally identifiable information. The app contains no user accounts, no analytics SDKs, no ad networks, and no telemetry frameworks. We operate no backend servers to receive your data — because we have no interest in having it.',
    },
    permissions: {
      heading: 'Why We Request Permissions',
      body: 'Wi‑Fi — Core functionality: scanning and analyzing nearby wireless networks.\n\nBluetooth — Used to discover nearby Bluetooth devices for coexistence analysis. All discovery runs locally on your machine.\n\nLocation Services — macOS requires this permission for any app that reads Wi‑Fi network names (SSIDs). WiFi Lens never accesses your GPS coordinates and never logs your location.',
    },
    localOnly: {
      heading: 'Everything Stays on Your Machine',
      body: 'All Wi‑Fi scan results, Bluetooth discovery data, channel recommendations, and regulatory region detection run entirely on-device. No scan data is ever uploaded to a remote server.\n\nCrash reports and diagnostic logs are written to files on your own disk. Nothing is transmitted unless you explicitly choose to share it.\n\nThe MCP server binds to 127.0.0.1 (localhost only). No scan data leaves your machine through MCP unless you deliberately route it elsewhere.',
    },
    distribution: {
      heading: 'Distribution Differences',
      body: 'WiFi Lens is available through two channels. They differ only in how updates are checked:\n\nMac App Store — Uses Apple\'s built-in update mechanism. The app never contacts any third-party server for version checks or updates.\n\nGitHub / Direct Download — Uses the Sparkle framework to check for new versions. Sparkle fetches a single appcast file (a version descriptor) from our release server. This request transmits no personal data, no usage analytics, and no diagnostic information — it is purely a version comparison.',
    },
    openSource: {
      heading: 'Open Source & Verifiable',
      body: 'The complete source code is available under the Apache 2.0 license. Every claim on this page can be independently verified by anyone who reads the code.',
    },
    lastUpdated: 'Last updated: May 27, 2026',
    contact: 'Questions? Open a GitHub Issue or reach us at wifi-lens@outlook.com',
  },
  footer: {
    copyright: '© 2026 WiFi Lens. Understand your Wi‑Fi.',
    x: '@WiFiLens',
    email: 'wifi-lens@outlook.com',
    privacy: 'Privacy',
    support: 'Support',
    oss: 'GitHub',
    license: 'Apache 2.0',
  },
} as const
