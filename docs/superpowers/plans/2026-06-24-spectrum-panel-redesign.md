# Spectrum Panel UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the spectrum chart area from 4 collapsible drawers to 2 reusable spectrum panels + table.

**Architecture:** Create a new `SpectrumPanelView` component that encapsulates chart type selection, filtering, and chart rendering. Each panel independently displays any chart type (2.4G/5G/6G spectrum or trend chart).

**Tech Stack:** SwiftUI, existing `BandChartViewModel`, `WiFiBandChart`, `TrendChartView`, `APFilterQueryParser`

## Global Constraints

- macOS 14+, Swift 6.0, SwiftUI + AppKit interop
- Tests use Swift Testing (`@Test`, `#expect()`) with `@testable import WiFiLens`
- No data pipeline changes - reuse existing `BandChartViewModel`
- Filter uses existing `APFilterQueryParser` syntax

---

## File Structure

| File | Action | Purpose |
|------|--------|---------|
| `WiFiLens/Sources/WiFiLens/Spectrum/BandPanelSelection.swift` | Create | Enum for chart type selection |
| `WiFiLens/Sources/WiFiLens/Spectrum/SpectrumPanelView.swift` | Create | Reusable spectrum panel component |
| `WiFiLens/Sources/WiFiLens/Spectrum/ContentView.swift` | Modify | Use new SpectrumPanelView |
| `WiFiLens/Tests/WiFiLensTests/BandPanelSelectionTests.swift` | Create | Unit tests for enum |

---

### Task 1: Create BandPanelSelection Enum

**Files:**
- Create: `WiFiLens/Sources/WiFiLens/Spectrum/BandPanelSelection.swift`
- Test: `WiFiLens/Tests/WiFiLensTests/BandPanelSelectionTests.swift`

**Interfaces:**
- Produces: `BandPanelSelection` enum with `.band24`, `.band5`, `.band6`, `.trend` cases

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import WiFiLens

@Suite struct BandPanelSelectionTests {
    @Test func rawValues() {
        #expect(BandPanelSelection.band24.rawValue == "24")
        #expect(BandPanelSelection.band5.rawValue == "5")
        #expect(BandPanelSelection.band6.rawValue == "6")
        #expect(BandPanelSelection.trend.rawValue == "trend")
    }
    
    @Test func displayNames() {
        #expect(BandPanelSelection.band24.displayName == "2.4 GHz")
        #expect(BandPanelSelection.band5.displayName == "5 GHz")
        #expect(BandPanelSelection.band6.displayName == "6 GHz")
        #expect(BandPanelSelection.trend.displayName == "Trend")
    }
    
    @Test func allCasesCount() {
        #expect(BandPanelSelection.allCases.count == 4)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -only-testing:WiFiLensTests test`
Expected: FAIL with "Cannot find 'BandPanelSelection' in scope"

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

enum BandPanelSelection: String, CaseIterable, Identifiable {
    case band24 = "24"
    case band5 = "5"
    case band6 = "6"
    case trend = "trend"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .band24: return "2.4 GHz"
        case .band5: return "5 GHz"
        case .band6: return "6 GHz"
        case .trend: return "Trend"
        }
    }
    
