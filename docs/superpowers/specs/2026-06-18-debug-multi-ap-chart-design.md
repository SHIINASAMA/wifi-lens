# Debug Multi-AP Chart Design

## Goal

Add a multi-AP debugging mode to `DebugChartView` so developers can reproduce complex Wi-Fi spectrum rendering cases without relying on live scans. The mode must let developers edit AP parameters in a table and immediately see the production `WiFiBandChart` update above it.

The first implementation stores the current debug scenario in `UserDefaults`. The data model must be `Codable` and versioned so a later JSON import/export feature can reuse the same schema without reworking the core state.

## Non-Goals

- Do not add a new sidebar destination.
- Do not create a separate chart renderer.
- Do not edit AP parameters through modal sheets or a side inspector.
- Do not implement JSON import/export in the first pass.
- Do not add this debug UI to release builds.

## Existing Context

`DebugChartView` currently injects a single synthetic AP into `BandChartViewModel.debugInject(series:)`. That path is valuable because it exercises the production spectrum chart stack:

```
Debug data
  -> ChartSeriesData
  -> BandChartViewModel.debugInject(series:)
  -> BandChartRenderModel
  -> WiFiBandChart
  -> Chart + BandChartLayout overlays
```

The new mode should keep this same path. Rendering bugs in labels, heatmap bins, hover hit testing, selection dimming, zoom, and RSSI animation should remain visible through the real production components.

## User Experience

`DebugChartView` gets a top-level mode picker:

- `Single AP`: the current oscillator-based debug chart remains available.
- `Multi AP`: a new workbench for table-driven custom scenarios.

The `Multi AP` layout is vertical:

```
[ Mode ] [ Band ] [ Preset ] [ Add AP ] [ Reset ]

+-----------------------------------------------+
|                 WiFiBandChart                 |
|     updates immediately from table edits       |
+-----------------------------------------------+

+-----------------------------------------------+
| on | ssid | ch | width | rssi | color | ...   |
| x  | AP-1 | 36 | 80    | -48  | blue  | ...   |
| x  | AP-2 | 44 | 40    | -67  | mint  | ...   |
+-----------------------------------------------+
```

The table is the primary editor. Each edit updates the in-memory scenario, persists it to `UserDefaults`, rebuilds `[ChartSeriesData]`, and calls `debugInject(series:)` so the chart above reflects the change immediately.

## Controls

### Top Bar

- Mode picker: `Single AP` / `Multi AP`
- Band picker: `2.4 GHz` / `5 GHz` / `6 GHz`
- Preset picker: fills the table with a known rendering scenario
- Add AP button: appends a default AP valid for the current band
- Reset button: restores the selected preset

Changing the band should keep rows when possible, but clamp invalid channels to a valid default for the new band.

### Multi-AP Table

Each row represents one synthetic AP:

| Column | Control | Effect |
|--------|---------|--------|
| Enabled | checkbox | Included or excluded from injected chart data |
| SSID | text field | Label and tooltip text |
| Channel | stepper or numeric text field | Primary channel passed to `ChannelSpanCalculator.channelBlock` |
| Width | picker | `20`, `40`, `80`, `160` MHz where meaningful for the band |
| RSSI | stepper or numeric text field | Curve height and strongest RSSI calculation |
| Color | color well or compact picker | Curve, label, and heatmap color |
| Hidden | checkbox | Sets `isHiddenSSID` |
| Visible | checkbox | Sets `isVisible` |
| Filtered | checkbox | Sets `isFilteredOut` |
| 11k | checkbox | Sets `supportsK` |
| 11r | checkbox | Sets `supportsR` |
| 11v | checkbox | Sets `supportsV` |
| WPA3 | checkbox | Sets `supportsWPA3` |
| Country | text field | Debug country code metadata |
| Trend | segmented control | none, up, down, stable |
| Delta | stepper | Debug trend delta shown in labels |
| Actions | icon buttons | duplicate and delete row |

The table can be implemented with SwiftUI `Table` if inline editing is practical. If SwiftUI table editing becomes too constrained, use a `ScrollView` + grid-style rows while preserving table-like alignment and stable column widths.

## Presets

Presets are not separate modes. They only populate the editable table.

Initial presets:

- Label collision: many APs with close apex channels and similar RSSI values.
- Dense 2.4 GHz: overlapping APs around channels 1, 6, and 11.
- 5 GHz wide overlap: 40/80/160 MHz APs sharing adjacent channel blocks.
- 6 GHz sparse: wide but less congested APs across the band.
- Hidden and filtered: hidden SSIDs plus invisible and filtered rows to verify selection and dimming behavior.

