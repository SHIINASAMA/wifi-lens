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

    /// Interpolate the thermal ramp at an arbitrary intensity in [0, 1]. Used
    /// by the heatmap's per-subcell field sampling so sparse grids stay smooth.
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

/// Samples the heatmap activity field at a fractional grid coordinate.
/// Keeping this calculation independent from Canvas makes the interpolation
/// contract testable and ensures fractional activity reaches the color ramp.
enum SpectrumHeatmapField {
    static func sampledIntensity(atCol col: Double, atRow row: Double, grid: [[Int]]) -> Double {
        let rows = grid.count
        let cols = grid.first?.count ?? 0
        guard rows > 0, cols > 0 else { return 0 }
        guard rows >= 2, cols >= 2 else {
            // Degenerate grid: fall back to the nearest cell's intensity.
            let r = min(max(Int(row), 0), rows - 1)
            let c = min(max(Int(col), 0), cols - 1)
            return SpectrumHeatmapColor.intensity(forActivity: grid[r][c])
        }
        let c = min(max(col, 0), Double(cols - 1))
        let r = min(max(row, 0), Double(rows - 1))
        let cl = min(Int(c), cols - 2)
        let ct = min(Int(r), rows - 2)
        let cr = cl + 1
        let cb = ct + 1
        let dx = c - Double(cl)
        let dy = r - Double(ct)
        let v11 = Double(grid[ct][cl])
        let v21 = Double(grid[ct][cr])
        let v12 = Double(grid[cb][cl])
        let v22 = Double(grid[cb][cr])
        let top = v11 + (v21 - v11) * dx
        let bottom = v12 + (v22 - v12) * dx
        let value = top + (bottom - top) * dy
        return SpectrumHeatmapColor.intensity(forActivity: value)
    }
}

/// Waterfall grid of channel activity over the recent past for one band.
/// X = channel, Y = time (newest at the bottom), cell color = activity
/// intensity. Each channel cell is subdivided into an n×n grid of subcells
/// whose color is sampled from a bilinear-interpolated activity field, so the
/// image reads as a continuous thermal scan rather than a mosaic of flat
/// rectangles. Environment-level: no AP selection, no per-panel store.
struct SpectrumHeatmapPanel: View {
    let viewModel: ScannerViewModel
    let band: ChannelBand

    /// Subdivision per cell edge. Higher n → smoother gradient within a cell,
    /// so even a sparse grid (few channels/timestamps) doesn't collapse into
    /// flat color blocks. Kept modest to bound the fill count (cells × n²).
    private let subdivision: Int = 6

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
            let activityByCell = buildActivityGrid(model, channels: channels)
            drawThermalGrid(context: context, gridRect: gridRect, model: model, activityByCell: activityByCell)
            drawChannelAxis(
                context: context,
                gridRect: gridRect,
                model: model,
                channels: channels,
                columnW: gridRect.width / CGFloat(channels.count)
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "spectrum.accessibility.heatmap_label", comment: "Channel occupancy heatmap accessibility label"))
    }

    /// Flatten the rows' cells into a (row, col) → activity lookup keyed by row
    /// index. Rows may carry a sparse cell set; unlisted channels default to 0.
    private func buildActivityGrid(_ model: SpectrumHeatmapModel, channels: [Int]) -> [[Int]] {
        model.rows.map { row in
            let byChannel = Dictionary(uniqueKeysWithValues: row.cells.map { ($0.channel, $0.activity) })
            return channels.map { byChannel[$0] ?? 0 }
        }
    }

    /// Draw the grid, subdividing each cell into `subdivision × subdivision`
    /// subcells whose color is sampled from the bilinear field, then lay a
    /// faint line at each original cell boundary for orientation.
    private func drawThermalGrid(
        context: GraphicsContext,
        gridRect: CGRect,
        model: SpectrumHeatmapModel,
        activityByCell: [[Int]]
    ) {
        let rows = activityByCell.count
        let cols = model.channels.count
        guard rows > 0, cols > 0 else { return }
        let cellW = gridRect.width / CGFloat(cols)
        let cellH = gridRect.height / CGFloat(rows)
        let subW = cellW / CGFloat(subdivision)
        let subH = cellH / CGFloat(subdivision)
        let n = CGFloat(subdivision)

        // 0.5pt overlap per subcell avoids antialiasing hairlines between them.
        for rowIndex in 0..<rows {
            let cellY = gridRect.minY + CGFloat(rowIndex) * cellH
            for colIndex in 0..<cols {
                let cellX = gridRect.minX + CGFloat(colIndex) * cellW
                for sy in 0..<subdivision {
                    for sx in 0..<subdivision {
                        let intensity = SpectrumHeatmapField.sampledIntensity(
                            atCol: Double(colIndex) + Double(sx + 1) / n,
                            atRow: Double(rowIndex) + Double(sy + 1) / n,
                            grid: activityByCell
                        )
                        let x = cellX + CGFloat(sx) * subW
                        let y = cellY + CGFloat(sy) * subH
                        let rect = CGRect(x: x, y: y, width: subW + 0.5, height: subH + 0.5)
                        context.fill(Path(rect), with: .color(SpectrumHeatmapColor.color(forIntensity: intensity)))
                    }
                }
            }
        }

        // Faint cell-boundary lines so individual channel/timestamp cells stay
        // locatable, without reverting to a mosaic.
        context.stroke(
            Path { path in
                for col in 0...cols {
                    let x = gridRect.minX + CGFloat(col) * cellW
                    path.move(to: CGPoint(x: x, y: gridRect.minY))
                    path.addLine(to: CGPoint(x: x, y: gridRect.maxY))
                }
                for row in 0...rows {
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
        model: SpectrumHeatmapModel,
        channels: [Int],
        columnW: CGFloat
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
            guard let colIndex = channels.firstIndex(of: ch) else { continue }
            let x = gridRect.minX + (CGFloat(colIndex) + 0.5) * columnW
            let label = Text("\(ch)")
                .font(.caption2)
                .foregroundColor(.secondary)
            let resolved = context.resolve(label)
            context.draw(resolved, at: CGPoint(x: x, y: gridRect.maxY + 10))
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
