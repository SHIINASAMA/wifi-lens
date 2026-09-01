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
                bandToolbar
            case .trend:
                EmptyView()
            case .table:
                tableToolbar
            }

            Spacer()
        }
        .frame(minHeight: 24)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.bar)
    }

    private var bandToolbar: some View {
        let bandPanel = SpectrumBandPanel(
            viewModel: viewModel,
            panelID: panelID,
            chartType: chartType,
            selectedNetworkID: $selectedNetworkID
        )
        return HStack(spacing: 8) {
            TextField(String(localized: "spectrum.panel.filter_placeholder", comment: "Filter input placeholder"), text: bandPanel.filterQueryBinding)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 300)

            if bandPanel.hiddenCount > 0 {
                Text("\(bandPanel.displayedCount)/\(bandPanel.totalCount)")
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            if !bandPanel.filterQueryBinding.wrappedValue.isEmpty {
                Button {
                    bandPanel.filterQueryBinding.wrappedValue = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "spectrum.filter.clear", comment: "Clear filter button"))
                .help(String(localized: "spectrum.filter.clear", comment: "Clear filter button"))
            }
        }
    }

    private var tableToolbar: some View {
        HStack(spacing: 12) {
            Toggle(isOn: $viewModel.hideHiddenSSIDs) {
                Text(String(localized: "spectrum.filter.hide_hidden", comment: "Toggle to hide networks with hidden SSIDs"))
                    .font(.body)
            }
            .toggleStyle(.checkbox)
            .controlSize(.regular)

            if !viewModel.combinedTableRows.isEmpty {
                Text(String(format: String(localized: "spectrum.panel.table_count_fmt", comment: "Network count in table toolbar"), viewModel.combinedTableRows.count))
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .frame(minHeight: 24)
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
