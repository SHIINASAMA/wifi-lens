import SwiftUI

struct SpectrumTablePanel: View {
    @Bindable var viewModel: ScannerViewModel
    let isVendorColumnAvailable: Bool
    @Binding var sortOrder: [NSSortDescriptor]
    @Binding var hiddenColumns: Set<String>

    var body: some View {
        tableContent
    }

    private var tableContent: some View {
        NativeTableView(
            rows: NetworkTableRowSorter.sort(
                viewModel.combinedTableRows,
                by: sortOrder
            ),
            selectedID: $viewModel.selectedNetworkID,
            sortOrder: $sortOrder,
            hiddenColumns: $hiddenColumns,
            isVendorColumnAvailable: isVendorColumnAvailable,
            onToggleVisibility: { seriesID in viewModel.toggleVisibility(seriesID: seriesID) },
            onToggleVisibilityLocked: { seriesID in viewModel.toggleVisibilityLocked(seriesID: seriesID) }
        )
    }
}
