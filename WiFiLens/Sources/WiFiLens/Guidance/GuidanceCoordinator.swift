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
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.kaoru.wifi-lens-pro") != nil
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
                isProAppInstalled: isProAppInstalled()
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
            dismissInvitation(id: invitation.id)
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
