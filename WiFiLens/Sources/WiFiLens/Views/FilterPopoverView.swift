import SwiftUI

struct FilterPopoverView: View {
    @Bindable var viewModel: BandChartViewModel
    @Bindable var scannerViewModel: ScannerViewModel

    var body: some View {
        HStack(spacing: 8) {
            TextField("Filter by SSID or MAC/BSSID", text: $scannerViewModel.globalFilterQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)

            Button("Clear") {
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
