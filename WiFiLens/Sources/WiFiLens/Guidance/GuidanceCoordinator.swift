import AppKit
import Foundation
import Logging
import Observation

/// One structured guidance event. `tokenID` is a process-memory UUID used by
/// tests to assert once-per-token behavior; the production log line never
/// carries the full UUID (only a short prefix in `metadata`).
struct GuidanceEvent: Equatable, Sendable {
    let name: String                        // "guidance.value_moment", "guidance.invitation.scheduled", ...
    let moment: GuidanceValueMoment?
    let tokenID: UUID?
    let suppressionReason: GuidanceSuppressionReason?
    let metadata: [String: String]
}

/// Records value moments, schedules presentations in memory only, consumes
/// persisted counts only on real UI/system interaction via token-gated APIs,
/// publishes observable state, and emits structured events through an injected
/// sink. It never executes StoreKit and never presents UI.
@MainActor @Observable
final class GuidanceCoordinator {
    static let shared: GuidanceCoordinator = GuidanceCoordinator(
        configuration: EditionComposition.guidanceConfiguration,
        stateStore: UserDefaultsGuidanceStateStore()
    )

    struct InvitationPresentation: Equatable, Identifiable, Sendable {
        let id: UUID
        let moment: GuidanceValueMoment
        let scheduledAt: Date
    }

    struct ReviewRequestPresentation: Equatable, Identifiable, Sendable {
        let id: UUID
        let moment: GuidanceValueMoment
        let scheduledAt: Date
    }

    struct ExportFeedback: Equatable {
        let occurredAt: Date
    }

    private(set) var pendingInvitation: InvitationPresentation?
    private(set) var pendingReviewRequest: ReviewRequestPresentation?
    private(set) var exportFeedback: ExportFeedback?

    var appStoreCampaignURL: URL? { configuration.appStoreCampaignURL }

    private let configuration: GuidanceConfiguration
    private let stateStore: any GuidanceStateStoring
    private let now: () -> Date
    private let calendar: Calendar
    private let appVersion: () -> String
    private let isProAppInstalled: () -> Bool
    private let eventSink: (GuidanceEvent) -> Void

    /// Invitation tokens whose first real `onAppear` was confirmed. Memory-only,
    /// used to make `invitationPresented(id:)` and `endInvitationPresentation(id:)`
    /// idempotent per token and to distinguish "cancelled unpresented" from
    /// "dismissed as Later".
    private var confirmedPresentedInvitationIDs: Set<UUID> = []

    init(
        configuration: GuidanceConfiguration,
        stateStore: any GuidanceStateStoring,
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .current,
        appVersion: @escaping () -> String = {
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        },
        isProAppInstalled: @escaping () -> Bool = {
            #if DEBUG
            // Debug-only in-memory override for manual invitation testing;
            // Release builds compile this block away and always use real
            // detection.
            switch GuidanceDebugOverrides.proInstallationOverride {
            case .useRealDetection:
                break
            case .treatAsNotInstalled:
                return false
            case .treatAsInstalled:
                return true
            }
            #endif
            return NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.kaoru.wifi-lens-pro") != nil
        },
        eventSink: @escaping (GuidanceEvent) -> Void = { event in
            var metadata = Logging.Logger.Metadata()
            for (key, value) in event.metadata {
                metadata[key] = .string(value)
            }
            AppLogger.guidance.info("\(event.name)", metadata: metadata)
        }
    ) {
        self.configuration = configuration
        self.stateStore = stateStore
        self.now = now
        self.calendar = calendar
        self.appVersion = appVersion
        self.isProAppInstalled = isProAppInstalled
        self.eventSink = eventSink
    }

    // MARK: - Recording

