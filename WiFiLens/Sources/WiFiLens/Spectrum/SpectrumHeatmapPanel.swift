import SwiftUI

struct SpectrumHeatmapRGB: Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double
}

/// Fixed thermal-imaging colormap for the heatmap field.
/// The ramp stays in purple → magenta → red → orange → yellow; it avoids a
/// broad white region so the hottest core remains visually localized.
enum SpectrumHeatmapColor {
    private static let stops: [(t: Double, r: Double, g: Double, b: Double)] = [
        (0.00, 0.005, 0.008, 0.020),
        (0.16, 0.035, 0.005, 0.120),
        (0.34, 0.220, 0.005, 0.390),
        (0.52, 0.650, 0.015, 0.230),
        (0.70, 0.960, 0.080, 0.025),
        (0.86, 1.000, 0.430, 0.015),
        (1.00, 1.000, 0.960, 0.120)
    ]

    static func intensity(forActivity activity: Int) -> Double {
        intensity(forActivity: Double(activity))
    }

    static func intensity(forActivity activity: Double) -> Double {
        SpectrumHeatmapActivity.normalizedIntensity(forActivity: activity)
    }

    static func color(forActivity activity: Int) -> Color {
        color(forIntensity: intensity(forActivity: activity))
    }

    static func color(forIntensity intensity: Double) -> Color {
        let rgb = components(forIntensity: intensity)
        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }

    static func components(forIntensity intensity: Double) -> SpectrumHeatmapRGB {
        let value = min(1, max(0, intensity))
        var lower = stops[0]
        var upper = stops[stops.count - 1]
        for index in 0..<(stops.count - 1) {
            if value >= stops[index].t && value <= stops[index + 1].t {
                lower = stops[index]
                upper = stops[index + 1]
                break
            }
        }
        let fraction = (value - lower.t) / max(upper.t - lower.t, .ulpOfOne)
        return SpectrumHeatmapRGB(
            red: lower.r + (upper.r - lower.r) * fraction,
            green: lower.g + (upper.g - lower.g) * fraction,
            blue: lower.b + (upper.b - lower.b) * fraction
        )
    }
}

/// Thermal-field waterfall for one band. X is real frequency, Y is wall-clock
/// time with the oldest part of the 60-second window at the top.
struct SpectrumHeatmapPanel: View {
    let viewModel: ScannerViewModel
    let band: ChannelBand

