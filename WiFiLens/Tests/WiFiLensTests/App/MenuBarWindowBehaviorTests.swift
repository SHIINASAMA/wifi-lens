import AppKit
import Testing
@testable import WiFi_Lens

@Suite("MenuBar Main Window Behavior")
struct MenuBarWindowBehaviorTests {
    @Test("route intent preserves current page when route is nil")
    func routeIntentPreservesCurrentPage() {
        #expect(routeIntent(for: nil) == .preserveCurrentPage)
    }

    @Test("route intent navigates when route is provided")
    func routeIntentNavigatesToSettings() {
        #expect(routeIntent(for: .settings) == .navigate(.settings))
    }

    @Test("close action switches to accessory only when menu bar is enabled")
    func closeActionDependsOnMenuBarFlag() {
        #expect(closeAction(menuBarEnabled: true) == .switchToAccessory)
        #expect(closeAction(menuBarEnabled: false) == .keepCurrentPolicy)
    }

    @Test("reopen action switches to regular only from accessory mode with menu bar enabled")
    func reopenActionDependsOnCurrentPolicy() {
        #expect(reopenAction(menuBarEnabled: true, currentPolicy: .accessory) == .switchToRegular)
        #expect(reopenAction(menuBarEnabled: true, currentPolicy: .regular) == .keepCurrentPolicy)
        #expect(reopenAction(menuBarEnabled: false, currentPolicy: .accessory) == .keepCurrentPolicy)
    }
}
