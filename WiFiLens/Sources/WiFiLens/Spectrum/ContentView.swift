import SwiftUI

#if PRO
enum SpectrumMode {
    case live
    case recording

    static func fromToolbarSelection(_ selection: SecondaryToolbarItemID) -> Self {
        switch selection {
        case .spectrumRecording:
            .recording
        default:
            .live
        }
    }
}

@MainActor
enum SpectrumRecordingSessionResolver {
    static func resolve(
        current: RecordingViewModel?,
        mode: SpectrumMode,
        scannerViewModel: ScannerViewModel
    ) -> RecordingViewModel? {
        switch mode {
        case .live:
            current
        case .recording:
            current ?? RecordingViewModel(scannerViewModel: scannerViewModel)
        }
    }
}
#endif

struct ContentView: View {
    @Bindable var viewModel: ScannerViewModel

    @State private var sortOrder: [NSSortDescriptor] = [NSSortDescriptor(key: "ssid", ascending: true)]
    @State private var panel1ChartType: BandPanelSelection = .band24
    @State private var panel2ChartType: BandPanelSelection = .band5
    @AppStorage("hiddenTableColumns") private var hiddenColumnsData: String = ""

#if PRO
    let mode: SpectrumMode
    @Binding var recordingViewModel: RecordingViewModel?
#else
    let mode: SecondaryToolbarItemID
#endif

    private var hiddenColumns: Binding<Set<String>> {
        Binding(
            get: { Set(hiddenColumnsData.split(separator: ",").map(String.init).filter { !$0.isEmpty }) },
            set: { hiddenColumnsData = $0.sorted().joined(separator: ",") }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            contentArea
        }
        .frame(minWidth: 700, idealWidth: 1000, minHeight: 600)
        .onChange(of: viewModel.hiddenBands) { _, _ in viewModel.applyGlobalFilterToBands() }
        .onChange(of: viewModel.hideHiddenSSIDs) { _, _ in viewModel.applyGlobalFilterToBands() }
#if PRO
        .onChange(of: mode) { _, newMode in
            recordingViewModel = SpectrumRecordingSessionResolver.resolve(
                current: recordingViewModel,
                mode: newMode,
                scannerViewModel: viewModel
            )
            if newMode == .recording {
                recordingViewModel?.checkReadiness()
            }
        }
        .onAppear {
            recordingViewModel = SpectrumRecordingSessionResolver.resolve(
                current: recordingViewModel,
                mode: mode,
                scannerViewModel: viewModel
            )
            if mode == .recording {
                recordingViewModel?.checkReadiness()
            }
        }
#endif
    }

    // MARK: - Content area

    @ViewBuilder
    private var contentArea: some View {
#if PRO
        switch mode {
        case .live:
            dashboardContent
        case .recording:
            if let rvm = recordingViewModel {
                RecordingView(viewModel: rvm)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task {
                        recordingViewModel = SpectrumRecordingSessionResolver.resolve(
                            current: recordingViewModel,
                            mode: mode,
                            scannerViewModel: viewModel
                        )
                        recordingViewModel?.checkReadiness()
                    }
            }
        }
#else
        if mode == .spectrumRecording {
            ProFeaturePlaceholderView(
                featureName: String(localized: "pro.recording.title", comment: "Pro recording feature title"),
                featureDescription: String(localized: "pro.recording.description", comment: "Pro recording feature description"),
                featureIcon: "record.circle"
            )
        } else {
            dashboardContent
        }
#endif
    }

    // MARK: - Dashboard Content

    private var dashboardContent: some View {
        GeometryReader { geometry in
            let totalH = geometry.size.height
            let panelHeight = totalH * 0.35
            let tableHeight = totalH * 0.30
            
            VStack(spacing: 0) {
                if shouldShowEmptyState {
                    emptyState
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    SpectrumPanelView(
                        viewModel: viewModel,
                        chartType: $panel1ChartType,
                        selectedNetworkID: $viewModel.selectedNetworkID
                    )
                    .frame(height: panelHeight)
                    
                    Divider()
                    
                    SpectrumPanelView(
                        viewModel: viewModel,
                        chartType: $panel2ChartType,
                        selectedNetworkID: $viewModel.selectedNetworkID
                    )
                    .frame(height: panelHeight)
                    
                    Divider()
                    
                    VStack(spacing: 0) {
                        tableFilterBar
                        bottomTable
                    }
                    .frame(height: tableHeight)
                }
            }
        }
    }

    // MARK: - Table Filter Bar

