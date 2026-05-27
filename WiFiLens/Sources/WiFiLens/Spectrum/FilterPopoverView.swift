import SwiftUI

struct FilterPopoverView: View {
    @Bindable var viewModel: BandChartViewModel
    @Bindable var scannerViewModel: ScannerViewModel

    var body: some View {
        HStack(spacing: 8) {
            TextField(String(localized: "spectrum.filter.placeholder", comment: "Filter field placeholder text"), text: $scannerViewModel.globalFilterQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)

            Button(String(localized: "common.action.clear", comment: "Clear input or filter button")) {
                scannerViewModel.globalFilterQuery = ""
                viewModel.showFilterPopover = false
            }
            .font(.system(size: 11))
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
        }
        .padding(8)
        .frame(width: 300)
    }
}
