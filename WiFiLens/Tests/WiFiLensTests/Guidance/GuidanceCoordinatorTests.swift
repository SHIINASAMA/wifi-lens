import Foundation
import Testing
@testable import WiFi_Lens

@MainActor
final class GuidanceCoordinatorTests {
    private var store: InMemoryGuidanceStateStore!
    private var collectedEvents: [GuidanceEvent] = []
    private var coordinator: GuidanceCoordinator!
    private var calendar: Calendar { Self.makeCalendar() }

    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: 5, hour: 12))!
    }

    // MARK: - Scheduling vs consumption

    @Test func schedulingInvitationPersistsOnlyCompletionCount() {
        let coordinator = makeCoordinator(state: invitationState())

        let decision = coordinator.record(.diagnosticsCompleted)

        #expect(decision == .showProInvitation)
        #expect(coordinator.pendingInvitation != nil)
        let loaded = store.load()
        #expect(loaded.meaningfulCompletionCount == 3)
        #expect(loaded.invitationPresentationCount == 0)
        #expect(loaded.lastInvitationDate == nil)
    }

    @Test func presentationConsumesCountAndDateIdempotently() {
        let coordinator = makeCoordinator(state: invitationState())
        _ = coordinator.record(.diagnosticsCompleted)
        let invitation = coordinator.pendingInvitation!

        coordinator.invitationPresented(id: invitation.id)
        coordinator.invitationPresented(id: invitation.id)

        let loaded = store.load()
        #expect(loaded.invitationPresentationCount == 1)
        #expect(loaded.lastInvitationDate == now)
        #expect(events(named: "guidance.invitation.presented").count == 1)
    }

    // MARK: - Token gates (reachable state sequences)

    @Test func staleInvitationTokenCannotAffectNewerInvitation() {
        let coordinator = makeCoordinator(state: invitationState())
        _ = coordinator.record(.diagnosticsCompleted)
        let a = coordinator.pendingInvitation!

        coordinator.openInvitation(id: a.id)
        #expect(coordinator.pendingInvitation == nil)

        // The next eligible moment schedules B — the only real path to a new
        // pending invitation while a host may still hold a stale rendered token.
        _ = coordinator.record(.diagnosticsCompleted)
        let b = coordinator.pendingInvitation!
        #expect(b.id != a.id)

        coordinator.invitationPresented(id: a.id)
        coordinator.dismissInvitation(id: a.id)
        coordinator.disableInvitations(id: a.id)
        coordinator.openInvitation(id: a.id)
        coordinator.endInvitationPresentation(id: a.id)

        #expect(coordinator.pendingInvitation?.id == b.id)
        let loaded = store.load()
        #expect(loaded.invitationPresentationCount == 0)
        #expect(loaded.invitationDismissalCount == 0)
        #expect(loaded.invitationsDisabled == false)
        #expect(loaded.lastInvitationDate == nil)
        #expect(events(named: "guidance.invitation.view_selected").map(\.tokenID) == [a.id])

        coordinator.dismissInvitation(id: b.id)
        #expect(coordinator.pendingInvitation == nil)
        #expect(store.load().invitationDismissalCount == 1)
    }

    @Test func dismissWithStaleOrNilPendingNeverCounts() {
        let coordinator = makeCoordinator(state: invitationState())

        coordinator.dismissInvitation(id: UUID())

        #expect(store.load().invitationDismissalCount == 0)
        #expect(events(named: "guidance.invitation.dismissed").isEmpty)
    }

    // MARK: - Host lifecycle

    @Test func unpresentedInvitationCancelsWithoutTrace() {
        let coordinator = makeCoordinator(state: invitationState())
        _ = coordinator.record(.diagnosticsCompleted)
        let invitation = coordinator.pendingInvitation!

        coordinator.endInvitationPresentation(id: invitation.id)

        #expect(coordinator.pendingInvitation == nil)
        let loaded = store.load()
        #expect(loaded.invitationPresentationCount == 0)
        #expect(loaded.invitationDismissalCount == 0)
        #expect(loaded.lastInvitationDate == nil)
        #expect(events(named: "guidance.invitation.cancelled").count == 1)
    }

    @Test func presentedInvitationWithoutChoiceConsumesAsLater() {
        let coordinator = makeCoordinator(state: invitationState())
        _ = coordinator.record(.diagnosticsCompleted)
        let invitation = coordinator.pendingInvitation!
        coordinator.invitationPresented(id: invitation.id)

        coordinator.endInvitationPresentation(id: invitation.id)

        #expect(coordinator.pendingInvitation == nil)
        #expect(store.load().invitationDismissalCount == 1)
        #expect(events(named: "guidance.invitation.dismissed").count == 1)
        #expect(events(named: "guidance.invitation.cancelled").isEmpty)
    }

    // MARK: - Pending gates

    @Test func pendingInvitationBlocksNewInvitationScheduling() {
        let coordinator = makeCoordinator(state: invitationState())
        _ = coordinator.record(.diagnosticsCompleted)

        let decision = coordinator.record(.diagnosticsCompleted)

        #expect(decision == .none(.invitationAlreadyPending))
        #expect(store.load().meaningfulCompletionCount == 4)
        #expect(coordinator.pendingInvitation != nil)
    }

    @Test func pendingReviewRequestBlocksNewReviewScheduling() {
        let coordinator = makeCoordinator(configuration: reviewConfig(), state: reviewState())
        _ = coordinator.record(.analysisLoaded)

        let decision = coordinator.record(.analysisLoaded)

        #expect(decision == .none(.reviewRequestPending))
        #expect(store.load().meaningfulCompletionCount == 6)
        #expect(coordinator.pendingReviewRequest != nil)
    }

    // MARK: - Review persistence timing and token

    @Test func reviewPersistenceHappensOnlyOnInvocation() {
        let coordinator = makeCoordinator(configuration: reviewConfig(), state: reviewState())
        _ = coordinator.record(.analysisLoaded)
        let request = coordinator.pendingReviewRequest!

        var loaded = store.load()
        #expect(loaded.lastReviewRequestDate == nil)
        #expect(loaded.lastReviewRequestVersion == nil)

        coordinator.reviewRequestPresented(id: request.id)
        coordinator.reviewRequestPresented(id: request.id)

        loaded = store.load()
        #expect(loaded.lastReviewRequestDate == now)
        #expect(loaded.lastReviewRequestVersion == "2.1.0")
        #expect(events(named: "guidance.review.request_invoked").count == 1)

        let decision = coordinator.record(.analysisLoaded)
        #expect(decision == .none(.reviewAlreadyRequestedForVersion))
        #expect(coordinator.pendingReviewRequest == nil)
    }

    @Test func staleReviewTokenIsNoOp() {
        let coordinator = makeCoordinator(configuration: reviewConfig(), state: reviewState())
        _ = coordinator.record(.analysisLoaded)
        let request = coordinator.pendingReviewRequest!

        coordinator.reviewRequestPresented(id: UUID())

        #expect(coordinator.pendingReviewRequest?.id == request.id)
        let loaded = store.load()
        #expect(loaded.lastReviewRequestDate == nil)
        #expect(loaded.lastReviewRequestVersion == nil)
    }

    // MARK: - Quit before consumption

    @Test func quitBeforeConsumptionLeavesNoPersistedTrace() {
        let coordinator = makeCoordinator(state: invitationState())
        _ = coordinator.record(.diagnosticsCompleted)

        let fresh = GuidanceCoordinator(
            configuration: invitationConfig(),
            stateStore: store,
            now: { self.now },
            calendar: calendar,
            appVersion: { "2.1.0" },
            isProAppInstalled: { false },
            eventSink: { _ in }
        )

        let loaded = store.load()
        #expect(loaded.invitationPresentationCount == 0)
        #expect(loaded.lastInvitationDate == nil)

        let decision = fresh.record(.diagnosticsCompleted)
        #expect(decision == .showProInvitation)
        #expect(fresh.pendingInvitation != nil)
    }

    // MARK: - Export feedback

    @Test func recordAppActiveIsIdempotentPerLocalDay() {
        let dayStart = calendar.date(from: DateComponents(year: 2026, month: 8, day: 5, hour: 8, minute: 30))!
        let dayEnd = calendar.date(from: DateComponents(year: 2026, month: 8, day: 5, hour: 23, minute: 30))!
        var current = dayStart
        store = InMemoryGuidanceStateStore()
        collectedEvents = []
        let coordinator = GuidanceCoordinator(
            configuration: invitationConfig(),
            stateStore: store,
            now: { current },
            calendar: calendar,
            appVersion: { "2.1.0" },
            isProAppInstalled: { false },
            eventSink: { self.collectedEvents.append($0) }
        )

        coordinator.recordAppActive()
        current = dayEnd
        coordinator.recordAppActive()

        let loaded = store.load()
        #expect(loaded.activeDays == ["2026-08-05"])
        #expect(loaded.firstLaunchDate == dayStart)
    }

    @Test func recordAppActiveDayBoundaryFollowsInjectedCalendar() {
        let dayOneLate = calendar.date(from: DateComponents(year: 2026, month: 8, day: 5, hour: 23, minute: 59))!
        let dayTwoEarly = calendar.date(from: DateComponents(year: 2026, month: 8, day: 6, hour: 0, minute: 1))!
        var current = dayOneLate
        store = InMemoryGuidanceStateStore()
        collectedEvents = []
        let coordinator = GuidanceCoordinator(
            configuration: invitationConfig(),
            stateStore: store,
            now: { current },
            calendar: calendar,
            appVersion: { "2.1.0" },
            isProAppInstalled: { false },
            eventSink: { self.collectedEvents.append($0) }
        )

        coordinator.recordAppActive()
        current = dayTwoEarly
        coordinator.recordAppActive()

        #expect(store.load().activeDays == ["2026-08-05", "2026-08-06"])
    }

    @Test func handleExportSucceededPublishesFeedbackAndRecordsMoment() {
        let coordinator = makeCoordinator(state: invitationState(completionCount: 3))

        coordinator.handleExportSucceeded()

        #expect(coordinator.exportFeedback != nil)
        #expect(store.load().meaningfulCompletionCount == 4)
        #expect(coordinator.pendingInvitation != nil)
    }

    @Test func recordExportSucceededAloneNeverPublishesFeedback() {
        let coordinator = makeCoordinator(configuration: reviewConfig(), state: reviewState())

        _ = coordinator.record(.exportSucceeded)

        #expect(coordinator.exportFeedback == nil)
        #expect(store.load().meaningfulCompletionCount == 5)
    }

    @Test func dismissExportFeedbackConsumesAttachedInvitationAsLater() throws {
        let coordinator = makeCoordinator(state: invitationState())
        coordinator.handleExportSucceeded()
        let invitation = try #require(coordinator.pendingInvitation)
        coordinator.invitationPresented(id: invitation.id)

        coordinator.dismissExportFeedback()

        #expect(coordinator.exportFeedback == nil)
        #expect(coordinator.pendingInvitation == nil)
        let loaded = store.load()
        #expect(loaded.invitationPresentationCount == 1)
        #expect(loaded.invitationDismissalCount == 1)
        #expect(loaded.lastInvitationDate == now)

        // The presented-then-dismissed invitation starts the 30-day cooldown.
        let decision = coordinator.record(.diagnosticsCompleted)
        #expect(decision == .none(.invitationCooldown))
    }

    @Test func dismissExportFeedbackBeforePresentationCancelsWithoutTrace() throws {
        let coordinator = makeCoordinator(state: invitationState())
        coordinator.handleExportSucceeded()
        _ = try #require(coordinator.pendingInvitation)

        coordinator.dismissExportFeedback()

        #expect(coordinator.exportFeedback == nil)
        #expect(coordinator.pendingInvitation == nil)
        let loaded = store.load()
        #expect(loaded.invitationPresentationCount == 0)
        #expect(loaded.invitationDismissalCount == 0)
        #expect(loaded.lastInvitationDate == nil)
        #expect(events(named: "guidance.invitation.cancelled").count == 1)
        #expect(events(named: "guidance.invitation.dismissed").isEmpty)
    }

    @Test func dismissExportFeedbackWithoutInvitationClearsFeedbackOnly() {
        let coordinator = makeCoordinator(state: invitationState(completionCount: 0))
        coordinator.handleExportSucceeded()
        #expect(coordinator.exportFeedback != nil)
        #expect(coordinator.pendingInvitation == nil)

        coordinator.dismissExportFeedback()

        #expect(coordinator.exportFeedback == nil)
        #expect(store.load().invitationDismissalCount == 0)
    }

    // MARK: - Invitation actions

    @Test func openInvitationEmitsViewSelectedAndClearsWithoutCount() {
        let coordinator = makeCoordinator(state: invitationState())
        _ = coordinator.record(.diagnosticsCompleted)
        let invitation = coordinator.pendingInvitation!

        coordinator.openInvitation(id: invitation.id)

        #expect(coordinator.pendingInvitation == nil)
        #expect(store.load().invitationDismissalCount == 0)
        #expect(events(named: "guidance.invitation.view_selected").count == 1)
    }

    @Test func disableInvitationsPersistsAndClears() {
        let coordinator = makeCoordinator(state: invitationState())
        _ = coordinator.record(.diagnosticsCompleted)
        let invitation = coordinator.pendingInvitation!

        coordinator.disableInvitations(id: invitation.id)

        #expect(coordinator.pendingInvitation == nil)
        #expect(store.load().invitationsDisabled == true)
        #expect(events(named: "guidance.invitation.disabled").count == 1)
    }

    // MARK: - Events

    @Test func eventSinkCapturesValueMomentScheduledPresentedDismissed() {
        let coordinator = makeCoordinator(state: invitationState())
        _ = coordinator.record(.diagnosticsCompleted)
        let invitation = coordinator.pendingInvitation!
        coordinator.invitationPresented(id: invitation.id)
        coordinator.dismissInvitation(id: invitation.id)

        #expect(events(named: "guidance.value_moment").count == 1)
        #expect(events(named: "guidance.invitation.scheduled").count == 1)
        #expect(events(named: "guidance.invitation.presented").count == 1)
        #expect(events(named: "guidance.invitation.dismissed").count == 1)
    }

    @Test func eventSinkEmitsNoActionWithSuppressionReason() {
        let coordinator = makeCoordinator(state: invitationState(completionCount: 0))

        _ = coordinator.record(.diagnosticsCompleted)

        let noAction = events(named: "guidance.no_action").first
        #expect(noAction?.suppressionReason == .completionThresholdNotMet)
        #expect(noAction?.moment == .diagnosticsCompleted)
    }

    @Test func roamingRecordsValueMomentWithoutCompletion() {
        let coordinator = makeCoordinator(state: invitationState())

        _ = coordinator.record(.roamingCompleted)

        #expect(store.load().meaningfulCompletionCount == 2)
        #expect(events(named: "guidance.no_action").first?.suppressionReason == .roamingPolicyNotEnabled)
        #expect(coordinator.pendingInvitation == nil)
    }

    @Test func reviewEventsOncePerToken() {
        let coordinator = makeCoordinator(configuration: reviewConfig(), state: reviewState())
        _ = coordinator.record(.analysisLoaded)
        let request = coordinator.pendingReviewRequest!
        coordinator.reviewRequestPresented(id: request.id)

        #expect(events(named: "guidance.review.scheduled").count == 1)
        #expect(events(named: "guidance.review.request_invoked").count == 1)
    }

    // MARK: - Helpers

    private func makeCoordinator(
        configuration: GuidanceConfiguration? = nil,
        state: GuidanceState = GuidanceState(),
        appVersion: String = "2.1.0"
    ) -> GuidanceCoordinator {
        store = InMemoryGuidanceStateStore(initial: state)
        collectedEvents = []
        let coordinator = GuidanceCoordinator(
            configuration: configuration ?? invitationConfig(),
            stateStore: store,
            now: { self.now },
            calendar: calendar,
            appVersion: { appVersion },
            isProAppInstalled: { false },
            eventSink: { self.collectedEvents.append($0) }
        )
        self.coordinator = coordinator
        return coordinator
    }

    private func events(named name: String) -> [GuidanceEvent] {
        collectedEvents.filter { $0.name == name }
    }

    private func invitationConfig() -> GuidanceConfiguration {
        var config = GuidanceConfiguration()
        config.invitationEnabled = true
        return config
    }

    private func reviewConfig() -> GuidanceConfiguration {
        var config = GuidanceConfiguration()
        config.reviewEnabled = true
        return config
    }

    private func invitationState(completionCount: Int = 2) -> GuidanceState {
        GuidanceState(
            activeDays: ["2026-07-01", "2026-07-02"],
            meaningfulCompletionCount: completionCount
        )
    }

    private func reviewState(completionCount: Int = 4) -> GuidanceState {
        GuidanceState(
            firstLaunchDate: daysAgo(7),
            activeDays: ["2026-07-01", "2026-07-02", "2026-07-03"],
            meaningfulCompletionCount: completionCount
        )
    }

    private func daysAgo(_ days: Int) -> Date {
        calendar.date(byAdding: .day, value: -days, to: now)!
    }

    private static func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }
}
