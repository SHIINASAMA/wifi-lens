import SwiftUI

struct SpectrumBandPanel: View {
    let viewModel: ScannerViewModel
    let panelID: SpectrumPanelID
    let chartType: SpectrumPanelViewType
    @Binding var selectedNetworkID: String?

    var bandVM: BandChartViewModel {
        viewModel.bandViewModel(for: panelID, selection: chartType)
    }

    var filterQueryBinding: Binding<String> {
        Binding(
            get: { viewModel.filterQuery(for: panelID) },
            set: { viewModel.setFilterQuery($0, for: panelID) }
        )
    }

    var totalCount: Int {
        bandVM.networkCount
    }

    var displayedCount: Int {
        bandVM.visibleSeriesData().count
    }

    var hiddenCount: Int {
        totalCount - displayedCount
    }

    var body: some View {
        chart
    }

    private var chart: some View {
        WiFiBandChart(
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
}
