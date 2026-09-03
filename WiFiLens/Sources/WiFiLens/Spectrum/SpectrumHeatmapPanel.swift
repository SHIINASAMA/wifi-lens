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

    static func color(forIntensity intensity: Float) -> Color {
        color(forIntensity: Double(intensity))
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

/// Aggregate thermal field for one band. X is physical frequency and Y is the
/// fixed RSSI range shared by the field generator and the axis.
struct SpectrumHeatmapPanel: View {
    let viewModel: ScannerViewModel
    let band: ChannelBand
    @State private var renderCache = SpectrumHeatmapRenderCache()

    static let rssiReferenceValues = [-100.0, -70.0, -30.0]
    static let rssiAxisLabels = ["-100", "-70", "-30 dBm"]
    static let timeAxisLabels: [String] = []

    private static let rssiRange = (-100.0)...(-30.0)
    private static let plotLeadingInset: CGFloat = 44
    private static let plotTopInset: CGFloat = 12
    private static let plotTrailingInset: CGFloat = 8
    private static let plotBottomInset: CGFloat = 28

    var body: some View {
        let model = viewModel.heatmapModel(for: band)
        Group {
            if Self.shouldShowEmptyState(for: model) {
                emptyState
            } else {
                heatmapCanvas(model)
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.aggregateAccessibilityLabel(for: band))
    }

    static func shouldShowEmptyState(for model: SpectrumHeatmapModel) -> Bool {
        model.envelopes.isEmpty
    }

    static func aggregateAccessibilityLabel(for band: ChannelBand) -> String {
        String(
            format: String(
                localized: "spectrum.accessibility.aggregate_heatmap_label",
                comment: "Aggregate Wi-Fi activity heatmap accessibility label with band"
            ),
            band.displayName
        )
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Text(String(localized: "spectrum.heatmap.empty", comment: "Placeholder when the current scan has no heatmap envelopes"))
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
            let plotRect = Self.plotRect(in: size)
            let resolution = Self.rasterResolution(for: plotRect.size)
            let key = SpectrumHeatmapRenderKey(
                model: model,
                domain: domain,
                rssiRange: Self.rssiRange,
                resolution: resolution
            )
            let smoothed = renderCache.smoothedRaster(
                for: key,
                generate: {
                    CPUHeatmapFieldGenerator().generate(
                        envelopes: model.envelopes,
                        domain: domain,
                        rssiRange: Self.rssiRange,
                        resolution: resolution
                    )
                },
                smooth: { raster in
                    SpectrumHeatmapRasterizer.smooth(raster, domain: domain)
                }
            )

            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color(red: 0.008, green: 0.014, blue: 0.038))
                rasterLayer(smoothed, in: plotRect, opacity: 0.42)
                    .blur(radius: 8)
                rasterLayer(smoothed, in: plotRect, opacity: 0.96)
                axisLayer(model: model, domain: domain, plotRect: plotRect)
            }
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .frame(minHeight: 160, idealHeight: 190, maxHeight: 240)
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
        plotRect: CGRect
    ) -> some View {
        Canvas { context, _ in
            let labelColor = Color.white.opacity(0.58)
            for (index, rssi) in Self.rssiReferenceValues.enumerated() {
                guard let y = SpectrumHeatmapLayout.yPosition(
                    forRSSI: rssi,
                    in: plotRect,
                    rssiRange: Self.rssiRange
                ) else { continue }
                let label = Text(Self.rssiAxisLabels[index])
                    .font(.caption2)
                    .foregroundColor(labelColor)
                context.draw(
                    context.resolve(label),
                    at: CGPoint(x: plotRect.minX - 8, y: y),
                    anchor: .trailing
                )
            }

            let ticks = SpectrumHeatmapLayout.channelTicks(
                channels: model.channels,
                band: band,
                in: plotRect,
                maximumCount: 10
            )
            for tick in ticks {
                let label = Text("\(tick.channel)")
                    .font(.caption2)
                    .foregroundColor(labelColor)
                context.draw(
                    context.resolve(label),
                    at: CGPoint(x: tick.x, y: plotRect.maxY + 8),
                    anchor: .top
                )
            }
        }
    }

    private static func plotRect(in size: CGSize) -> CGRect {
        CGRect(
            x: plotLeadingInset,
            y: plotTopInset,
            width: max(1, size.width - plotLeadingInset - plotTrailingInset),
            height: max(1, size.height - plotTopInset - plotBottomInset)
        )
    }

    static func rasterResolution(for _: CGSize) -> SpectrumHeatmapResolution {
        SpectrumHeatmapResolution.standard
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
