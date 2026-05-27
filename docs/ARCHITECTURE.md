# Architecture

macOS Wi-Fi spectrum analyzer (SwiftUI + CoreWLAN + AppKit interop). Targets macOS 14+, Swift 6.0.

## Data Flow

```
CoreWLAN scan → WiFiNetwork → ChannelSpanCalculator → ChartSeriesData (Gaussian curves)
                          → BandChartViewModel (per-band rendering state)
                          → ScannerViewModel (single source of truth)
                              ├── combinedTableRows → NativeTableView (AppKit NSTableView)
                              ├── channelQualities → ChannelQualityCalculator → ChannelQualityView
                              ├── bandViewModels → BandChartView (SwiftUI Canvas)
                              ├── networkInfo → InterfacesView
                              └── roamingSamples → RoamingTestViewModel → RoamingTestView (Timeline Chart)
```

## Source Layout

| Path | Responsibility |
|------|---------------|
| `Scanner/` | CoreWLAN scan loop, ViewModel, network/channel models |
| `Spectrum/` | BandChartView (Canvas), TrendChartView, ContentView (dashboard), SignalHistoryStore |
| `Channels/` | ChannelQualityCalculator, ChannelQualityView |
| `Charts/` | Shared Canvas utilities: ChartGeometry, splines, grid/axis rendering, time formatting, range selector |
| `Interfaces/` | InterfacesView, ThroughputMonitor, NetworkInfoService |
| `Roaming/` | RoamingTestView, RoamingTestViewModel, AP transition tracking, timeline chart with range selector |
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
- Chart curves are Gaussian bell shapes computed in `ChartSeriesData.curvePoints`/`displayCurvePoints`; `displayRSSI` animates toward `rssi` for smooth transitions
- All Canvas charts share utilities from `Charts/`: `ChartGeometry` for coordinate mapping, `ChartRendering` for grid/axis/area-fill, `SplineInterpolation` for Catmull-Rom and clamped cubic curves, `RangeSelectorView` for timeline window selection
- AP roaming transitions share a single timestamp between old and new segments, eliminating gaps on the timeline
- Signal history (`SignalHistoryStore`) keeps 20 snapshots per BSSID in memory
- `StableScore` provides hysteresis for quality level boundaries (upgrade margin 2, downgrade margin 5)

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
- Tests cover pure-logic modules: `ChannelSpanCalculator`, `IEParser`, `SSIDColorHasher`, `ChannelQualityCalculator`, `NetworkTableRow`
- Test target uses `@testable import WiFiLens`

## Design Conventions

- Cards: `.regularMaterial` + `RoundedRectangle(cornerRadius: 12)`, 16pt padding
- Sub-cards: `.thinMaterial` + `RoundedRectangle(cornerRadius: 10)`
- Font: 9pt labels, 11-13pt body, 15pt semibold hero
- RSSI colors: green ≥ -55, yellow ≥ -70, orange ≥ -85, red below
- Quality colors: hex strings from `QualityLevel.color`
- Overlap badge on channel cards includes trailing "overlap" label for context
