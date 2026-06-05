import SwiftUI

private let headerHeight: CGFloat = 28

#if PRO
private enum SpectrumMode { case live, recording }
#endif

struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var viewModel: ScannerViewModel

    @State private var sortOrder: [NSSortDescriptor] = [NSSortDescriptor(key: "ssid", ascending: true)]
    @State private var is2GHzCollapsed = false
    @State private var is5GHzCollapsed = false
    @State private var is6GHzCollapsed = false
    @State private var isTableCollapsed = false
    @State private var isTrendCollapsed = false
    @AppStorage("hiddenTableColumns") private var hiddenColumnsData: String = ""

#if PRO
    @State private var mode: SpectrumMode = .live
    @State private var recordingViewModel: RecordingViewModel?
#endif

    private var hiddenColumns: Binding<Set<String>> {
        Binding(
            get: { Set(hiddenColumnsData.split(separator: ",").map(String.init).filter { !$0.isEmpty }) },
            set: { hiddenColumnsData = $0.sorted().joined(separator: ",") }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
#if PRO
            modeToolbar
#endif
            contentArea
        }
        .frame(minWidth: 700, idealWidth: 1000, minHeight: 600)
        .onChange(of: viewModel.hiddenBands) { _, _ in viewModel.applyGlobalFilterToBands() }
        .onChange(of: viewModel.hideHiddenSSIDs) { _, _ in viewModel.applyGlobalFilterToBands() }
#if PRO
        .onChange(of: mode) { _, newMode in
            if newMode == .recording {
                if recordingViewModel == nil {
                    recordingViewModel = RecordingViewModel(scannerViewModel: viewModel)
                }
                recordingViewModel?.checkReadiness()
            }
        }
#endif
    }

    // MARK: - Mode toolbar (Pro only)

#if PRO
    private var modeToolbar: some View {
        HStack {
            Picker("", selection: $mode.animation(reduceMotion ? nil : .bouncy)) {
                Text(String(localized: "spectrum.mode.live", comment: "Live spectrum mode")).tag(SpectrumMode.live)
                Text(String(localized: "spectrum.mode.recording_page", comment: "Recording page mode")).tag(SpectrumMode.recording)
            }
            .pickerStyle(.segmented)
            .controlSize(.regular)
            .frame(width: 160)
            .accessibilityLabel(String(localized: "spectrum.mode.label", comment: "Spectrum view mode picker"))
            .accessibilityIdentifier("spectrum-mode-picker")
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
#endif

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
            }
        }
#else
        dashboardContent
#endif
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
                .font(.callout.weight(.semibold))

            Spacer()

            Text(section.subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .frame(height: headerHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(reduceMotion ? nil : .default) { toggleCollapse(section) }
        }
    }

    // MARK: - Section Content

    @ViewBuilder
    private func sectionContent(_ section: SectionInfo, height: CGFloat) -> some View {
        switch section.kind {
        case .band(let bandVM):
            WiFiBandChart(
                model: bandVM.renderModel,
                selectedNetworkID: $viewModel.selectedNetworkID,
                onResetZoom: { bandVM.resetZoom() },
                onToggleExpand: { bandVM.toggleExpand() },
                onApplyZoom: { lo, hi in bandVM.applyZoom(lo: lo, hi: hi) }
            )
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
            Text(String(localized: "spectrum.filter.show_label", comment: "Label for band filter checkboxes"))
                .font(.caption)
                .foregroundColor(.secondary)
            bandToggle(String(localized: "wifi.band.24ghz", comment: "2.4 GHz Wi-Fi band name"), bandID: "24")
            bandToggle(String(localized: "wifi.band.5ghz", comment: "5 GHz Wi-Fi band name"), bandID: "5")
            if viewModel.supportedBands.contains(.band6GHz) {
                bandToggle(String(localized: "wifi.band.6ghz", comment: "6 GHz Wi-Fi band name"), bandID: "6")
            }
            Text("·")
                .foregroundColor(.secondary)
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

    private func bandToggle(_ label: String, bandID: String) -> some View {
        let isOn = Binding(get: { !viewModel.hiddenBands.contains(bandID) },
                           set: { show in
            if show {
                viewModel.hiddenBands.remove(bandID)
            } else {
                viewModel.hiddenBands.insert(bandID)
            }
            // Collapse / expand matching chart section with animation
            withAnimation(reduceMotion ? nil : .default) {
                switch bandID {
                case "24": is2GHzCollapsed = !show
                case "5":  is5GHzCollapsed = !show
                case "6":  is6GHzCollapsed = !show
                default: break
                }
            }
        })
        return Toggle(isOn: isOn) {
            Text(label).font(.caption)
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
            onToggleVisibility: { bssid in viewModel.toggleVisibility(bssid: bssid) }
        )
    }

    // MARK: - Section Info

    private struct SectionInfo {
        enum Kind { case band(BandChartViewModel); case trend(snapshots: [NetworkSnapshot], color: Color); case table }
        let kind: Kind
        let title: String
        let subtitle: String

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
                subtitle: String(format: String(localized: "spectrum.trend.network_count_fmt", comment: "Network count for trend chart"), vm.networkCount)
            ))
        }

        // Shared trend section — shows signal history for selected network across any band
        if let selID = viewModel.selectedNetworkID {
            for vm in viewModel.bandViewModels {
                if let snaps = vm.snapshots(for: selID),
                   let series = vm.series(for: selID),
                   snaps.count >= 2 {
                    sections.append(SectionInfo(
                        kind: .trend(snapshots: snaps, color: series.color),
                        title: "\(series.displaySSID)  ·  \(vm.band.displayName)  ·  \(series.bssid)",
                        subtitle: String(format: String(localized: "format.sample_count", comment: "Sample count with number"), snaps.count)
                    ))
                    break
                }
            }
        }

        sections.append(SectionInfo(
            kind: .table,
            title: String(localized: "spectrum.table.ap_label", comment: "Access Point abbreviation (singular)"),
            subtitle: String(format: String(localized: "spectrum.table.ap_count_fmt", comment: "Access Point count with number"), tableRows.count)
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
