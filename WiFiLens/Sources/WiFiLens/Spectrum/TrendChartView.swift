import SwiftUI
import ChartLens

struct TrendChartView: View {
    let snapshots: [NetworkSnapshot]
    let color: Color

    var body: some View {
        if snapshots.count < 2 {
            Text(String(localized: "common.label.collecting_data", comment: "Status shown while collecting sensor data"))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)
        } else {
            Chart(series: buildSeries(), axis: axisConfig, style: chartStyle)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private let chartStyle = ChartStyle(
        leftAxisWidth: 36,
        bottomAxisHeight: 20,
        marginTop: 8,
        marginRight: 8,
        marginBottom: 4
    )

    private var axisConfig: ChartAxisConfig {
        let values = snapshots.map(\.rssi)
        let dataMin = Double(values.min() ?? -90)
        let dataMax = Double(values.max() ?? -30)
        let headroom: Double = 6
        let now = snapshots.last?.timestamp ?? Date()

        var axis = ChartAxisConfig()
        axis.yMin = max(Double(Constants.rssiNoiseFloor), dataMin - headroom)
        axis.yMax = min(0.0, dataMax + headroom)
        axis.yStep = 10
        axis.yTickLabelOffset = 14

        // X-axis time labels
        let tickCount = min(5, max(2, snapshots.count))
        var ticks: [ChartAxisConfig.XTick] = []
        for t in 0..<tickCount {
            let idx = t * (snapshots.count - 1) / max(1, tickCount - 1)
            let secs = now.timeIntervalSince(snapshots[idx].timestamp)
            let label = chartDurationLabel(secs, zeroText: String(localized: "common.label.now", comment: "Just now timestamp indicator"))
            ticks.append(ChartAxisConfig.XTick(position: Double(idx), label: label))
        }
        axis.xTicks = ticks
        axis.xTickLabelOffset = 10
        return axis
    }

    private func buildSeries() -> [ChartSeries] {
        let points: [ChartPoint] = snapshots.enumerated().map { i, snap in
            ChartPoint(x: Double(i), y: Double(snap.rssi))
        }
        let style = ChartSeries.ChartSeriesStyle(
            color: color,
            lineWidth: 1.5,
            areaOpacity: 0.12,
            pointRadius: 2.0,
            strokeOpacity: 1.0,
            interpolation: .linear
        )
        return [ChartSeries(id: "trend", points: points, style: style)]
    }
}
