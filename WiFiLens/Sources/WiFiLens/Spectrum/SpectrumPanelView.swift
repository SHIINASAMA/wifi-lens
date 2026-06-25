import SwiftUI

struct SpectrumPanelView: View {
    let viewModel: ScannerViewModel
    @Binding var chartType: BandPanelSelection
    @Binding var selectedNetworkID: String?

    @State private var filterQuery: String = ""

    private var currentBandVM: BandChartViewModel {
        bandViewModel(for: chartType)
    }

    private var localFilteredSeries: [ChartSeriesData] {
        let needle = filterQuery.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else {
            return currentBandVM.visibleSeriesData()
        }
        return currentBandVM.visibleSeriesData().filter { series in
            series.ssid.lowercased().contains(needle)
                || series.bssid.lowercased().contains(needle)
        }
    }

    private var localRenderModel: BandChartRenderModel {
        let vm = currentBandVM
        let original = vm.renderModel
        let filtered = localFilteredSeries
        return BandChartRenderModel(
            xDataMin: original.xDataMin,
            xDataMax: original.xDataMax,
            yMin: original.yMin,
            visibleSeriesData: filtered,
            displayedSeriesData: filtered,
            strongestRSSI: Int(filtered.map(\.displayRSSI).max() ?? 0),
            isEmpty: filtered.isEmpty,
            zoomMin: original.zoomMin,
            zoomMax: original.zoomMax,
            isExpanded: original.isExpanded,
            axisTickStartChannel: original.axisTickStartChannel
        )
    }

    private var totalCount: Int {
        currentBandVM.visibleSeriesData().count
    }

    private var displayedCount: Int {
        localFilteredSeries.count
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

    // MARK: - Toolbar

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

            TextField(String(localized: "spectrum.panel.filter_placeholder", comment: "Filter input placeholder"), text: $filterQuery)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 300)

            if hiddenCount > 0 {
                Text("\(displayedCount)/\(totalCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if !filterQuery.isEmpty {
                Button {
                    filterQuery = ""
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

    // MARK: - Chart Content

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
            model: localRenderModel,
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

    // MARK: - Helpers

    private var supportedChartTypes: [BandPanelSelection] {
        var types: [BandPanelSelection] = []
        if viewModel.supportedBands.contains(.band24GHz) { types.append(.band24) }
        if viewModel.supportedBands.contains(.band5GHz) { types.append(.band5) }
        if viewModel.supportedBands.contains(.band6GHz) { types.append(.band6) }
        types.append(.trend)
        return types
    }

    private func bandViewModel(for selection: BandPanelSelection) -> BandChartViewModel {
        switch selection {
        case .band24: return viewModel.band24
        case .band5: return viewModel.band5
        case .band6: return viewModel.band6
        case .trend: return viewModel.band24 // fallback, won't be used
        }
    }

    private func selectedNetworkSnapshots(for networkID: String) -> [NetworkSnapshot]? {
        for vm in viewModel.bandViewModels {
            if let snaps = vm.snapshots(for: networkID) {
                return snaps
            }
        }
        return nil
    }

    private func selectedNetworkSeries(for networkID: String) -> ChartSeriesData? {
        for vm in viewModel.bandViewModels {
            if let series = vm.series(for: networkID) {
                return series
            }
        }
        return nil
    }
}
