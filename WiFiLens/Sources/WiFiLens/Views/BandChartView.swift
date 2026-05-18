import SwiftUI

struct BandChartView: View {
    @Bindable var viewModel: BandChartViewModel
    @Bindable var scannerViewModel: ScannerViewModel

    private let leftAxisWidth: CGFloat = 38
    private let bottomAxisHeight: CGFloat = 24

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

    private var chartContent: some View {
        Group {
            if viewModel.isEmpty {
                VStack {
                    Spacer()
                    Text("Loading...")
                        .foregroundColor(Color(hex: "#888888"))
                        .font(.system(size: 16))
                    Spacer()
                }
            } else {
                GeometryReader { geometry in
                    chartCanvas
                        .gesture(zoomGesture(in: geometry))
                }
            }
        }
    }

    private var chartCanvas: some View {
        Canvas { context, size in
            let chartRect = CGRect(
                x: leftAxisWidth, y: 0,
                width: size.width - leftAxisWidth,
                height: size.height - bottomAxisHeight
            )

            let xMin = viewModel.zoomMin ?? Double(xDataMin)
            let xMax = viewModel.zoomMax ?? Double(viewModel.band.maxChannel)
            let yMin = Double(Constants.rssiNoiseFloor)

            // Dynamic y-axis: scale to the strongest visible signal, rounded up to nearest 10
            let strongestRSSI = viewModel.displayedSeriesData.map(\.rssi).max() ?? 0
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
                    at: CGPoint(x: x, y: chartRect.maxY + 12)
                )
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

            for series in viewModel.displayedSeriesData {
                let isSelected = scannerViewModel.selectedNetworkID == series.id
                let hasSelection = scannerViewModel.selectedNetworkID != nil

                let areaOpacity: Double
                let strokeOpacity: Double
                let strokeWidth: CGFloat

                if isSelected {
                    areaOpacity = 0.55
                    strokeOpacity = 1.0
                    strokeWidth = 2
                } else if hasSelection {
                    areaOpacity = series.isFilteredOut ? 0.05 : 0.10
                    strokeOpacity = series.isFilteredOut ? 0.08 : 0.20
                    strokeWidth = 1
                } else {
                    areaOpacity = series.isFilteredOut ? Constants.filteredOutOpacity : 0.3
                    strokeOpacity = series.isFilteredOut ? Constants.filteredOutOpacity : 0.6
                    strokeWidth = 1
                }

                let curve = series.curvePoints
                guard curve.count >= 2 else { continue }

                var path = Path()
                path.move(to: dataToPoint(channel: curve[0].x, rssi: curve[0].y))
                for pt in curve.dropFirst() {
                    path.addLine(to: dataToPoint(channel: pt.x, rssi: pt.y))
                }
                path.addLine(to: dataToPoint(channel: Double(series.right), rssi: yMin))
                path.addLine(to: dataToPoint(channel: Double(series.left), rssi: yMin))
                path.closeSubpath()

                context.fill(path, with: .color(series.color.opacity(areaOpacity)))
                context.stroke(path, with: .color(series.color.opacity(strokeOpacity)), lineWidth: strokeWidth)
            }
        }
        .overlay {
            DataLabelOverlay(
                seriesData: viewModel.displayedSeriesData,
                leftAxisWidth: leftAxisWidth,
                bottomAxisHeight: bottomAxisHeight,
                xDataMin: xDataMin,
                xDataMax: viewModel.band.maxChannel,
                zoomMin: viewModel.zoomMin,
                zoomMax: viewModel.zoomMax,
                selectedNetworkID: scannerViewModel.selectedNetworkID
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
                let chartAreaWidth = totalWidth - chartAreaLeft
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
    let xDataMin: Int
    let xDataMax: Int
    let zoomMin: Double?
    let zoomMax: Double?
    let selectedNetworkID: String?

    var body: some View {
        GeometryReader { geometry in
            let chartRect = CGRect(
                x: leftAxisWidth, y: 0,
                width: geometry.size.width - leftAxisWidth,
                height: geometry.size.height - bottomAxisHeight
            )
            let xMin = zoomMin ?? Double(xDataMin)
            let xMax = zoomMax ?? Double(xDataMax)
            let scaleX = chartRect.width / (xMax - xMin)
            let yRange = 0.0 - Double(Constants.rssiNoiseFloor)
            let scaleY = chartRect.height / yRange
            let hasSelection = selectedNetworkID != nil

            ForEach(seriesData) { series in
                if !series.isFilteredOut || series.id == selectedNetworkID {
                    let px = chartRect.minX + (Double(series.channel) - xMin) * scaleX
                    let py = chartRect.maxY - (Double(series.rssi) - Double(Constants.rssiNoiseFloor)) * scaleY - 10
                    let opacity: Double = hasSelection ? (series.id == selectedNetworkID ? 1.0 : 0.25) : 1.0
                    Text("\(series.channel) \(series.displaySSID)")
                        .font(.system(size: 9))
                        .foregroundColor(series.color)
                        .opacity(opacity)
                        .position(x: px, y: py)
                }
            }
        }
    }
}
