# AP Count Limit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Limit displayed APs to 15 per band when count exceeds threshold, with toolbar indicator.

**Architecture:** Modify `visibleSeriesData()` in `BandChartViewModel` to sort by RSSI and truncate. Add toolbar indicator in `SpectrumPanelView`.

**Tech Stack:** SwiftUI, existing `BandChartViewModel`, `SpectrumPanelView`

## Global Constraints

- macOS 14+, Swift 6.0, SwiftUI + AppKit interop
- Tests use Swift Testing (`@Test`, `#expect()`) with `@testable import WiFi_Lens`
- Module name is `WiFi_Lens` (with underscore)
- Fixed limit of 15, not configurable

---

## File Structure

| File | Action | Purpose |
|------|--------|---------|
| `WiFiLens/Sources/WiFiLens/Spectrum/BandChartViewModel.swift` | Modify | Add maxVisibleAPs constant, modify visibleSeriesData() |
| `WiFiLens/Sources/WiFiLens/Spectrum/SpectrumPanelView.swift` | Modify | Add toolbar indicator |
| `WiFiLens/Tests/WiFiLensTests/BandChartViewModelTests.swift` | Modify | Add tests for visibleSeriesData() limit |

---

### Task 1: Add AP Count Limit to BandChartViewModel

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/Spectrum/BandChartViewModel.swift`

**Interfaces:**
- Produces: `maxVisibleAPs` constant, modified `visibleSeriesData()`

- [ ] **Step 1: Add constant**

In `BandChartViewModel.swift`, add after line 26 (after `var chartSize`):

```swift
static let maxVisibleAPs = 15
```

- [ ] **Step 2: Modify visibleSeriesData()**

Replace the `visibleSeriesData()` method (lines 97-99) with:

```swift
func visibleSeriesData() -> [ChartSeriesData] {
    let filtered = displayedSeriesData.filter { $0.isVisible && !$0.isFilteredOut }
    guard filtered.count > Self.maxVisibleAPs else { return filtered }
    return Array(filtered.sorted { $0.rssi > $1.rssi }.prefix(Self.maxVisibleAPs))
}
```

- [ ] **Step 3: Build to verify no compilation errors**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add WiFiLens/Sources/WiFiLens/Spectrum/BandChartViewModel.swift
git commit -m "feat: add AP count limit (max 15 per band)"
```

---

### Task 2: Add Toolbar Indicator in SpectrumPanelView

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/Spectrum/SpectrumPanelView.swift`

**Interfaces:**
- Consumes: `BandChartViewModel.maxVisibleAPs`

- [ ] **Step 1: Add computed properties**

In `SpectrumPanelView.swift`, add after `@State private var filterQuery` (line 8):

```swift
private var currentBandVM: BandChartViewModel {
    bandViewModel(for: chartType)
}

private var totalCount: Int {
    currentBandVM.allSeriesData.count
}

private var displayedCount: Int {
    currentBandVM.visibleSeriesData().count
}

private var hiddenCount: Int {
    totalCount - displayedCount
}
```

- [ ] **Step 2: Add indicator to toolbar**

In the `toolbar` computed property, after the filter TextField and before the clear button (around line 38):

```swift
if hiddenCount > 0 {
    Text("\(displayedCount)/\(totalCount)")
        .font(.caption)
        .foregroundColor(.secondary)
}
```

- [ ] **Step 3: Build to verify no compilation errors**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add WiFiLens/Sources/WiFiLens/Spectrum/SpectrumPanelView.swift
git commit -m "feat: add toolbar indicator for AP count limit"
```

---

### Task 3: Add Unit Tests

**Files:**
- Modify: `WiFiLens/Tests/WiFiLensTests/BandChartViewModelTests.swift`

**Interfaces:**
- Consumes: `BandChartViewModel.maxVisibleAPs`, `visibleSeriesData()`

- [ ] **Step 1: Add test for max limit**

In `BandChartViewModelTests.swift`, add:

```swift
@Test func visibleSeriesDataLimitsToMax() {
    let vm = BandChartViewModel(band: .band5GHz)
    var series: [ChartSeriesData] = []
    for i in 0..<20 {
        series.append(ChartSeriesData(
            id: "ap\(i)",
            ssid: "Network\(i)",
            bssid: "00:11:22:33:44:\(String(format: "%02x", i))",
            channel: 36,
            left: 36,
            apex: 36.0,
            right: 40,
            rssi: -50 - i
        ))
    }
    vm.debugInject(series: series)
    #expect(vm.visibleSeriesData().count == BandChartViewModel.maxVisibleAPs)
}

@Test func visibleSeriesDataReturnsAllWhenUnderLimit() {
    let vm = BandChartViewModel(band: .band5GHz)
    var series: [ChartSeriesData] = []
    for i in 0..<10 {
        series.append(ChartSeriesData(
            id: "ap\(i)",
            ssid: "Network\(i)",
            bssid: "00:11:22:33:44:\(String(format: "%02x", i))",
            channel: 36,
            left: 36,
            apex: 36.0,
            right: 40,
            rssi: -50 - i
        ))
    }
    vm.debugInject(series: series)
    #expect(vm.visibleSeriesData().count == 10)
}

@Test func visibleSeriesDataSortsByRSSI() {
    let vm = BandChartViewModel(band: .band5GHz)
    let series = [
        ChartSeriesData(id: "weak", ssid: "Weak", bssid: "00:00:00:00:00:01", channel: 36, left: 36, apex: 36.0, right: 40, rssi: -80),
        ChartSeriesData(id: "strong", ssid: "Strong", bssid: "00:00:00:00:00:02", channel: 36, left: 36, apex: 36.0, right: 40, rssi: -30),
        ChartSeriesData(id: "mid", ssid: "Mid", bssid: "00:00:00:00:00:03", channel: 36, left: 36, apex: 36.0, right: 40, rssi: -50),
    ]
    vm.debugInject(series: series)
    let result = vm.visibleSeriesData()
    #expect(result[0].id == "strong")
    #expect(result[1].id == "mid")
    #expect(result[2].id == "weak")
}
```

- [ ] **Step 2: Run tests**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -only-testing:WiFiLensTests/BandChartViewModelTests test`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add WiFiLens/Tests/WiFiLensTests/BandChartViewModelTests.swift
git commit -m "test: add tests for AP count limit"
```

---

### Task 4: Final Verification

- [ ] **Step 1: Full build**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED

- [ ] **Step 2: Full test suite**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -only-testing:WiFiLensTests test`
Expected: ALL TESTS PASS

- [ ] **Step 3: Manual verification checklist**

- [ ] When a band has > 15 APs, only 15 are shown
- [ ] Toolbar shows "15/N" indicator
- [ ] Filtering re-applies the limit
- [ ] When ≤ 15 APs, all are shown
- [ ] Indicator disappears when no APs are hidden

- [ ] **Step 4: Commit any final fixes**

```bash
git add -A
git commit -m "feat: complete AP count limit feature"
```
