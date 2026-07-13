# Architecture

macOS Wi-Fi spectrum analyzer (SwiftUI + CoreWLAN + AppKit interop). Targets macOS 14+, Swift 6.0.

## Data Flow

```
WiFi — CoreWLAN scan source → WiFiObservationRuntime
                               ├── scan lifecycle + one in-flight / one latest-pending raw-cycle gate
                               ├── one immutable NetworkInterfaceSnapshot per admitted cycle
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
- **Single production observation runtime**: `WiFiObservationRuntime` owns the CoreWLAN scan source, serialized start/restart/stop lifecycle, per-start device capability cache, publication eligibility gate, and the sole raw-cycle admission buffer. The buffer permits one in-flight cycle and one replaceable latest pending cycle; replacing an older pending cycle increments `rawCycleReplacementCount`. No `AsyncStream` adds a second raw backlog.
- **Single interface snapshot**: every admitted runtime cycle awaits one value-semantic `NetworkInterfaceSnapshot` with a cycle ID and capture timestamp from the serial `SystemNetworkInterfaceSnapshotSource` actor. SystemConfiguration and `getifaddrs` enumeration therefore runs off the main actor. `WiFiCurrentConnectionProvider` derives status from that snapshot, `WiFiObservationScanOutput` carries the same value, and `ScannerViewModel.networkInfo` projects its interfaces. Current status and the Interfaces page share exact provenance without a second `NetworkInfoService.fetchAll()` call.
- **Immutable ordered publication**: after producing a cycle, the runtime applies the exact accepted `WiFiObservation` to `WiFiObservationStore` and updates `ScannerViewModel` presentation before awaiting fixed edition consumers in order. The Pro Journal consumer waits only for bounded FIFO admission, not SQLite completion. A saturated admission may keep the raw cycle in flight, while already-admitted persistence continues on the Journal's single worker; overload is still absorbed only by the replaceable latest-pending raw slot. The runtime is a Wi-Fi observation boundary, not a general application event bus.
- **Stop barrier**: `WiFiObservationRuntime.stopScanning()` invalidates the scan generation, clears pending raw work, cancels and joins the in-flight raw task, stops the source, and drains consumer admission work before returning. Cancellation removes a capacity-blocked Journal admission, so stopping the runtime does not require shutting down or waiting for the Journal's SQLite worker. The final raw diagnostics have neither an in-flight nor a pending cycle.
- **Application termination barrier**: AppKit termination requests return `.terminateLater` through one process-scoped delegate coordinator. Repeated Command-Q and menu-bar quit requests share one operation and receive one reply. A three-second deadline covers scanner/runtime stop plus the target-selected edition hook; expiration requests cancellation and replies without joining a non-cooperative task. `ScannerViewModel.stopForTermination()` synchronously enters a permanent gate, stops CoreWLAN monitoring, supersedes suspended runtime startup, and rejects later reconcile/start/restart work. Pro bounds both Journal drain and shutdown waiting and reports them separately. The bound guarantees the AppKit reply, not completion of a synchronous SQLite call that ignores cancellation; such work may remain suspended until process exit.
- **Scanner presentation boundary**: `ScannerViewModel` forwards lifecycle/configuration commands to the runtime and projects runtime output into raw-network caches, RSSI history, filters, AP visibility/lock state, charts, tables, selection, channel/recommendation UI, interface presentation, and the existing MCP data-provider surface. It does not scan directly, construct production observations, run the production analyzers, or publish to the Store.
- **Edition composition**: the shared runtime and Store projection compile into both app targets. OSS registers no paid event consumer. Pro registers one `WiFiObservationEventJournal` at app composition time; the Journal and every concrete Pro event implementation remain absent from the OSS Sources phase.
- **Edition composition seam**: the shared app shell owns product routes, the common export menu shell, and upsell descriptors, while exactly one `EditionComposition` implementation is compiled for each edition. Its narrow Markdown command contribution is either an executable action (Pro) or a locked preview (OSS); shared root code does not name `MarkdownExportService` or inject arbitrary command views. Pro lifecycle and domain composition remain Pro-source responsibilities.
- **Pro per-window state**: the shared main-window root owns one opaque edition state for that window's lifetime. The Pro adapter supplies concrete Spectrum session and Timeline presentation owners; route changes reuse them, while inactive Timeline tasks stop. AppKit window activation selects the menu-bar routing target, and `NSWindow.willCloseNotification` triggers idempotent teardown that stops recording and restores the scan interval. Registry references are weak, so distinct windows do not share or prolong state.
- **Shared route-resource leases**: each main window registers its current route under a stable scene ID. A process-scoped coordinator aggregates those leases for the process-shared Spectrum charts and BLE scanner; resources start on the first matching route and stop only after the final lease is released by a route change or real window close. BLE starts return generation-bound sessions whose stop operation cannot terminate a newer session, and stopping always finishes that session's event stream.
- **Pro Event Journal boundary**: the Journal consumes each exact immutable runtime observation and privately owns event derivation, optimistic recent publication, hydration validation, generation-safe queries, clear coalescing, and persistence ordering. Derived events enter a bounded FIFO persistence delivery with capacity 32 by default; `consume` returns after admission, while one independent worker persists admitted batches in FIFO order. Saturation waits for capacity and records depth, saturation count, blocked admissions, and backpressure duration rather than replacing events. Query, clear, and explicit drain operations enqueue persistence barriers; query falls back to deterministically sorted optimistic recent state without reading SQLite when a deferred failure reaches its barrier. Cancelling a Timeline reload removes only its queued, not-yet-running read barrier; admitted appends and deletes remain non-cancellable and ordered. Diagnostics expose persistence failures, pending deferred failure state, and live unpersisted accounting. Failed appends, cancelled blocked append admissions, and queued/blocked appends discarded by shutdown add to an O(1) permanent scalar without retaining request IDs. Only the shutdown-time in-flight append retains its ID while pending; the single worker bounds this map to one entry. Late success removes that pending count, while failure or cancellation transfers it to permanent without changing the total. Actor serialization and exclusive removal from blocked, queued, or in-flight ownership make those terminal paths mutually exclusive. Aggregate addition saturates at `UInt64.max`. The termination result retains an immutable cutoff snapshot even if live accounting later converges. Cancellation removes blocked admission, and linearized shared shutdown rejects new work and releases queued/blocked callers. Normal callers join the worker; process termination bounds that join and may exit with a non-cooperative store call still suspended. `WiFiObservationEventLogStoring` remains the persistence seam, with SQLite as the production adapter.
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
