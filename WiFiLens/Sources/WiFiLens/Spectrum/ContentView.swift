import SwiftUI

struct SpectrumSectionLayout {
    static let headerHeight: CGFloat = 28

    struct Section {
        let kind: Kind
        let isCollapsed: Bool
    }

    enum Kind {
        case band
        case trend
        case table

        var weight: CGFloat {
            switch self {
            case .band: return 1.0
            case .trend: return 0.5
            case .table: return 1.5
            }
        }

        var minimumContentHeight: CGFloat {
            switch self {
            case .band: return 60
            case .trend: return 100
            case .table: return 60
            }
        }
    }

    static func computeContentHeights(sections: [Section], totalHeight: CGFloat) -> [CGFloat] {
        let contentPool = max(0, totalHeight - CGFloat(sections.count) * headerHeight)
        let expanded = sections.enumerated().filter { !$0.element.isCollapsed }
        let minimumTotal = expanded.reduce(CGFloat.zero) { $0 + $1.element.kind.minimumContentHeight }

        guard !expanded.isEmpty else {
            return Array(repeating: 0, count: sections.count)
        }

        if contentPool <= minimumTotal {
            let scale = minimumTotal > 0 ? contentPool / minimumTotal : 0
            return sections.map { section in
                section.isCollapsed ? 0 : section.kind.minimumContentHeight * scale
            }
        }

        let extraPool = contentPool - minimumTotal
        let totalWeight = expanded.reduce(CGFloat.zero) { $0 + $1.element.kind.weight }

        return sections.map { section in
            guard !section.isCollapsed else { return 0 }
            let extra = totalWeight > 0 ? extraPool * section.kind.weight / totalWeight : 0
            return section.kind.minimumContentHeight + extra
        }
    }
}

enum SpectrumPanelID: String, CaseIterable, Hashable {
    case primary
    case secondary
}

enum BandPanelSelection: String, CaseIterable, Identifiable {
    case band24 = "24"
    case band5 = "5"
    case band6 = "6"
    case trend = "trend"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .band24: return String(localized: "spectrum.panel.band.24ghz", comment: "2.4 GHz band label in spectrum panel")
        case .band5: return String(localized: "spectrum.panel.band.5ghz", comment: "5 GHz band label in spectrum panel")
        case .band6: return String(localized: "spectrum.panel.band.6ghz", comment: "6 GHz band label in spectrum panel")
        case .trend: return String(localized: "spectrum.panel.trend", comment: "Trend chart label in spectrum panel")
        }
    }
}

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

struct SpectrumDashboardLayout {
    static let primaryRatio: CGFloat = 0.35
    static let secondaryRatio: CGFloat = 0.35
    static let tableRatio: CGFloat = 0.30

    let viewportHeight: CGFloat

    var primaryHeight: CGFloat {
        viewportHeight * Self.primaryRatio
    }

    var secondaryHeight: CGFloat {
        viewportHeight * Self.secondaryRatio
    }

