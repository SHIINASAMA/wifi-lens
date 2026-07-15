import AppKit
import Testing
@testable import WiFi_Lens

@Suite("MenuBar Main Window Behavior")
struct MenuBarWindowBehaviorTests {
    @Test("debug console does not duplicate OSLog levels")
    func debugConsoleDoesNotDuplicateOSLogLevels() {
        #expect(DebugConsoleLogPolicy.shouldWrite(.trace))
        #expect(DebugConsoleLogPolicy.shouldWrite(.debug))
        #expect(!DebugConsoleLogPolicy.shouldWrite(.info))
        #expect(!DebugConsoleLogPolicy.shouldWrite(.error))
    }

    @Test("network diagnostics route is shared and permission independent")
    func networkDiagnosticsRouteRequirements() {
        #expect(SidebarPage.networkDiagnostics.requiresLocationAuthorization == false)
        #expect(SidebarPage.networkDiagnostics.requiresWiFi == false)
        #expect(SidebarPage.networkDiagnostics.icon == "stethoscope")
    }

    @Test("route intent preserves current page when route is nil")
    func routeIntentPreservesCurrentPage() {
        #expect(routeIntent(for: nil) == .preserveCurrentPage)
    }

    @Test("route intent navigates when route is provided")
    func routeIntentNavigatesToSettings() {
        #expect(routeIntent(for: .settings) == .navigate(.settings))
    }

    @Test("route intent navigates to timeline when route is provided")
    func routeIntentNavigatesToTimeline() {
        #expect(routeIntent(for: .timeline) == .navigate(.timeline))
    }

    @Test("timeline page remains browse-only")
    func timelinePageDoesNotRequireLiveWiFiOrLocation() {
        #expect(SidebarPage.timeline.icon == "clock.arrow.circlepath")
        #expect(!SidebarPage.timeline.requiresLocationAuthorization)
        #expect(!SidebarPage.timeline.requiresWiFi)
    }

    @Test("sidebar section titles use localized keys")
    func sidebarSectionTitlesUseLocalizedKeys() {
        #expect(SidebarSection.overview.localizationKey == "sidebar.section.overview")
        #expect(SidebarSection.tools.localizationKey == "sidebar.section.tools")
        #expect(SidebarSection.insights.localizationKey == "sidebar.section.insights")
        #expect(SidebarSection.debug.localizationKey == "sidebar.section.debug")
        #expect(SidebarSection.settings.localizationKey == "sidebar.section.settings")
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

    @Test("resolved window is focused only when reopening requires window creation")
    func resolvedWindowFocusIntentDependsOnExistingWindow() {
        #expect(resolvedWindowFocusIntent(hasExistingMainWindow: true) == .noFollowUpFocus)
        #expect(resolvedWindowFocusIntent(hasExistingMainWindow: false) == .focusResolvedWindow)
    }
}
