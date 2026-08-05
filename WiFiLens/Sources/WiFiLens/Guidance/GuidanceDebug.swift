#if DEBUG
import Foundation

/// Debug-only, in-memory override of the Pro installation detection used by
/// the OSS invitation flow. Exists only for the current process: never
/// persisted, never uploaded, never included in Release builds.
enum ProInstallationOverride: String, Equatable, Sendable {
    case useRealDetection
    case treatAsNotInstalled
    case treatAsInstalled
}

/// Debug-only holder for lifecycle-guidance manual-testing overrides.
/// The production installation checker is unchanged; the coordinator's
/// default detection closure consults this holder only in Debug builds.
@MainActor
enum GuidanceDebugOverrides {
    private(set) static var proInstallationOverride: ProInstallationOverride = .useRealDetection

    /// Debug-only staging hook installed by the diagnostics host so the Debug
    /// menu can render the production result host without running a real
    /// diagnostic. Memory-only; never persisted.
    private static var diagnosticsStaging: (() -> Void)?

    static func setProInstallationOverride(_ override: ProInstallationOverride) {
        proInstallationOverride = override
    }

    static func installDiagnosticsStaging(_ staging: @escaping () -> Void) {
        diagnosticsStaging = staging
    }

    static func stageDiagnosticsCompletion() {
        diagnosticsStaging?()
    }
}
#endif
