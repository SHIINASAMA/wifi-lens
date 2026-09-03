import SwiftUI

struct SpectrumDashboardLayout {
    static let panelRatio: CGFloat = 1.0 / 3.0

    let viewportHeight: CGFloat

    var primaryHeight: CGFloat {
        viewportHeight * Self.panelRatio
    }

    var secondaryHeight: CGFloat {
        viewportHeight * Self.panelRatio
    }

    var tertiaryHeight: CGFloat {
        viewportHeight * Self.panelRatio
    }
}

struct ContentView: View {
    @Bindable var viewModel: ScannerViewModel
    let isVendorColumnAvailable: Bool

    @State private var sortOrder: [NSSortDescriptor] = [NSSortDescriptor(key: "ssid", ascending: true)]
    @AppStorage("hiddenTableColumns") private var hiddenColumnsData: String = ""

    private var hiddenColumns: Binding<Set<String>> {
        Binding(
            get: { Set(hiddenColumnsData.split(separator: ",").map(String.init).filter { !$0.isEmpty }) },
            set: { hiddenColumnsData = $0.sorted().joined(separator: ",") }
        )
    }

    init(viewModel: ScannerViewModel, isVendorColumnAvailable: Bool) {
        self.viewModel = viewModel
        self.isVendorColumnAvailable = isVendorColumnAvailable
    }

    init(viewModel: ScannerViewModel, macVendorDatabaseManager: MACVendorDatabaseManager) {
        self.init(
            viewModel: viewModel,
            isVendorColumnAvailable: macVendorDatabaseManager.availability.isVendorColumnAvailable
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            contentArea
        }
        // Same guardrail as Channels.ChannelQualityView: `minWidth: 700` forces the
        // whole dashboard to lay out 700pt wide — wider than the ~600pt detail column
        // at the minimum window size, clipping the right edge. Keep only the ideals as
        // page layout hints.
        .frame(idealWidth: 1000, idealHeight: 700)
        .onChange(of: viewModel.hiddenBands) { _, _ in viewModel.applyGlobalFilterToBands() }
        .onChange(of: viewModel.hideHiddenSSIDs) { _, _ in viewModel.applyGlobalFilterToBands() }
    }

    @ViewBuilder
    private var contentArea: some View {
        dashboardContent
    }

    private var dashboardContent: some View {
        GeometryReader { geometry in
            let layout = SpectrumDashboardLayout(viewportHeight: geometry.size.height)

            VStack(spacing: 0) {
                if shouldShowEmptyState {
                    emptyState
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    SpectrumPanelContainer(
                        viewModel: viewModel,
                        panelID: .primary,
                        isVendorColumnAvailable: isVendorColumnAvailable,
                        defaultViewType: .spectrum,
                        defaultBand: .band24GHz,
                        selectedNetworkID: $viewModel.selectedNetworkID,
                        sortOrder: $sortOrder,
                        hiddenColumns: hiddenColumns
                    )
                    .frame(height: layout.primaryHeight)

                    Divider()

                    SpectrumPanelContainer(
                        viewModel: viewModel,
                        panelID: .secondary,
                        isVendorColumnAvailable: isVendorColumnAvailable,
                        defaultViewType: .spectrum,
                        defaultBand: .band5GHz,
                        selectedNetworkID: $viewModel.selectedNetworkID,
                        sortOrder: $sortOrder,
                        hiddenColumns: hiddenColumns
                    )
                    .frame(height: layout.secondaryHeight)

                    Divider()

                    SpectrumPanelContainer(
                        viewModel: viewModel,
                        panelID: .tertiary,
                        isVendorColumnAvailable: isVendorColumnAvailable,
                        defaultViewType: .table,
                        selectedNetworkID: $viewModel.selectedNetworkID,
                        sortOrder: $sortOrder,
                        hiddenColumns: hiddenColumns
                    )
                    .frame(height: layout.tertiaryHeight)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .accessibilityIdentifier("spectrum-dashboard")
        .accessibilityElement(children: .contain)
    }

    private var shouldShowEmptyState: Bool {
        switch viewModel.accessState {
        case .waitingForAuthorization, .denied, .scanFailed: return true
        case .scanning, .grantedButSSIDUnavailable: return false
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView().scaleEffect(1.5)
            switch viewModel.accessState {
            case .waitingForAuthorization:
                Text(String(localized: "permission.location.waiting", comment: "Status while waiting for Location Services authorization")).foregroundColor(.orange)
                Button(String(localized: "common.action.open_system_settings", comment: "Button to open macOS System Settings")) { viewModel.locationManager.openLocationPreferences() }
            case .denied:
                Text(String(localized: "permission.location.required_short", comment: "Short label: Location Services required")).foregroundColor(.secondary)
                Button(String(localized: "common.action.open_location_preferences", comment: "Button to open Location Services preferences")) { viewModel.locationManager.openLocationPreferences() }
            case .scanFailed(let msg):
                Text(String(localized: "common.error.scan_failed", comment: "Generic scan failure message")).foregroundColor(.secondary)
                Text(msg).font(.caption).foregroundColor(.secondary)
            default:
                EmptyView()
            }
            Spacer()
        }
    }
}
