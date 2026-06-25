# AP Focus State Design Spec

## Overview

Repurpose the existing visibility toggle to also control focus state. Manually checked APs always display, regardless of count limits or filters.

## Core Rule

**手动勾选的 AP 始终显示**：用户勾选复选框的 AP，无论筛选条件如何、无论数量是否超过 15，都会显示。

## Existing Behavior (Current)

- 复选框勾选 → AP 可见
- 复选框取消勾选 → AP 隐藏
- 隐藏的 AP 从图表中移除

## New Behavior

- 复选框勾选 → AP 可见且为焦点（即使超过 15 个或被筛选）
- 复选框取消勾选 → AP 隐藏
- 焦点 AP 在图表中显示，非焦点 AP 在图表中不显示

## Data Model Changes

### ChartSeriesRenderState

**File:** `WiFiLens/Sources/WiFiLens/Spectrum/ChartSeriesData.swift`

```swift
struct ChartSeriesRenderState {
    var displayRSSI: Double = 0.0
    var color: Color = .gray
    var isFilteredOut: Bool = false
    var isVisible: Bool = true  // 控制可见性和焦点状态
    var qualityScore: Int = 0
    var trendArrow: String = ""
    var trendDelta: Int = 0
}
```

**不需要新增属性**，复用现有的 `isVisible`。

## Core Logic

### visibleSeriesData()

**File:** `WiFiLens/Sources/WiFiLens/Spectrum/BandChartViewModel.swift`

```swift
func visibleSeriesData() -> [ChartSeriesData] {
    let filtered = displayedSeriesData.filter { $0.isVisible && !$0.isFilteredOut }
    let sorted = filtered.sorted { $0.rssi > $1.rssi }
    
    // 手动勾选的 AP（isVisible = true）始终显示
    // 自动选择前 15 个（排除已手动勾选的）
    var result: [ChartSeriesData] = []
    var autoCount = 0
    
    for series in sorted {
        if series.isVisible {
            // 手动勾选的 AP 始终显示
            result.append(series)
        } else if autoCount < Self.maxVisibleAPs {
            // 自动选择前 15 个
            result.append(series)
            autoCount += 1
        }
    }
    
    return result
}
```

### toggleVisibility() - 修改现有方法

**File:** `WiFiLens/Sources/WiFiLens/Spectrum/ScannerViewModel.swift`

现有方法已经可以工作，无需修改。勾选复选框会设置 `isVisible = true`，取消勾选会设置 `isVisible = false`。

## Chart Rendering

**File:** `WiFiLens/Sources/WiFiLens/Spectrum/BandChartView.swift`

```swift
private func buildSeries() -> [ChartSeries<ChartPoint>] {
    visibleSeries.map { s in
        // ... existing chart series building logic
    }
}
```

`visibleSeries` 已经是筛选后的结果，无需修改。

## Table Display

**File:** `WiFiLens/Sources/WiFiLens/Spectrum/ContentView.swift`

表格显示所有 AP。复选框控制 `isVisible` 状态：
- 勾选 → `isVisible = true`
- 取消勾选 → `isVisible = false`

## Toolbar Indicator

**File:** `WiFiLens/Sources/WiFiLens/Spectrum/SpectrumPanelView.swift`

```swift
private var displayedCount: Int {
    localFilteredSeries.filter { $0.isVisible }.count
}

private var manualCount: Int {
    localFilteredSeries.filter { $0.isVisible }.count  // 手动勾选的
}
```

## What Changes

- `BandChartViewModel.visibleSeriesData()` - 实现混合焦点逻辑
- `SpectrumPanelView.displayedCount` - 计算焦点 AP 数量

## What Stays Unchanged

- `ChartSeriesRenderState` - 不变
- `ChartSeriesData` - 不变
- `ScannerViewModel.toggleVisibility()` - 不变
- `NativeTableView` - 不变
- `BandChartView` - 不变
- `TrendChartView` - 不变
- Filter engine - 不变

## Testing

- Unit test: 手动勾选的 AP 始终显示（即使超过 15 个）
- Unit test: 自动选择前 15 个 AP
- Unit test: 筛选只影响非手动勾选的 AP
- Unit test: toggleVisibility() 正确切换状态
