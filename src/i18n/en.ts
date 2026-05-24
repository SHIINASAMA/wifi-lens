export const en = {
  nav: {
    features: 'Features',
    download: 'Download',
    docs: 'Docs',
  },
  hero: {
    badge: 'macOS 14+  ·  SwiftUI + CoreWLAN',
    title: 'WiFi Lens',
    subtitle: 'A native Wi-Fi spectrum analyzer for macOS. Real-time scanning, connection diagnostics, AP roaming tracking, and an MCP automation server — all without tracking or telemetry.',
    cta: {
      oss: 'Download Free',
      pro: 'Mac App Store',
      proSoon: 'Coming soon',
    },
    hint: 'Open source  ·  Apache 2.0  ·  No tracking',
  },
  features: {
    title: 'Deep visibility into your wireless environment',
    scanning: {
      title: 'Tri-Band Spectrum Scanning',
      desc: 'Scans 2.4 GHz, 5 GHz, and 6 GHz bands every 1–10 seconds. Each access point renders as a Gaussian bell curve centered on its channel, with 80 interpolation steps for smooth rendering. Per-band freeze, drag-to-zoom, and deterministic SSID-based color assignment from a 16-color palette using SHA-1 hashing.',
    },
    table: {
      title: '18-Column Network Table',
      desc: 'Native NSTableView with multi-column sort, row selection, and bi-directional chart highlighting. Columns include SSID, BSSID, RSSI with trend arrow and delta, PHY mode, channel width, 802.11k/r/v support, WPA3 detection, MCS index, spatial streams, and a per-network quality score (0–100). Right-click headers to show or hide columns.',
    },
    roaming: {
      title: 'Roaming Test with Timeline',
      desc: 'Designed for battery-equipped Mac laptops. Polls the Wi-Fi interface every second, detecting AP transitions by BSSID change. Dual-tier timeline chart — a detail view with Catmull-Rom spline curves and an overview strip with a draggable range selector. Exports sessions as .wifi-roam JSON files with full segment and transition data.',
    },
    quality: {
      title: 'Channel Quality Scoring',
      desc: 'Analyzes every channel across all three bands. The scoring algorithm weights overlapping APs by co-channel proximity, RSSI strength, channel width, and band congestion sensitivity. Five quality tiers: Excellent (90+), Good, Moderate, Busy, and Congested (<30). Simple and Professional view modes with per-channel score bars and recommendations.',
    },
    overview: {
      title: 'Connection Diagnostics Dashboard',
      desc: 'A dashboard centered on your current connection. Shows SSID with RSSI gauge and signal bars, three health pills (Signal strength, Channel quality, Security level), and seven prioritized diagnostic states — from "Your connection looks great" (strong RSSI + clean channel + WPA3) down to channel congestion with specific alternative channel recommendations and PHY generation warnings. A channel advice card appears when your current channel scores below 70, listing better alternatives with quality scores and AP counts. An environment summary card shows total network counts per band.',
    },
    privacy: {
      title: 'Private by Default',
      desc: 'No analytics, no telemetry, no outbound network calls. Location Services is used solely because macOS requires it to expose Wi-Fi SSID names via CoreWLAN — your location is never tracked or stored. Crash reports are written to timestamped files on your own disk. Structured logging via OSLog with optional Finder reveal.',
    },
  },
  demo: {
    title: 'Tour the app',
    subtitle: 'Six focused views, each purpose-built for a specific Wi-Fi diagnostic task. Replace these placeholder images with your own screenshots.',
    items: [
      {
        title: 'Overview Dashboard',
        desc: 'Landing page centered on your current connection. Shows your SSID with RSSI gauge and signal bars, three health pills (Signal strength, Channel quality, Security level), and a prioritized diagnostic card — from "Your connection looks great" to specific channel congestion advice with alternative recommendations. A channel advice card appears when your channel scores below 70, listing better alternatives. An environment summary card shows per-band network counts.',
        bullets: ['RSSI gauge + signal bars + health pills', '7-tier diagnostic with actionable advice', 'Channel recommendation card', 'Per-band environment summary', 'Hysteresis-stabilized quality scoring'],
        image: '/screenshots/overview.png',
      },
      {
        title: 'Spectrum Scanner',
        desc: 'Tri-band real-time scanning with Gaussian bell-curve charts. Each access point renders as a smooth curve centered on its channel, with 80 interpolation steps. The Y-axis auto-scales per band. A channel occupancy heatmap sits below the X-axis — taller, brighter bars mean more APs sharing that channel. SSID labels are drawn at curve apexes with collision avoidance. Hover anywhere for a tooltip with SSID, channel, RSSI, and BSSID. Drag to zoom, tap a curve to select, and freeze any band to snapshot the current state while scanning continues in the background.',
        bullets: ['Gaussian curves, 80 steps per curve', 'Collision-avoided SSID labels', 'Channel occupancy heatmap', 'Hover tooltips + drag-to-zoom + freeze', 'Trend arrows with signed RSSI delta'],
        image: '/screenshots/spectrum.png',
      },
      {
        title: 'Channel Quality Analyzer',
        desc: 'Scores every channel across all three bands using an overlap-based penalty model: each co-channel and adjacent-channel AP contributes a penalty weighted by RSSI strength, channel width, and band congestion sensitivity. Five quality tiers from Excellent (90+) to Congested (<30). Simple mode shows scrollable channel cards with score bars, overlap details, and strongest neighbor RSSI. Professional mode is a sortable grid with columns for channel, band, score, level, AP count, co-channel, adjacent, overlap, RSSI, interference, and recommendations.',
        bullets: ['Overlap factor × RSSI × width × band sensitivity', '5 quality tiers: Excellent → Congested', 'Simple (cards) and Professional (grid) modes', 'Per-channel AP count + strongest neighbor', 'Sortable multi-column professional view'],
        image: '/screenshots/channels.png',
      },
      {
        title: '18-Column Network Table',
        desc: 'A native NSTableView with bi-directional chart highlighting — click a row to highlight its curve, click a curve to select its row. Multi-column sort with persisted sort descriptors. Columns: SSID, BSSID, RSSI with trend arrow and delta, PHY mode (ax/ac/n), channel width, 802.11k/r/v checkmarks, quality score (0–100, color-coded), security type, MCS index, spatial streams, and country code. Right-click any column header to show or hide columns. A text filter field above the table accepts SSID or BSSID substrings. Band checkboxes and a "Hide Hidden" toggle control row visibility.',
        bullets: ['Native NSTableView, 18 sortable columns', 'Bi-directional chart/table selection', 'Right-click column visibility toggles', 'SSID/BSSID filter + band checkboxes', 'Per-row visibility toggle via checkbox'],
        image: '/screenshots/table.png',
      },
      {
        title: 'Roaming Test',
        desc: 'Designed for battery-equipped Mac laptops. Polls the Wi-Fi interface every second via CoreWLAN and detects AP transitions when the BSSID changes. A dual-tier timeline chart shows the full session — a detail view with Catmull-Rom spline curves and filled areas per BSSID segment, and a compact overview strip below with a draggable range selector (default 30s window, minimum 5s). Vertical dashed lines mark each AP handoff. Hover over the chart to see a value badge with time, RSSI, channel, Tx rate, and gateway latency. A transition table below lists every handoff with before/after RSSI and channel values. Save sessions as .wifi-roam JSON files for later analysis.',
        bullets: ['1-second CoreWLAN polling', 'BSSID change detection for AP transitions', 'Catmull-Rom splines + filled areas per segment', 'Dual-tier chart with draggable range selector', 'Session save/load as .wifi-roam JSON'],
        image: '/screenshots/roaming.png',
      },
      {
        title: 'Network Interfaces',
        desc: 'Three view modes: Simple shows a connection hero with SSID, interface name, band, channel, and three health indicators (RSSI bar, PHY mode with Wi-Fi generation label, stability score). A link details table shows BSSID, security, MCS/NSS, Tx rate, k/r/v support, IPv4, subnet, router, DNS, and hardware MAC. Monitor mode displays a real-time throughput chart with download (green) and upload (blue) as clamped cubic spline curves, polling ifi_ibytes/ifi_obytes deltas every second. All network interfaces (Wi-Fi, Ethernet, VPN, virtual) are listed with type badges and key metrics.',
        bullets: ['Simple, Details, and Monitor modes', 'Real-time throughput chart (1s polling)', 'All interfaces: Wi-Fi, Ethernet, VPN, virtual', 'Stability score: RSSI + trend + protocols + width', 'Gateway latency with live ping'],
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
    title: 'MCP Server — Let AI See Your Wi-Fi',
    subtitle: 'WiFi Lens doubles as a Model Context Protocol server, exposing live scan data to AI tools like Claude Desktop. A local HTTP server on 127.0.0.1 — no cloud, no data leaving your machine.',
    endpoints: {
      title: 'Three JSON endpoints',
      networks: 'All visible networks with SSID, BSSID, RSSI, channel, band, PHY mode, channel width, security, MCS, NSS, and country code. Optional ?band= filter.',
      detail: 'Per-BSSID detail with the raw channel width in MHz.',
      occupancy: 'Per-band per-channel AP counts for occupancy analysis.',
    },
    config: {
      title: 'One config to connect',
      desc: 'Enable the MCP server in Settings, then add this to your Claude Desktop config:',
    },
    cta: {
      docs: 'Read the docs',
      github: 'View on GitHub',
    },
  },
  download: {
    title: 'Get WiFi Lens',
    oss: {
      title: 'WiFi Lens OSS',
      badge: 'Free & Open Source',
      desc: 'The complete Wi-Fi analyzer. Download the pre-built binary from GitHub Releases, or clone the repo and build from source with a single xcodebuild command.',
      features: [
        'Tri-band scanning with Gaussian chart rendering',
        '18-column network table with bi-directional selection',
        'Channel quality analyzer (5 levels, 2 view modes)',
        'Roaming test with timeline chart and session save/load',
        'Connection diagnostics dashboard',
        'Network interface inspector with throughput monitor',
        'Export charts as PNG or CSV per band',
        'MCP automation server (3 JSON endpoints)',
        'Configurable scan interval, theme, and more',
        'Community support via GitHub Issues',
      ],
      cta: 'Download from GitHub',
      url: 'https://github.com/SHIINASAMA/wifi-lens/releases/latest',
    },
    pro: {
      title: 'WiFi Lens PRO',
      badge: 'Coming to Mac App Store',
      desc: 'The same powerful engine, delivered through the Mac App Store — no Gatekeeper workaround needed, with automatic updates included.',
      features: [
        'Everything in the OSS edition',
        'Mac App Store installation — no Gatekeeper hassle',
        'Automatic background updates',
        'Support ongoing indie development',
      ],
      cta: 'Coming Soon',
    },
  },
  footer: {
    copyright: 'WiFi Lens. Built with SwiftUI, CoreWLAN, and Sparkle.',
    oss: 'GitHub',
    license: 'Apache 2.0',
  },
} as const
