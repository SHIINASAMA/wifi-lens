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
            Text("Collecting data…")
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

                let gridColor = Color.gray.opacity(0.15)

                // Y axis grid + labels
                for rssiVal in stride(from: Int(yMin), through: Int(yMax), by: 10) {
                    let y = chartRect.maxY - (Double(rssiVal) - yMin) * scaleY
                    var line = Path()
                    line.move(to: CGPoint(x: chartRect.minX, y: y))
                    line.addLine(to: CGPoint(x: chartRect.maxX, y: y))
                    context.stroke(line, with: .color(gridColor), lineWidth: 1)
                    context.draw(
                        Text("\(rssiVal)").font(.caption2).foregroundColor(.secondary),
                        at: CGPoint(x: chartRect.minX - 14, y: y)
                    )
                }

                // X axis time labels — show 4-5 evenly spaced ticks
                let now = snapshots.last?.timestamp ?? Date()
                let tickCount = min(5, max(2, snapshots.count))
                var drawnLabels: [CGFloat] = [] // avoid overlapping labels
                for t in 0..<tickCount {
                    let idx = t * (snapshots.count - 1) / max(1, tickCount - 1)
                    let x = chartRect.minX + CGFloat(idx) * scaleX
                    let secs = now.timeIntervalSince(snapshots[idx].timestamp)
                    let label = formatDuration(secs)
                    // simple overlap avoidance
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
                var xAxis = Path()
                xAxis.move(to: CGPoint(x: chartRect.minX, y: chartRect.maxY))
                xAxis.addLine(to: CGPoint(x: chartRect.maxX, y: chartRect.maxY))
                context.stroke(xAxis, with: .color(.secondary), lineWidth: 1)

                var yAxis = Path()
                yAxis.move(to: CGPoint(x: chartRect.minX, y: chartRect.minY))
                yAxis.addLine(to: CGPoint(x: chartRect.minX, y: chartRect.maxY))
                context.stroke(yAxis, with: .color(.secondary), lineWidth: 1)

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

    private func formatDuration(_ secs: TimeInterval) -> String {
        if secs < 1 { return "now" }
        if secs < 60 { return "\(Int(secs))s" }
        let m = Int(secs) / 60
        let s = Int(secs) % 60
        return "\(m):\(String(format: "%02d", s))"
    }
}
