import Foundation

/// Edition-provided onboarding tuning. The shared welcome view reads only
/// this configuration — it never checks bundle identifiers, target names,
/// Pro files, StoreKit, or receipts.
struct OnboardingConfiguration: Equatable, Sendable {
    var welcomeEnabled: Bool
    var showsProLink: Bool
    var proURL: URL?
    var startRoute: SidebarPage?

    static let disabled = OnboardingConfiguration(
        welcomeEnabled: false,
        showsProLink: false,
        proURL: nil,
        startRoute: nil
    )
}