    var body: some View {
        let model = viewModel.heatmapModel(for: band)
        Group {
            if model.frames.count < 2 {
                emptyState
            } else {
                heatmapCanvas(model)
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Text(String(localized: "spectrum.heatmap.empty", comment: "Placeholder when not enough scans are collected for the heatmap"))
                .foregroundColor(.secondary)
                .font(.caption)
            Spacer()
        }
        .frame(minHeight: 150)
    }

    var heatmapToolbarContent: some View {
        HStack(spacing: 6) {
            Text(String(localized: "spectrum.heatmap.legend.low", comment: "Low end of the heatmap intensity legend"))
                .font(.caption2)
                .foregroundColor(.secondary)
            SpectrumLegendBar()
                .frame(width: 90, height: 8)
            Text(String(localized: "spectrum.heatmap.legend.high", comment: "High end of the heatmap intensity legend"))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private func heatmapCanvas(_ model: SpectrumHeatmapModel) -> some View {
        GeometryReader { proxy in
            let size = proxy.size
            let domain = SpectrumHeatmapLayout.frequencyDomain(channels: model.channels, band: band)
            let timeDomain = SpectrumHeatmapTimeDomain(
                start: model.frames.last!.timestamp.addingTimeInterval(-60),
                end: model.frames.last!.timestamp
            )
            let plotRect = CGRect(
                x: 28,
                y: 18,
                width: max(1, size.width - 36),
                height: max(1, size.height - 42)
            )
            let raster = SpectrumHeatmapRasterizer.rasterize(
                frames: model.frames,
                domain: domain,
                timeDomain: timeDomain,
                size: plotRect.size
            )
            let smoothed = SpectrumHeatmapRasterizer.smooth(raster, domain: domain)

            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color(red: 0.008, green: 0.014, blue: 0.038))
                rasterLayer(smoothed, in: plotRect, opacity: 0.65)
                    .blur(radius: 8)
                rasterLayer(raster, in: plotRect, opacity: 0.96)
                axisLayer(
                    model: model,
                    domain: domain,
                    plotRect: plotRect,
                    size: size
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .frame(minHeight: 160, idealHeight: 190, maxHeight: 240)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "spectrum.accessibility.heatmap_label", comment: "Channel activity heatmap accessibility label"))
    }

    private func rasterLayer(
        _ raster: SpectrumHeatmapRaster,
        in plotRect: CGRect,
        opacity: Double
    ) -> some View {
        Canvas { context, _ in
            guard raster.width > 0, raster.height > 0 else { return }
            let cellWidth = plotRect.width / CGFloat(raster.width)
            let cellHeight = plotRect.height / CGFloat(raster.height)
            for y in 0..<raster.height {
                for x in 0..<raster.width {
                    let intensity = raster.value(x: x, y: y)
                    guard intensity > 0.005 else { continue }
                    let cell = CGRect(
                        x: plotRect.minX + CGFloat(x) * cellWidth,
                        y: plotRect.minY + CGFloat(y) * cellHeight,
                        width: cellWidth + 0.5,
                        height: cellHeight + 0.5
                    )
                    context.fill(
                        Path(cell),
                        with: .color(SpectrumHeatmapColor.color(forIntensity: intensity).opacity(opacity))
                    )
                }
            }
        }
    }

    private func axisLayer(
        model: SpectrumHeatmapModel,
        domain: SpectrumHeatmapFrequencyDomain,
        plotRect: CGRect,
        size: CGSize
    ) -> some View {
        Canvas { context, _ in
            let tickColor = Color.white.opacity(0.42)
            let tickLabel = Text(String(localized: "spectrum.heatmap.time.ago", comment: "Heatmap oldest time label"))
                .font(.caption2)
                .foregroundColor(.white.opacity(0.9))
            context.draw(context.resolve(tickLabel), at: CGPoint(x: 7, y: 10), anchor: .topLeading)

            let nowLabel = Text(String(localized: "spectrum.heatmap.time.now", comment: "Heatmap newest time label"))
                .font(.caption2)
                .foregroundColor(.white.opacity(0.9))
            context.draw(context.resolve(nowLabel), at: CGPoint(x: 7, y: size.height - 17), anchor: .topLeading)

            var timeAxis = Path()
            timeAxis.move(to: CGPoint(x: 17, y: plotRect.minY + 8))
            timeAxis.addLine(to: CGPoint(x: 17, y: plotRect.maxY - 5))
            context.stroke(timeAxis, with: .color(tickColor), lineWidth: 0.7)

            let ticks = SpectrumHeatmapLayout.channelTicks(
                channels: model.channels,
                band: band,
                in: plotRect,
                maximumCount: 10
            )
            for tick in ticks {
                let label = Text("\(tick.channel)")
                    .font(.caption2)
                    .foregroundColor(tickColor)
                context.draw(
                    context.resolve(label),
                    at: CGPoint(x: tick.x, y: plotRect.maxY + 8),
                    anchor: .top
                )
            }
        }
    }
}

/// Compact toolbar legend matching the thermal colormap.
struct SpectrumLegendBar: View {
    var body: some View {
        Canvas { context, size in
            let strips = 64
            for index in 0..<strips {
                let intensity = Double(index) / Double(strips - 1)
                let rect = CGRect(
                    x: size.width * CGFloat(index) / CGFloat(strips),
                    y: 0,
                    width: size.width / CGFloat(strips) + 0.5,
                    height: size.height
                )
                context.fill(
                    Path(rect),
                    with: .color(SpectrumHeatmapColor.color(forIntensity: intensity))
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .accessibilityLabel(String(localized: "spectrum.heatmap.legend.gradient", comment: "Thermal color gradient legend"))
    }
}
