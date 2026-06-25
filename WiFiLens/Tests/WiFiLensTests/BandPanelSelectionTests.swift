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
        for selection in BandPanelSelection.allCases {
            #expect(!selection.displayName.isEmpty)
            #expect(selection.displayName != selection.rawValue)
        }
    }
    
    @Test func allCasesCount() {
        #expect(BandPanelSelection.allCases.count == 4)
    }
}
