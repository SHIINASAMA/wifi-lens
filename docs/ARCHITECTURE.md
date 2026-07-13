# Architecture

macOS Wi-Fi spectrum analyzer (SwiftUI + CoreWLAN + AppKit interop). Targets macOS 14+, Swift 6.0.

## Data Flow

```
WiFi — CoreWLAN scan source → WiFiObservationRuntime
                               ├── scan lifecycle + device capability cache
                               ├── WiFiObservationPipeline.produceCycle(...)
                               │     ├── current connection + same-cycle gateway latency
                               │     ├── normalized environment + channel analysis
                               │     ├── regulatory inference + recommendation
                               │     └── quality + diagnosis → immutable WiFiObservation
                               └── publication gate
                                     ├── WiFiObservationStore UI projection
                                     └── ordered edition consumer (Pro only; none in OSS)
                                           └── WiFiObservationEventJournal
                                                 ├── optimistic recent publication
                                                 ├── generation-safe query / clear
                                                 └── WiFiObservationEventLogStoring
                                                       └── SQLite

Runtime output → ScannerViewModel presentation projection
                  ├── WiFiNetwork → ChannelSpanCalculator → ChartSeriesData (Gaussian curves)
                  │                 → BandChartViewModel (per-band state → BandChartRenderModel)
                                       ├── combinedTableRows → NativeTableView (AppKit NSTableView)
                                       ├── channelQualities → ChannelQualityCalculator → ChannelQualityView
                                       ├── bandViewModels → WiFiBandChart → Chart (universal renderer)
                                       ├── networkInfo → InterfacesView (throughput, gateway, DNS)
                                       ├── roamingSamples → RoamingTestViewModel → RoamingTestView
                                       ├── mcpServer → MCPServer → HTTP API (127.0.0.1:19840)
                                       └── regulatoryData → RegulatoryPipeline → ChannelRecommendation

BLE — CoreBluetooth scan → BLEAdvertisementEvent → BLEDeviceTracker → BLEViewModel
                                                                       ├── BLEScannerView
                                                                       └── BLETrendChartView (via Chart engine)

Chart Engine (ChartLens package):
  Caller builds [ChartSeries] + ChartAxisConfig + ChartStyle
      → Chart<Overlay> → GeometryReader → ChartGeometry
      → Canvas: grid, axes, clip, draw series by interpolation mode
      → overlay(geo, series)

  DetailOverviewChart wraps two Charts + RangeSelector for linked zoom/overview.
  See [ChartLens/README.md](../ChartLens/README.md) and docs/CHARTS.md for full architecture.
  See docs/BLE.md for BLE scan architecture.
  See docs/REGULATORY.md for regulatory pipeline.
  Pro features documented in Pro/docs/ARCHITECTURE.md (separate submodule).
```

## Source Layout

