import SwiftUI

struct WiFiBandChart: View {
    let model: BandChartRenderModel
    @Binding var selectedNetworkID: String?
    let onResetZoom: () -> Void
    let onToggleExpand: () -> Void
    let onApplyZoom: (Double, Double) -> Void

    @State private var hoveredSeries: ChartSeriesData?
    @State private var hoverPoint: CGPoint = .zero
    @State private var isHovering: Bool = false

    private let leftAxisWidth: CGFloat = 38
    private let bottomAxisHeight: CGFloat = 42
    private let chartMarginTop: CGFloat = 6
    private let chartMarginRight: CGFloat = 8
    private let chartMarginBottom: CGFloat = 4

    var body: some View {
        VStack(spacing: 0) {
            chartToolbar
            chartContent
        }
        .overlay {
            if model.isExpanded { expandedOverlay }
        }
    }

    // MARK: - Toolbar

    private var chartToolbar: some View {
        HStack(spacing: 4) {
            if model.zoomMin != nil {
                Button {
                    onResetZoom()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .frame(width: 24, height: 24)
                }
                .help(String(localized: "common.action.reset_zoom", comment: "Reset chart zoom to default"))
            }
            Spacer()
        }
        .padding(.horizontal, 8).padding(.vertical, 2)
    }

    // MARK: - Computed properties

    private var visibleSeries: [ChartSeriesData] { model.visibleSeriesData }
    private var hasSelection: Bool { selectedNetworkID != nil }
    private func isSelected(_ s: ChartSeriesData) -> Bool { selectedNetworkID == s.id }

    private func strokeStyle(for s: ChartSeriesData) -> (areaOpacity: Double, strokeOpacity: Double, strokeWidth: CGFloat) {
        if isSelected(s) { return (0.55, 1.0, 2) }
        if hasSelection { return (0.10, 0.20, 1) }
        return (0.3, 0.6, 1)
    }

    // MARK: - Chart Data

    private func buildSeries() -> [ChartSeries] {
        visibleSeries.map { s in
            let halfWidth = Double(s.right - s.left) / 2.0
            let sigma = halfWidth / 4.0
            let baseline = Double(Constants.rssiNoiseFloor)
            let st = strokeStyle(for: s)
            return ChartSeries(
                id: s.id,
                points: [
                    ChartPoint(x: Double(s.left), y: s.displayRSSI),
                    ChartPoint(x: Double(s.right), y: s.displayRSSI),
                ],
                style: ChartSeries.ChartSeriesStyle(
                    color: s.color, lineWidth: st.strokeWidth,
                    areaOpacity: st.areaOpacity, strokeOpacity: st.strokeOpacity,
                    interpolation: .gaussian(sigma: sigma, baseline: baseline),
                    baseline: baseline
                )
            )
        }
    }

    private func computeGeo(size: CGSize) -> ChartGeometry {
        let chartRect = CGRect(
            x: leftAxisWidth, y: chartMarginTop,
            width: size.width - leftAxisWidth - chartMarginRight,
            height: size.height - bottomAxisHeight - chartMarginTop - chartMarginBottom
        )
        let xMin = model.zoomMin ?? Double(model.xDataMin)
        let xMax = model.zoomMax ?? Double(model.xDataMax)
        let yMin = model.yMin
        let yMax = min(0.0, ceil(Double(model.strongestRSSI) / 10.0) * 10)
        return ChartGeometry(chartRect: chartRect, xMin: xMin, xMax: xMax, yMin: yMin, yMax: yMax)
    }

    // MARK: - Axis & Style

    private var axisConfig: ChartAxisConfig {
        let xMin = model.zoomMin ?? Double(model.xDataMin)
        let xMax = model.zoomMax ?? Double(model.xDataMax)
        let tickValues = BandChartLayout.axisTickValues(
            xMin: xMin, xMax: xMax,
            maxChannel: model.xDataMax,
            axisTickStartChannel: model.axisTickStartChannel
        )
        var a = ChartAxisConfig()
        a.xMin = xMin; a.xMax = xMax
        a.yMin = model.yMin; a.yStep = 10; a.gridColor = .gray.opacity(0.15)
        a.xTicks = tickValues.map { ChartAxisConfig.XTick(position: Double($0), label: "\($0)") }
        a.xTickLabelOffset = 28; a.yTickLabelOffset = 14
        return a
    }

    private let chartStyle = ChartStyle(
        leftAxisWidth: 38, bottomAxisHeight: 42,
        marginTop: 6, marginRight: 8, marginBottom: 4
    )

    // MARK: - Content

