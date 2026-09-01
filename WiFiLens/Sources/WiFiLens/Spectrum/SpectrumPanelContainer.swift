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
    }

    var body: some View {
        SpectrumPanelView(
            viewModel: viewModel,
            panelID: panelID,
            isVendorColumnAvailable: isVendorColumnAvailable,
            chartType: $viewType,
            selectedNetworkID: $selectedNetworkID,
            sortOrder: $sortOrder,
            hiddenColumns: $hiddenColumns
        )
    }
}
