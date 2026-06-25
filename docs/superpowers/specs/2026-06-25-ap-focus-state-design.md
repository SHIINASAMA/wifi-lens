# AP Focus State Design Spec

## Overview

实现两条并行数据路径：筛选路径和可见性路径，最终合并为用户锁定的结果。

## 数据流

```
数据 Pipeline → 原始 APs
                ↓
        ┌───────┴───────┐
        ↓               ↓
    用户自定义筛选      表
        ↓               ↓
    数量筛选          可见性
        ↓               ↓
    筛选结果      可见性筛选的 APs
        ↓               ↓
        └───────┬───────┘
                ↓
            用户锁定
                ↓
    可见性筛选的 APs + 用户锁定的 APs
```

## 三条规则

1. **可见性**：UI 状态，由表格控制，决定 AP 是否在图表中显示
2. **锁定**：UI 状态，由表格控制，锁定后的 AP 无法被筛选影响
3. **筛选**：独立路径，筛选结果会更新 UI 可见性属性（除了已锁定的 APs）

## 数据模型变化

### ChartSeriesRenderState

**File:** `WiFiLens/Sources/WiFiLens/Spectrum/ChartSeriesData.swift`

```swift
struct ChartSeriesRenderState {
    var displayRSSI: Double = 0.0
    var color: Color = .gray
    var isFilteredOut: Bool = false
    var isVisible: Bool = true      // 可见性：表格控制
    var isLocked: Bool = false      // 锁定：绕过筛选
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

## 核心逻辑

### 筛选路径

**File:** `WiFiLens/Sources/WiFiLens/Spectrum/BandChartViewModel.swift`

修改 `makeDisplayedSeriesData()` 让锁定的 AP 绕过筛选：

```swift
private func makeDisplayedSeriesData(from source: [ChartSeriesData], hiddenBands: Set<String>, hideHiddenSSIDs: Bool) -> [ChartSeriesData] {
    let needle = currentFilterQuery.trimmingCharacters(in: .whitespaces).lowercased()
    let bandHidden = hiddenBands.contains(band.id)
    return source.map { series in
        var series = series
        let sourceFilteredOut = series.isFilteredOut
        
        // 锁定的 AP 绕过筛选（筛选结果无法影响锁定的 AP）
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

### 可见性路径

**File:** `WiFiLens/Sources/WiFiLens/Spectrum/BandChartViewModel.swift`

修改 `visibleSeriesData()` 合并两条路径：

```swift
func visibleSeriesData() -> [ChartSeriesData] {
    let filtered = displayedSeriesData.filter { $0.isVisible && !$0.isFilteredOut }
    let sorted = filtered.sorted { $0.rssi > $1.rssi }
    
    // 合并两条路径：
    // 1. 锁定的 AP 始终显示（筛选结果无法影响）
    // 2. 可见性筛选的 APs（isVisible = true 且未被筛选排除）
    
    var result: [ChartSeriesData] = []
    var autoCount = 0
    
    for series in sorted {
        if series.isLocked {
            // 锁定的 AP 始终显示
            result.append(series)
        } else if series.isVisible {
            // 可见性筛选的 APs
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

### 用户锁定

**File:** `WiFiLens/Sources/WiFiLens/Spectrum/BandChartViewModel.swift`

```swift
func toggleLock(for seriesID: String) {
    guard let series = allSeriesData.first(where: { $0.id == seriesID }) else { return }
    series.isLocked.toggle()
    refreshRenderedState()
}
```

## 表格显示

**File:** `WiFiLens/Sources/WiFiLens/Spectrum/ContentView.swift`

表格显示所有 AP：
- **行点击** → 显示趋势图（现有行为，不变）
- **行复选框** → 切换锁定状态（新行为）

```swift
// 在 NativeTableView 中添加复选框列
// 复选框状态绑定到 isLocked
// 点击复选框调用 toggleLock()
```

## 工具栏指示器

**File:** `WiFiLens/Sources/WiFiLens/Spectrum/SpectrumPanelView.swift`

```swift
private var displayedCount: Int {
    localFilteredSeries.filter { $0.isVisible && !$0.isFilteredOut }.count
}

private var lockedCount: Int {
    localFilteredSeries.filter { $0.isLocked }.count
}
```

## 变更内容

- `ChartSeriesRenderState` - 添加 `isLocked` 属性
- `ChartSeriesData` - 添加 `isLocked` 计算属性
- `BandChartViewModel.makeDisplayedSeriesData()` - 锁定的 AP 绕过筛选
- `BandChartViewModel.visibleSeriesData()` - 合并两条路径
- `BandChartViewModel.toggleLock()` - 新方法
- `NativeTableView` - 复选框控制锁定状态
- `SpectrumPanelView` - 更新工具栏指示器

## 不变内容

- `BandChartView` - 不变
- `TrendChartView` - 不变
- Filter engine - 不变
- Data pipeline - 不变

## 测试

- 单元测试：锁定的 AP 绕过筛选
- 单元测试：锁定的 AP 始终显示
- 单元测试：可见性筛选的 APs 正确显示
- 单元测试：toggleLock() 正确切换状态
