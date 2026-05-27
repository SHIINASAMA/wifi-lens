import SwiftUI

/// Canvas-based time-series chart showing RSSI over time for a selected BLE device.
/// Draws two lines: raw RSSI (thin, semi-transparent) and EMA-smoothed RSSI (thick, solid).
struct BLETrendChartView: View {
    let samples: [BLERSSISample]
    let color: Color

    private let chartHeight: CGFloat = 200
    private let leftAxisWidth: CGFloat = 36
    private let bottomAxisHeight: CGFloat = 20
    private let marginTop: CGFloat = 8

    var body: some View {
        if samples.count < 2 {
            Text(String(localized: "common.label.collecting_data", comment: "Status shown while collecting sensor data"))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(height: chartHeight)
        } else {
            Canvas { context, size in
                let chartRect = CGRect(
                    x: leftAxisWidth,
                    y: marginTop,
                    width: size.width - leftAxisWidth - 4,
                    height: chartHeight - marginTop - bottomAxisHeight
                )

                let rawValues = samples.map { Double($0.rawRSSI) }
                let yMin = (rawValues.min() ?? -100) - 10
                let yMax = (rawValues.max() ?? -30) + 10
                let clampedYMin = floor(yMin / 10) * 10
                let clampedYMax = ceil(yMax / 10) * 10
                let scaleY = chartRect.height / (clampedYMax - clampedYMin)
                let scaleX = samples.count > 1
                    ? chartRect.width / Double(samples.count - 1)
                    : chartRect.width

                // Y-axis grid
                drawYAxisGrid(
                    context: &context,
                    chartRect: chartRect,
                    yMin: clampedYMin,
                    yMax: clampedYMax,
                    scaleY: scaleY,
                    step: 10
                )

                // X-axis time labels
                if samples.count >= 2 {
                    let firstTime = samples.first!.timestamp
                    for i in 0..<min(4, samples.count) {
                        let idx = i * (samples.count - 1) / max(3, 1)
                        let clampedIdx = min(idx, samples.count - 1)
                        let elapsed = samples[clampedIdx].timestamp.timeIntervalSince(firstTime)
                        let x = chartRect.minX + Double(clampedIdx) * scaleX
                        let label = formatElapsed(elapsed)
                        context.draw(
                            Text(label).font(.caption2).foregroundColor(.secondary),
                            at: CGPoint(x: x, y: chartRect.maxY + 10)
                        )
                    }
                }

                drawAxes(context: &context, chartRect: chartRect)

                // Smoothed line (thick, solid)
                if samples.count >= 2 {
                    var smoothPath = Path()
                    for (i, s) in samples.enumerated() {
                        let x = chartRect.minX + Double(i) * scaleX
                        let y = chartRect.maxY - (s.smoothedRSSI - clampedYMin) * scaleY
                        if i == 0 { smoothPath.move(to: CGPoint(x: x, y: y)) }
                        else { smoothPath.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    context.stroke(smoothPath, with: .color(color), lineWidth: 1.5)

                    // Raw line (thin, transparent)
                    var rawPath = Path()
                    for (i, s) in samples.enumerated() {
                        let x = chartRect.minX + Double(i) * scaleX
                        let y = chartRect.maxY - (Double(s.rawRSSI) - clampedYMin) * scaleY
                        if i == 0 { rawPath.move(to: CGPoint(x: x, y: y)) }
                        else { rawPath.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    context.stroke(rawPath, with: .color(color.opacity(0.3)), lineWidth: 0.8)

                    // Fill area under smoothed line
                    var areaPath = smoothPath
                    areaPath.addLine(to: CGPoint(
                        x: chartRect.minX + Double(samples.count - 1) * scaleX,
                        y: chartRect.maxY
                    ))
                    areaPath.addLine(to: CGPoint(x: chartRect.minX, y: chartRect.maxY))
                    areaPath.closeSubpath()
                    context.fill(areaPath, with: .color(color.opacity(0.08)))
                }
            }
            .frame(height: chartHeight)
        }
    }

    private func formatElapsed(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            "\(Int(seconds))s"
        } else {
            "\(Int(seconds / 60))m"
        }
    }
}
