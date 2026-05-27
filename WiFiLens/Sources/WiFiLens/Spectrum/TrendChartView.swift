import SwiftUI

struct TrendChartView: View {
    let snapshots: [NetworkSnapshot]
    let color: Color

    private let leftAxisWidth: CGFloat = 36
    private let bottomAxisHeight: CGFloat = 20
    private let marginTop: CGFloat = 8
    private let marginRight: CGFloat = 8
    private let marginBottom: CGFloat = 4

    var body: some View {
        if snapshots.count < 2 {
            Text(String(localized: "common.label.collecting_data", comment: "Status shown while collecting sensor data"))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)
        } else {
            Canvas { context, size in
                let chartRect = CGRect(
                    x: leftAxisWidth, y: marginTop,
                    width: size.width - leftAxisWidth - marginRight,
                    height: size.height - bottomAxisHeight - marginTop - marginBottom
                )

                let values = snapshots.map(\.rssi)
                let dataMax = Double(values.max() ?? -30)
                let dataMin = Double(values.min() ?? -90)
                let headroom: Double = 6
                let yMax = min(0.0, dataMax + headroom)
                let yMin = max(Double(Constants.rssiNoiseFloor), dataMin - headroom)

                let scaleX = chartRect.width / CGFloat(max(1, snapshots.count - 1))
                let scaleY = chartRect.height / (yMax - yMin)

                // Y axis grid + labels
                drawYAxisGrid(context: &context, chartRect: chartRect, yMin: yMin, yMax: yMax, scaleY: scaleY)

                // X axis time labels — show 4-5 evenly spaced ticks
                let now = snapshots.last?.timestamp ?? Date()
                let tickCount = min(5, max(2, snapshots.count))
                var drawnLabels: [CGFloat] = []
                for t in 0..<tickCount {
                    let idx = t * (snapshots.count - 1) / max(1, tickCount - 1)
                    let x = chartRect.minX + CGFloat(idx) * scaleX
                    let secs = now.timeIntervalSince(snapshots[idx].timestamp)
                    let label = chartDurationLabel(secs, zeroText: String(localized: "common.label.now", comment: "Just now timestamp indicator"))
                    let overlaps = drawnLabels.contains(where: { abs($0 - x) < 32 })
                    if !overlaps {
                        drawnLabels.append(x)
                        context.draw(
                            Text(label).font(.caption2).foregroundColor(.secondary),
                            at: CGPoint(x: x, y: chartRect.maxY + 10)
                        )
                    }
                }

                // Axes
                drawAxes(context: &context, chartRect: chartRect)

                // Build polyline + fill path
                var line = Path()
                var fill = Path()
                let firstX = chartRect.minX
                let firstY = chartRect.maxY - (Double(snapshots[0].rssi) - yMin) * scaleY
                line.move(to: CGPoint(x: firstX, y: firstY))
                fill.move(to: CGPoint(x: firstX, y: chartRect.maxY))
                fill.addLine(to: CGPoint(x: firstX, y: firstY))

                for i in 1..<snapshots.count {
                    let sx = chartRect.minX + CGFloat(i) * scaleX
                    let sy = chartRect.maxY - (Double(snapshots[i].rssi) - yMin) * scaleY
                    line.addLine(to: CGPoint(x: sx, y: sy))
                    fill.addLine(to: CGPoint(x: sx, y: sy))
                }

                let lastX = chartRect.minX + CGFloat(snapshots.count - 1) * scaleX
                fill.addLine(to: CGPoint(x: lastX, y: chartRect.maxY))
                fill.closeSubpath()

                context.fill(fill, with: .color(color.opacity(0.12)))
                context.stroke(line, with: .color(color), lineWidth: 1.5)

                // Data dots
                for i in 0..<snapshots.count {
                    let dx = chartRect.minX + CGFloat(i) * scaleX
                    let dy = chartRect.maxY - (Double(snapshots[i].rssi) - yMin) * scaleY
                    let r: CGFloat = 2.0
                    context.fill(
                        Path(ellipseIn: CGRect(x: dx - r, y: dy - r, width: r * 2, height: r * 2)),
                        with: .color(color)
                    )
                }
            }
            .frame(height: 100)
        }
    }
}
