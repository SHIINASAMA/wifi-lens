import SwiftUI

private let headerHeight: CGFloat = 28

struct ContentView: View {
    @Bindable var viewModel: ScannerViewModel

    @State private var sortOrder: [NSSortDescriptor] = [NSSortDescriptor(key: "ssid", ascending: true)]
    @State private var is2GHzCollapsed = false
    @State private var is5GHzCollapsed = false
    @State private var is6GHzCollapsed = false
    @State private var isTableCollapsed = false
    @State private var isTrendCollapsed = false
    @AppStorage("hiddenTableColumns") private var hiddenColumnsData: String = ""

    private var hiddenColumns: Binding<Set<String>> {
        Binding(
            get: { Set(hiddenColumnsData.split(separator: ",").map(String.init).filter { !$0.isEmpty }) },
            set: { hiddenColumnsData = $0.sorted().joined(separator: ",") }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            dashboardContent
        }
        .frame(minWidth: 700, idealWidth: 1000, minHeight: 600)
        .onChange(of: viewModel.hiddenBands) { _, _ in viewModel.applyGlobalFilterToBands() }
        .onChange(of: viewModel.hideHiddenSSIDs) { _, _ in viewModel.applyGlobalFilterToBands() }
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
            if case .trend = section.kind { return 0.5 }
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
                }
                .buttonStyle(.plain)
                .help(bandVM.isFrozen ? String(localized: "Resume") : String(localized: "Pause"))
            }

            Spacer()

            Text(section.subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .frame(height: headerHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation { toggleCollapse(section) }
        }
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

        case .trend(let snaps, let color):
            TrendChartView(snapshots: snaps, color: color)
                .frame(height: height)
                .padding(.horizontal, 6)

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
            Text(String(localized: "Show:"))
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            bandToggle(String(localized: "2.4 GHz"), bandID: "24")
            bandToggle(String(localized: "5 GHz"), bandID: "5")
            if viewModel.supportedBands.contains(.band6GHz) {
                bandToggle(String(localized: "6 GHz"), bandID: "6")
            }
            Text("·")
                .foregroundColor(.secondary)
            Toggle(isOn: $viewModel.hideHiddenSSIDs) {
                Text(String(localized: "Hide Hidden")).font(.system(size: 11))
            }
            .toggleStyle(.checkbox)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(.bar)
    }

    private func bandToggle(_ label: String, bandID: String) -> some View {
        let isOn = Binding(get: { !viewModel.hiddenBands.contains(bandID) },
                           set: { show in
            if show {
                viewModel.hiddenBands.remove(bandID)
            } else {
                viewModel.hiddenBands.insert(bandID)
            }
            // Collapse / expand matching chart section with animation
            withAnimation {
                switch bandID {
                case "24": is2GHzCollapsed = !show
                case "5":  is5GHzCollapsed = !show
                case "6":  is6GHzCollapsed = !show
                default: break
                }
            }
        })
        return Toggle(isOn: isOn) {
            Text(label).font(.system(size: 11))
        }
        .toggleStyle(.checkbox)
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
            onToggleVisibility: { bssid in viewModel.toggleVisibility(bssid: bssid) }
        )
    }

    // MARK: - Section Info

    private struct SectionInfo {
        enum Kind { case band(BandChartViewModel); case trend(snapshots: [NetworkSnapshot], color: Color); case table }
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
            case .trend:
                Image(systemName: "chart.line.uptrend.xyaxis")
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
                subtitle: String(localized: "\(vm.renderedNetworkCount) networks")
            ))
        }

        // Shared trend section — shows signal history for selected network across any band
        if let selID = viewModel.selectedNetworkID {
            for vm in viewModel.bandViewModels {
                if let snaps = vm.renderedSnapshots(for: selID),
                   let series = vm.renderedSeries(for: selID),
                   snaps.count >= 2 {
                    sections.append(SectionInfo(
                        kind: .trend(snapshots: snaps, color: series.color),
                        title: "\(series.displaySSID)  ·  \(vm.band.displayName)  ·  \(series.bssid)",
                        subtitle: String(localized: "\(snaps.count) samples")
                    ))
                    break
                }
            }
        }

        sections.append(SectionInfo(
            kind: .table,
            title: String(localized: "AP"),
            subtitle: String(localized: "\(tableRows.count) APs")
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
        case .trend: return isTrendCollapsed
        case .table: return isTableCollapsed
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
        case .trend: isTrendCollapsed.toggle()
        case .table: isTableCollapsed.toggle()
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
                Text(String(localized: "Waiting for Location Services permission...")).foregroundColor(.orange)
                Button(String(localized: "Open System Settings")) { viewModel.locationManager.openLocationPreferences() }
            case .denied:
                Text(String(localized: "Location Services required.")).foregroundColor(.secondary)
                Button(String(localized: "Open Location Preferences")) { viewModel.locationManager.openLocationPreferences() }
            case .scanFailed(let msg):
                Text(String(localized: "Scan failed")).foregroundColor(.secondary)
                Text(msg).font(.caption).foregroundColor(.secondary)
            default:
                EmptyView()
            }
            Spacer()
        }
    }
}
