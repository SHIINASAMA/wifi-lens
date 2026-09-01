import Testing
import SwiftUI
import AppKit
@testable import WiFi_Lens

@Suite struct SpectrumPanelViewTests {
    @Test func bandPanelSelectionFromBand() {
        let selection = SpectrumPanelViewType.band5
        #expect(selection.rawValue == "5")
        #expect(!selection.displayName.isEmpty)
        #expect(selection.displayName != selection.rawValue)
    }

    @Test func bandPanelSelectionTrend() {
        let selection = SpectrumPanelViewType.trend
        #expect(selection.rawValue == "trend")
        #expect(!selection.displayName.isEmpty)
        #expect(selection.displayName != selection.rawValue)
    }

    @Test func bandPanelSelectionIconNames() {
        #expect(SpectrumPanelViewType.band24.icon == "wave.3.left")
        #expect(SpectrumPanelViewType.band5.icon == "wave.3.right")
        #expect(SpectrumPanelViewType.band6.icon == "wave.3.right.circle")
        #expect(SpectrumPanelViewType.trend.icon == "chart.line.uptrend.xyaxis")
        #expect(SpectrumPanelViewType.table.icon == "tablecells")
    }

    @Test func spectrumPanelIDHasTertiary() {
        #expect(SpectrumPanelID.tertiary.rawValue == "tertiary")
    }

    @MainActor
    @Test func supportedViewTypesIncludeTable() {
        let vm = ScannerViewModel()
        let panel = SpectrumPanelView(
            viewModel: vm,
            panelID: .tertiary,
            isVendorColumnAvailable: true,
            chartType: .constant(.table),
            selectedNetworkID: .constant(nil),
            sortOrder: .constant([]),
            hiddenColumns: .constant([])
        )
        #expect(panel.supportedViewTypes.contains(.table))
        #expect(panel.supportedViewTypes.contains(.trend))
    }
}
