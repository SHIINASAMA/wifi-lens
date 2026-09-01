import SwiftUI

struct SpectrumPanelView: View {
    let viewModel: ScannerViewModel
    let panelID: SpectrumPanelID
    let isVendorColumnAvailable: Bool
    @Binding var chartType: SpectrumPanelViewType
    @Binding var selectedNetworkID: String?
    @Binding var sortOrder: [NSSortDescriptor]
    @Binding var hiddenColumns: Set<String>

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
                ForEach(supportedViewTypes) { type in
                    Text(type.displayName)
                        .lineLimit(1)
                        .tag(type)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 180)

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
            SpectrumBandPanel(
                viewModel: viewModel,
                panelID: panelID,
                chartType: chartType,
                selectedNetworkID: $selectedNetworkID
            )
        case .trend:
            SpectrumTrendPanel(
                viewModel: viewModel,
                panelID: panelID,
                selectedNetworkID: $selectedNetworkID
            )
        case .table:
            tablePanel
        }
    }

    private var tablePanel: some View {
        SpectrumTablePanel(
            viewModel: viewModel,
            isVendorColumnAvailable: isVendorColumnAvailable,
            sortOrder: $sortOrder,
            hiddenColumns: $hiddenColumns
        )
    }

    // MARK: - Helpers

    var supportedViewTypes: [SpectrumPanelViewType] {
        var types: [SpectrumPanelViewType] = []
        if viewModel.supportedBands.contains(.band24GHz) { types.append(.band24) }
        if viewModel.supportedBands.contains(.band5GHz) { types.append(.band5) }
        if viewModel.supportedBands.contains(.band6GHz) { types.append(.band6) }
        types.append(.trend)
        types.append(.table)
        return types
    }

}
