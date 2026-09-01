import SwiftUI

struct SpectrumTablePanel: View {
    @Bindable var viewModel: ScannerViewModel
    let isVendorColumnAvailable: Bool
    @Binding var sortOrder: [NSSortDescriptor]
    @Binding var hiddenColumns: Set<String>

    var body: some View {
        VStack(spacing: 0) {
            tableToolbar
            tableContent
        }
        .padding(.trailing, 8)
    }

    private var tableToolbar: some View {
        HStack(spacing: 12) {
            Toggle(isOn: $viewModel.hideHiddenSSIDs) {
                Text(String(localized: "spectrum.filter.hide_hidden", comment: "Toggle to hide networks with hidden SSIDs"))
                    .font(.caption)
            }
            .toggleStyle(.checkbox)

            if !viewModel.combinedTableRows.isEmpty {
                Text("\(viewModel.combinedTableRows.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(.bar)
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