| Path | Responsibility |
|------|---------------|
| `WiFiLensApp.swift` | Root `@main` App struct, Scene, menu commands, window group |
| `Scanner/` | Presentation-facing scanner ViewModel, CoreWLAN scan source, network/channel models, Wi-Fi power monitoring, and CWChannel extensions |
| `Spectrum/` | WiFiBandChart, BandChartViewModel, BandChartRenderModel, BandChartLayout, ContentView (dashboard), ChartSeriesData, ChannelSpanCalculator, SignalHistoryStore, NetworkSnapshot, TrendChartView, SnapshotToChartAdapter, SSIDColorHasher |
| `Channels/` | ChannelQualityCalculator, ChannelQualityView, RecommendationReason, RecommendationReasonCalculator, ReasonPopover |
| `Charts/` | Universal Chart engine: ChartView, ChartTypes, DetailOverviewChart, RangeSelectorView, ChartGeometry, SplineInterpolation, ChartTimeFormatting, ChartRendering (legacy) |
| `Interfaces/` | InterfacesView, ThroughputMonitor, ThroughputChartView, NetworkInfoService |
| `Roaming/` | RoamingTestView, RoamingTestViewModel, AP transition tracking, timeline chart with DetailOverviewChart |
| `SignalProcessing/` | RSSI signal smoothing: SignalSmoothing protocol, ExponentialMovingAverage, KalmanFilter1D, HysteresisEMA |
| `Table/` | NativeTableView (NSViewRepresentable wrapping NSTableView) |
| `App/` | OverviewView, SidebarView, SettingsView, Logging, CrashReporter, SparkleUpdater, TitleBadge, HelpCenterView, LocationPermissionRequiredView, WiFiOffView, MetricKitManager |
| `BLE/` | BLEScanner, BLEDeviceTracker, BLEViewModel, BLEScannerView, BLETrendChartView, BLEAdvertisementEvent, BLEChannel, BLEDeviceSnapshot, BLERSSISample, BluetoothPermissionManager. See docs/BLE.md |
| `Debug/` | DebugChartView, DebugRoamingChartView (DEV builds only) |
| `MCP/` | MCPServer — embedded HTTP/1.1 JSON API (NWListener on 127.0.0.1:19840) exposing scan data |
| `Regulatory/` | RegulatoryPipeline, RegulatoryDatabase, RegulatoryFilter, RegionInferenceEngine, ChannelRecommendation, DeviceCompatibilityFilter, RegulatoryDomain. See docs/REGULATORY.md |
| `Observation/` | Immutable Wi-Fi observation models, providers, analyzers, single-cycle pipeline, Store projection, and the production observation runtime |
| `Utilities/` | Constants, Color extensions, BuildConfig, DeviceCapabilities, GatewayPinger |
| `Resources/` | Localizable.xcstrings (String Catalog) |

Pro features (Recording, Session, StoreKit, Timeline, and Wi-Fi observation event persistence) live in the `Pro/` submodule at the repo root — see `Pro/docs/ARCHITECTURE.md`.

## Key Patterns

