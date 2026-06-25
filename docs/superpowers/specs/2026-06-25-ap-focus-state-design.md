# AP Focus State Design Spec

## Overview

Replace the current AP count limit behavior (truncating to 15) with a focus state system. Instead of hiding non-focused APs, mark them with `isFocused = false` so they can be displayed in the table but hidden in the chart.

## Goals

- Mark top 15 APs by RSSI as "focused" (`isFocused = true`)
- Mark remaining APs as "non-focused" (`isFocused = false`)
- Chart only shows focused APs
- Table shows all APs (focused and non-focused)
- Clear data model for focus state

## Data Model Changes

### ChartSeriesRenderState

**File:** `WiFiLens/Sources/WiFiLens/Spectrum/ChartSeriesData.swift`

Add `isFocused` property:

```swift
struct ChartSeriesRenderState {
    var displayRSSI: Double = 0.0
    var color: Color = .gray
    var isFilteredOut: Bool = false
    var isVisible: Bool = true
    var isFocused: Bool = true  // NEW
    var qualityScore: Int = 0
    var trendArrow: String = ""
    var trendDelta: Int = 0
}
```

### ChartSeriesData

Add computed property:

```swift
var isFocused: Bool {
    get { render.isFocused }
    set { render.isFocused = newValue }
}
```

## Core Logic: visibleSeriesData()

**File:** `WiFiLens/Sources/WiFiLens/Spectrum/BandChartViewModel.swift`

Modify `visibleSeriesData()` to mark focus state instead of truncating:

```swift
func visibleSeriesData() -> [ChartSeriesData] {
    let filtered = displayedSeriesData.filter { $0.isVisible && !$0.isFilteredOut }
    let sorted = filtered.sorted { $0.rssi > $1.rssi }
    for (index, series) in sorted.enumerated() {
        series.isFocused = index < Self.maxVisibleAPs
    }
    return sorted
}
```

## Chart Rendering

**File:** `WiFiLens/Sources/WiFiLens/Spectrum/BandChartView.swift`

Modify `buildSeries()` to only include focused APs:

```swift
private func buildSeries() -> [ChartSeries<ChartPoint>] {
    visibleSeries.filter { $0.isFocused }.map { s in
        // ... existing chart series building logic
    }
}
```

## Table Display

**File:** `WiFiLens/Sources/WiFiLens/Spectrum/ContentView.swift`

Table shows all APs (no change needed). The `isFocused` property is available for future use if needed.

## Toolbar Indicator

**File:** `WiFiLens/Sources/WiFiLens/Spectrum/SpectrumPanelView.swift`

Update `displayedCount` to count focused APs:

```swift
private var displayedCount: Int {
    localFilteredSeries.filter { $0.isFocused }.count
}
```

## What Changes

- `ChartSeriesRenderState` - add `isFocused` property
- `ChartSeriesData` - add `isFocused` computed property
- `BandChartViewModel.visibleSeriesData()` - mark focus state instead of truncating
- `BandChartView.buildSeries()` - filter by `isFocused`
- `SpectrumPanelView.displayedCount` - count focused APs

## What Stays Unchanged

- `TrendChartView` - no changes
- `NativeTableView` - no changes
- Data pipeline - no changes
- Filter engine - no changes

## Testing

- Unit test: `visibleSeriesData()` marks top 15 as focused
- Unit test: `visibleSeriesData()` marks remaining as non-focused
- Unit test: chart only renders focused APs
