import Testing
@testable import WiFi_Lens

@Suite struct SpectrumPanelViewTests {
    @Test func bandPanelSelectionFromBand() {
        let selection = BandPanelSelection.band5
        #expect(selection.rawValue == "5")
        #expect(!selection.displayName.isEmpty)
        #expect(selection.displayName != selection.rawValue)
    }
    
    @Test func bandPanelSelectionTrend() {
        let selection = BandPanelSelection.trend
        #expect(selection.rawValue == "trend")
        #expect(!selection.displayName.isEmpty)
        #expect(selection.displayName != selection.rawValue)
    }
    
    @Test func bandPanelSelectionIconNames() {
        #expect(BandPanelSelection.band24.icon == "wave.3.left")
        #expect(BandPanelSelection.band5.icon == "wave.3.right")
        #expect(BandPanelSelection.band6.icon == "wave.3.right.circle")
        #expect(BandPanelSelection.trend.icon == "chart.line.uptrend.xyaxis")
    }
}