    var tableHeight: CGFloat {
        viewportHeight * Self.tableRatio
    }
}

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

    private var dashboardContent: some View {
        GeometryReader { geometry in
            let layout = SpectrumDashboardLayout(viewportHeight: geometry.size.height)

            VStack(spacing: 0) {
                if shouldShowEmptyState {
                    emptyState
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    SpectrumPanelView(
                        viewModel: viewModel,
                        panelID: .primary,
                        chartType: $panel1ChartType,
                        selectedNetworkID: $viewModel.selectedNetworkID
                    )
                    .frame(height: layout.primaryHeight)

                    Divider()

                    SpectrumPanelView(
                        viewModel: viewModel,
                        panelID: .secondary,
                        chartType: $panel2ChartType,
                        selectedNetworkID: $viewModel.selectedNetworkID
                    )
                    .frame(height: layout.secondaryHeight)

                    Divider()

                    VStack(spacing: 0) {
                        tableFilterBar
                        bottomTable
                    }
                    .frame(height: layout.tableHeight)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

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

    private var tableRows: [NetworkTableRow] {
        viewModel.combinedTableRows
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
        case "ssid": cmp = a.ssid.localizedCaseInsensitiveCompare(b.ssid)
        case "bandLabel": cmp = a.bandLabel.localizedCaseInsensitiveCompare(b.bandLabel)
        case "channel": cmp = a.channel < b.channel ? .orderedAscending : a.channel > b.channel ? .orderedDescending : .orderedSame
        case "rssi": cmp = a.rssi > b.rssi ? .orderedAscending : a.rssi < b.rssi ? .orderedDescending : .orderedSame
        case "bssid": cmp = a.bssid.localizedCaseInsensitiveCompare(b.bssid)
        case "phyMode": cmp = a.phyMode.localizedCaseInsensitiveCompare(b.phyMode)
        case "channelWidth": cmp = Int(a.channelWidth) ?? 0 < Int(b.channelWidth) ?? 0 ? .orderedAscending : Int(a.channelWidth) ?? 0 > Int(b.channelWidth) ?? 0 ? .orderedDescending : .orderedSame
        case "supportsK": cmp = a.supportsK == b.supportsK ? .orderedSame : a.supportsK ? .orderedDescending : .orderedAscending
        case "supportsR": cmp = a.supportsR == b.supportsR ? .orderedSame : a.supportsR ? .orderedDescending : .orderedAscending
        case "supportsV": cmp = a.supportsV == b.supportsV ? .orderedSame : a.supportsV ? .orderedDescending : .orderedAscending
        case "isHiddenSSID": cmp = a.isHiddenSSID == b.isHiddenSSID ? .orderedSame : a.isHiddenSSID ? .orderedDescending : .orderedAscending
        case "qualityScore": cmp = a.qualityScore > b.qualityScore ? .orderedAscending : a.qualityScore < b.qualityScore ? .orderedDescending : .orderedSame
        case "security": cmp = a.security.localizedCaseInsensitiveCompare(b.security)
        case "mcs": cmp = (Int(a.mcs) ?? 0) < (Int(b.mcs) ?? 0) ? .orderedAscending : (Int(a.mcs) ?? 0) > (Int(b.mcs) ?? 0) ? .orderedDescending : .orderedSame
        case "nss": cmp = (Int(a.nss) ?? 0) < (Int(b.nss) ?? 0) ? .orderedAscending : (Int(a.nss) ?? 0) > (Int(b.nss) ?? 0) ? .orderedDescending : .orderedSame
        case "country": cmp = a.country.localizedCaseInsensitiveCompare(b.country)
        case "lastSeen": cmp = a.lastSeen.localizedCaseInsensitiveCompare(b.lastSeen)
        default: cmp = .orderedSame
        }
        return ascending ? cmp : (cmp == .orderedAscending ? .orderedDescending : cmp == .orderedDescending ? .orderedAscending : .orderedSame)
    }

    private var bottomTable: some View {
        NativeTableView(
            rows: sortedRows,
            selectedID: $viewModel.selectedNetworkID,
            sortOrder: $sortOrder,
            hiddenColumns: hiddenColumns,
            onToggleVisibility: { seriesID in viewModel.toggleVisibility(seriesID: seriesID) },
            onToggleVisibilityLocked: { seriesID in viewModel.toggleVisibilityLocked(seriesID: seriesID) }
        )
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

private struct SpectrumPanelView: View {
    let viewModel: ScannerViewModel
    let panelID: SpectrumPanelID
    @Binding var chartType: BandPanelSelection
    @Binding var selectedNetworkID: String?

    private var currentBandVM: BandChartViewModel {
        bandViewModel(for: chartType)
    }

    private var filterQueryBinding: Binding<String> {
        Binding(
            get: { viewModel.filterQuery(for: panelID) },
            set: { viewModel.setFilterQuery($0, for: panelID) }
        )
    }

    private var totalCount: Int {
        currentBandVM.networkCount
    }

    private var displayedCount: Int {
        currentBandVM.visibleSeriesData().count
    }

    private var hiddenCount: Int {
        totalCount - displayedCount
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            chartContent
        }
        .padding(.trailing, 8)
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Picker(String(localized: "spectrum.panel.chart_type", comment: "Chart type picker label"), selection: $chartType) {
                ForEach(supportedChartTypes) { type in
                    Text(type.displayName)
                        .lineLimit(1)
                        .tag(type)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 180)

            TextField(String(localized: "spectrum.panel.filter_placeholder", comment: "Filter input placeholder"), text: filterQueryBinding)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 300)

            if hiddenCount > 0 {
                Text("\(displayedCount)/\(totalCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if !filterQueryBinding.wrappedValue.isEmpty {
                Button {
                    filterQueryBinding.wrappedValue = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.bar)
    }

    @ViewBuilder
    private var chartContent: some View {
        switch chartType {
        case .band24, .band5, .band6:
            spectrumChart
        case .trend:
            trendChart
        }
    }

    private var spectrumChart: some View {
        let bandVM = bandViewModel(for: chartType)
        return WiFiBandChart(
            model: bandVM.renderModel,
            selectedNetworkID: $selectedNetworkID,
            onResetZoom: { bandVM.resetZoom() },
            onToggleExpand: { bandVM.toggleExpand() },
            onApplyZoom: { lo, hi in bandVM.applyZoom(lo: lo, hi: hi) }
        )
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        bandVM.chartSize = geometry.size
                    }
                    .onChange(of: geometry.size) { _, newSize in
                        bandVM.chartSize = newSize
                    }
            }
        }
    }

    private var trendChart: some View {
        Group {
            if let selID = selectedNetworkID,
               let snaps = selectedNetworkSnapshots(for: selID),
               let series = selectedNetworkSeries(for: selID),
               snaps.count >= 2 {
                TrendChartView(snapshots: snaps, color: series.color)
            } else {
                VStack {
                    Spacer()
                    Text(String(localized: "spectrum.panel.select_network_for_trend", comment: "Placeholder when no network is selected for trend chart"))
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Spacer()
                }
            }
        }
    }

    private var supportedChartTypes: [BandPanelSelection] {
        var types: [BandPanelSelection] = []
        if viewModel.supportedBands.contains(.band24GHz) { types.append(.band24) }
        if viewModel.supportedBands.contains(.band5GHz) { types.append(.band5) }
        if viewModel.supportedBands.contains(.band6GHz) { types.append(.band6) }
        types.append(.trend)
        return types
    }

    private func bandViewModel(for selection: BandPanelSelection) -> BandChartViewModel {
        viewModel.bandViewModel(for: panelID, selection: selection)
    }

    private func selectedNetworkSnapshots(for networkID: String) -> [NetworkSnapshot]? {
        for vm in viewModel.panelBandViewModels(for: panelID) {
            if let snaps = vm.snapshots(for: networkID) {
                return snaps
            }
        }
        return nil
    }

    private func selectedNetworkSeries(for networkID: String) -> ChartSeriesData? {
        for vm in viewModel.panelBandViewModels(for: panelID) {
            if let series = vm.series(for: networkID) {
                return series
            }
        }
        return nil
    }
}
