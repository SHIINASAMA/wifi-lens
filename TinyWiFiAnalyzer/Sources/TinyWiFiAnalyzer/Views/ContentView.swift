import SwiftUI

private let headerHeight: CGFloat = 28
private let toolbarHeight: CGFloat = 34

struct ContentView: View {
    @Bindable var viewModel: ScannerViewModel
    @Environment(\.scenePhase) private var scenePhase

    @State private var sortOrder: [NSSortDescriptor] = [NSSortDescriptor(key: "ssid", ascending: true)]
    @State private var is2GHzCollapsed = false
    @State private var is5GHzCollapsed = false
    @State private var is6GHzCollapsed = false
    @State private var isTableCollapsed = false

    var body: some View {
        VStack(spacing: 0) {
            unifiedToolbar
            Divider()
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

    // MARK: - Unified Toolbar

    private var unifiedToolbar: some View {
        HStack(spacing: 8) {
            TextField("Filter by SSID or BSSID…", text: $viewModel.globalFilterQuery)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 300)

            if !viewModel.globalFilterQuery.isEmpty {
                Button("Clear") {
                    viewModel.globalFilterQuery = ""
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            if viewModel.interfaceName.isEmpty == false {
                Text(viewModel.interfaceName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: toolbarHeight)
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

        case .table:
            bottomTable
                .frame(height: height)
        }
    }

    // MARK: - Bottom Table (shared)

    private var sortedRows: [NetworkTableRow] {
        guard !sortOrder.isEmpty else { return viewModel.combinedTableRows }
        return viewModel.combinedTableRows.sorted { a, b in
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
        case "bssid":      cmp = a.bssid.localizedCaseInsensitiveCompare(b.bssid)
        default:           cmp = .orderedSame
        }
        return ascending ? cmp : (cmp == .orderedAscending ? .orderedDescending : cmp == .orderedDescending ? .orderedAscending : .orderedSame)
    }

    private var bottomTable: some View {
        NativeTableView(
            rows: sortedRows,
            selectedID: $viewModel.selectedNetworkID,
            sortOrder: $sortOrder
        )
    }

    // MARK: - Section Info

    private struct SectionInfo {
        enum Kind { case band(BandChartViewModel); case table }
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
