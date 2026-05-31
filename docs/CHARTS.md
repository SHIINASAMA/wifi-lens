# Chart Engine

Universal, data-driven chart rendering engine introduced in the Spectrum refactoring. All chart views now build `[ChartSeries]` arrays and delegate rendering to the shared `Chart` component instead of drawing their own `Canvas`.

## Architecture

```
Caller builds [ChartSeries] + ChartAxisConfig + ChartStyle
    → Chart<Overlay> (SwiftUI View)
        → GeometryReader → computeGeo → ChartGeometry
        → Canvas: Y-grid, X-ticks, axes, clip, draw series
        → overlay(geo, series)
```

All domain-specific rendering (tooltips, data labels, heatmaps, transition markers) is injected via an overlay `ViewBuilder` that receives the computed `ChartGeometry`.

## Core Types

| Type | File | Purpose |
|------|------|---------|
| `ChartPoint` | `ChartTypes.swift` | Single (x, y) in data-space coordinates |
| `ChartSeries` | `ChartTypes.swift` | Array of points + rendering style + interpolation mode |
| `ChartSeriesStyle` | `ChartTypes.swift` | Color, lineWidth, areaOpacity, pointRadius, strokeOpacity, baseline |
| `ChartAxisConfig` | `ChartTypes.swift` | Axis bounds, grid step, tick labels/formatters, colors, fonts |
| `ChartStyle` | `ChartTypes.swift` | Layout margins → `chartRect(size:)` |
| `ChartInteraction` | `ChartTypes.swift` | Hover/tap/zoom callbacks + gesture toggles |
| `ChartGeometry` | `ChartGeometry.swift` | Maps data-space ↔ pixel-space via `dataToPoint`/`pointToData` |
| `SplineInterpolation` | `SplineInterpolation.swift` | Catmull-Rom and clamped cubic spline path generators |
| `ChartTimeFormatting` | `ChartTimeFormatting.swift` | `chartDurationLabel()` — seconds → "30s"/"2m"/"1h" |

### Interpolation Modes (`ChartSeries.Interpolation`)

| Mode | Behavior |
|------|----------|
| `.linear` | Straight polyline between points |
| `.catmullRom` | Smooth curve through all points |
| `.clampedCubic` | Monotonic cubic spline (no overshoot) |
| `.step` | Right-angle steps (horizontal then vertical) |
| `.gaussian(sigma:baseline:)` | Gaussian bell curve between two points — used for WiFi channel occupancy |

## Chart View (`ChartView.swift`)

Generic `Chart<Overlay: View>` component. Three initializers:

1. **No overlay**: `Chart(series:axis:style:interaction:)` — bare chart, overlay is `EmptyView`
2. **With overlay**: `Chart(series:axis:style:interaction:overlay:)` — overlay closure receives `(ChartGeometry, [ChartSeries])`

### Rendering Pipeline

1. `computeGeo(size:)` — calculates `ChartGeometry` from data range + axis config
2. `computeYRange()` — snaps `yMin`/`yMax` to multiples of `yStep`; guards against zero step
3. `computeXMin()`/`computeXMax()` — uses axis config or auto-computes from data
4. `drawContent(context:geo:)`:
   - Y-axis grid lines at step intervals + tick labels (uses `yTickLabel` formatter)
   - X-axis tick labels with overlap prevention (`minXTickSpacing`)
   - Axis lines (X at bottom, Y at left)
   - Optional clip rect
   - Series drawing by interpolation mode

### Hit Testing & Gestures

- `hitTest(location:geo:)` — finds nearest data point within 20px radius across all series
- `zoomGesture(geo:)` — `DragGesture` mapping pixel range → data-space `(lo, hi)` → `onZoom` callback
- `.onContinuousHover` triggers `onHover` callback with data-space point
- `.simultaneousGesture` allows parent views to add their own gestures without conflict

### Key Design Decisions

- No empty `.onTapGesture` — the Chart does not consume taps, allowing parent views to handle tap-to-select
- `ChartGeometry.scaleX`/`scaleY` denominators clamped to `max(1e-6, ...)` to prevent division by zero
- Y-grid loop uses index-based iteration (`yMin + i * step`) instead of `Int(step)` stride to avoid truncation
- `ChartStyle.chartRect` clamps width/height to `max(0, ...)` for safety in narrow containers

## Detail + Overview Chart (`DetailOverviewChart.swift`)

A linked pair: a detail chart showing a zoomed window, and an overview strip with a `RangeSelector` for panning/resizing.

```
DetailOverviewChart<DetailOverlay, OverviewOverlay>
    ├── detailChart: Chart (series filtered to windowStart...windowEnd)
    └── overviewStrip
        ├── RangeSelector (draggable window)
        │   └── overview: Chart (full series, compressed)
        └── overviewTimeAxis (domain labels)
```

