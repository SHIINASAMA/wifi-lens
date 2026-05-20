import SwiftUI

struct BandChartView: View {
    @Bindable var viewModel: BandChartViewModel
    @Bindable var scannerViewModel: ScannerViewModel

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
            if viewModel.isExpanded {
                expandedOverlay
            }
        }
    }

    private var chartToolbar: some View {
        HStack(spacing: 4) {
            if viewModel.zoomMin != nil {
                Button {
                    viewModel.resetZoom()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .frame(width: 24, height: 24)
                }
                .help("Reset Zoom")
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
    }

    /// Snapshots for the network currently selected (if it belongs to this band).
    private var selectedSnapshots: [NetworkSnapshot]? {
        viewModel.renderedSnapshots(for: scannerViewModel.selectedNetworkID)
    }

    private var selectedSeries: ChartSeriesData? {
        viewModel.renderedSeries(for: scannerViewModel.selectedNetworkID)
    }

    private var visibleSeries: [ChartSeriesData] {
        viewModel.visibleSeriesData()
    }

    private var renderedSeriesData: [ChartSeriesData] {
        viewModel.renderedDisplayedSeriesData
    }

    private var strongestRSSI: Int {
        viewModel.strongestRenderedRSSI()
    }

    private var isEmpty: Bool {
        viewModel.renderedIsEmpty
    }

    private var selectedNetworkID: String? {
        scannerViewModel.selectedNetworkID
    }

    private var hasSelection: Bool {
        selectedNetworkID != nil
    }

    private func isSelected(_ series: ChartSeriesData) -> Bool {
        selectedNetworkID == series.id
    }

    private func strokeStyle(for series: ChartSeriesData) -> (areaOpacity: Double, strokeOpacity: Double, strokeWidth: CGFloat) {
        if isSelected(series) {
            return (0.55, 1.0, 2)
        }
        if hasSelection {
            return (0.10, 0.20, 1)
        }
        return (0.3, 0.6, 1)
    }

    private var chartContent: some View {
        Group {
            if isEmpty {
                VStack {
                    Spacer()
                    Text("Loading...")
                        .foregroundColor(Color(hex: "#888888"))
                        .font(.system(size: 16))
                    Spacer()
                }
            } else {
                VStack(spacing: 0) {
                    GeometryReader { geometry in
                        chartCanvas
                            .gesture(zoomGesture(in: geometry))
                    }

                    if let snaps = selectedSnapshots, let series = selectedSeries {
                        Divider()
                            .padding(.top, 2)
                        TrendChartView(snapshots: snaps, color: series.color)
                            .padding(.horizontal, 6)
                            .padding(.bottom, 6)
                    }
                }
            }
        }
    }

    private var chartCanvas: some View {
        Canvas { context, size in
            let chartRect = CGRect(
                x: leftAxisWidth, y: chartMarginTop,
                width: size.width - leftAxisWidth - chartMarginRight,
                height: size.height - bottomAxisHeight - chartMarginTop - chartMarginBottom
            )

            let xMin = viewModel.zoomMin ?? Double(xDataMin)
            let xMax = viewModel.zoomMax ?? Double(viewModel.band.maxChannel)
            let yMin = Double(Constants.rssiNoiseFloor)

            // Dynamic y-axis: scale to the strongest visible signal, rounded up to nearest 10
            let yMax = min(0.0, ceil(Double(strongestRSSI) / 10.0) * 10)

            let scaleX = chartRect.width / (xMax - xMin)
            let scaleY = chartRect.height / (yMax - yMin)

            func dataToPoint(channel: Double, rssi: Double) -> CGPoint {
                CGPoint(
                    x: chartRect.minX + (channel - xMin) * scaleX,
                    y: chartRect.maxY - (rssi - yMin) * scaleY
                )
            }

            let gridColor = Color.gray.opacity(0.15)

            for rssiVal in stride(from: Int(yMin), through: Int(yMax), by: 10) {
                let rssi = Double(rssiVal)
                let y = chartRect.maxY - (rssi - yMin) * scaleY
                var line = Path()
                line.move(to: CGPoint(x: chartRect.minX, y: y))
                line.addLine(to: CGPoint(x: chartRect.maxX, y: y))
                context.stroke(line, with: .color(gridColor), lineWidth: 1)

                context.draw(
                    Text("\(rssiVal)").font(.caption2).foregroundColor(.secondary),
                    at: CGPoint(x: chartRect.minX - 14, y: y)
                )
            }

            let desiredTicks = min(viewModel.band.maxChannel - Int(xMin), 15)
            let rawStep = max(1, Int((xMax - xMin) / Double(desiredTicks)))
            let step = max(1, rawStep)
            for ch in stride(from: Int(xMin), through: Int(xMax), by: step) {
                if viewModel.band == .band24GHz && ch < 1 { continue }

                let x = chartRect.minX + (Double(ch) - xMin) * scaleX

                var line = Path()
                line.move(to: CGPoint(x: x, y: chartRect.minY))
                line.addLine(to: CGPoint(x: x, y: chartRect.maxY))
                context.stroke(line, with: .color(gridColor), lineWidth: 1)

                context.draw(
                    Text("\(ch)").font(.caption2).foregroundColor(.secondary),
                    at: CGPoint(x: x, y: chartRect.maxY + 28)
                )
            }

            // Channel occupancy heatmap — one bar per signal, below the x-axis
            let heatHeight: CGFloat = 14
            let barWidth: CGFloat = 5
            let barGap: CGFloat = 1
            let heatY = chartRect.maxY + 3
            let visible = visibleSeries

            // Group by integer-rounded apex to count occupancy and stack bars
            var apexSignals: [Int: [Color]] = [:]
            for s in visible {
                apexSignals[Int(s.apex.rounded()), default: []].append(s.color)
            }
            let maxCnt = CGFloat(max(1, apexSignals.values.map(\.count).max() ?? 1))
            for (apex, colors) in apexSignals {
                let x = chartRect.minX + (Double(apex) - xMin) * scaleX
                let opacity = 0.18 + (CGFloat(colors.count) / maxCnt) * 0.45
                for (i, color) in colors.enumerated() {
                    let offset = CGFloat(i) * (barWidth + barGap) - CGFloat(colors.count - 1) * (barWidth + barGap) / 2
                    let barX = x - barWidth / 2 + offset
                    var bar = Path()
                    bar.addRect(CGRect(x: barX, y: heatY, width: barWidth, height: heatHeight))
                    context.fill(bar, with: .color(color.opacity(opacity)))
                }
            }

            var xAxis = Path()
            xAxis.move(to: CGPoint(x: chartRect.minX, y: chartRect.maxY))
            xAxis.addLine(to: CGPoint(x: chartRect.maxX, y: chartRect.maxY))
            context.stroke(xAxis, with: .color(.secondary), lineWidth: 1)

            var yAxis = Path()
            yAxis.move(to: CGPoint(x: chartRect.minX, y: chartRect.minY))
            yAxis.addLine(to: CGPoint(x: chartRect.minX, y: chartRect.maxY))
            context.stroke(yAxis, with: .color(.secondary), lineWidth: 1)

            let clipPath = Path(chartRect)
            context.clip(to: clipPath)

            for series in visibleSeries {
                let style = strokeStyle(for: series)

                let curve = series.displayCurvePoints
                guard curve.count >= 2 else { continue }

                var path = Path()
                path.move(to: dataToPoint(channel: curve[0].x, rssi: curve[0].y))
                for pt in curve.dropFirst() {
                    path.addLine(to: dataToPoint(channel: pt.x, rssi: pt.y))
                }
                path.addLine(to: dataToPoint(channel: Double(series.right), rssi: yMin))
                path.addLine(to: dataToPoint(channel: Double(series.left), rssi: yMin))
                path.closeSubpath()

                context.fill(path, with: .color(series.color.opacity(style.areaOpacity)))
                context.stroke(path, with: .color(series.color.opacity(style.strokeOpacity)), lineWidth: style.strokeWidth)
            }
        }
        .overlay {
            DataLabelOverlay(
                seriesData: renderedSeriesData,
                leftAxisWidth: leftAxisWidth,
                bottomAxisHeight: bottomAxisHeight,
                chartMarginTop: chartMarginTop,
                chartMarginRight: chartMarginRight,
                chartMarginBottom: chartMarginBottom,
                xDataMin: xDataMin,
                xDataMax: viewModel.band.maxChannel,
                zoomMin: viewModel.zoomMin,
                zoomMax: viewModel.zoomMax,
                selectedNetworkID: selectedNetworkID
            )
        }
    }

    private func zoomGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onEnded { value in
                let startX = min(value.startLocation.x, value.location.x)
                let endX = max(value.startLocation.x, value.location.x)
                guard endX - startX > 20 else { return }

                let totalWidth = geometry.size.width
                let chartAreaLeft = leftAxisWidth
                let chartAreaWidth = totalWidth - chartAreaLeft - chartMarginRight
                guard chartAreaWidth > 0 else { return }

                let relStart = Swift.max(0.0, startX - chartAreaLeft)
                let relEnd = Swift.min(chartAreaWidth, endX - chartAreaLeft)

                let dataXMin = Double(xDataMin)
                let dataXMax = Double(viewModel.band.maxChannel)
                let dataRange = dataXMax - dataXMin

                let lo = dataXMin + (relStart / chartAreaWidth) * dataRange
                let hi = dataXMin + (relEnd / chartAreaWidth) * dataRange
                viewModel.applyZoom(lo: lo, hi: hi)
            }
    }

    private var expandedOverlay: some View {
        ZStack(alignment: .topTrailing) {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                chartToolbar
                chartCanvas
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding()

            Button {
                viewModel.toggleExpand()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .padding(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var xDataMin: Int {
        viewModel.band == .band24GHz ? -1 : 1
    }
}

private struct DataLabelOverlay: View {
    let seriesData: [ChartSeriesData]
    let leftAxisWidth: CGFloat
    let bottomAxisHeight: CGFloat
    let chartMarginTop: CGFloat
    let chartMarginRight: CGFloat
    let chartMarginBottom: CGFloat
    let xDataMin: Int
    let xDataMax: Int
    let zoomMin: Double?
    let zoomMax: Double?
    let selectedNetworkID: String?

    var body: some View {
        GeometryReader { geometry in
            let chartRect = CGRect(
                x: leftAxisWidth, y: chartMarginTop,
                width: geometry.size.width - leftAxisWidth - chartMarginRight,
                height: geometry.size.height - bottomAxisHeight - chartMarginTop - chartMarginBottom
            )
            let xMin = zoomMin ?? Double(xDataMin)
            let xMax = zoomMax ?? Double(xDataMax)
            let scaleX = chartRect.width / (xMax - xMin)
            let yRange = 0.0 - Double(Constants.rssiNoiseFloor)
            let scaleY = chartRect.height / yRange
            let hasSelection = selectedNetworkID != nil

            let labels = placedLabels(chartRect: chartRect, xMin: xMin, scaleX: scaleX, scaleY: scaleY, hasSelection: hasSelection)

            ForEach(labels, id: \.series.id) { item in
                let trendStr: String = if !item.series.trendArrow.isEmpty {
                    " \(item.series.trendArrow)\(item.series.trendDelta != 0 ? " \(item.series.trendDelta > 0 ? "+" : "")\(item.series.trendDelta)" : "")"
                } else { "" }
                Text("\(item.series.channel) \(item.series.displaySSID)\(trendStr)")
                    .font(.system(size: 9))
                    .foregroundColor(item.series.color)
                    .opacity(item.opacity)
                    .position(x: item.x, y: item.y)
            }
        }
    }

    private struct PlacedLabel {
        let series: ChartSeriesData
        let x: CGFloat
        let y: CGFloat
        let opacity: Double
    }

    private func placedLabels(chartRect: CGRect, xMin: Double, scaleX: CGFloat, scaleY: CGFloat, hasSelection: Bool) -> [PlacedLabel] {
        let labelEstWidth: CGFloat = 100
        let labelEstHeight: CGFloat = 14
        let lineHeight: CGFloat = labelEstHeight + 2

        // Sort: selected first, then strongest RSSI
        let candidates = seriesData
            .filter { ($0.isVisible && !$0.isFilteredOut) || $0.id == selectedNetworkID }
            .sorted { a, b in
                if a.id == selectedNetworkID { return true }
                if b.id == selectedNetworkID { return false }
                return a.rssi > b.rssi
            }

        var placed: [PlacedLabel] = []
        var occupied: [CGRect] = []

        for series in candidates {
            let px = chartRect.minX + (series.apex - xMin) * scaleX
            let naturalY = chartRect.maxY - (series.displayRSSI - Double(Constants.rssiNoiseFloor)) * scaleY - 8
            let isSelected = series.id == selectedNetworkID
            let opacity: Double = hasSelection ? (isSelected ? 1.0 : 0.25) : 1.0

            var labelY = naturalY
            var fits = false
            for _ in 0..<6 {
                let rect = CGRect(x: px - labelEstWidth / 2, y: labelY - labelEstHeight,
                                  width: labelEstWidth, height: labelEstHeight)
                if !occupied.contains(where: { $0.intersects(rect) }) {
                    occupied.append(rect)
                    fits = true
                    break
                }
                labelY -= lineHeight
            }
            // Always show selected label even if it overlaps
            if !fits && !isSelected { continue }
            if !fits { labelY = naturalY }  // selected but overlaps: use natural position

            placed.append(PlacedLabel(series: series, x: px, y: labelY, opacity: opacity))
        }
        return placed
    }
}
