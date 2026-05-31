import SwiftUI

/// Universal chart component. Renders grid, axes, curves, fills, and dots from a
/// `[ChartSeries]` array. All business-specific overlays (tooltips, labels, heatmaps)
/// are injected via an overlay ViewBuilder that receives the computed ChartGeometry.
struct Chart<Overlay: View>: View {
    let series: [ChartSeries]
    var axis: ChartAxisConfig = .init()
    var style: ChartStyle = .init()
    var interaction: ChartInteraction = .init()
    @ViewBuilder var overlay: (ChartGeometry, [ChartSeries]) -> Overlay

    init(
        series: [ChartSeries],
        axis: ChartAxisConfig = .init(),
        style: ChartStyle = .init(),
        interaction: ChartInteraction = .init()
    ) where Overlay == EmptyView {
        self.series = series
        self.axis = axis
        self.style = style
        self.interaction = interaction
        self.overlay = { _, _ in EmptyView() }
    }

    init(
        series: [ChartSeries],
        axis: ChartAxisConfig = .init(),
        style: ChartStyle = .init(),
        interaction: ChartInteraction = .init(),
        @ViewBuilder overlay: @escaping (ChartGeometry, [ChartSeries]) -> Overlay
    ) {
        self.series = series
        self.axis = axis
        self.style = style
        self.interaction = interaction
        self.overlay = overlay
    }

    @State private var hoverScreenPt: CGPoint?

    var body: some View {
        GeometryReader { geometry in
            let geo = computeGeo(size: geometry.size)

            ZStack {
                Canvas { context, _ in
                    drawContent(context: &context, geo: geo)
                }

                overlay(geo, series)
            }
            .contentShape(Rectangle())
            .onContinuousHover(coordinateSpace: .local) { phase in
                switch phase {
                case .active(let location):
                    if let (pt, screenPt) = hitTest(location: location, geo: geo) {
                        hoverScreenPt = screenPt
                        interaction.onHover?(pt, screenPt)
                    } else {
                        hoverScreenPt = nil
                        interaction.onHover?(nil, nil)
                    }
                case .ended:
                    hoverScreenPt = nil
                    interaction.onHover?(nil, nil)
                }
            }
            .onTapGesture { _ in }
            .simultaneousGesture(
                interaction.zoomGestureEnabled && interaction.onZoom != nil
                    ? zoomGesture(geo: geo)
                    : nil
            )
        }
    }

    // MARK: - Geometry

    private func computeGeo(size: CGSize) -> ChartGeometry {
        let chartRect = style.chartRect(size: size)
        let (yMin, yMax) = computeYRange()
        let xMin = computeXMin()
        let xMax = computeXMax()
        return ChartGeometry(chartRect: chartRect, xMin: xMin, xMax: xMax, yMin: yMin, yMax: yMax)
    }

    private func computeYRange() -> (Double, Double) {
        let allY = series.flatMap { $0.points.map(\.y) }
        let dataMin = allY.min() ?? -100
        let dataMax = allY.max() ?? 0
        let rawMin = axis.yMin ?? dataMin
        let rawMax = axis.yMax ?? dataMax
        let step = axis.yStep
        let yMin = floor(rawMin / step) * step
        let yMax = ceil(rawMax / step) * step
        return (yMin, yMax)
    }

    private func computeXMin() -> Double {
        axis.xMin ?? series.flatMap { $0.points.map(\.x) }.min() ?? 0
    }

    private func computeXMax() -> Double {
        axis.xMax ?? series.flatMap { $0.points.map(\.x) }.max() ?? 1
    }

    // MARK: - Canvas Content

