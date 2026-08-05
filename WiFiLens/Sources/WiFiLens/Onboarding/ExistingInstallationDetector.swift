import Foundation

/// Decides whether the current device already had a WiFi Lens install before
/// the first-run onboarding feature shipped. Pure evidence check; the
/// onboarding coordinator turns the answer into a one-time migration.
protocol ExistingInstallationDetecting {
    func hasExistingInstallationEvidence() -> Bool
}

/// Edition with no reliable pre-onboarding install marker. The migration
/// still writes a `false` result on first launch, but never marks anyone
/// completed based on a foreign marker (e.g. Sparkle, which is OSS-only).
struct NoExistingInstallationDetector: ExistingInstallationDetecting {
    func hasExistingInstallationEvidence() -> Bool {
        false
    }
}

/// Uses Sparkle's automatic-check key, which every build since May 2026
/// writes on first launch. The migration must run before `SparkleUpdater`
/// initializes, otherwise a brand-new install would already carry the key and
/// the welcome would never show for clean installs.
struct SparkleAutomaticCheckExistingInstallationDetector: ExistingInstallationDetecting {
    static let defaultsKey = "SUEnableAutomaticChecks"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func hasExistingInstallationEvidence() -> Bool {
        defaults.object(forKey: Self.defaultsKey) != nil
    }
}
