import Foundation
import Testing
@testable import WiFi_Lens

@MainActor
final class WhatsNewCoordinatorTests {
    private var store: InMemoryWhatsNewStateStore!
    private var coordinator: WhatsNewCoordinator!

    // MARK: - Version gating

    @Test func showsSheetWhenVersionDiffers() {
        let coordinator = makeCoordinator(storedVersion: "1.5.0", appVersion: "1.6.0")
        coordinator.checkForUpdate()
        #expect(coordinator.shouldShowSheet == true)
    }

    @Test func doesNotShowSheetWhenVersionMatches() {
        let coordinator = makeCoordinator(storedVersion: "1.6.0", appVersion: "1.6.0")
        coordinator.checkForUpdate()
        #expect(coordinator.shouldShowSheet == false)
    }

    @Test func showsSheetWhenNoStoredVersion() {
        let coordinator = makeCoordinator(storedVersion: nil, appVersion: "1.6.0")
        coordinator.checkForUpdate()
        #expect(coordinator.shouldShowSheet == true)
    }

    // MARK: - Mark seen

    @Test func markSeenPersistsVersion() {
        let coordinator = makeCoordinator(storedVersion: nil, appVersion: "1.6.0")
        coordinator.checkForUpdate()
        coordinator.markSeen()
        #expect(store.load().lastSeenVersion == "1.6.0")
        #expect(coordinator.shouldShowSheet == false)
    }

    @Test func dismissDoesNotPersistVersion() {
        let coordinator = makeCoordinator(storedVersion: nil, appVersion: "1.6.0")
        coordinator.checkForUpdate()
        coordinator.dismiss()
        #expect(store.load().lastSeenVersion == nil)
        #expect(coordinator.shouldShowSheet == false)
    }

    // MARK: - Onboarding integration

    @Test func markVersionSeenForOnboardingPreventsSheet() {
        let coordinator = makeCoordinator(storedVersion: nil, appVersion: "1.6.0")
        coordinator.markVersionSeenForOnboarding()
        coordinator.checkForUpdate()
        #expect(store.load().lastSeenVersion == "1.6.0")
        #expect(coordinator.shouldShowSheet == false)
    }

    // MARK: - Badge re-view

    @Test func badgeReViewOpensSheet() {
        let coordinator = makeCoordinator(storedVersion: "1.6.0", appVersion: "1.6.0")
        coordinator.showSheetFromBadge = true
        #expect(coordinator.showSheetFromBadge == true)
    }

    @Test func badgeReViewDismissResetsFlag() {
        let coordinator = makeCoordinator(storedVersion: "1.6.0", appVersion: "1.6.0")
        coordinator.showSheetFromBadge = true
        coordinator.markSeen()
        #expect(coordinator.showSheetFromBadge == false)
    }

    // MARK: - Version string

    @Test func versionStringContainsCurrentVersion() {
        let coordinator = makeCoordinator(storedVersion: nil, appVersion: "1.6.0")
        #expect(coordinator.versionString == "WiFi Lens 1.6.0")
    }

    // MARK: - Helpers

    private func makeCoordinator(
        storedVersion: String?,
        appVersion: String
    ) -> WhatsNewCoordinator {
        store = InMemoryWhatsNewStateStore(
            initial: WhatsNewState(lastSeenVersion: storedVersion)
        )
        return WhatsNewCoordinator(store: store, currentVersion: appVersion)
    }
}
