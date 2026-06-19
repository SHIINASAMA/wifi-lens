import SwiftUI
import Testing
@testable import WiFi_Lens

struct SecondaryToolbarCapsuleTests {

    @Test func capsuleSelectionUpdatesBinding() {
        var selection: SecondaryToolbarItemID = .channelsSimple
        let binding = Binding(
            get: { selection },
            set: { selection = $0 }
        )

        binding.wrappedValue = .channelsTable

        #expect(selection == .channelsTable)
    }
}