    @discardableResult
    func record(_ moment: GuidanceValueMoment) -> GuidanceDecision {
        var state = stateStore.load()

        switch moment {
        case .diagnosticsCompleted, .exportSucceeded, .analysisLoaded:
            state.meaningfulCompletionCount += 1
        case .roamingCompleted:
            break
        }

        let canInvite = moment == .diagnosticsCompleted || moment == .exportSucceeded
        let canReview = moment == .diagnosticsCompleted || moment == .exportSucceeded || moment == .analysisLoaded

        let decision: GuidanceDecision
        if canInvite, pendingInvitation != nil {
            decision = .none(.invitationAlreadyPending)
        } else if canReview, pendingReviewRequest != nil {
            decision = .none(.reviewRequestPending)
        } else {
            decision = GuidancePolicy.decide(
                for: moment,
                state: state,
                config: configuration,
                now: now(),
                calendar: calendar,
                appVersion: appVersion(),
                isProAppInstalled: canInvite && configuration.invitationEnabled ? isProAppInstalled() : false
            )
        }

        switch decision {
        case .showProInvitation:
            let invitation = InvitationPresentation(id: UUID(), moment: moment, scheduledAt: now())
            pendingInvitation = invitation
            emit("guidance.invitation.scheduled", moment: moment, tokenID: invitation.id)
        case .requestReview:
            let request = ReviewRequestPresentation(id: UUID(), moment: moment, scheduledAt: now())
            pendingReviewRequest = request
            emit("guidance.review.scheduled", moment: moment, tokenID: request.id)
        case let .none(reason):
            emit("guidance.no_action", moment: moment, suppressionReason: reason)
        }

        stateStore.save(state)
        emit(
            "guidance.value_moment",
            moment: moment,
            metadata: ["completionCount": String(state.meaningfulCompletionCount)]
        )
        return decision
    }

    func recordAppActive() {
        var state = stateStore.load()
        if state.firstLaunchDate == nil {
            state.firstLaunchDate = now()
        }
        state.recordActiveDay(at: now(), calendar: calendar)
        stateStore.save(state)
    }

    // MARK: - Export feedback

    func handleExportSucceeded() {
        record(.exportSucceeded)
        exportFeedback = ExportFeedback(occurredAt: now())
    }

    func dismissExportFeedback() {
        exportFeedback = nil
        if let invitation = pendingInvitation, invitation.moment == .exportSucceeded {
            endInvitationPresentation(id: invitation.id)
        }
    }

    // MARK: - Invitation consumption (token-gated)

    func invitationPresented(id: UUID) {
        guard let invitation = pendingInvitation, invitation.id == id else { return }
        guard !confirmedPresentedInvitationIDs.contains(id) else { return }
        confirmedPresentedInvitationIDs.insert(id)
        var state = stateStore.load()
        state.invitationPresentationCount += 1
        state.lastInvitationDate = now()
        stateStore.save(state)
        emit("guidance.invitation.presented", moment: invitation.moment, tokenID: id)
    }

    func dismissInvitation(id: UUID) {
        guard let invitation = pendingInvitation, invitation.id == id else { return }
        pendingInvitation = nil
        var state = stateStore.load()
        state.invitationDismissalCount += 1
        stateStore.save(state)
        emit("guidance.invitation.dismissed", moment: invitation.moment, tokenID: id)
    }

    func disableInvitations(id: UUID) {
        guard let invitation = pendingInvitation, invitation.id == id else { return }
        pendingInvitation = nil
        var state = stateStore.load()
        state.invitationsDisabled = true
        stateStore.save(state)
        emit("guidance.invitation.disabled", moment: invitation.moment, tokenID: id)
    }

    func openInvitation(id: UUID) {
        guard let invitation = pendingInvitation, invitation.id == id else { return }
        pendingInvitation = nil
        emit("guidance.invitation.view_selected", moment: invitation.moment, tokenID: id)
    }

    /// Host-lifecycle end, called from the host view's `onDisappear` with the
    /// exact token the host rendered. An unpresented invitation is cancelled
    /// without any count or cooldown; a presented one without a user choice is
    /// consumed as Later.
    func endInvitationPresentation(id: UUID) {
        guard let invitation = pendingInvitation, invitation.id == id else { return }
        pendingInvitation = nil
        if confirmedPresentedInvitationIDs.contains(id) {
            var state = stateStore.load()
            state.invitationDismissalCount += 1
            stateStore.save(state)
            emit("guidance.invitation.dismissed", moment: invitation.moment, tokenID: id)
        } else {
            emit("guidance.invitation.cancelled", moment: invitation.moment, tokenID: id)
        }
    }

