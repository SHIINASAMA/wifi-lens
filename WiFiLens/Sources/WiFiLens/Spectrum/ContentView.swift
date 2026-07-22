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
        .accessibilityIdentifier("spectrum-dashboard")
        .accessibilityElement(children: .contain)
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
        case "vendor": cmp = a.vendor.localizedCaseInsensitiveCompare(b.vendor)
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
