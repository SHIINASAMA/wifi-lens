import SwiftUI

enum EditionComposition {
    static var guidanceConfiguration: GuidanceConfiguration {
        var config = GuidanceConfiguration()
        config.invitationEnabled = true
        // Dev builds use the plain listing. Before release, replace this with
        // the official App Store Connect "oss_invite" Campaign Link. Never
        // handcraft campaign parameters.
        config.appStoreCampaignURL = ExternalLinks.url(for: .appStore)
        return config
    }

    static var exportSuccessPresentation: ExportSuccessPresentation { .banner }

    @MainActor
    static var markdownExportCommandContribution: MarkdownExportCommandContribution {
        .lockedPreview
    }

    @MainActor
    static func makeMainWindowState() -> AnyObject { NSObject() }

    @MainActor
    static func registerMainWindowState(_ state: AnyObject, for windowID: UUID) -> Bool { true }

    @MainActor
    static func unregisterMainWindowState(_ state: AnyObject, for windowID: UUID) {}

    static let isTimelineLockedPreview = true

    static var timelineToolbarDescriptor: SecondaryToolbarDescriptor? { nil }

    static var spectrumToolbarDescriptor: SecondaryToolbarDescriptor {
        .spectrum(recordingLocked: true)
    }

    @ViewBuilder
    @MainActor
    static func settingsContribution() -> some View {
        Section {
            BLEFeatureSettingsRow()
            MenuBarFeaturePreviewRow()
        } header: {
            Text(String(localized: "settings.section.features", comment: "Features subsection header in settings"))
        }
    }

    @ViewBuilder
    @MainActor
    static func detailContribution(context: EditionCompositionContext) -> some View {
        switch context.selectedPage.wrappedValue {
        case .spectrum:
            OSSSpectrumCompositionView(
                scannerViewModel: context.scannerViewModel,
                isVendorColumnAvailable: context.isMACVendorDatabaseAvailable,
                selection: context.secondaryToolbarSelections.wrappedValue.spectrum
            )
            .accessibilityIdentifier("page-spectrum")
            .accessibilityElement(children: .contain)
        case .timeline:
            ProFeaturePlaceholderView(
                featureName: String(localized: "pro.timeline.title", comment: "Pro timeline feature title"),
                featureDescription: String(localized: "pro.timeline.description", comment: "Pro timeline feature description"),
                featureIcon: SidebarPage.timeline.icon,
                customSkeleton: { TimelineSkeletonView() }
            )
            .accessibilityIdentifier("page-timeline")
        case .statistics:
            ProFeaturePlaceholderView(
                featureName: String(localized: "pro.statistics.title", comment: "Pro Statistics feature title"),
                featureDescription: String(localized: "pro.statistics.description", comment: "Pro Statistics feature description"),
                featureIcon: SidebarPage.statistics.icon,
                customSkeleton: { StatisticsSkeletonView() }
            )
            .accessibilityIdentifier("page-statistics")
        case .insights:
            ProFeaturePlaceholderView(
                featureName: String(localized: "pro.insights.title", comment: "Pro Insights feature title"),
                featureDescription: String(localized: "pro.insights.description", comment: "Pro Insights feature description"),
                featureIcon: SidebarPage.insights.icon,
                customSkeleton: { InsightsSkeletonView() }
            )
            .accessibilityIdentifier("page-insights")
        default:
            EmptyView()
        }
    }

    static func startLifecycle(observationRuntime: WiFiObservationRuntime) {}

    @MainActor
    static func prepareForTermination() async {}

    @MainActor
    static func mainWindowDidBecomeActive(_ windowID: UUID) {}

    @MainActor
    static func mainWindowWillClose(_ windowID: UUID) {}

    @SceneBuilder
    @MainActor
    static func menuBarScene(
        openMainWindow: @escaping (SidebarPage?) -> Void,
        terminate: @escaping () -> Void
    ) -> some Scene {}

    static let menuBarWindowManagementEnabled = false
}

private struct OSSSpectrumCompositionView: View {
    @Bindable var scannerViewModel: ScannerViewModel
    let isVendorColumnAvailable: Bool
    let selection: SecondaryToolbarItemID

    var body: some View {
        if selection == .spectrumRecording {
            ProFeaturePlaceholderView(
                featureName: String(localized: "pro.recording.title", comment: "Pro recording feature title"),
                featureDescription: String(localized: "pro.recording.description", comment: "Pro recording feature description"),
                featureIcon: "record.circle",
                customSkeleton: { RecordingSkeletonView() }
            )
        } else {
            ContentView(
                viewModel: scannerViewModel,
                isVendorColumnAvailable: isVendorColumnAvailable
            )
        }
    }
}
