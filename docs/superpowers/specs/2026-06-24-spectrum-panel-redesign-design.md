# Spectrum Panel UI Redesign Design Spec

## Overview

Redesign the spectrum chart area from 4 collapsible drawers (3 band charts + trend + table) to 3 scrollable sections: 2 reusable spectrum panels + table.

## Goals

- Two identical spectrum panels that can independently display any chart type
- Each panel has its own chart type selection and filter
- Bottom table unchanged
- No data pipeline changes

## Layout

```
┌─────────────────────────────────────────────┐
│ Panel 1 (35%)                               │
│ [Chart Type ▼] [Filter: _____________]     │
│ ┌─────────────────────────────────────────┐ │
│ │         Spectrum / Trend Chart          │ │
│ └─────────────────────────────────────────┘ │
├─────────────────────────────────────────────┤
│ Panel 2 (35%)                               │
│ [Chart Type ▼] [Filter: _____________]     │
│ ┌─────────────────────────────────────────┐ │
│ │         Spectrum / Trend Chart          │ │
│ └─────────────────────────────────────────┘ │
├─────────────────────────────────────────────┤
│ Table (30%)                                 │
│ [Hide Hidden SSIDs] [Column toggles]       │
│ ┌─────────────────────────────────────────┐ │
│ │              AP Table                   │ │
│ └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

## New Types

### BandPanelSelection

```swift
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

## New Component: SpectrumPanelView

### Interface

```swift
struct SpectrumPanelView: View {
    let viewModel: ScannerViewModel
    @Binding var chartType: BandPanelSelection
    @Binding var selectedNetworkID: String?
    
    // Filter is managed internally per panel
    @State private var filterQuery: String = ""
}
```

### Behavior

1. **Chart Type Selector**: Dropdown menu in toolbar, selects which chart to display
2. **Filter Input**: Text field in toolbar, filters APs in this panel only
3. **Chart Rendering**:
   - `.band24` / `.band5` / `.band6`: Renders `WiFiBandChart` with corresponding `BandChartViewModel`
   - `.trend`: Renders `TrendChartView` for selected network
   - `.trend` with no selected network: Shows placeholder message "Select a network to view trend"

### Filter Integration

- Use existing `APFilterQueryParser` and `APFilterService`
- Filter is local to this panel, does not affect other panel or table
- Filter query stored in `@Binding var filterQuery: String`

## ContentView Changes

### Remove

- `is2GHzCollapsed`, `is5GHzCollapsed`, `is6GHzCollapsed`, `isTrendCollapsed` state
- `visibleSections` computed property
- `sectionHeader`, `sectionContent`, `isCollapsed`, `toggleCollapse` methods
- `SpectrumSectionLayout` struct (no longer needed)

### Add

- `@State private var panel1ChartType: BandPanelSelection = .band24`
- `@State private var panel2ChartType: BandPanelSelection = .band5`

### Layout

```swift
private var dashboardContent: some View {
    GeometryReader { geometry in
        let totalH = geometry.size.height
        let panelHeight = totalH * 0.35
        let tableHeight = totalH * 0.30
        
        VStack(spacing: 0) {
            if shouldShowEmptyState {
                emptyState
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
                
                // Table section (unchanged)
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

## Data Flow

```
ScannerViewModel
├── band24: BandChartViewModel
├── band5: BandChartViewModel
├── band6: BandChartViewModel
└── globalFilterQuery (for table)

SpectrumPanelView (Panel 1)
├── chartType: .band24 / .band5 / .band6 / .trend (state)
├── filterQuery: local filter (state)
└── uses: viewModel.band24 / band5 / band6

SpectrumPanelView (Panel 2)
├── chartType: .band24 / .band5 / .band6 / .trend (state)
├── filterQuery: local filter (state)
└── uses: viewModel.band24 / band5 / band6
```

## Filter Behavior

- Each panel applies its own filter independently
- Filter uses existing `APFilterQueryParser` syntax (e.g., `band:5G AND rssi:>-60`)
- Filter does NOT affect:
  - Other panel's display
  - Bottom table
  - Global `ScannerViewModel` state

## What Stays Unchanged

- `BandChartViewModel` - no changes
- `WiFiBandChart` - no changes
- `TrendChartView` - no changes
- `NativeTableView` - no changes
- `tableFilterBar` - no changes (keeps global hide SSID toggle)
- Data pipeline - no changes

## Testing

- Unit tests for `BandPanelSelection` enum
- UI tests for panel switching chart types
- UI tests for independent filter behavior
- Verify table unaffected by panel filters
