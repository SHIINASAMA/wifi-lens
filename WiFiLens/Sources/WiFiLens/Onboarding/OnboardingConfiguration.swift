import Foundation

/// One short first-run highlight shown in the welcome sheet. Keeps the card
/// visually balanced without turning onboarding into a feature tour.
struct OnboardingHighlight: Equatable, Sendable {
    var icon: String
    var titleKey: String
}

/// Edition-provided onboarding tuning. The shared welcome view reads only
/// this configuration — it never checks bundle identifiers, target names,
/// Pro files, StoreKit, or receipts.
struct OnboardingConfiguration: Equatable, Sendable {
    var welcomeEnabled: Bool
    var showsProLink: Bool
    var proURL: URL?
    var startRoute: SidebarPage?
    var startToolbarSelection: SecondaryToolbarItemID?
    var primaryActionKey: String
    var highlights: [OnboardingHighlight]

    static let disabled = OnboardingConfiguration(
        welcomeEnabled: false,
        showsProLink: false,
        proURL: nil,
        startRoute: nil,
        startToolbarSelection: nil,
        primaryActionKey: "onboarding.welcome.start",
        highlights: []
    )
}
