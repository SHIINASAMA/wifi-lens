# Architecture

macOS Wi-Fi spectrum analyzer (SwiftUI + CoreWLAN + AppKit interop). Targets macOS 14+, Swift 6.0.

## Data Flow

```
WiFi — CoreWLAN scan → WiFiNetwork → ChannelSpanCalculator → ChartSeriesData (Gaussian curves)
                                   → BandChartViewModel (per-band state → BandChartRenderModel)
                                   → ScannerViewModel (single source of truth)
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

Chart Engine (Charts/):
  Caller builds [ChartSeries] + ChartAxisConfig + ChartStyle
      → Chart<Overlay> → GeometryReader → ChartGeometry
      → Canvas: grid, axes, clip, draw series by interpolation mode
      → overlay(geo, series)

  DetailOverviewChart wraps two Charts + RangeSelector for linked zoom/overview.
  See docs/CHARTS.md for full architecture.
  See docs/BLE.md for BLE scan architecture.
  See docs/REGULATORY.md for regulatory pipeline.
  Pro features documented in Pro/docs/ARCHITECTURE.md (separate submodule).
```

## Source Layout

| Path | Responsibility |
|------|---------------|
| `WiFiLensApp.swift` | Root `@main` App struct, Scene, menu commands, window group |
| `Scanner/` | CoreWLAN scan loop, ViewModel, network/channel models, WiFi power monitoring, CWChannel extensions |
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
| `Utilities/` | Constants, Color extensions, BuildConfig, DeviceCapabilities, GatewayPinger |
| `Pro/` | Paid features (Recording, Session, StoreKit) — see `Pro/docs/ARCHITECTURE.md` in submodule |
| `Resources/` | Localizable.xcstrings (String Catalog) |

## Key Patterns

- `ScannerViewModel` is `@Observable`, passed via `@Bindable` through the view tree
- Selection flows bidirectionally: table row → `selectedNetworkID` → chart highlight; chart curve click → `selectedNetworkID` → table row highlight
- `NativeTableView` uses `Coordinator` as `NSTableViewDelegate` + `NSTableViewDataSource`
- **Chart Engine** — All chart views build `[ChartSeries]` arrays and delegate rendering to the universal `Chart<Overlay>` component. Domain-specific overlays (tooltips, heatmaps, data labels, transition markers) are injected via a `ViewBuilder` closure. See `docs/CHARTS.md`.
- `WiFiBandChart` is decoupled from `BandChartViewModel` via `BandChartRenderModel` — a value-type snapshot created each render pass, so the view never holds a reference to the ViewModel
- **ChartSeriesData split**: `ChartSeriesDomainData` (immutable network identity) + `ChartSeriesRenderState` (mutable visual state: animated `displayRSSI`, `color`, filter/visibility flags, trend indicators). `ChartSeriesData` wraps both with computed passthrough properties
- `displayRSSI` animates toward `rssi` each tick for smooth Gaussian curve transitions
- AP roaming transitions share a single timestamp between old and new segments, eliminating gaps on the timeline
- Signal history (`SignalHistoryStore`) keeps 20 snapshots per BSSID in memory
- `ScannerViewModel.scanIntervalSeconds` supports dynamic override — external code (e.g., recording feature in Pro submodule, see `Pro/docs/ARCHITECTURE.md`) can set it to a custom value and restore the UserDefaults-configured value on stop. The `didSet` automatically cancels and restarts the scan loop with the new interval when `isScanning` is true. This prevents chart domains driven by real-time `Date()` from pulling ahead of data points (gated by scan interval).
- `StableScore` provides hysteresis for quality level boundaries (upgrade margin 2, downgrade margin 5)
- `ChannelBand(id:)` failable initializer maps String band IDs ("24"/"5"/"6") to enum cases, used by `SnapshotToChartAdapter` for history playback
- **Channel recommendation priority**: `ChannelRecommendationAvailability.from()` checks `.currentGoodEnough` and `.targetUnknown` before `.isRecommended`. When the current channel is already good enough, no switching recommendation is shown — even if other channels score higher. This prevents contradictory UI messages (status banner says "good enough" while channel cards show "★ Recommended")
- Page-internal secondary navigation is hosted in the real window toolbar principal area, while the sidebar remains the primary top-level navigator
- `AppRootView` owns the active `SecondaryToolbarDescriptor` and per-page selection state for shared business-page mode switching
- Pages that participate in the shared secondary toolbar consume root-owned mode state instead of rendering their own local segmented controls
- **Toolbar selection state**: `SecondaryToolbarSelections` is a concrete `Equatable` struct with typed per-page properties (not a `[SidebarPage: ID]` dictionary). Each page's `SecondaryToolbarCapsule` binds directly to its typed property via `@ToolbarContentBuilder`. This lets SwiftUI compare old/new structs and skip `updateNSView` when nothing changed — critical because `WiFiLensApp.body` re-renders frequently due to `ScannerViewModel` observation
- **@Observable observation chain**: `BandChartViewModel` animation timer modifies `displayedSeriesData` at 60fps. If any parent view reads these properties (e.g. `allSeriesData.count`), the observation chain propagates up to `WiFiLensApp.body`, causing unnecessary re-renders of the entire view hierarchy including the toolbar. Cache frequently-changing derived values (e.g. `cachedTotalNetworks`, `cachedBandSummary`) in `ScannerViewModel` and have child views read the cached values instead

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
- **Multi-target builds**: When adding new `.swift` source files, they must be added to both the `WiFiLens` and `WiFiLensPro` targets' `PBXSourcesBuildPhase` in `project.pbxproj`. The Pro target maintains its own independent build phase — omitting it causes "cannot find type in scope" errors in the `WiFi Lens Pro` scheme.
