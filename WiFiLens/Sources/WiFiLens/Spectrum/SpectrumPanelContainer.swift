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
        defaultBand: ChannelBand? = nil,
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
        self._band = State(initialValue: Self.initialBand(
            preferredBand: defaultBand,
            supportedBands: viewModel.supportedBands
        ))
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
    }

    private static func initialBand(
        preferredBand: ChannelBand?,
        supportedBands: Set<ChannelBand>
    ) -> ChannelBand {
        let preferredBand = preferredBand

        if let preferredBand, supportedBands.contains(preferredBand) {
            return preferredBand
        }

        return supportedBands.min { $0.rawValue < $1.rawValue } ?? .band24GHz
    }
}
