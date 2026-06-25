# AP Count Limit Design Spec

## Overview

When a band has too many APs (e.g., 40), the chart becomes cluttered and hard to read. This feature adds a selective activation strategy that limits the number of displayed APs to a fixed maximum, showing only the strongest ones by RSSI.

## Goals

- Limit displayed APs to 15 per band when count exceeds threshold
- Show toolbar indicator when APs are hidden (e.g., "15/40")
- Re-apply limit after filtering (show top 15 of filtered results)
- Minimal code changes, no data pipeline modifications

## Layout

```
[Chart Type ▼] [Filter...] [15/40]
┌─────────────────────────────────────────┐
│         Spectrum Chart (15 APs)         │
└─────────────────────────────────────────┘
```

## Constants

```swift
// In BandChartViewModel or Constants
static let maxVisibleAPs = 15
```

## Core Logic: visibleSeriesData()

**File:** `WiFiLens/Sources/WiFiLens/Spectrum/BandChartViewModel.swift`

Modify `visibleSeriesData()` to sort by RSSI and truncate:

```swift
func visibleSeriesData() -> [ChartSeriesData] {
    let filtered = displayedSeriesData.filter { $0.isVisible && !$0.isFilteredOut }
    guard filtered.count > Self.maxVisibleAPs else { return filtered }
    return Array(filtered.sorted { $0.rssi > $1.rssi }.prefix(Self.maxVisibleAPs))
}
```

## Toolbar Indicator

**File:** `WiFiLens/Sources/WiFiLens/Spectrum/SpectrumPanelView.swift`

Add after the filter TextField:

```swift
if hiddenCount > 0 {
    Text("\(displayedCount)/\(totalCount)")
        .font(.caption)
        .foregroundColor(.secondary)
}
```

**Computed properties in SpectrumPanelView:**
- `totalCount`: `viewModel.bandViewModels` 中当前频段的 `allSeriesData.count`
- `displayedCount`: `visibleSeriesData().count`
- `hiddenCount`: `totalCount - displayedCount`

## Filtering Behavior

1. User enters filter query (e.g., `rssi:>-60`)
2. Filter applied → `filteredResults`
3. If `filteredResults.count > 15`, take top 15 by RSSI
4. Toolbar shows `15/N` (N = total filtered count)

## What Stays Unchanged

- `BandChartViewModel` — only `visibleSeriesData()` changes
- `WiFiBandChart` — no changes
- `TrendChartView` — no changes
- `NativeTableView` — no changes
- Data pipeline — no changes
- Filter engine (`APFilterQueryParser`) — no changes

## Testing

- Unit test: `visibleSeriesData()` returns max 15 items when > 15 exist
- Unit test: returns all items when ≤ 15 exist
- Unit test: sorting by RSSI is correct
- UI test: toolbar shows count when APs are hidden
