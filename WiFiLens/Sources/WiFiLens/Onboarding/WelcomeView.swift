import AppKit
import SwiftUI

/// First-run welcome sheet. A dumb presentation component: it receives the
/// edition configuration and the claiming host id, and every action routes
/// through `OnboardingCoordinator`. It never checks bundle identifiers,
/// StoreKit, or receipts, and it never calls any permission API.
struct WelcomeView: View {
    let configuration: OnboardingConfiguration
    let coordinator: OnboardingCoordinator
    let hostID: UUID
    var onStart: (SidebarPage) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "onboarding.welcome.title", comment: "First-run welcome sheet title"))
                        .font(.title2.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)

                    Text(String(localized: "onboarding.welcome.body", comment: "First-run welcome sheet body"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Button {
                    coordinator.completeWelcomeWithoutRouting(hostID: hostID)
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(String(localized: "onboarding.welcome.close", comment: "Close first-run welcome sheet"))
                .keyboardShortcut(.cancelAction)
            }

            VStack(alignment: .leading, spacing: 10) {
                Button {
                    startAnalyzing()
                } label: {
                    Label {
                        Text(String(localized: "onboarding.welcome.start", comment: "Primary first-run welcome action"))
                    } icon: {
                        Image(systemName: "chart.bar.xaxis")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("onboarding-start-analyzing")

                if configuration.showsProLink, let proURL = configuration.proURL {
                    Button {
                        learnAboutPro(proURL)
                    } label: {
                        Text(String(localized: "onboarding.welcome.learn_pro", comment: "OSS secondary first-run welcome action"))
                            .frame(maxWidth: .infinity)
                    }
                    .accessibilityIdentifier("onboarding-learn-pro")
                }

                Button {
                    coordinator.completeWelcomeWithoutRouting(hostID: hostID)
                    dismiss()
                } label: {
                    Text(String(localized: "onboarding.welcome.skip", comment: "Skip first-run welcome action"))
                        .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("onboarding-skip")
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    private func startAnalyzing() {
        let route = configuration.startRoute ?? .overview
        if let resolved = coordinator.completeWelcomeStart(hostID: hostID, startRoute: route) {
            onStart(resolved)
        }
        dismiss()
    }

    private func learnAboutPro(_ url: URL) {
        guard NSWorkspace.shared.open(url) else {
            // Keep the welcome visible and do not mark completion.
            AppLogger.guidance.error("onboarding pro link open failed")
            return
        }
        coordinator.completeWelcomeAfterOpeningProURL(hostID: hostID, openedSuccessfully: true)
        dismiss()
    }
}
