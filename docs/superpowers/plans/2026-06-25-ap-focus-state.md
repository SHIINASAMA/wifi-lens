# AP Focus State Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 重构 AP 筛选与图形渲染逻辑，实现 visibility/visibilityLocked 模型。

**Architecture:** 表格持有完整 AP 列表和状态，筛选器只修改未锁定 AP 的 visibility，锁定保护 visibility 不被自动逻辑修改，图形渲染只读取 visibility。

**Tech Stack:** SwiftUI, existing `BandChartViewModel`, `ChartSeriesData`, `NativeTableView`

## Global Constraints

- macOS 14+, Swift 6.0, SwiftUI + AppKit interop
- Tests use Swift Testing (`@Test`, `#expect()`) with `@testable import WiFi_Lens`
- Module name is `WiFi_Lens` (with underscore)
- 不修改现有数据管线和筛选引擎

---

## File Structure

| File | Action | Purpose |
|------|--------|---------|
| `WiFiLens/Sources/WiFiLens/Spectrum/ChartSeriesData.swift` | Modify | 添加 visibilityLocked 属性 |
| `WiFiLens/Sources/WiFiLens/Spectrum/BandChartViewModel.swift` | Modify | 重构筛选和渲染逻辑 |
| `WiFiLens/Tests/WiFiLensTests/BandChartViewModelTests.swift` | Modify | 添加单元测试 |

---

### Task 1: Add visibilityLocked to Data Model

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/Spectrum/ChartSeriesData.swift`

**Interfaces:**
- Produces: `visibilityLocked` property

- [ ] **Step 1: Add to ChartSeriesRenderState**

In `ChartSeriesData.swift`, add `visibilityLocked` property to `ChartSeriesRenderState`:

```swift
struct ChartSeriesRenderState {
    var displayRSSI: Double = 0.0
    var color: Color = .gray
    var isFilteredOut: Bool = false
    var isVisible: Bool = true
    var visibilityLocked: Bool = false
    var qualityScore: Int = 0
    var trendArrow: String = ""
    var trendDelta: Int = 0
}
```

- [ ] **Step 2: Add to ChartSeriesData**

In `ChartSeriesData.swift`, add computed property:

```swift
var visibilityLocked: Bool {
    get { render.visibilityLocked }
    set { render.visibilityLocked = newValue }
}
```

Also add `visibilityLocked` parameter to all init methods.

- [ ] **Step 3: Build to verify no compilation errors**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add WiFiLens/Sources/WiFiLens/Spectrum/ChartSeriesData.swift
git commit -m "feat: add visibilityLocked property to ChartSeriesData"
```

---

### Task 2: Refactor Filter Logic

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/Spectrum/BandChartViewModel.swift`

**Interfaces:**
- Consumes: `visibilityLocked` property
- Produces: modified `makeDisplayedSeriesData()`

- [ ] **Step 1: Modify makeDisplayedSeriesData()**

Replace the `makeDisplayedSeriesData()` method with:

```swift
private func makeDisplayedSeriesData(from source: [ChartSeriesData], hiddenBands: Set<String>, hideHiddenSSIDs: Bool) -> [ChartSeriesData] {
    let needle = currentFilterQuery.trimmingCharacters(in: .whitespaces).lowercased()
    let bandHidden = hiddenBands.contains(band.id)
    
    return source.map { series in
        var series = series
        
        // 锁定保护：visibilityLocked == true 的 AP，筛选器不能修改其 visibility
        guard !series.visibilityLocked else { return series }
        
        // 计算目标可见性
        let textFilter = needle.isEmpty
            || series.ssid.lowercased().contains(needle)
            || series.bssid.lowercased().contains(needle)
        let hiddenSSIDFilter = !hideHiddenSSIDs || !series.isHiddenSSID
        let targetVisibility = !bandHidden && textFilter && hiddenSSIDFilter
        
        // 更新 visibility（只对未锁定的 AP）
        series.isVisible = targetVisibility
        
        return series
    }
}
```

- [ ] **Step 2: Build to verify no compilation errors**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add WiFiLens/Sources/WiFiLens/Spectrum/BandChartViewModel.swift
git commit -m "refactor: filter only modifies visibility for unlocked APs"
```

---

### Task 3: Refactor Chart Rendering

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/Spectrum/BandChartViewModel.swift`

**Interfaces:**
- Consumes: `visibility` property
- Produces: modified `visibleSeriesData()`

- [ ] **Step 1: Modify visibleSeriesData()**

Replace the `visibleSeriesData()` method with:

```swift
func visibleSeriesData() -> [ChartSeriesData] {
    // 只渲染 visibility == true 的 AP
    return displayedSeriesData.filter { $0.isVisible && !$0.isFilteredOut }
}
```

- [ ] **Step 2: Build to verify no compilation errors**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add WiFiLens/Sources/WiFiLens/Spectrum/BandChartViewModel.swift
git commit -m "refactor: chart only renders APs with visibility == true"
```

---

