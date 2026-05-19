import SwiftUI

struct ThroughputChartView: View {
    let samples: [ThroughputSample]
    let interfaceName: String

    private let leftAxisWidth: CGFloat = 44
    private let bottomAxisHeight: CGFloat = 24
    private let marginTop: CGFloat = 8
    private let marginRight: CGFloat = 8
    private let marginBottom: CGFloat = 4

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Circle().fill(.green).frame(width: 6, height: 6)
                    Text(String(localized: "Download"))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 4) {
                    Circle().fill(.blue).frame(width: 6, height: 6)
                    Text(String(localized: "Upload"))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(interfaceName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, leftAxisWidth + 4)
            .padding(.bottom, 2)

            if samples.count < 2 {
                Spacer()
                Text(String(localized: "Collecting data…"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                Canvas { context, size in
                    let chartRect = CGRect(
                        x: leftAxisWidth, y: marginTop,
                        width: size.width - leftAxisWidth - marginRight,
                        height: size.height - bottomAxisHeight - marginTop - marginBottom
                    )

                    let values = samples.flatMap { [$0.rateIn, $0.rateOut] }
                    let dataMax = values.max() ?? 1
                    let yMax = max(dataMax * 1.15, 1_024.0) // at least 1 KB/s headroom
                    let yMin: Double = 0

                    let totalSecs = samples.last.map { $0.timestamp.timeIntervalSince(samples[0].timestamp) } ?? 1
                    let xMax = Double(samples.count - 1)
                    let xMin: Double = 0

                    let scaleX = chartRect.width / max(1, xMax - xMin)
                    let scaleY = chartRect.height / max(1, yMax - yMin)

                    // Grid + Y axis labels
                    let gridColor = Color.gray.opacity(0.15)
                    let tickCount = 4
                    for t in 0...tickCount {
                        let frac = Double(t) / Double(tickCount)
                        let yVal = yMin + (yMax - yMin) * frac
                        let y = chartRect.maxY - (yVal - yMin) * scaleY

                        var line = Path()
                        line.move(to: CGPoint(x: chartRect.minX, y: y))
                        line.addLine(to: CGPoint(x: chartRect.maxX, y: y))
                        context.stroke(line, with: .color(gridColor), lineWidth: 1)

                        context.draw(
                            Text(rateAxisLabel(yVal)).font(.caption2).foregroundColor(.secondary),
                            at: CGPoint(x: chartRect.minX - 22, y: y)
                        )
                    }

                    // X axis time labels
                    let duration = samples.last.map { $0.timestamp.timeIntervalSince(samples[0].timestamp) } ?? 0
                    let tickSeconds = niceTickInterval(seconds: duration)
                    if tickSeconds > 0, let startTime = samples.first?.timestamp {
                        var lastLabelX: CGFloat = -100
                        for i in 0..<samples.count {
                            let elapsed = samples[i].timestamp.timeIntervalSince(startTime)
                            let labelSecs = (elapsed / tickSeconds).rounded() * tickSeconds
                            let idx = Int(labelSecs / tickSeconds)
                            let x = chartRect.minX + CGFloat(i) * scaleX
                            if x - lastLabelX > 36 {
                                lastLabelX = x

                                var tick = Path()
                                tick.move(to: CGPoint(x: x, y: chartRect.maxY))
                                tick.addLine(to: CGPoint(x: x, y: chartRect.maxY + 4))
                                context.stroke(tick, with: .color(.secondary.opacity(0.3)), lineWidth: 1)

                                let label = elapsed < 60
                                    ? "-\(Int(elapsed))s"
                                    : "-\(Int(elapsed / 60))m"
                                context.draw(
                                    Text(label).font(.caption2).foregroundColor(.secondary),
                                    at: CGPoint(x: x, y: chartRect.maxY + 14)
                                )
                            }
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

                    // Data lines
                    func drawLine(rate: (ThroughputSample) -> Double, color: Color) {
                        var path = Path()
                        var first = true
                        for i in 0..<samples.count {
                            let x = chartRect.minX + CGFloat(i) * scaleX
                            let r = rate(samples[i])
                            let y = chartRect.maxY - (r - yMin) * scaleY
                            if first { path.move(to: CGPoint(x: x, y: y)); first = false }
                            else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                        context.stroke(path, with: .color(color), lineWidth: 2)
                    }

                    drawLine(rate: { $0.rateIn }, color: .green)
                    drawLine(rate: { $0.rateOut }, color: .blue)
                }
            }
        }
    }

    private func rateAxisLabel(_ bytesPerSec: Double) -> String {
        if bytesPerSec < 1_024 { return "0" }
        if bytesPerSec < 10_240 { return String(format: "%.0fK", bytesPerSec / 1_024) }
        if bytesPerSec < 1_048_576 { return String(format: "%.0fK", bytesPerSec / 1_024) }
        return String(format: "%.1fM", bytesPerSec / 1_048_576)
    }

    private func niceTickInterval(seconds: Double) -> Double {
        if seconds <= 10 { return 2 }
        if seconds <= 30 { return 5 }
        if seconds <= 60 { return 10 }
        if seconds <= 120 { return 30 }
        return 60
    }
}