After loading a preset, every row remains editable and auto-saved.

## Data Model

Add debug-only models near `DebugChartView` or in a dedicated debug source file:

```swift
#if DEBUG
struct DebugScenario: Codable, Equatable {
    var version: Int
    var bandID: String
    var presetID: String?
    var aps: [DebugAPConfig]
}

struct DebugAPConfig: Codable, Identifiable, Equatable {
    var id: UUID
    var enabled: Bool
    var ssid: String
    var bssidSuffix: String
    var channel: Int
    var widthMHz: Int
    var rssi: Int
    var colorHex: String
    var hiddenSSID: Bool
    var visible: Bool
    var filtered: Bool
    var supportsK: Bool
    var supportsR: Bool
    var supportsV: Bool
    var supportsWPA3: Bool
    var country: String
    var trend: DebugTrend
    var trendDelta: Int
}
#endif
```

Use `bandID` instead of encoding `ChannelBand` directly so future JSON files remain stable even if enum internals change.

Use `colorHex` instead of encoding SwiftUI `Color`. Convert at the boundary when building `ChartSeriesRenderState`.

## Persistence

Store one current scenario in `UserDefaults` under a debug-specific key, for example:

```
debug.multiAPChart.scenario.v1
```

Persistence behavior:

- Load on `Multi AP` appear or when switching into the mode.
- If loading fails, fall back to a default preset.
- Save after every table edit.
- Keep the schema version in the stored payload.
- Avoid writing anything in release builds by keeping all code inside `#if DEBUG`.

The future JSON feature should use the same `DebugScenario` encoder and decoder. JSON import/export only adds file IO, schema validation, and user-facing error handling.

## Conversion to Chart Data

Create a small debug-only adapter:

```swift
DebugScenarioBuilder.seriesData(from scenario: DebugScenario, band: ChannelBand) -> [ChartSeriesData]
```

Rules:

- Drop rows where `enabled == false`.
- Clamp channel and RSSI values to valid debug ranges before conversion.
- Use `ChannelSpanCalculator.channelBlock(primaryChannel:widthMHz:band:spanDirection:)` to match production span behavior.
- Use stable IDs based on `DebugAPConfig.id` and band.
- Generate deterministic BSSIDs from `bssidSuffix` or the row index.
- Set `displayRSSI` equal to `rssi` when injecting new rows, then let `BandChartViewModel` preserve animated display values on subsequent injections.
- Map `trend` to the same arrow strings used by production conversion.

## Real-Time Update Flow

```
Table edit
  -> update DebugScenario @State
  -> save encoded scenario to UserDefaults
  -> build [ChartSeriesData]
  -> bandVM.debugInject(series:)
  -> BandChartRenderModel updates
  -> WiFiBandChart redraws
```

Use `onChange` or explicit binding setters to trigger the update. Prefer a single `applyScenario()` function so all edit paths share the same conversion and persistence behavior.

## Error Handling

This is a debug-only view, so errors should be visible but lightweight:

- Invalid saved payload: discard it and load the default preset.
- Empty AP list: show the normal chart empty/loading state and keep the table visible.
- Invalid numeric input: clamp to a valid value rather than presenting blocking alerts.
- All rows disabled: inject an empty series list.

## Testing

Add focused Swift Testing coverage for pure logic:

- `DebugScenario` encode/decode round trip.
- Preset generation returns valid AP rows for each target band.
- Scenario-to-series conversion computes expected left/apex/right channel spans.
- Disabled AP rows are not injected.
- Hidden, visible, filtered, protocol, country, color, and trend fields map to `ChartSeriesData`.
- UserDefaults store load failure falls back to default data.

If new test files are added, update `project.pbxproj` so they are included in the `WiFiLensTests` target sources and scheme metadata, following `AGENTS.md`.

## Implementation Notes

- Keep `Single AP` behavior unchanged except for moving it behind the mode picker.
- Keep new models and helpers inside `#if DEBUG`.
- Prefer small helper types over expanding `DebugChartView` into a large mixed view/model file.
- Do not localize debug-only controls unless the existing debug UI already does so.
- Maintain the existing production chart API boundary. The debug view should not reach into `WiFiBandChart` internals.

## Open Extension Point

JSON import/export can be added later by:

- Reusing `DebugScenario` as the file schema.
- Adding `version` migration if schema fields change.
- Adding import validation before replacing the current table.
- Adding export from the current in-memory scenario.

The first implementation should not include these controls, but the model should make them straightforward.