    var icon: String {
        switch self {
        case .band24: return "wave.3.left"
        case .band5: return "wave.3.right"
        case .band6: return "wave.3.right.circle"
        case .trend: return "chart.line.uptrend.xyaxis"
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -only-testing:WiFiLensTests/BandPanelSelectionTests test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add WiFiLens/Sources/WiFiLens/Spectrum/BandPanelSelection.swift WiFiLens/Tests/WiFiLensTests/BandPanelSelectionTests.swift
git commit -m "feat: add BandPanelSelection enum for chart type selection"
```

---

### Task 2: Create SpectrumPanelView Component

**Files:**
- Create: `WiFiLens/Sources/WiFiLens/Spectrum/SpectrumPanelView.swift`

**Interfaces:**
- Consumes: `ScannerViewModel`, `BandPanelSelection`
- Produces: `SpectrumPanelView` struct

- [ ] **Step 1: Create the SpectrumPanelView file**

```swift
import SwiftUI

struct SpectrumPanelView: View {
    let viewModel: ScannerViewModel
    @Binding var chartType: BandPanelSelection
    @Binding var selectedNetworkID: String?
    
    @State private var filterQuery: String = ""
    @State private var localSelectedNetworkID: String?
    
    var body: some View {
        VStack(spacing: 0) {
            toolbar
            chartContent
        }
        .onChange(of: filterQuery) { _, _ in
            applyFilter()
        }
    }
    
    // MARK: - Toolbar
    
    private var toolbar: some View {
        HStack(spacing: 8) {
            Picker("Chart Type", selection: $chartType) {
                ForEach(BandPanelSelection.allCases) { type in
                    HStack {
                        Image(systemName: type.icon)
                        Text(type.displayName)
                    }
                    .tag(type)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 120)
            
            TextField("Filter...", text: $filterQuery)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)
            
            if !filterQuery.isEmpty {
                Button {
                    filterQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.bar)
    }
    
    // MARK: - Chart Content
    
    @ViewBuilder
    private var chartContent: some View {
        switch chartType {
        case .band24, .band5, .band6:
            spectrumChart
        case .trend:
            trendChart
        }
    }
    
    private var spectrumChart: some View {
        let bandVM = bandViewModel(for: chartType)
        return WiFiBandChart(
            model: bandVM.renderModel,
            selectedNetworkID: $localSelectedNetworkID,
            onResetZoom: { bandVM.resetZoom() },
            onToggleExpand: { bandVM.toggleExpand() },
            onApplyZoom: { lo, hi in bandVM.applyZoom(lo: lo, hi: hi) }
        )
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        bandVM.chartSize = geometry.size
                    }
                    .onChange(of: geometry.size) { _, newSize in
                        bandVM.chartSize = newSize
                    }
            }
        }
    }
    
    private var trendChart: some View {
        Group {
            if let selID = localSelectedNetworkID,
               let snaps = selectedNetworkSnapshots(for: selID),
               let series = selectedNetworkSeries(for: selID),
               snaps.count >= 2 {
                TrendChartView(snapshots: snaps, color: series.color)
            } else {
                VStack {
                    Spacer()
                    Text("Select a network to view trend")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func bandViewModel(for selection: BandPanelSelection) -> BandChartViewModel {
        switch selection {
        case .band24: return viewModel.band24
        case .band5: return viewModel.band5
        case .band6: return viewModel.band6
        case .trend: return viewModel.band24 // fallback, won't be used
        }
    }
    
    private func selectedNetworkSnapshots(for networkID: String) -> [NetworkSnapshot]? {
        for vm in viewModel.bandViewModels {
            if let snaps = vm.snapshots(for: networkID) {
                return snaps
            }
        }
        return nil
    }
    
    private func selectedNetworkSeries(for networkID: String) -> ChartSeriesData? {
        for vm in viewModel.bandViewModels {
            if let series = vm.series(for: networkID) {
                return series
            }
        }
        return nil
    }
    
    private func applyFilter() {
        let trimmed = filterQuery.trimmingCharacters(in: .whitespaces)
        for vm in viewModel.bandViewModels {
            vm.applyFilter(trimmed.isEmpty ? nil : filterQuery)
        }
    }
}
```

- [ ] **Step 2: Build to verify no compilation errors**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add WiFiLens/Sources/WiFiLens/Spectrum/SpectrumPanelView.swift
git commit -m "feat: add SpectrumPanelView reusable component"
```

---

### Task 3: Modify ContentView to Use SpectrumPanelView

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/Spectrum/ContentView.swift`

**Interfaces:**
- Consumes: `SpectrumPanelView`, `BandPanelSelection`

- [ ] **Step 1: Add new state variables**

In `ContentView.swift`, add these state variables after line 103:

```swift
@State private var panel1ChartType: BandPanelSelection = .band24
@State private var panel2ChartType: BandPanelSelection = .band5
```

- [ ] **Step 2: Replace dashboardContent**

Replace the `dashboardContent` computed property (lines 190-218) with:

```swift
private var dashboardContent: some View {
    GeometryReader { geometry in
        let totalH = geometry.size.height
        let panelHeight = totalH * 0.35
        let tableHeight = totalH * 0.30
        
        VStack(spacing: 0) {
            if shouldShowEmptyState {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                SpectrumPanelView(
                    viewModel: viewModel,
                    chartType: $panel1ChartType,
                    selectedNetworkID: $viewModel.selectedNetworkID
                )
                .frame(height: panelHeight)
                
                Divider()
                
                SpectrumPanelView(
                    viewModel: viewModel,
                    chartType: $panel2ChartType,
                    selectedNetworkID: $viewModel.selectedNetworkID
                )
                .frame(height: panelHeight)
                
                Divider()
                
                VStack(spacing: 0) {
                    tableFilterBar
                    bottomTable
                }
                .frame(height: tableHeight)
            }
        }
    }
}
```

- [ ] **Step 3: Remove unused code**

Remove these methods and properties that are no longer needed:
- `computeHeights(sections:totalH:)` method
- `sectionHeader(_:)` method
- `sectionContent(_:height:)` method
- `isCollapsed(_:)` method
- `toggleCollapse(_:)` method
- `visibleSections` computed property
- `SpectrumSectionLayout` struct (lines 3-58)
- State variables: `is2GHzCollapsed`, `is5GHzCollapsed`, `is6GHzCollapsed`, `isTableCollapsed`, `isTrendCollapsed`

- [ ] **Step 4: Build to verify no compilation errors**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Run tests**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -only-testing:WiFiLensTests test`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add WiFiLens/Sources/WiFiLens/Spectrum/ContentView.swift
git commit -m "feat: refactor ContentView to use SpectrumPanelView"
```

---

### Task 4: Add Band Panel Selection Tests

**Files:**
- Create: `WiFiLens/Tests/WiFiLensTests/SpectrumPanelViewTests.swift`

**Interfaces:**
- Consumes: `SpectrumPanelView`, `BandPanelSelection`

- [ ] **Step 1: Create test file**

```swift
import Testing
@testable import WiFiLens

@Suite struct SpectrumPanelViewTests {
    @Test func bandPanelSelectionFromBand() {
        let selection = BandPanelSelection.band5
        #expect(selection.rawValue == "5")
        #expect(selection.displayName == "5 GHz")
    }
    
    @Test func bandPanelSelectionTrend() {
        let selection = BandPanelSelection.trend
        #expect(selection.rawValue == "trend")
        #expect(selection.displayName == "Trend")
    }
    
    @Test func bandPanelSelectionIconNames() {
        #expect(BandPanelSelection.band24.icon == "wave.3.left")
        #expect(BandPanelSelection.band5.icon == "wave.3.right")
        #expect(BandPanelSelection.band6.icon == "wave.3.right.circle")
        #expect(BandPanelSelection.trend.icon == "chart.line.uptrend.xyaxis")
    }
}
```

- [ ] **Step 2: Run tests**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -only-testing:WiFiLensTests/SpectrumPanelViewTests test`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add WiFiLens/Tests/WiFiLensTests/SpectrumPanelViewTests.swift
git commit -m "test: add SpectrumPanelView unit tests"
```

---

### Task 5: Final Verification

- [ ] **Step 1: Full build**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED

- [ ] **Step 2: Full test suite**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -only-testing:WiFiLensTests test`
Expected: ALL TESTS PASS

- [ ] **Step 3: Manual verification checklist**

- [ ] Two spectrum panels visible
- [ ] Each panel has chart type dropdown
- [ ] Each panel has filter input
- [ ] Changing chart type updates the chart
- [ ] Filter affects only the current panel
- [ ] Bottom table unchanged
- [ ] Hide Hidden SSIDs toggle still works in table

- [ ] **Step 4: Commit any final fixes**

```bash
git add -A
git commit -m "feat: complete spectrum panel UI redesign"
```