- `ScannerViewModel` is `@Observable`, passed via `@Bindable` through the view tree
- **Single production observation runtime**: `WiFiObservationRuntime` owns the CoreWLAN scan stream, serialized start/restart/stop lifecycle, per-start device capability cache, and publication eligibility gate. Each accepted scan event is sent through `WiFiObservationPipeline.produceCycle(networks:context:)`; the pipeline fetches current connection and same-cycle gateway latency once, performs normalized analysis, and returns one complete immutable observation plus inferred-region output. Scan failures still produce a partial observation containing current connection, latency, and the environment error.
- **Immutable ordered publication**: the runtime applies the exact accepted `WiFiObservation` to `WiFiObservationStore` first, then enqueues that same value independently for each fixed edition-level consumer. Each consumer is serial and lossless in acceptance order; consumer latency or failure does not delay or invalidate Store projection. The runtime is a Wi-Fi observation boundary, not a general application event bus.
- **Stop drain barrier**: a normal `WiFiObservationRuntime.stopScanning()` first stops the scan source and joins the active scan task so no further observation can be accepted, then drains every accepted consumer tail before returning. Internal source replacement for `restartScanning()` does not apply this drain barrier, so interval/configuration restarts remain independent of consumer latency.
- **Scanner presentation boundary**: `ScannerViewModel` forwards lifecycle/configuration commands to the runtime and projects runtime output into raw-network caches, RSSI history, filters, AP visibility/lock state, charts, tables, selection, channel/recommendation UI, interface presentation, and the existing MCP data-provider surface. It does not scan directly, construct production observations, run the production analyzers, or publish to the Store.
- **Edition composition**: the shared runtime and Store projection compile into both app targets. OSS registers no paid event consumer. Pro registers one `WiFiObservationEventJournal` at app composition time; the Journal and every concrete Pro event implementation remain absent from the OSS Sources phase.
- **Edition composition seam**: the shared app shell owns product routes and upsell descriptors, while exactly one `EditionComposition` implementation is compiled for each edition. Pro lifecycle and domain composition are Pro-source responsibilities rather than shared-source responsibilities. This lets OSS retain Timeline and recording upsell surfaces without importing Pro domain code.
- **Pro Event Journal boundary**: the Journal consumes each exact immutable runtime observation and privately owns event derivation, optimistic recent publication, hydration validation, generation-safe queries, clear coalescing, clear-time queueing, and persistence ordering. `WiFiObservationEventLogStoring` remains the persistence seam, with SQLite as the production adapter. Timeline and menu receive the same Journal instance and preserve its event IDs; the menu continues to read live connection metrics from `WiFiObservationStore`. Clear state is published directly through the Journal rather than a process-wide notification.
- **Pro connection identity boundary**: Pro connection and disconnection events carry `WiFiNetworkIdentity(ssid:bssid:)` as their sole transition identity. The Journal persists the payload into separate SQLite v2 SSID and BSSID columns. Timeline and menu render it through the shared `WiFiNetworkIdentityPresentation` adapter. `EventContextSnapshot` supplies diagnostic detail only and cannot provide a connection label or persistence fallback. Development schema v1 history is dropped once when the store installs v2; the installer does not parse legacy combined labels.
- Selection flows bidirectionally: table row → `selectedNetworkID` → chart highlight; chart curve click → `selectedNetworkID` → table row highlight
- `NativeTableView` uses `Coordinator` as `NSTableViewDelegate` + `NSTableViewDataSource`
- **Chart Engine** — All chart views build `[ChartSeries]` arrays and delegate rendering to the universal `Chart<Overlay>` component. Domain-specific overlays (tooltips, heatmaps, data labels, transition markers) are injected via a `ViewBuilder` closure. See `docs/CHARTS.md`.
- `WiFiBandChart` is decoupled from `BandChartViewModel` via `BandChartRenderModel` — a value-type snapshot created each render pass, so the view never holds a reference to the ViewModel
- **ChartSeriesData split**: `ChartSeriesDomainData` (immutable network identity) + `ChartSeriesRenderState` (mutable visual state: animated `displayRSSI`, `color`, filter/visibility flags, trend indicators). `ChartSeriesData` wraps both with computed passthrough properties
- `displayRSSI` animates toward `rssi` each tick for smooth Gaussian curve transitions
- AP roaming transitions share a single timestamp between old and new segments, eliminating gaps on the timeline
- Signal history (`SignalHistoryStore`) keeps 20 snapshots per BSSID in memory
- Wi-Fi observation event derivation, Journal state, Timeline history, and SQLite-backed event persistence are Pro-only runtime features. OSS may keep navigation or upsell entry points, but the concrete event model, Journal, Timeline data flow, and SQLite storage implementation must stay inside the `Pro/` submodule.
- `ScannerViewModel.scanIntervalSeconds` supports dynamic override — external code (e.g., recording in the Pro submodule) can set it to a custom value and restore the UserDefaults-configured value on stop. Its `didSet` forwards a serialized runtime restart when scanning. Recording continues to sample `ScannerViewModel.signalHistory`, and MCP continues to read the scanner's raw-network cache; neither public integration has been migrated directly to the observation stream.
- `StableScore` provides hysteresis for quality level boundaries (upgrade margin 2, downgrade margin 5)
- `ChannelBand(id:)` failable initializer maps String band IDs ("24"/"5"/"6") to enum cases, used by `SnapshotToChartAdapter` for history playback
- **Channel recommendation priority**: `ChannelRecommendationAvailability.from()` checks `.currentGoodEnough` and `.targetUnknown` before `.isRecommended`. When the current channel is already good enough, no switching recommendation is shown — even if other channels score higher. This prevents contradictory UI messages (status banner says "good enough" while channel cards show "★ Recommended")
- Page-internal secondary navigation is hosted in the real window toolbar principal area, while the sidebar remains the primary top-level navigator
- `AppRootView` owns the active `SecondaryToolbarDescriptor` and per-page selection state for shared business-page mode switching
- Pages that participate in the shared secondary toolbar consume root-owned mode state instead of rendering their own local segmented controls
- **Toolbar selection state**: `SecondaryToolbarSelections` is a concrete `Equatable` struct with typed per-page properties (not a `[SidebarPage: ID]` dictionary). Each page's `SecondaryToolbarCapsule` binds directly to its typed property via `@ToolbarContentBuilder`. This lets SwiftUI compare old/new structs and skip `updateNSView` when nothing changed — critical because `WiFiLensApp.body` re-renders frequently due to `ScannerViewModel` observation
- **@Observable observation chain**: `BandChartViewModel` animation timer modifies `displayedSeriesData` at 60fps. If any parent view reads these properties (e.g. `allSeriesData.count`), the observation chain propagates up to `WiFiLensApp.body`, causing unnecessary re-renders of the entire view hierarchy including the toolbar. Cache frequently-changing derived values (e.g. `cachedTotalNetworks`, `cachedBandSummary`) in `ScannerViewModel` and have child views read the cached values instead
- **Main window policy**: The shipping app uses a standard resizable macOS main window. Do not use scene-level `.windowResizability(.contentSize)` on the app `WindowGroup`; page `idealWidth` / `idealHeight` values must stay local layout hints. Restored frames are normalized against the current screen `visibleFrame`. See `docs/WINDOWING.md`.