    private func drawContent(context: inout GraphicsContext, geo: ChartGeometry) {
        let rect = geo.chartRect

        // Y-axis grid + labels
        if axis.showYGrid {
            let step = Int(axis.yStep)
            for val in stride(from: Int(geo.yMin), through: Int(geo.yMax), by: step) where Double(val) >= geo.yMin {
                let y = rect.maxY - (Double(val) - geo.yMin) * geo.scaleY
                var line = Path()
                line.move(to: CGPoint(x: rect.minX, y: y))
                line.addLine(to: CGPoint(x: rect.maxX, y: y))
                context.stroke(line, with: .color(axis.gridColor), lineWidth: 1)
                context.draw(
                    Text("\(val)").font(axis.yTickFont).foregroundColor(axis.yTickColor),
                    at: CGPoint(x: rect.minX - axis.yTickLabelOffset, y: y)
                )
            }
        }

        // X-axis ticks + labels
        for tick in axis.xTicks where tick.position >= geo.xMin && tick.position <= geo.xMax {
            let x = rect.minX + (tick.position - geo.xMin) * geo.scaleX
            context.draw(
                Text(tick.label).font(axis.xTickFont).foregroundColor(axis.xTickColor),
                at: CGPoint(x: x, y: rect.maxY + axis.xTickLabelOffset)
            )
        }

        // Axis lines
        if axis.showXAxis {
            var p = Path(); p.move(to: CGPoint(x: rect.minX, y: rect.maxY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            context.stroke(p, with: .color(axis.axisColor), lineWidth: 1)
        }
        if axis.showYAxis {
            var p = Path(); p.move(to: CGPoint(x: rect.minX, y: rect.minY)); p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            context.stroke(p, with: .color(axis.axisColor), lineWidth: 1)
        }

        // Clip
        if axis.clipToRect { context.clip(to: Path(rect)) }

        // Series
        for s in series where s.points.count >= 2 {
            drawSeries(context: &context, series: s, geo: geo)
        }
    }

    // MARK: - Series Drawing

    private func drawSeries(context: inout GraphicsContext, series: ChartSeries, geo: ChartGeometry) {
        switch series.style.interpolation {
        case .linear, .step:
            drawPolyline(context: &context, series: series, geo: geo, stepped: series.style.interpolation == .step)
        case .catmullRom:
            let pts = series.points.map { geo.dataToPoint(x: $0.x, y: $0.y) }
            drawCurvePath(context: &context, curve: catmullRomSpline(points: pts), series: series, style: series.style, geo: geo)
        case .clampedCubic:
            let pts = series.points.map { geo.dataToPoint(x: $0.x, y: $0.y) }
            drawCurvePath(context: &context, curve: clampedCubicSpline(points: pts), series: series, style: series.style, geo: geo)
        case .gaussian(let sigma, let baseline):
            drawGaussianCurve(context: &context, series: series, style: series.style, geo: geo, sigma: sigma, baseline: baseline)
        }
    }

    private func drawPolyline(context: inout GraphicsContext, series: ChartSeries, geo: ChartGeometry, stepped: Bool) {
        let pts = series.points; let sty = series.style
        var line = Path(); var prevSY: CGFloat = 0
        for (i, pt) in pts.enumerated() {
            let sx = geo.chartRect.minX + (pt.x - geo.xMin) * geo.scaleX
            let sy = geo.chartRect.maxY - (pt.y - geo.yMin) * geo.scaleY
            if stepped, i > 0 { line.addLine(to: CGPoint(x: sx, y: prevSY)) }
            if i == 0 { line.move(to: CGPoint(x: sx, y: sy)) } else { line.addLine(to: CGPoint(x: sx, y: sy)) }
            prevSY = sy
        }

        if sty.areaOpacity > 0 {
            let fillY = sty.baseline.map { geo.chartRect.maxY - ($0 - geo.yMin) * geo.scaleY } ?? geo.chartRect.maxY
            let lx = geo.chartRect.minX + (pts.last!.x - geo.xMin) * geo.scaleX
            let fx = geo.chartRect.minX + (pts.first!.x - geo.xMin) * geo.scaleX
            var fill = line
            fill.addLine(to: CGPoint(x: lx, y: fillY))
            fill.addLine(to: CGPoint(x: fx, y: fillY))
            fill.closeSubpath()
            context.fill(fill, with: .color(sty.color.opacity(sty.areaOpacity)))
        }
        if sty.lineWidth > 0, sty.strokeOpacity > 0 {
            context.stroke(line, with: .color(sty.color.opacity(sty.strokeOpacity)), lineWidth: sty.lineWidth)
        }
        if sty.pointRadius > 0 {
            let r = sty.pointRadius
            for pt in pts {
                let sx = geo.chartRect.minX + (pt.x - geo.xMin) * geo.scaleX
                let sy = geo.chartRect.maxY - (pt.y - geo.yMin) * geo.scaleY
                context.fill(Path(ellipseIn: CGRect(x: sx - r, y: sy - r, width: r * 2, height: r * 2)), with: .color(sty.color))
            }
        }
    }

    private func drawCurvePath(context: inout GraphicsContext, curve: Path, series: ChartSeries, style: ChartSeries.ChartSeriesStyle, geo: ChartGeometry) {
        let pts = series.points
        if style.areaOpacity > 0 {
            let fillY = style.baseline.map { geo.chartRect.maxY - ($0 - geo.yMin) * geo.scaleY } ?? geo.chartRect.maxY
            let lx = geo.chartRect.minX + (pts.last!.x - geo.xMin) * geo.scaleX
            let fx = geo.chartRect.minX + (pts.first!.x - geo.xMin) * geo.scaleX
            var fill = curve
            fill.addLine(to: CGPoint(x: lx, y: fillY)); fill.addLine(to: CGPoint(x: fx, y: fillY))
            fill.closeSubpath()
            context.fill(fill, with: .color(style.color.opacity(style.areaOpacity)))
        }
        if style.lineWidth > 0, style.strokeOpacity > 0 {
            context.stroke(curve, with: .color(style.color.opacity(style.strokeOpacity)), lineWidth: style.lineWidth)
        }
    }

    private func drawGaussianCurve(context: inout GraphicsContext, series: ChartSeries, style: ChartSeries.ChartSeriesStyle, geo: ChartGeometry, sigma: Double, baseline: Double) {
        guard let first = series.points.first, let last = series.points.last else { return }
        let center = (first.x + last.x) / 2.0
        // The first point's y is the peak RSSI; amplitude is peak minus baseline
        let amplitude = max(0, first.y - baseline)
        let steps = 80

        var topPts: [CGPoint] = []; var full = Path()
        for i in 0...steps {
            let x = first.x + (last.x - first.x) * Double(i) / Double(steps)
            let g = exp(-((x - center) * (x - center)) / (2 * sigma * sigma))
            let y = baseline + amplitude * g
            let pt = geo.dataToPoint(x: x, y: y)
            topPts.append(pt)
            if i == 0 { full.move(to: pt) } else { full.addLine(to: pt) }
        }
        full.addLine(to: geo.dataToPoint(x: last.x, y: baseline))
        full.addLine(to: geo.dataToPoint(x: first.x, y: baseline))
        full.closeSubpath()

        if style.areaOpacity > 0 { context.fill(full, with: .color(style.color.opacity(style.areaOpacity))) }
        if style.lineWidth > 0, style.strokeOpacity > 0 {
            var top = Path(); top.move(to: topPts[0]); for pt in topPts.dropFirst() { top.addLine(to: pt) }
            context.stroke(top, with: .color(style.color.opacity(style.strokeOpacity)), lineWidth: style.lineWidth)
        }
    }

    // MARK: - Hit Testing

    private func hitTest(location: CGPoint, geo: ChartGeometry) -> (ChartPoint, CGPoint)? {
        guard geo.chartRect.contains(location) else { return nil }
        let radius: CGFloat = 20
        var best: (ChartPoint, CGPoint)?
        var bestDist: CGFloat = radius

        for s in series where s.points.count >= 1 {
            for pt in s.points {
                let screen = geo.dataToPoint(x: pt.x, y: pt.y)
                let dx = screen.x - location.x
                let dy = screen.y - location.y
                let dist = sqrt(dx * dx + dy * dy)
                if dist < bestDist { bestDist = dist; best = (pt, screen) }
            }
        }
        return best
    }

    // MARK: - Zoom Gesture

    private func zoomGesture(geo: ChartGeometry) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onEnded { value in
                let startX = min(value.startLocation.x, value.location.x)
                let endX = max(value.startLocation.x, value.location.x)
                guard endX - startX > 20 else { return }
                let relStart = Swift.max(0.0, startX - geo.chartRect.minX)
                let relEnd = Swift.min(geo.chartRect.width, endX - geo.chartRect.minX)
                let lo = geo.xMin + (relStart / geo.chartRect.width) * (geo.xMax - geo.xMin)
                let hi = geo.xMin + (relEnd / geo.chartRect.width) * (geo.xMax - geo.xMin)
                interaction.onZoom?(lo, hi)
            }
    }
}
