import SwiftUI

struct SpectrumPanelView: View {
    @Bindable var viewModel: ScannerViewModel
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

            switch chartType {
            case .band24, .band5, .band6:
                bandPanel.toolbarContent
            case .trend:
                EmptyView()
            case .table:
                tablePanel.toolbarContent
            }

            Spacer()
        }
        .frame(minHeight: 24)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.bar)
    }

    private var bandPanel: SpectrumBandPanel {
        SpectrumBandPanel(
            viewModel: viewModel,
            panelID: panelID,
            chartType: chartType,
            selectedNetworkID: $selectedNetworkID
        )
    }

    // MARK: - Chart Content

    @ViewBuilder
    private var chartContent: some View {
        switch chartType {
        case .band24, .band5, .band6:
            bandPanel
        case .trend:
            SpectrumTrendPanel(
                viewModel: viewModel,
                selectedNetworkID: $selectedNetworkID
            )
        case .table:
            tablePanel
        }
    }

    private var tablePanel: SpectrumTablePanel {
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