## Localization

- All user-facing strings use `String(localized: "domain.component.element", comment: "Context for translators")` in source
- Keys use hierarchical dot-notation: `<domain>.<component>.<element>` with lowercase and underscores
- Domains: `common` (shared UI), `nav` (sidebar), `settings`, `overview`, `spectrum`, `channels`, `interfaces`, `roaming`, `ble`, `permission`, `wifi` (terminology), `format` (parameterized)
- Example: `"overview.diagnosis.congested.title"` for "Channel is congested" diagnosis heading
- Parameterized strings use `String(format: String(localized: "format.key"), args...)` — never interpolate values into the key string
- Translations in `Resources/Localizable.xcstrings` (Xcode String Catalog, `en`, `ja`, `zh-Hans`)
- New strings must be manually added to `.xcstrings` with `"extractionState": "manual"` and an explicit `en` localization with `"state": "translated"`
- Xcode auto-extraction is disabled (`SWIFT_EMIT_LOC_STRINGS = NO`)

## Testing

- Framework: Swift Testing (`import Testing`, `@Test`, `#expect()`)
- Tests cover pure-logic modules: `ChannelSpanCalculator`, `IEParser`, `SSIDColorHasher`, `ChannelQualityCalculator`, `NetworkTableRow`, `BandChartViewModel`, `BandChartLayout`, `SnapshotToChartAdapter`
- Test target uses `@testable import WiFiLens`

## Design Conventions

- Cards: `.regularMaterial` + `RoundedRectangle(cornerRadius: 12)`, 16pt padding
- Sub-cards: `.thinMaterial` + `RoundedRectangle(cornerRadius: 10)`
- Font: 9pt labels, 11-13pt body, 15pt semibold hero
- RSSI colors: green ≥ -55, yellow ≥ -70, orange ≥ -85, red below
- Quality colors: hex strings from `QualityLevel.color`
- Overlap badge on channel cards includes trailing "overlap" label for context
- **Target membership**: Add new `.swift` source files only to the targets that should legally ship that code. Shared OSS runtime files must be added to both `WiFiLens` and `WiFiLensPro`; Pro-only implementations must be added only to `WiFiLensPro`. The Pro target maintains its own independent build phase, so missing membership there still causes "cannot find type in scope" errors in the `WiFi Lens Pro` scheme.
