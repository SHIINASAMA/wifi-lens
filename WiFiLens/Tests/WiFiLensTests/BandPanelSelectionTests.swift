import Testing
@testable import WiFi_Lens

@Suite struct SpectrumPanelViewTypeTests {
    @Test func rawValues() {
        #expect(SpectrumPanelViewType.band24.rawValue == "24")
        #expect(SpectrumPanelViewType.band5.rawValue == "5")
        #expect(SpectrumPanelViewType.band6.rawValue == "6")
        #expect(SpectrumPanelViewType.trend.rawValue == "trend")
        #expect(SpectrumPanelViewType.table.rawValue == "table")
        #expect(SpectrumPanelViewType.heatmap.rawValue == "heatmap")
    }

    @Test func displayNames() {
        for selection in SpectrumPanelViewType.allCases {
            #expect(!selection.displayName.isEmpty)
            #expect(selection.displayName != selection.rawValue)
        }
    }

    @Test func allCasesCount() {
        #expect(SpectrumPanelViewType.allCases.count == 6)
    }

    @Test func icons() {
        #expect(SpectrumPanelViewType.band24.icon == "wave.3.left")
        #expect(SpectrumPanelViewType.band5.icon == "wave.3.right")
        #expect(SpectrumPanelViewType.band6.icon == "wave.3.right.circle")
        #expect(SpectrumPanelViewType.trend.icon == "chart.line.uptrend.xyaxis")
        #expect(SpectrumPanelViewType.table.icon == "tablecells")
        #expect(SpectrumPanelViewType.heatmap.icon == "square.grid.3x3.fill")
    }
}
