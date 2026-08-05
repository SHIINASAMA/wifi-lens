import Foundation

/// Serialization boundary for `OnboardingState`. Mirrors the guidance store:
/// the coordinator serializes access on the main actor, so the protocol needs
/// no `Sendable` requirement.
@MainActor
protocol OnboardingStateStoring {
    func load() -> OnboardingState
    func save(_ state: OnboardingState)
}

/// `UserDefaults`-backed onboarding store. Uses a versioned key so a future
/// intentional `v2` onboarding can ship without breaking `v1` semantics.
struct UserDefaultsOnboardingStateStore: OnboardingStateStoring {
    private enum Key {
        static let welcomeCompleted = "onboarding.welcome.completed.v1"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> OnboardingState {
        OnboardingState(
            hasCompletedWelcome: defaults.bool(forKey: Key.welcomeCompleted)
        )
    }

    func save(_ state: OnboardingState) {
        defaults.set(state.hasCompletedWelcome, forKey: Key.welcomeCompleted)
    }
}

/// In-memory store for tests and previews.
@MainActor
final class InMemoryOnboardingStateStore: OnboardingStateStoring {
    private var state: OnboardingState

    init(initial: OnboardingState = OnboardingState()) {
        self.state = initial
    }

    func load() -> OnboardingState {
        state
    }

    func save(_ state: OnboardingState) {
        self.state = state
    }
}
