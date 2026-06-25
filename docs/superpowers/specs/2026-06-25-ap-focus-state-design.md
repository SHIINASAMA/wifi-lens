# AP Focus State Design Spec

## Overview

Implement a hybrid focus state system where manually selected APs always display, while automatic selection (top 15 by RSSI) provides defaults that can be overridden by filters and count limits.

## Core Rule

**手动选择的 AP 优先级最高**：用户手动点击专注的 AP，无论筛选条件如何、无论数量是否超过 15，都会显示。

## Priority Order

1. **手动选择** (最高优先级) - 用户手动点击的 AP，始终显示
2. **自动选择** - 按 RSSI 排序，前 15 个为焦点
3. **筛选** - 可以隐藏非手动选择的 AP
4. **数量限制** - 可以隐藏非手动选择的 AP

## Goals

- 用户手动选择的 AP 始终显示（最高优先级）
- 自动选择前 15 个 AP 作为默认焦点
- 筛选和数量限制只影响非手动选择的 AP
- 图表只显示焦点 AP
- 表格显示所有 AP

## Data Model Changes

### ChartSeriesRenderState

**File:** `WiFiLens/Sources/WiFiLens/Spectrum/ChartSeriesData.swift`

```swift
struct ChartSeriesRenderState {
    var displayRSSI: Double = 0.0
    var color: Color = .gray
    var isFilteredOut: Bool = false
    var isVisible: Bool = true
    var isFocused: Bool = false
    var isManuallyFocused: Bool = false  // NEW: 手动选择标记
    var qualityScore: Int = 0
    var trendArrow: String = ""
    var trendDelta: Int = 0
}
```

### ChartSeriesData

```swift
var isFocused: Bool {
    get { render.isFocused }
    set { render.isFocused = newValue }
}

var isManuallyFocused: Bool {
    get { render.isManuallyFocused }
    set { render.isManuallyFocused = newValue }
}
```

## Core Logic

### visibleSeriesData()

**File:** `WiFiLens/Sources/WiFiLens/Spectrum/BandChartViewModel.swift`

```swift
func visibleSeriesData() -> [ChartSeriesData] {
    let filtered = displayedSeriesData.filter { $0.isVisible && !$0.isFilteredOut }
    let sorted = filtered.sorted { $0.rssi > $1.rssi }
    
    // 手动选择的 AP 始终为焦点
    for series in sorted {
        if series.isManuallyFocused {
            series.isFocused = true
        }
    }
    
    // 自动选择前 15 个（排除已手动选择的）
    var autoCount = 0
    for series in sorted {
        if !series.isManuallyFocused {
            if autoCount < Self.maxVisibleAPs {
                series.isFocused = true
                autoCount += 1
            } else {
                series.isFocused = false
            }
        }
    }
    
    return sorted
}
```

### toggleFocus() - 用户手动切换焦点

**File:** `WiFiLens/Sources/WiFiLens/Spectrum/BandChartViewModel.swift`

```swift
func toggleFocus(for seriesID: String) {
    guard let series = allSeriesData.first(where: { $0.id == seriesID }) else { return }
    series.isManuallyFocused.toggle()
    series.isFocused = series.isManuallyFocused
    refreshRenderedState()
}
```

## Chart Rendering

**File:** `WiFiLens/Sources/WiFiLens/Spectrum/BandChartView.swift`

```swift
private func buildSeries() -> [ChartSeries<ChartPoint>] {
    visibleSeries.filter { $0.isFocused }.map { s in
        // ... existing chart series building logic
    }
}
```

## Table Display

**File:** `WiFiLens/Sources/WiFiLens/Spectrum/ContentView.swift`

Table shows all APs with:

- **行点击** → 显示趋势图（现有行为，不变）
- **行复选框** → 切换焦点状态（新行为）

```swift
// 在 NativeTableView 中添加复选框列
// 复选框状态绑定到 isManuallyFocused
// 点击复选框调用 toggleFocus()
```

## Toolbar Indicator

**File:** `WiFiLens/Sources/WiFiLens/Spectrum/SpectrumPanelView.swift`

```swift
private var displayedCount: Int {
    localFilteredSeries.filter { $0.isFocused }.count
}

private var manualCount: Int {
    localFilteredSeries.filter { $0.isManuallyFocused }.count
}
```

## Multi-View Coordination

**问题**：两个面板可能显示同一个频段（如都显示 5GHz），手动选择的 AP 应该在两个面板中都显示。

**解决方案**：
- `isManuallyFocused` 存储在 `ChartSeriesData` 中
- 两个面板共享同一个 `BandChartViewModel`
- 手动选择的状态在两个面板中同步

**示例**：
1. Panel A 显示 5GHz，用户手动选择 AP X
2. Panel B 切换到 5GHz
3. AP X 在 Panel B 中也显示为焦点（因为 `isManuallyFocused = true`）

## What Changes

- `ChartSeriesRenderState` - add `isFocused` and `isManuallyFocused` properties
- `ChartSeriesData` - add computed properties
- `BandChartViewModel.visibleSeriesData()` - implement hybrid focus logic
- `BandChartViewModel.toggleFocus()` - new method for manual toggle
- `BandChartView.buildSeries()` - filter by `isFocused`
- `NativeTableView` - add checkbox column for focus toggle
- `SpectrumPanelView` - update toolbar indicator

## What Stays Unchanged

- `TrendChartView` - no changes
- `NativeTableView` - no changes
- Data pipeline - no changes
- Filter engine - no changes

## Testing

- Unit test: 手动选择的 AP 始终显示（即使超过 15 个）
- Unit test: 自动选择前 15 个 AP
- Unit test: 筛选只影响非手动选择的 AP
- Unit test: toggleFocus() 正确切换状态