- Domain-agnostic — works with time, frequency, channel numbers, or any continuous `Double` domain
- `domainLabel` closure formats domain values into axis labels
- `followMax: true` auto-scrolls the window to stay at the trailing edge (for live data)
- `minWindowSpan` / `defaultWindowSpan` control the zoom window
- Convenience init (no overlays) sets `overviewAxis` with all decorations disabled for a clean navigational thumbnail

## Range Selector (`RangeSelectorView.swift`)

Horizontal overview strip with a draggable, resizable selection window.

- Three drag modes: `resizeLeft`, `panWindow`, `resizeRight`
- `InvertedRoundedSelectionShape` masks the area outside the selection
- `SelectorHandle` views on left/right edges with hover cursor changes
- Edge badges show the current window bounds formatted via `edgeLabel`
- `followMax` auto-snaps the window to the domain's max edge (e.g., live data)
- Snap tolerance: when dragged within 8px of the max edge, snaps to follow mode

## WiFi Spectrum Integration

### ChartSeriesData Split (`ChartSeriesData.swift`)

The original flat `ChartSeriesData` was split into immutable domain data and mutable render state:

- **`ChartSeriesDomainData`** — immutable per-network identity: `id`, `ssid`, `bssid`, `channel`, `left`, `apex`, `right`, `rssi`, `phyMode`, `channelWidth`, protocol support flags, security info
- **`ChartSeriesRenderState`** — mutable visual state: `displayRSSI` (animated), `color`, `isFilteredOut`, `isVisible`, `qualityScore`, `trendArrow`, `trendDelta`
- **`ChartSeriesData`** — wraps both, exposing computed passthrough properties for backward compatibility

### BandChartRenderModel (`BandChartRenderModel.swift`)

Snapshot struct decoupling `BandChartViewModel` from `WiFiBandChart`. Contains pre-computed values: `xDataMin`, `xDataMax`, `yMin`, `visibleSeriesData`, `displayedSeriesData`, `strongestRSSI`, `isEmpty`, `zoomMin`, `zoomMax`, `isExpanded`, `axisTickStartChannel`.

Created fresh on each render pass via `BandChartViewModel.renderModel` — the view never holds a reference to the ViewModel.

### WiFiBandChart (`BandChartView.swift`)

Thin wrapper around `Chart` for WiFi spectrum visualization:
- Builds `[ChartSeries]` with `.gaussian` interpolation from `visibleSeriesData`
- Heatmap overlay: color-coded channel occupancy bars below the chart
- Data label overlay: SSID + trend arrows positioned above curves
- Tooltip overlay: SSID, RSSI, channel, BSSID on hover
- Tap-to-select, drag-to-zoom, expand to fullscreen
- `typealias BandChartView = WiFiBandChart` for backward compatibility

### BandChartLayout (`BandChartLayout.swift`)

Static layout utilities extracted from the old `DataLabelOverlay`:
- `axisTickValues()` — channel-number tick placement
- `heatmapBins()` — group series by apex channel, compute max bar count
- `placeLabels()` — collision-aware label placement with occupancy tracking
- `nearestSeries()` — hit-testing for hover/selection within curves

### SnapshotToChartAdapter (`SnapshotToChartAdapter.swift`)

Converts recorded `NetworkSnapshot` data into `ChartSeriesData` for history playback:
- `snapshotsNearest(to:in:)` — finds closest snapshot per BSSID at a given timestamp
- `toSeriesData(snapshotsByBSSID:band:colorHasher:trends:)` — mirrors `ChannelSpanCalculator.toSeriesData()` but operates on snapshots
- Supports optional `trends` parameter for trend arrows in history mode

## Ported Chart Views

All chart views now use the universal `Chart` component instead of custom `Canvas` drawing:

| View | Migration |
|------|-----------|
| `WiFiBandChart` | Gaussian curves via `Chart` + heatmap/label overlays |
| `TrendChartView` | Linear line + area fill + dot markers via `Chart` |
| `ThroughputChartView` | Clamped-cubic area fills (upload/download) via `Chart` |
| `BLETrendChartView` | Dual linear line series (smooth + raw) via `Chart` |
| `DebugChartView` | Same `WiFiBandChart` with debug-injected data |
| `DebugRoamingChartView` | Timeline → `DetailOverviewChart` + `RangeSelector` |

## Removed Features

- **Freeze/Pause**: The `isFrozen`/`frozenSnapshot`/`toggleFreeze()` mechanism and `freezeAllBands` notification were removed. The freeze UI (pause button, Cmd-. menu item) was also deleted.
- **FilterPopoverView**: Deleted. Filtering is now done via the global filter query in `ScannerViewModel`.

## Caller Quick Reference

```swift
// Minimal: line chart with auto-computed axes
Chart(series: [ChartSeries(id: "data", points: points, style: .line(color: .blue))])

// Full: with axis, style, overlay, and interactions
Chart(
    series: buildSeries(),
    axis: axisConfig,
    style: chartStyle
) { geo, series in
    // overlay views using geo for positioning
}
```
