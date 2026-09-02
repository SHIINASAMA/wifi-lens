import SwiftUI

/// Fixed thermal-imaging colormap for heatmap cells.
/// activity 0 → pure black (cold), activity 5+ → warm white (hot), walking
/// the classic FLIR pseudo-color path: black → deep blue → cyan-blue → gold →
/// orange-red → white. Clamped, never normalized against the current window,
/// so equal activity always renders the same color across scans.
enum SpectrumHeatmapColor {
    /// Stops for the thermal ramp, evenly spaced in [0, 1]. The color for any
    /// intensity is a linear blend between the surrounding stops (see
    /// `color(forActivity:)`).
    private static let stops: [(t: Double, r: Double, g: Double, b: Double)] = [
        (0.00, 0.00, 0.00, 0.00),   // black      (coldest)
        (0.20, 0.10, 0.10, 0.28),   // deep blue
        (0.40, 0.00, 0.55, 0.85),   // cyan-blue
        (0.60, 0.95, 0.60, 0.10),   // gold
        (0.85, 0.95, 0.25, 0.10),   // orange-red
        (1.00, 1.00, 0.95, 0.85),   // warm white (hottest)
    ]

    static func intensity(forActivity activity: Int) -> Double {
        intensity(forActivity: Double(activity))
    }

    static func intensity(forActivity activity: Double) -> Double {
        min(5, max(0, activity)) / 5.0
    }

    static func color(forActivity activity: Int) -> Color {
        color(forIntensity: intensity(forActivity: activity))
    }

    /// Interpolate the thermal ramp at an arbitrary intensity in [0, 1].
    static func color(forIntensity t: Double) -> Color {
        let clamped = min(1, max(0, t))
        // Find the surrounding stops spanning `clamped`.
        var lo = stops[0]
        var hi = stops[stops.count - 1]
        for i in 0..<(stops.count - 1) {
            if clamped >= stops[i].t && clamped <= stops[i + 1].t {
                lo = stops[i]
                hi = stops[i + 1]
                break
            }
        }
        let span = max(hi.t - lo.t, .ulpOfOne)
        let f = (clamped - lo.t) / span
        return Color(
            red: lo.r + (hi.r - lo.r) * f,
            green: lo.g + (hi.g - lo.g) * f,
            blue: lo.b + (hi.b - lo.b) * f
        )
    }
}

/// Waterfall grid of channel activity over the recent past for one band.
/// X = channel, Y = time (newest at the bottom), cell color = activity
/// intensity. Every model cell is rendered as one discrete rectangle.
/// Environment-level: no AP selection, no per-panel store.
struct SpectrumHeatmapPanel: View {
    let viewModel: ScannerViewModel
    let band: ChannelBand

    var body: some View {
        let model = viewModel.heatmapModel(for: band)
        Group {
            if model.rows.count < 2 {
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
            Text(String(localized: "spectrum.heatmap.empty", comment: "Placeholder when not enough snapshots are collected for the heatmap"))
                .foregroundColor(.secondary)
                .font(.caption)
            Spacer()
        }
    }

    /// Spectrum-style gradient legend rendered into the toolbar by
    /// `SpectrumPanelView` via `heatmapToolbarContent`. Kept as a computed
    /// property so the panel owns the colormap while the toolbar owns layout.
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
        Canvas { context, size in
            let bottomInset: CGFloat = 18
            let gridRect = CGRect(x: 0, y: 0, width: size.width, height: size.height - bottomInset)
            let channels = model.channels
            guard !channels.isEmpty, !model.rows.isEmpty else { return }
            let columnRects = SpectrumHeatmapLayout.columnRects(channels: channels, band: band, in: gridRect)
            drawCells(context: context, gridRect: gridRect, model: model, columnRects: columnRects)
            drawChannelAxis(
                context: context,
                gridRect: gridRect,
                channels: channels,
                columnRects: columnRects
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "spectrum.accessibility.heatmap_label", comment: "Channel occupancy heatmap accessibility label"))
    }

