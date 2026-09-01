import SwiftUI

/// Fixed intensity ramp for heatmap cells. activity 0 → low (translucent blue),
/// 5+ → high (solid orange). Clamped, never normalized against the current
/// window, so equal activity always renders the same color across scans.
enum SpectrumHeatmapColor {
    static func intensity(forActivity activity: Int) -> Double {
        Double(min(5, max(0, activity))) / 5.0
    }

    static func color(forActivity activity: Int) -> Color {
        let t = intensity(forActivity: activity)
        return Color(
            red: 0.10 + (1.00 - 0.10) * t,
            green: 0.42 + (0.60 - 0.42) * t,
            blue: 0.80 + (0.00 - 0.80) * t,
            opacity: 0.18 + (0.90 - 0.18) * t
        )
    }
}

/// Waterfall grid of channel activity over the recent past for one band.
/// X = channel, Y = time (newest at the bottom), cell color = activity
/// intensity. Environment-level: no AP selection, no per-panel store.
struct SpectrumHeatmapPanel: View {
    let viewModel: ScannerViewModel
    let band: ChannelBand

    var body: some View {
        let model = viewModel.heatmapModel(for: band)
        VStack(spacing: 4) {
            legend
            if model.rows.count < 2 {
                emptyState
            } else {
                heatmapCanvas(model)
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }

    private var legend: some View {
        HStack(spacing: 6) {
            Text(String(localized: "spectrum.heatmap.legend.low", comment: "Low end of the heatmap intensity legend"))
                .font(.caption2)
                .foregroundColor(.secondary)
            RoundedRectangle(cornerRadius: 2)
                .fill(SpectrumHeatmapColor.color(forActivity: 0))
                .frame(width: 40, height: 8)
            Spacer()
            RoundedRectangle(cornerRadius: 2)
                .fill(SpectrumHeatmapColor.color(forActivity: 5))
                .frame(width: 40, height: 8)
            Text(String(localized: "spectrum.heatmap.legend.high", comment: "High end of the heatmap intensity legend"))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
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

    private func heatmapCanvas(_ model: SpectrumHeatmapModel) -> some View {
        Canvas { context, size in
            let bottomInset: CGFloat = 18
            let gridRect = CGRect(x: 0, y: 0, width: size.width, height: size.height - bottomInset)
            let channels = model.channels
            guard !channels.isEmpty, !model.rows.isEmpty else { return }
            let columnW = gridRect.width / CGFloat(channels.count)
            let rowH = gridRect.height / CGFloat(model.rows.count)

            // Oldest row drawn at top; newest lands at the bottom.
            for (rowIndex, row) in model.rows.enumerated() {
                let y = gridRect.minY + CGFloat(rowIndex) * rowH
                for (colIndex, cell) in row.cells.enumerated() {
                    let x = gridRect.minX + CGFloat(colIndex) * columnW
                    // +0.5 overlap avoids antialiasing hairlines between cells.
                    let rect = CGRect(x: x, y: y, width: columnW + 0.5, height: rowH + 0.5)
                    let path = Path(rect)
                    context.fill(path, with: .color(SpectrumHeatmapColor.color(forActivity: cell.activity)))
                }
            }

            // Channel axis ticks along the bottom, reusing the band chart's tick helper.
            let ticks = BandChartLayout.axisTickValues(
                xMin: Double(channels.first ?? 1),
                xMax: Double(channels.last ?? 1),
                maxChannel: band.maxChannel,
                axisTickStartChannel: 1
            )
            for ch in ticks {
                let x = gridRect.minX + (CGFloat(ch) - CGFloat(channels.first ?? 1)) * columnW
                let label = Text("\(ch)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                let resolved = context.resolve(label)
                context.draw(resolved, at: CGPoint(x: x, y: gridRect.maxY + 10))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "spectrum.accessibility.heatmap_label", comment: "Channel occupancy heatmap accessibility label"))
    }
}