    // MARK: - Review consumption (token-gated)

    func reviewRequestPresented(id: UUID) {
        guard let request = pendingReviewRequest, request.id == id else { return }
        pendingReviewRequest = nil
        var state = stateStore.load()
        state.lastReviewRequestDate = now()
        state.lastReviewRequestVersion = appVersion()
        stateStore.save(state)
        emit("guidance.review.request_invoked", moment: request.moment, tokenID: id)
    }

    // MARK: - Events

    private func emit(
        _ name: String,
        moment: GuidanceValueMoment? = nil,
        tokenID: UUID? = nil,
        suppressionReason: GuidanceSuppressionReason? = nil,
        metadata: [String: String] = [:]
    ) {
        var metadata = metadata
        if let moment {
            metadata["moment"] = moment.rawValue
        }
        if let suppressionReason {
            metadata["reason"] = suppressionReason.rawValue
        }
        if let tokenID {
            metadata["token"] = String(tokenID.uuidString.prefix(8))
        }
        eventSink(
            GuidanceEvent(
                name: name,
                moment: moment,
                tokenID: tokenID,
                suppressionReason: suppressionReason,
                metadata: metadata
            )
        )
    }
}

#if DEBUG
extension GuidanceCoordinator {
    // MARK: - Debug-only manual test entry points
    //
    // These APIs exist only in Debug builds. They may bypass the eligibility
    // policy for manual testing, but they never bypass the token lifecycle:
    // every schedule creates a fresh UUID token, respects the pending gate,
    // and is consumed only through the existing presentation/consume/cancel
    // APIs. Nothing here is persisted, uploaded, or included in Release.

    /// Clears every persisted guidance field and every pending in-memory
    /// presentation.
    func debugResetState() {
        pendingInvitation = nil
        pendingReviewRequest = nil
        confirmedPresentedInvitationIDs.removeAll()
        exportFeedback = nil
        stateStore.save(GuidanceState())
        emit("guidance.debug.state_reset")
    }

    /// Clears review-eligibility state (persisted review fields, completion
    /// count, active days, first-launch age) and the pending review request,
    /// preserving the (inert in Pro) invitation fields.
    func debugResetReviewState() {
        pendingReviewRequest = nil
        let current = stateStore.load()
        stateStore.save(GuidanceState(
            firstLaunchDate: nil,
            activeDays: [],
            meaningfulCompletionCount: 0,
            lastInvitationDate: current.lastInvitationDate,
            invitationPresentationCount: current.invitationPresentationCount,
            invitationDismissalCount: current.invitationDismissalCount,
            invitationsDisabled: current.invitationsDisabled
        ))
        emit("guidance.debug.review_state_reset")
    }

