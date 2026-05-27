import SwiftUI

struct ThroughputChartView: View {
    let samples: [ThroughputSample]
    let interfaceName: String

    private let leftAxisWidth: CGFloat = 48
    private let bottomAxisHeight: CGFloat = 26
    private let marginTop: CGFloat = 10
    private let marginRight: CGFloat = 10
    private let marginBottom: CGFloat = 6

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Circle().fill(.green).frame(width: 6, height: 6)
                    Text(String(localized: "common.label.download", comment: "Download/throughput receive label"))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 4) {
                    Circle().fill(.blue).frame(width: 6, height: 6)
                    Text(String(localized: "common.label.upload", comment: "Upload/throughput send label"))
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
                Text(String(localized: "common.label.collecting_data", comment: "Status shown while collecting sensor data"))
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

                    let centerY = chartRect.midY

                    let maxUp = samples.map(\.rateOut).max() ?? 1
                    let maxDown = samples.map(\.rateIn).max() ?? 1
                    let maxRate = max(maxUp, maxDown, 1_024) * 1.15
                    // Y range: +maxRate (top, upload) → -maxRate (bottom, download)
                    let yRange = maxRate * 2
                    let scaleY = chartRect.height / yRange
                    let scaleX = chartRect.width / CGFloat(max(1, samples.count - 1))

                    // Grid
                    let gridColor = Color.gray.opacity(0.12)
                    let tickCount = 4
                    for t in 0...tickCount {
                        let rate = maxRate * Double(t) / Double(tickCount)
                        // Positive (upload) grid line
                        let yTop = centerY - rate * scaleY
                        // Negative (download) grid line
                        let yBot = centerY + rate * scaleY

                        if t == 0 {
                            // Center line — slightly stronger
                            var cl = Path()
                            cl.move(to: CGPoint(x: chartRect.minX, y: centerY))
                            cl.addLine(to: CGPoint(x: chartRect.maxX, y: centerY))
                            context.stroke(cl, with: .color(gridColor), lineWidth: 1)
                        } else {
                            var gl = Path()
                            gl.move(to: CGPoint(x: chartRect.minX, y: yTop))
                            gl.addLine(to: CGPoint(x: chartRect.maxX, y: yTop))
                            context.stroke(gl, with: .color(gridColor), lineWidth: 1)

                            var g2 = Path()
                            g2.move(to: CGPoint(x: chartRect.minX, y: yBot))
                            g2.addLine(to: CGPoint(x: chartRect.maxX, y: yBot))
                            context.stroke(g2, with: .color(gridColor), lineWidth: 1)
                        }

                        if t > 0 {
                            let label = rateLabel(rate)
                            context.draw(
                                Text(label).font(.system(size: 8)).foregroundColor(.secondary),
                                at: CGPoint(x: chartRect.minX - 24, y: yTop)
                            )
                            if t < tickCount {
                                context.draw(
                                    Text(label).font(.system(size: 8)).foregroundColor(.secondary),
                                    at: CGPoint(x: chartRect.minX - 24, y: yBot)
                                )
                            }
                        }
                    }

                    // Center "0" label
                    context.draw(
                        Text("0").font(.system(size: 8)).foregroundColor(.secondary),
                        at: CGPoint(x: chartRect.minX - 10, y: centerY)
                    )

                    // X axis time labels — index-based, evenly spaced
                    let now = samples.last?.timestamp ?? Date()
                    let tickIndices = evenlySpacedTickIndices(count: samples.count, targetCount: min(6, max(3, samples.count / 15)))
                    var lastLabelX: CGFloat = -100
                    for idx in tickIndices {
                        let x = chartRect.minX + CGFloat(idx) * scaleX
                        if x - lastLabelX > 40 {
                            lastLabelX = x
                            let secs = now.timeIntervalSince(samples[idx].timestamp)
                            let label = chartDurationLabel(secs)

                            var tick = Path()
                            tick.move(to: CGPoint(x: x, y: centerY - 3))
                            tick.addLine(to: CGPoint(x: x, y: centerY + 3))
                            context.stroke(tick, with: .color(.secondary.opacity(0.25)), lineWidth: 1)

                            context.draw(
                                Text(label).font(.system(size: 8)).foregroundColor(.secondary),
                                at: CGPoint(x: x, y: chartRect.maxY + 14)
                            )
                        }
                    }

                    // Axes
                    var xAxis = Path()
                    xAxis.move(to: CGPoint(x: chartRect.minX, y: centerY))
                    xAxis.addLine(to: CGPoint(x: chartRect.maxX, y: centerY))
                    context.stroke(xAxis, with: .color(.secondary.opacity(0.5)), lineWidth: 1)

                    var yAxis = Path()
                    yAxis.move(to: CGPoint(x: chartRect.minX, y: chartRect.minY))
                    yAxis.addLine(to: CGPoint(x: chartRect.minX, y: chartRect.maxY))
                    context.stroke(yAxis, with: .color(.secondary.opacity(0.5)), lineWidth: 1)

                    // --- Download area (below center, green fill) ---
                    drawCurvedArea(
                        context: &context,
                        points: samples.enumerated().map { i, s in
                            let y = centerY + s.rateIn * scaleY
                            return CGPoint(x: chartRect.minX + CGFloat(i) * scaleX, y: max(centerY, y))
                        },
                        baseline: centerY,
                        color: .green
                    )

                    // --- Upload area (above center, blue fill) ---
                    drawCurvedArea(
                        context: &context,
                        points: samples.enumerated().map { i, s in
                            let y = centerY - s.rateOut * scaleY
                            return CGPoint(x: chartRect.minX + CGFloat(i) * scaleX, y: min(centerY, y))
                        },
                        baseline: centerY,
                        color: .blue
                    )
                }
            }
        }
    }

    // MARK: - Curve Fill

    private func drawCurvedArea(
        context: inout GraphicsContext,
        points: [CGPoint],
        baseline: CGFloat,
        color: Color
    ) {
        guard points.count >= 2 else { return }

        let curve = clampedCubicSpline(points: points)

        var fill = Path()
        fill.addPath(curve)
        fill.addLine(to: CGPoint(x: points.last!.x, y: baseline))
        fill.addLine(to: CGPoint(x: points.first!.x, y: baseline))
        fill.closeSubpath()

        context.fill(fill, with: .color(color.opacity(0.18)))
        context.stroke(curve, with: .color(color.opacity(0.7)), lineWidth: 1.5)
    }

    private func rateLabel(_ bytesPerSec: Double) -> String {
        if bytesPerSec < 1_024 { return String(format: "%.0f", bytesPerSec) }
        if bytesPerSec < 1_048_576 { return String(format: "%.0fK", bytesPerSec / 1_024) }
        if bytesPerSec < 1_073_741_824 { return String(format: "%.1fM", bytesPerSec / 1_048_576) }
        return String(format: "%.1fG", bytesPerSec / 1_073_741_824)
    }
}
