import Testing
@testable import WiFi_Lens

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