    private func drawCells(
        context: GraphicsContext,
        gridRect: CGRect,
        model: SpectrumHeatmapModel,
        columnRects: [(channel: Int, rect: CGRect)]
    ) {
        guard !model.rows.isEmpty, !columnRects.isEmpty else { return }
        let cellH = gridRect.height / CGFloat(model.rows.count)
        let rectByChannel = Dictionary(uniqueKeysWithValues: columnRects.map { ($0.channel, $0.rect) })

        for (rowIndex, row) in model.rows.enumerated() {
            let y = gridRect.minY + CGFloat(rowIndex) * cellH
            for cell in row.cells {
                guard let columnRect = rectByChannel[cell.channel] else { continue }
                let cellRect = CGRect(x: columnRect.minX, y: y, width: columnRect.width, height: cellH)
                context.fill(
                    Path(cellRect),
                    with: .color(SpectrumHeatmapColor.color(forActivity: cell.activity))
                )
            }
        }

        context.stroke(
            Path { path in
                for column in columnRects {
                    for x in [column.rect.minX, column.rect.maxX] {
                        path.move(to: CGPoint(x: x, y: gridRect.minY))
                        path.addLine(to: CGPoint(x: x, y: gridRect.maxY))
                    }
                }
                for row in 0...model.rows.count {
                    let y = gridRect.minY + CGFloat(row) * cellH
                    path.move(to: CGPoint(x: gridRect.minX, y: y))
                    path.addLine(to: CGPoint(x: gridRect.maxX, y: y))
                }
            },
            with: .color(Color.white.opacity(0.05)),
            lineWidth: 0.5
        )
    }

    private func drawChannelAxis(
        context: GraphicsContext,
        gridRect: CGRect,
        channels: [Int],
        columnRects: [(channel: Int, rect: CGRect)]
    ) {
        guard !channels.isEmpty else { return }
        // Choose representative channels from the legal set itself — never
        // fabricate channel numbers that don't exist (5 GHz has gaps; 6 GHz is
        // a sparse PSC grid). Target ≤ ~10 labels across the grid width.
        let targetCount = 10
        var ticks: [Int] = []
        if channels.count <= targetCount {
            ticks = channels
        } else {
            let stride = Int((Double(channels.count) / Double(targetCount)).rounded(.up))
            var index = 0
            while index < channels.count {
                ticks.append(channels[index])
                index += stride
            }
            if (ticks.last ?? 0) != (channels.last ?? 0), let lastChannel = channels.last {
                ticks.append(lastChannel)
            }
        }

        // Position each label at its column's center so labels sit under their
        // data, aligned with the cell grid — not at a fabricated channel offset.
        for ch in ticks {
            guard let columnRect = columnRects.first(where: { $0.channel == ch })?.rect else { continue }
            let label = Text("\(ch)")
                .font(.caption2)
                .foregroundColor(.secondary)
            let resolved = context.resolve(label)
            context.draw(resolved, at: CGPoint(x: columnRect.midX, y: gridRect.maxY + 10))
        }
    }
}

/// A thin continuous gradient bar matching the thermal colormap, used for the
/// in-toolbar spectrum legend.
struct SpectrumLegendBar: View {
    var body: some View {
        Canvas { context, size in
            let strips = 64
            for i in 0..<strips {
                let t = Double(i) / Double(strips - 1)
                let sub = CGRect(
                    x: size.width * CGFloat(i) / CGFloat(strips),
                    y: 0,
                    width: size.width / CGFloat(strips) + 0.5,
                    height: size.height
                )
                context.fill(
                    Path(sub),
                    with: .color(SpectrumHeatmapColor.color(forIntensity: t))
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .accessibilityLabel(String(localized: "spectrum.heatmap.legend.gradient", comment: "Thermal color gradient legend"))
    }
}