    private var tableFilterBar: some View {
        HStack(spacing: 12) {
            Toggle(isOn: $viewModel.hideHiddenSSIDs) {
                Text(String(localized: "spectrum.filter.hide_hidden", comment: "Toggle to hide networks with hidden SSIDs")).font(.caption)
            }
            .toggleStyle(.checkbox)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(.bar)
    }

    // MARK: - Bottom Table (shared)

    private var tableRows: [NetworkTableRow] {
        viewModel.combinedTableRows.filter { row in
            if viewModel.hiddenBands.contains(row.bandID) { return false }
            if viewModel.hideHiddenSSIDs && row.isHiddenSSID { return false }
            return true
        }
    }

    private var sortedRows: [NetworkTableRow] {
        guard !sortOrder.isEmpty else { return tableRows }
        return tableRows.sorted { a, b in
            for desc in sortOrder {
                let result = compareRow(a, b, key: desc.key ?? "", ascending: desc.ascending)
                if result != .orderedSame { return result == .orderedAscending }
            }
            return false
        }
    }

    private func compareRow(_ a: NetworkTableRow, _ b: NetworkTableRow, key: String, ascending: Bool) -> ComparisonResult {
        let cmp: ComparisonResult
        switch key {
        case "ssid":       cmp = a.ssid.localizedCaseInsensitiveCompare(b.ssid)
        case "bandLabel":  cmp = a.bandLabel.localizedCaseInsensitiveCompare(b.bandLabel)
        case "channel":    cmp = a.channel < b.channel ? .orderedAscending : a.channel > b.channel ? .orderedDescending : .orderedSame
        case "rssi":       cmp = a.rssi > b.rssi ? .orderedAscending : a.rssi < b.rssi ? .orderedDescending : .orderedSame
        case "bssid":         cmp = a.bssid.localizedCaseInsensitiveCompare(b.bssid)
        case "phyMode":       cmp = a.phyMode.localizedCaseInsensitiveCompare(b.phyMode)
        case "channelWidth":  cmp = Int(a.channelWidth) ?? 0 < Int(b.channelWidth) ?? 0 ? .orderedAscending : Int(a.channelWidth) ?? 0 > Int(b.channelWidth) ?? 0 ? .orderedDescending : .orderedSame
        case "supportsK":     cmp = a.supportsK == b.supportsK ? .orderedSame : a.supportsK ? .orderedDescending : .orderedAscending
        case "supportsR":     cmp = a.supportsR == b.supportsR ? .orderedSame : a.supportsR ? .orderedDescending : .orderedAscending
        case "supportsV":     cmp = a.supportsV == b.supportsV ? .orderedSame : a.supportsV ? .orderedDescending : .orderedAscending
        case "isHiddenSSID":  cmp = a.isHiddenSSID == b.isHiddenSSID ? .orderedSame : a.isHiddenSSID ? .orderedDescending : .orderedAscending
        case "qualityScore":  cmp = a.qualityScore > b.qualityScore ? .orderedAscending : a.qualityScore < b.qualityScore ? .orderedDescending : .orderedSame
        case "security":      cmp = a.security.localizedCaseInsensitiveCompare(b.security)
        case "mcs":           cmp = (Int(a.mcs) ?? 0) < (Int(b.mcs) ?? 0) ? .orderedAscending : (Int(a.mcs) ?? 0) > (Int(b.mcs) ?? 0) ? .orderedDescending : .orderedSame
        case "nss":           cmp = (Int(a.nss) ?? 0) < (Int(b.nss) ?? 0) ? .orderedAscending : (Int(a.nss) ?? 0) > (Int(b.nss) ?? 0) ? .orderedDescending : .orderedSame
        case "country":       cmp = a.country.localizedCaseInsensitiveCompare(b.country)
        case "lastSeen":      cmp = a.lastSeen.localizedCaseInsensitiveCompare(b.lastSeen)
        default:              cmp = .orderedSame
        }
        return ascending ? cmp : (cmp == .orderedAscending ? .orderedDescending : cmp == .orderedDescending ? .orderedAscending : .orderedSame)
    }

    private var bottomTable: some View {
        NativeTableView(
            rows: sortedRows,
            selectedID: $viewModel.selectedNetworkID,
            sortOrder: $sortOrder,
            hiddenColumns: hiddenColumns,
            onToggleVisibility: { bssid in viewModel.toggleVisibility(bssid: bssid) },
            onToggleVisibilityLocked: { bssid in viewModel.toggleVisibilityLocked(bssid: bssid) }
        )
    }

    // MARK: - Helpers

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