### Task 4: Add User Operations

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/Spectrum/BandChartViewModel.swift`

**Interfaces:**
- Produces: `toggleVisibility()`, `toggleVisibilityLocked()`

- [ ] **Step 1: Add toggleVisibility()**

Add new method to `BandChartViewModel`:

```swift
func toggleVisibility(for seriesID: String) {
    guard let series = allSeriesData.first(where: { $0.id == seriesID }) else { return }
    series.isVisible.toggle()
    refreshRenderedState()
}
```

- [ ] **Step 2: Add toggleVisibilityLocked()**

Add new method to `BandChartViewModel`:

```swift
func toggleVisibilityLocked(for seriesID: String) {
    guard let series = allSeriesData.first(where: { $0.id == seriesID }) else { return }
    series.visibilityLocked.toggle()
    refreshRenderedState()
}
```

- [ ] **Step 3: Build to verify no compilation errors**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add WiFiLens/Sources/WiFiLens/Spectrum/BandChartViewModel.swift
git commit -m "feat: add toggleVisibility and toggleVisibilityLocked methods"
```

---

### Task 5: Add Unit Tests

**Files:**
- Modify: `WiFiLens/Tests/WiFiLensTests/BandChartViewModelTests.swift`

**Interfaces:**
- Consumes: `visibilityLocked`, `toggleVisibility()`, `toggleVisibilityLocked()`

- [ ] **Step 1: Add test for locked AP not modified by filter**

```swift
@Test func lockedAPNotModifiedByFilter() {
    let vm = BandChartViewModel(band: .band5GHz)
    let series = ChartSeriesData(
        id: "locked",
        ssid: "Office",
        bssid: "00:11:22:33:44:55",
        channel: 36,
        left: 36,
        apex: 36.0,
        right: 40,
        rssi: -50,
        visibilityLocked: true,
        isVisible: true
    )
    vm.debugInject(series: [series])
    vm.applyFilter("Home")
    // 锁定的 AP 不应被筛选器修改 visibility
    #expect(vm.allSeriesData.first?.isVisible == true)
}
```

- [ ] **Step 2: Add test for unlocked AP modified by filter**

```swift
@Test func unlockedAPModifiedByFilter() {
    let vm = BandChartViewModel(band: .band5GHz)
    let series = ChartSeriesData(
        id: "unlocked",
        ssid: "Office",
        bssid: "00:11:22:33:44:55",
        channel: 36,
        left: 36,
        apex: 36.0,
        right: 40,
        rssi: -50,
        visibilityLocked: false,
        isVisible: true
    )
    vm.debugInject(series: [series])
    vm.applyFilter("Home")
    // 未锁定的 AP 应被筛选器修改 visibility
    #expect(vm.allSeriesData.first?.isVisible == false)
}
```

- [ ] **Step 3: Add test for toggleVisibility**

```swift
@Test func toggleVisibility() {
    let vm = BandChartViewModel(band: .band5GHz)
    let series = ChartSeriesData(
        id: "test",
        ssid: "Test",
        bssid: "00:11:22:33:44:55",
        channel: 36,
        left: 36,
        apex: 36.0,
        right: 40,
        rssi: -50,
        isVisible: true
    )
    vm.debugInject(series: [series])
    vm.toggleVisibility(for: "test")
    #expect(vm.allSeriesData.first?.isVisible == false)
    vm.toggleVisibility(for: "test")
    #expect(vm.allSeriesData.first?.isVisible == true)
}
```

- [ ] **Step 4: Add test for toggleVisibilityLocked**

```swift
@Test func toggleVisibilityLocked() {
    let vm = BandChartViewModel(band: .band5GHz)
    let series = ChartSeriesData(
        id: "test",
        ssid: "Test",
        bssid: "00:11:22:33:44:55",
        channel: 36,
        left: 36,
        apex: 36.0,
        right: 40,
        rssi: -50,
        visibilityLocked: false
    )
    vm.debugInject(series: [series])
    vm.toggleVisibilityLocked(for: "test")
    #expect(vm.allSeriesData.first?.visibilityLocked == true)
    vm.toggleVisibilityLocked(for: "test")
    #expect(vm.allSeriesData.first?.visibilityLocked == false)
}
```

- [ ] **Step 5: Run tests**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -only-testing:WiFiLensTests/BandChartViewModelTests test`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add WiFiLens/Tests/WiFiLensTests/BandChartViewModelTests.swift
git commit -m "test: add unit tests for visibility/visibilityLocked model"
```

---

### Task 6: Final Verification

- [ ] **Step 1: Full build**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED

- [ ] **Step 2: Full test suite**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -only-testing:WiFiLensTests test`
Expected: ALL TESTS PASS

- [ ] **Step 3: Manual verification checklist**

- [ ] 锁定的 AP 不被筛选器修改 visibility
- [ ] 未锁定的 AP 被筛选器修改 visibility
- [ ] 只渲染 visibility == true 的 AP
- [ ] 表格显示完整原始 APs
- [ ] toggleVisibility() 正确切换状态
- [ ] toggleVisibilityLocked() 正确切换状态

- [ ] **Step 4: Commit any final fixes**

```bash
git add -A
git commit -m "feat: complete visibility/visibilityLocked model"
```
