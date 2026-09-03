import SwiftUI

struct SpectrumPanelContainer: View {
    let viewModel: ScannerViewModel
    let panelID: SpectrumPanelID
    let isVendorColumnAvailable: Bool
    let defaultViewType: SpectrumPanelViewType
    @Binding var selectedNetworkID: String?
    @Binding var sortOrder: [NSSortDescriptor]
    @Binding var hiddenColumns: Set<String>
    @State private var viewType: SpectrumPanelViewType
    @State private var band: ChannelBand

    init(
        viewModel: ScannerViewModel,
        panelID: SpectrumPanelID,
        isVendorColumnAvailable: Bool,
        defaultViewType: SpectrumPanelViewType,
        selectedNetworkID: Binding<String?>,
        sortOrder: Binding<[NSSortDescriptor]>,
        hiddenColumns: Binding<Set<String>>
    ) {
        self.viewModel = viewModel
        self.panelID = panelID
        self.isVendorColumnAvailable = isVendorColumnAvailable
        self.defaultViewType = defaultViewType
        self._selectedNetworkID = selectedNetworkID
        self._sortOrder = sortOrder
        self._hiddenColumns = hiddenColumns
        self._viewType = State(initialValue: defaultViewType)
        self._band = State(initialValue: Self.initialBand(for: defaultViewType, supportedBands: viewModel.supportedBands))
    }

    var body: some View {
        SpectrumPanelView(
            viewModel: viewModel,
            panelID: panelID,
            isVendorColumnAvailable: isVendorColumnAvailable,
            band: $band,
            chartType: $viewType,
            selectedNetworkID: $selectedNetworkID,
            sortOrder: $sortOrder,
            hiddenColumns: $hiddenColumns
        )
        .onChange(of: viewType) { _, newType in
            switch newType {
            case .band24: band = .band24GHz
            case .band5: band = .band5GHz
            case .band6: band = .band6GHz
            case .trend, .table, .heatmap: break
            }
        }
    }

    /// The band the heatmap shows: the panel's current band selection if it is a
    /// band case, otherwise the first supported band (covers `.table`/`.trend`
    /// defaults such as Panel3). `ChannelBand` raw values are 1/2/3, so `min`
    /// orders 2.4 GHz first.
    private static func initialBand(
        for viewType: SpectrumPanelViewType,
        supportedBands: Set<ChannelBand>
    ) -> ChannelBand {
        switch viewType {
        case .band24: return .band24GHz
        case .band5: return .band5GHz
        case .band6: return .band6GHz
        case .trend, .table, .heatmap:
            return supportedBands.min { $0.rawValue < $1.rawValue } ?? .band24GHz
        }
    }
}
