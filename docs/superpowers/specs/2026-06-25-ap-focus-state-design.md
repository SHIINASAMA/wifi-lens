# AP Focus State Design Spec

## Overview

Implement a two-layer system: "锁定" (Lock) bypasses filters, "可见性" (Visibility) controls chart display.

## Business Logic

### Three Layers

1. **筛选 (Filter)** → 决定哪些 AP 在结果集中
2. **锁定 (Lock)** → 绕过筛选条件，始终出现在结果集中
3. **可见性 (Visibility)** → 决定锁定的 AP 是否在图表中显示

### Priority

- 锁定的 AP 始终在结果集中（忽略筛选）
- 可见性只影响锁定的 AP 是否在图表中显示
- 未锁定的 AP 正常受筛选影响

### Examples

| AP | 锁定 | 可见性 | 筛选结果 | 图表显示 |
|----|------|--------|----------|----------|
| X | 否 | - | 通过筛选 | 显示 |
| Y | 是 | 开 | 在结果集中 | 显示 |
| Z | 是 | 关 | 在结果集中 | 不显示 |

## Data Model Changes

### ChartSeriesRenderState

**File:** `WiFiLens/Sources/WiFiLens/Spectrum/ChartSeriesData.swift`

```swift
struct ChartSeriesRenderState {
    var displayRSSI: Double = 0.0
    var color: Color = .gray
    var isFilteredOut: Bool = false
    var isVisible: Bool = true
    var isLocked: Bool = false  // NEW: 锁定状态
    var qualityScore: Int = 0
    var trendArrow: String = ""
    var trendDelta: Int = 0
}
```

### ChartSeriesData

```swift
var isLocked: Bool {
    get { render.isLocked }
    set { render.isLocked = newValue }
}
```

## Core Logic

### Filter Behavior

**File:** `WiFiLens/Sources/WiFiLens/Spectrum/BandChartViewModel.swift`

修改 `makeDisplayedSeriesData()` 让锁定的 AP 绕过筛选：

```swift
private func makeDisplayedSeriesData(from source: [ChartSeriesData], hiddenBands: Set<String>, hideHiddenSSIDs: Bool) -> [ChartSeriesData] {
    let needle = currentFilterQuery.trimmingCharacters(in: .whitespaces).lowercased()
    let bandHidden = hiddenBands.contains(band.id)
    return source.map { series in
        var series = series
        let sourceFilteredOut = series.isFilteredOut
        
        // 锁定的 AP 绕过筛选
        if series.isLocked {
            series.isFilteredOut = false
        } else {
            let textFilter = needle.isEmpty
                || series.ssid.lowercased().contains(needle)
                || series.bssid.lowercased().contains(needle)
            let hiddenSSIDFilter = !hideHiddenSSIDs || !series.isHiddenSSID
            series.isFilteredOut = sourceFilteredOut || bandHidden || !textFilter || !hiddenSSIDFilter
        }
        
        return series
    }
}
```

### visibleSeriesData()

**File:** `WiFiLens/Sources/WiFiLens/Spectrum/BandChartViewModel.swift`

```swift
func visibleSeriesData() -> [ChartSeriesData] {
    let filtered = displayedSeriesData.filter { $0.isVisible && !$0.isFilteredOut }
    let sorted = filtered.sorted { $0.rssi > $1.rssi }
    
    // 锁定的 AP 始终显示（如果可见性开启）
    // 自动选择前 15 个（排除已锁定的）
    var result: [ChartSeriesData] = []
    var autoCount = 0
    
    for series in sorted {
        if series.isLocked && series.isVisible {
            // 锁定且可见的 AP 始终显示
            result.append(series)
        } else if !series.isLocked && autoCount < Self.maxVisibleAPs {
            // 未锁定的 AP 自动选择前 15 个
            result.append(series)
            autoCount += 1
        }
    }
    
    return result
}
```

### toggleLock() - 切换锁定状态

**File:** `WiFiLens/Sources/WiFiLens/Spectrum/BandChartViewModel.swift`

```swift
func toggleLock(for seriesID: String) {
    guard let series = allSeriesData.first(where: { $0.id == seriesID }) else { return }
    series.isLocked.toggle()
    refreshRenderedState()
}
```

## Table Display

**File:** `WiFiLens/Sources/WiFiLens/Spectrum/ContentView.swift`

表格显示所有 AP：
- **行点击** → 显示趋势图（现有行为，不变）
- **行复选框** → 切换锁定状态（新行为）

```swift
// 在 NativeTableView 中添加复选框列
// 复选框状态绑定到 isLocked
// 点击复选框调用 toggleLock()
```

## Toolbar Indicator

**File:** `WiFiLens/Sources/WiFiLens/Spectrum/SpectrumPanelView.swift`

```swift
private var displayedCount: Int {
    localFilteredSeries.filter { $0.isVisible && !$0.isFilteredOut }.count
}

private var lockedCount: Int {
    localFilteredSeries.filter { $0.isLocked }.count
}
```

## What Changes

- `ChartSeriesRenderState` - add `isLocked` property
- `ChartSeriesData` - add `isLocked` computed property
- `BandChartViewModel.makeDisplayedSeriesData()` - locked APs bypass filters
- `BandChartViewModel.visibleSeriesData()` - implement hybrid logic
- `BandChartViewModel.toggleLock()` - new method
- `NativeTableView` - checkbox controls lock state
- `SpectrumPanelView` - update toolbar indicator

## What Stays Unchanged

- `BandChartView` - no changes
- `TrendChartView` - no changes
- Filter engine - no changes
- Data pipeline - no changes

## Testing

- Unit test: 锁定的 AP 绕过筛选
- Unit test: 锁定且可见的 AP 始终显示
- Unit test: 未锁定的 AP 自动选择前 15 个
- Unit test: toggleLock() 正确切换状态