    private var chartContent: some View {
        Group {
            if model.isEmpty {
                VStack {
                    Spacer()
                    Text(String(localized: "common.label.loading", comment: "Loading indicator text"))
                        .foregroundColor(Color(hex: "#888888")).font(.system(size: 16))
                    Spacer()
                }
            } else {
                GeometryReader { geometry in
                    let geo = computeGeo(size: geometry.size)
                    Chart(series: buildSeries(), axis: axisConfig, style: chartStyle) { chartGeo, _ in
                        heatmapOverlay(geo: chartGeo)
                        dataLabelOverlay(geo: chartGeo)
                    }
                    .onContinuousHover(coordinateSpace: .local) { phase in
                        switch phase {
                        case .active(let location):
                            isHovering = true
                            if let (series, pt) = BandChartLayout.nearestSeries(at: location, in: visibleSeries, geometry: geo, radius: 14) {
                                hoveredSeries = series; hoverPoint = pt
                            } else { hoveredSeries = nil }
                        case .ended:
                            isHovering = false; hoveredSeries = nil
                        }
                    }
                    .onTapGesture { selectedNetworkID = hoveredSeries?.id }
                    .gesture(zoomGesture(in: geometry, geo: geo))
                    .overlay {
                        if isHovering, let series = hoveredSeries {
                            ChartTooltip(ssid: series.displaySSID, rssi: series.rssi, channel: series.channel, bssid: series.bssid)
                                .position(x: clampX(hoverPoint.x, in: geo.chartRect), y: max(hoverPoint.y - 22, 4))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Overlays

    private func heatmapOverlay(geo: ChartGeometry) -> some View {
        Canvas { context, _ in
            let heatHeight: CGFloat = 14; let barWidth: CGFloat = 5; let barGap: CGFloat = 1
            let heatY = geo.chartRect.maxY + 3
            let heatmap = BandChartLayout.heatmapBins(series: visibleSeries)
            for bin in heatmap.bins {
                let x = geo.chartRect.minX + (Double(bin.apex) - geo.xMin) * geo.scaleX
                let op = 0.18 + (CGFloat(bin.colors.count) / CGFloat(heatmap.maxCount)) * 0.45
                for bar in bin.bars(barWidth: barWidth, barGap: barGap) {
                    var p = Path()
                    p.addRect(CGRect(x: x - barWidth / 2 + bar.offset, y: heatY, width: barWidth, height: heatHeight))
                    context.fill(p, with: .color(bar.color.opacity(op)))
                }
            }
        }
    }

    private func dataLabelOverlay(geo: ChartGeometry) -> some View {
        let seriesList = model.displayedSeriesData
        let labels = BandChartLayout.placeLabels(
            seriesData: seriesList, chartRect: geo.chartRect,
            xMin: geo.xMin, scaleX: geo.scaleX, scaleY: geo.scaleY,
            yMin: model.yMin, selectedNetworkID: selectedNetworkID
        )
        return ForEach(labels, id: \.series.id) { item in
            Text("\(item.series.channel) \(item.series.displaySSID)\(trendSuffix(for: item.series))")
                .font(.system(size: 9)).foregroundColor(item.series.color)
                .opacity(item.opacity).position(x: item.x, y: item.y)
        }
    }

    private func trendSuffix(for series: ChartSeriesData) -> String {
        guard !series.trendArrow.isEmpty else { return "" }
        let d = series.trendDelta == 0 ? "" : " \(series.trendDelta > 0 ? "+" : "")\(series.trendDelta)"
        return " \(series.trendArrow)\(d)"
    }

    // MARK: - Gestures

    private func clampX(_ x: CGFloat, in rect: CGRect) -> CGFloat {
        min(max(x, rect.minX + 60), rect.maxX - 60)
    }

    private func zoomGesture(in geometry: GeometryProxy, geo: ChartGeometry) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onEnded { value in
                let startX = min(value.startLocation.x, value.location.x)
                let endX = max(value.startLocation.x, value.location.x)
                guard endX - startX > 20 else { return }
                let relStart = Swift.max(0.0, startX - geo.chartRect.minX)
                let relEnd = Swift.min(geo.chartRect.width, endX - geo.chartRect.minX)
                let lo = geo.xMin + (relStart / geo.chartRect.width) * (geo.xMax - geo.xMin)
                let hi = geo.xMin + (relEnd / geo.chartRect.width) * (geo.xMax - geo.xMin)
                onApplyZoom(lo, hi)
            }
    }

    // MARK: - Expanded Overlay

    private var expandedOverlay: some View {
        ZStack(alignment: .topTrailing) {
            Color(nsColor: .windowBackgroundColor).ignoresSafeArea()
            VStack(spacing: 0) {
                chartToolbar
                GeometryReader { geometry in
                    Chart(series: buildSeries(), axis: axisConfig, style: chartStyle) { chartGeo, _ in
                        heatmapOverlay(geo: chartGeo)
                        dataLabelOverlay(geo: chartGeo)
                    }
                }
            }
            .padding()
            Button { onToggleExpand() } label: {
                Image(systemName: "xmark.circle.fill").font(.title).foregroundColor(.secondary)
            }
            .buttonStyle(.plain).padding(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

typealias BandChartView = WiFiBandChart

// MARK: - Chart Tooltip

private struct ChartTooltip: View {
    let ssid: String; let rssi: Int; let channel: Int; let bssid: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(ssid).font(.system(size: 10, weight: .semibold)).foregroundColor(.primary)
            Text("CH \(channel)  \(rssi) dBm").font(.system(size: 9)).foregroundColor(.secondary)
            Text(bssid).font(.system(size: 8)).foregroundColor(.secondary)
        }
        .padding(.horizontal, 6).padding(.vertical, 4)
        .background(.regularMaterial).clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
