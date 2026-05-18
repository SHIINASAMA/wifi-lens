import SwiftUI

private let headerHeight: CGFloat = 28

struct ContentView: View {
    @Bindable var viewModel: ScannerViewModel
    @Environment(\.scenePhase) private var scenePhase

    @State private var sortOrder: [NSSortDescriptor] = [NSSortDescriptor(key: "ssid", ascending: true)]
    @State private var is2GHzCollapsed = false
    @State private var is5GHzCollapsed = false
    @State private var is6GHzCollapsed = false
    @State private var isTableCollapsed = false
    @State private var isNetworkInfoCollapsed = false
    @State private var show24InTable = true
    @State private var show5InTable = true
    @State private var show6InTable = true

    var body: some View {
        VStack(spacing: 0) {
            dashboardContent
        }
        .frame(minWidth: 700, idealWidth: 1000, minHeight: 600)
        .task { await viewModel.start() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await viewModel.handleSceneDidBecomeActive() }
            }
        }
        .onDisappear { viewModel.stop() }
    }

    // MARK: - Dashboard Content

    private var dashboardContent: some View {
        GeometryReader { geometry in
            let totalH = geometry.size.height
            let sections = visibleSections
            let heights = computeHeights(sections: sections, totalH: totalH)

            VStack(spacing: 0) {
                if shouldShowEmptyState {
                    emptyState
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ForEach(sections.indices, id: \.self) { idx in
                        let section = sections[idx]

                        if isCollapsed(section) {
                            sectionHeader(section)
                        } else {
                            sectionHeader(section)
                            sectionContent(section, height: heights[idx])
                        }

                        if idx < sections.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    /// Compute proportional heights: charts weight 1, table weight 1.5
    private func computeHeights(sections: [SectionInfo], totalH: CGFloat) -> [CGFloat] {
        let allHeaders = CGFloat(sections.count) * headerHeight
        let contentPool = totalH - allHeaders

        // Build weights for each section
        let weights = sections.map { section -> CGFloat in
            if case .table = section.kind { return 1.5 }
            return 1.0
        }
        let totalWeight = sections.enumerated()
            .filter { !isCollapsed($0.element) }
            .map { weights[$0.offset] }
            .reduce(0, +)

        var result: [CGFloat] = Array(repeating: 0, count: sections.count)
        for (idx, section) in sections.enumerated() {
            if isCollapsed(section) {
                result[idx] = headerHeight
            } else {
                let fraction = weights[idx] / max(1, totalWeight)
                result[idx] = max(60, contentPool * fraction)
            }
        }
        return result
    }

    // MARK: - Section Header

    private func sectionHeader(_ section: SectionInfo) -> some View {
        Button {
            withAnimation { toggleCollapse(section) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isCollapsed(section) ? "chevron.right" : "chevron.down")
                    .font(.caption)
                    .frame(width: 12)

                section.icon

                Text(section.title)
                    .font(.system(size: 12, weight: .semibold))

                if section.isChart, let bandVM = section.bandVM {
                    Button {
                        bandVM.toggleFreeze()
                    } label: {
                        Image(systemName: bandVM.isFrozen ? "play.fill" : "pause.fill")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .help(bandVM.isFrozen ? "Resume" : "Pause")
                }

                Spacer()

                Text(section.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .frame(height: headerHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section Content

    @ViewBuilder
    private func sectionContent(_ section: SectionInfo, height: CGFloat) -> some View {
        switch section.kind {
        case .band(let bandVM):
            BandChartView(viewModel: bandVM, scannerViewModel: viewModel)
                .frame(height: height)
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

        case .networkInfo:
            networkInfoContent
                .frame(height: height)
        case .table:
            VStack(spacing: 0) {
                tableFilterBar
                bottomTable
            }
            .frame(height: height)
        }
    }

    private var tableFilterBar: some View {
        HStack(spacing: 12) {
            Text("Show:")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            bandToggle("2.4 GHz", isOn: $show24InTable)
            bandToggle("5 GHz", isOn: $show5InTable)
            if viewModel.supportedBands.contains(.band6GHz) {
                bandToggle("6 GHz", isOn: $show6InTable)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }

    private func bandToggle(_ label: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(label).font(.system(size: 11))
        }
        .toggleStyle(.checkbox)
    }

    // MARK: - Bottom Table (shared)

    private var tableRows: [NetworkTableRow] {
        viewModel.combinedTableRows.filter { row in
            switch row.bandLabel {
            case "2.4 GHz": return show24InTable
            case "5 GHz":   return show5InTable
            case "6 GHz":   return show6InTable
            default: return true
            }
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
        case "security":      cmp = a.security.localizedCaseInsensitiveCompare(b.security)
        case "mcs":           cmp = (Int(a.mcs) ?? 0) < (Int(b.mcs) ?? 0) ? .orderedAscending : (Int(a.mcs) ?? 0) > (Int(b.mcs) ?? 0) ? .orderedDescending : .orderedSame
        case "nss":           cmp = (Int(a.nss) ?? 0) < (Int(b.nss) ?? 0) ? .orderedAscending : (Int(a.nss) ?? 0) > (Int(b.nss) ?? 0) ? .orderedDescending : .orderedSame
        case "country":       cmp = a.country.localizedCaseInsensitiveCompare(b.country)
        default:              cmp = .orderedSame
        }
        return ascending ? cmp : (cmp == .orderedAscending ? .orderedDescending : cmp == .orderedDescending ? .orderedAscending : .orderedSame)
    }

    private var bottomTable: some View {
        NativeTableView(
            rows: sortedRows,
            selectedID: $viewModel.selectedNetworkID,
            sortOrder: $sortOrder,
            onToggleVisibility: { bssid in viewModel.toggleVisibility(bssid: bssid) }
        )
    }

    // MARK: - Section Info

    private struct SectionInfo {
        enum Kind { case band(BandChartViewModel); case table; case networkInfo }
        let kind: Kind
        let title: String
        let subtitle: String

        var isChart: Bool {
            if case .band = kind { return true }
            return false
        }

        var bandVM: BandChartViewModel? {
            if case .band(let vm) = kind { return vm }
            return nil
        }

        @ViewBuilder
        var icon: some View {
            switch kind {
            case .band(let vm):
                Circle()
                    .fill(vm.band == .band24GHz ? Color.blue.opacity(0.6)
                          : vm.band == .band5GHz ? Color.green.opacity(0.6)
                          : Color.purple.opacity(0.6))
                    .frame(width: 8, height: 8)
            case .networkInfo:
                Image(systemName: "wifi")
                    .font(.caption)
            case .table:
                Image(systemName: "tablecells")
                    .font(.caption)
            }
        }
    }

    private var visibleSections: [SectionInfo] {
        var sections: [SectionInfo] = []
        for vm in viewModel.bandViewModels {
            sections.append(SectionInfo(
                kind: .band(vm),
                title: vm.band.displayName,
                subtitle: "\(vm.allSeriesData.count) networks"
            ))
        }
        sections.append(SectionInfo(
            kind: .networkInfo,
            title: "Network Info",
            subtitle: viewModel.networkInfo?.displaySSID ?? "Disconnected"
        ))
        sections.append(SectionInfo(
            kind: .table,
            title: "Network Table",
            subtitle: "\(viewModel.combinedTableRows.count) rows"
        ))
        return sections
    }

    // MARK: - Collapse Helpers

    private func isCollapsed(_ section: SectionInfo) -> Bool {
        switch section.kind {
        case .band(let vm):
            switch vm.band {
            case .band24GHz: return is2GHzCollapsed
            case .band5GHz:  return is5GHzCollapsed
            case .band6GHz:  return is6GHzCollapsed
            }
        case .table: return isTableCollapsed
        case .networkInfo: return isNetworkInfoCollapsed
        }
    }

    private func toggleCollapse(_ section: SectionInfo) {
        switch section.kind {
        case .band(let vm):
            switch vm.band {
            case .band24GHz: is2GHzCollapsed.toggle()
            case .band5GHz:  is5GHzCollapsed.toggle()
            case .band6GHz:  is6GHzCollapsed.toggle()
            }
        case .table: isTableCollapsed.toggle()
        case .networkInfo: isNetworkInfoCollapsed.toggle()
        }
    }

    // MARK: - Network Info

    private var networkInfoContent: some View {
        guard let info = viewModel.networkInfo else {
            return AnyView(Text("No Wi-Fi connection").foregroundColor(.secondary))
        }
        let leftPairs: [(String, String)] = [
            ("SSID", info.displaySSID),
            ("BSSID", info.displayBSSID),
            ("Channel", info.displayChannel),
            ("RSSI", info.displayRSSI),
            ("Tx Rate", info.displayTxRate),
            ("PHY Mode", info.displayPhyMode),
        ]
        let rightPairs: [(String, String)] = [
            ("Security", info.displaySecurity),
            ("IP Address", info.displayIP),
            ("Subnet Mask", info.displaySubnet),
            ("Router", info.displayRouter),
            ("DNS", info.displayDNS),
            ("MAC", info.displayMAC),
        ]
        return AnyView(
            ScrollView {
                HStack(alignment: .top, spacing: 24) {
                    kvGrid(leftPairs)
                    kvGrid(rightPairs)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
        )
    }

    private func kvGrid(_ pairs: [(String, String)]) -> some View {
        LazyVGrid(columns: [GridItem(.fixed(80), alignment: .trailing), GridItem(.flexible(), alignment: .leading)], spacing: 2) {
            ForEach(pairs, id: \.0) { label, value in
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.caption)
            }
        }
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
                Text("Waiting for Location Services permission...").foregroundColor(.orange)
                Button("Open System Settings") { viewModel.locationManager.openLocationPreferences() }
            case .denied:
                Text("Location Services required.").foregroundColor(.secondary)
                Button("Open Location Preferences") { viewModel.locationManager.openLocationPreferences() }
            case .scanFailed(let msg):
                Text("Scan failed").foregroundColor(.secondary)
                Text(msg).font(.caption).foregroundColor(.secondary)
            case .scanning:
                Text("Scanning for Wi-Fi networks...").foregroundColor(.secondary)
            case .grantedButSSIDUnavailable:
                Text("SSID unavailable").foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}