    /// Seeds persisted state to exactly meet the invitation policy, so the
    /// next real value moment schedules an invitation through the production
    /// policy path. Refuses while an invitation is already pending.
    func debugPrepareInvitationEligibility() {
        guard pendingInvitation == nil else {
            emit("guidance.debug.refused", metadata: ["reason": "pending_invitation"])
            return
        }
        var state = GuidanceState()
        let now = now()
        state.recordActiveDay(at: now, calendar: calendar)
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now) {
            state.recordActiveDay(at: yesterday, calendar: calendar)
        }
        state.meaningfulCompletionCount = configuration.minimumInvitationCompletions
        stateStore.save(state)
        emit("guidance.debug.invitation_eligibility_prepared")
    }

    /// Seeds persisted state to exactly meet the review policy, so the next
    /// real value moment schedules a review request through the production
    /// policy path. Refuses while a review request is already pending.
    func debugPrepareReviewEligibility() {
        guard pendingReviewRequest == nil else {
            emit("guidance.debug.refused", metadata: ["reason": "pending_review"])
            return
        }
        var state = GuidanceState()
        let now = now()
        state.firstLaunchDate = calendar.date(
            byAdding: .day,
            value: -configuration.minimumReviewAgeDays,
            to: now
        )
        for daysAgo in 0..<configuration.minimumReviewActiveDays {
            if let day = calendar.date(byAdding: .day, value: -daysAgo, to: now) {
                state.recordActiveDay(at: day, calendar: calendar)
            }
        }
        state.meaningfulCompletionCount = configuration.minimumReviewCompletions
        stateStore.save(state)
        emit("guidance.debug.review_eligibility_prepared")
    }

    /// Force-schedules an invitation for a supported moment, bypassing the
    /// policy but keeping the pending gate and token lifecycle intact.
    func debugScheduleInvitation(for moment: GuidanceValueMoment) {
        guard moment == .diagnosticsCompleted || moment == .exportSucceeded else {
            emit("guidance.debug.refused", metadata: ["reason": "unsupported_moment"])
            return
        }
        guard pendingInvitation == nil else {
            emit("guidance.debug.refused", metadata: ["reason": "pending_invitation"])
            return
        }
        let invitation = InvitationPresentation(id: UUID(), moment: moment, scheduledAt: now())
        pendingInvitation = invitation
        emit("guidance.invitation.scheduled", moment: moment, tokenID: invitation.id)
        emit("guidance.debug.invitation_triggered", moment: moment, tokenID: invitation.id)
    }

    /// Force-schedules a review request, bypassing the policy but keeping the
    /// pending gate and token lifecycle intact. Consumed only by the real
    /// Pro-only bridge; never by direct StoreKit calls.
    func debugScheduleReview(for moment: GuidanceValueMoment) {
        guard moment != .roamingCompleted else {
            emit("guidance.debug.refused", metadata: ["reason": "unsupported_moment"])
            return
        }
        guard pendingReviewRequest == nil else {
            emit("guidance.debug.refused", metadata: ["reason": "pending_review"])
            return
        }
        let request = ReviewRequestPresentation(id: UUID(), moment: moment, scheduledAt: now())
        pendingReviewRequest = request
        emit("guidance.review.scheduled", moment: moment, tokenID: request.id)
        emit("guidance.debug.review_triggered", moment: moment, tokenID: request.id)
    }

    /// Publishes export feedback so the real OSS banner host renders, without
    /// running a real file save.
    func debugPublishExportFeedback() {
        exportFeedback = ExportFeedback(occurredAt: now())
        emit("guidance.debug.export_feedback_published")
    }

    /// Emits a sanitized state summary for local Debug logs. Contains no
    /// UUIDs, SSIDs, BSSIDs, IPs, DNS data, or diagnostic results.
    func debugLogState(edition: String) {
        let state = stateStore.load()
        var metadata: [String: String] = [
            "edition": edition,
            "completionCount": String(state.meaningfulCompletionCount),
            "activeDayCount": String(state.activeDays.count),
            "invitationPresentationCount": String(state.invitationPresentationCount),
            "invitationDismissalCount": String(state.invitationDismissalCount),
            "invitationsDisabled": String(state.invitationsDisabled),
            "hasReviewRequestHistory": String(state.lastReviewRequestDate != nil),
            "reviewConsumedForCurrentVersion": String(state.lastReviewRequestVersion == appVersion()),
            "hasPendingInvitation": String(pendingInvitation != nil),
            "hasPendingReviewRequest": String(pendingReviewRequest != nil),
            "proInstallationOverride": GuidanceDebugOverrides.proInstallationOverride.rawValue,
        ]
        if let lastInvitationDate = state.lastInvitationDate {
            metadata["invitationCooldownActive"] = String(
                debugWholeDaysSince(lastInvitationDate) < configuration.invitationCooldownDays
            )
        } else {
            metadata["invitationCooldownActive"] = "false"
        }
        if let lastReviewRequestDate = state.lastReviewRequestDate {
            metadata["reviewCooldownActive"] = String(
                debugWholeDaysSince(lastReviewRequestDate) < configuration.reviewCooldownDays
            )
        } else {
            metadata["reviewCooldownActive"] = "false"
        }
        emit("guidance.debug.state_summary", metadata: metadata)
    }

    private func debugWholeDaysSince(_ date: Date) -> Int {
        let start = calendar.startOfDay(for: date)
        let startNow = calendar.startOfDay(for: now())
        return calendar.dateComponents([.day], from: start, to: startNow).day ?? 0
    }
}
#endif
