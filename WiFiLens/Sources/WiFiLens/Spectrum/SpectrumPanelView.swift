import SwiftUI

struct SpectrumPanelView: View {
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
