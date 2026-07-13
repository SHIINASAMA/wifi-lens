import SwiftUI

enum EditionComposition {
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
                selection: context.secondaryToolbarSelections.wrappedValue.spectrum
            )
            .accessibilityIdentifier("page-spectrum")
        case .timeline:
            ProFeaturePlaceholderView(
                featureName: String(localized: "pro.timeline.title", comment: "Pro timeline feature title"),
                featureDescription: String(localized: "pro.timeline.description", comment: "Pro timeline feature description"),
                featureIcon: SidebarPage.timeline.icon,
                customSkeleton: { TimelineSkeletonView() }
            )
            .accessibilityIdentifier("page-timeline")
        default:
            EmptyView()
        }
    }

    static func startLifecycle(observationRuntime: WiFiObservationRuntime) {}

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
            ContentView(viewModel: scannerViewModel)
        }
    }
}
