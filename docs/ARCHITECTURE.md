# Architecture

macOS Wi-Fi spectrum analyzer (SwiftUI + CoreWLAN + AppKit interop). Targets macOS 14+, Swift 6.0.

## Data Flow

```
CoreWLAN scan → WiFiNetwork → ChannelSpanCalculator → ChartSeriesData (Gaussian curves)
                          → BandChartViewModel (per-band state → BandChartRenderModel)
                          → ScannerViewModel (single source of truth)
                              ├── combinedTableRows → NativeTableView (AppKit NSTableView)
                              ├── channelQualities → ChannelQualityCalculator → ChannelQualityView
                              ├── bandViewModels → WiFiBandChart → Chart (universal renderer)
                              ├── networkInfo → InterfacesView
                              └── roamingSamples → RoamingTestViewModel → RoamingTestView

Chart Engine (Charts/):
  Caller builds [ChartSeries] + ChartAxisConfig + ChartStyle
      → Chart<Overlay> → GeometryReader → ChartGeometry
      → Canvas: grid, axes, clip, draw series by interpolation mode
      → overlay(geo, series)

  DetailOverviewChart wraps two Charts + RangeSelector for linked zoom/overview.
  See docs/CHARTS.md for full architecture.
```

## Source Layout

| Path | Responsibility |
|------|---------------|
| `Scanner/` | CoreWLAN scan loop, ViewModel, network/channel models |
| `Spectrum/` | WiFiBandChart, BandChartViewModel, BandChartRenderModel, BandChartLayout, ContentView (dashboard), ChartSeriesData, ChannelSpanCalculator, SignalHistoryStore, NetworkSnapshot, TrendChartView, SnapshotToChartAdapter, SSIDColorHasher |
| `Channels/` | ChannelQualityCalculator, ChannelQualityView |
| `Charts/` | Universal Chart engine: ChartView, ChartTypes, DetailOverviewChart, RangeSelectorView, ChartGeometry, SplineInterpolation, ChartTimeFormatting, ChartRendering (legacy) |
| `Interfaces/` | InterfacesView, ThroughputMonitor, ThroughputChartView, NetworkInfoService |
| `Roaming/` | RoamingTestView, RoamingTestViewModel, AP transition tracking, timeline chart with DetailOverviewChart |
| `SignalProcessing/` | RSSI signal smoothing (EMA, Kalman, Hysteresis EMA) |
| `Table/` | NativeTableView (NSViewRepresentable wrapping NSTableView) |
| `App/` | OverviewView, SidebarView, SettingsView, Logging, CrashReporter, SparkleUpdater, TitleBadge |
| `BLE/` | BLEScanner, BLEDeviceTracker, BLEViewModel, BLEScannerView, BLETrendChartView, BLEAdvertisementEvent |
| `Debug/` | DebugChartView, DebugRoamingChartView (DEV builds only) |
| `MCP/` | HTTP server exposing scan data to MCP clients |
| `Regulatory/` | RegulatoryPipeline, RegulatoryDatabase, RegulatoryFilter, RegionInferenceEngine, ChannelRecommendation |
| `Utilities/` | Constants, Color extensions, BuildConfig |
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
- `StableScore` provides hysteresis for quality level boundaries (upgrade margin 2, downgrade margin 5)
- `ChannelBand(id:)` failable initializer maps String band IDs ("24"/"5"/"6") to enum cases, used by `SnapshotToChartAdapter` for history playback

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
