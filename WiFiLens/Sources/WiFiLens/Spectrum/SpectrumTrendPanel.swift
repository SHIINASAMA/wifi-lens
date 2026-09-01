import SwiftUI

struct SpectrumTrendPanel: View {
    let viewModel: ScannerViewModel
    let panelID: SpectrumPanelID
    @Binding var selectedNetworkID: String?

    var body: some View {
        Group {
            if let selID = selectedNetworkID,
               let snaps = selectedNetworkSnapshots(for: selID),
               let series = selectedNetworkSeries(for: selID),
               snaps.count >= 2 {
                TrendChartView(snapshots: snaps, color: series.color)
            } else {
                VStack {
                    Spacer()
                    Text(String(localized: "spectrum.panel.select_network_for_trend", comment: "Placeholder when no network is selected for trend chart"))
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Spacer()
                }
            }
        }
    }

    private func selectedNetworkSnapshots(for networkID: String) -> [NetworkSnapshot]? {
        for vm in viewModel.panelBandViewModels(for: panelID) {
            if let snaps = vm.snapshots(for: networkID) {
                return snaps
            }
        }
        return nil
    }

    private func selectedNetworkSeries(for networkID: String) -> ChartSeriesData? {
        for vm in viewModel.panelBandViewModels(for: panelID) {
            if let series = vm.series(for: networkID) {
                return series
            }
        }
        return nil
    }
}
