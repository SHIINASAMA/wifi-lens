import SwiftUI

// MARK: - Chart Layout

private let pointSpacing: CGFloat = 4
private let chartHeight: CGFloat = 180
private let leftAxisWidth: CGFloat = 40
private let bottomAxisHeight: CGFloat = 24
private let topMargin: CGFloat = 40

private let segmentColors: [Color] = [
    .blue, .green, .orange, .purple, .teal, .pink, .mint, .indigo
]

private struct BSSIDColorMap {
    private(set) var mapping: [String: Color] = [:]
    private var nextIndex = 0

    mutating func color(for bssid: String) -> Color {
        if let existing = mapping[bssid] { return existing }
        let color = segmentColors[nextIndex % segmentColors.count]
        mapping[bssid] = color
        nextIndex += 1
        return color
    }
}

private func buildBSSIDColorMap(from segments: [RoamingSegment]) -> [String: Color] {
    var map = BSSIDColorMap()
    for segment in segments {
        _ = map.color(for: segment.bssid)
    }
    return map.mapping
}

// MARK: - Formatters

private let timeFormatter: DateComponentsFormatter = {
    let f = DateComponentsFormatter()
    f.allowedUnits = [.minute, .second]
    f.unitsStyle = .positional
    f.zeroFormattingBehavior = .pad
    return f
}()

// MARK: - View

struct RoamingTestView: View {
    @Bindable var viewModel: RoamingTestViewModel

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.isPortable {
                nonPortableWarning
            }

            switch viewModel.state {
            case .idle:
                idleState
            case .ready, .running, .stopped:
                runningContent
            }
        }
        .task {
            viewModel.checkReadiness()
        }
    }

    // MARK: - Non-portable warning

    private var nonPortableWarning: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(String(localized: "This feature is designed for battery-equipped Mac laptops. Desktop Macs cannot simulate mobile roaming scenarios."))
                .font(.system(size: 11))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
    }

    // MARK: - Idle

    private var idleState: some View {
        VStack(spacing: 16) {
            Spacer()
            if let error = viewModel.errorMessage {
                Image(systemName: "wifi.slash")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text(error)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Button(String(localized: "Check Again")) {
                    viewModel.checkReadiness()
                }
                .padding(.top, 8)
            } else {
                ProgressView()
                Text(String(localized: "Checking connection..."))
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Running / Stopped content

    private var runningContent: some View {
        VStack(spacing: 0) {
            signalInfoCard
            statusBar
            trendChart
            transitionTable
        }
    }

    // MARK: - Signal info card

    private var signalInfoCard: some View {
        HStack(spacing: 16) {
            // Left: SSID + status
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(viewModel.isRunning ? Color.green : Color.secondary)
                        .frame(width: 6, height: 6)
                    Text(viewModel.currentSSID ?? "—")
                        .font(.system(size: 15, weight: .semibold))
                }
                HStack(spacing: 8) {
                    if let bssid = viewModel.currentBSSID {
                        Text(bssid)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    if let phy = viewModel.currentPhyMode {
                        Text("·")
                            .foregroundColor(.secondary)
                        Text(phy)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Right: metrics
            HStack(spacing: 20) {
                metricLabel(String(localized: "RSSI"), "\(viewModel.currentRSSI) dBm", rssiColor(viewModel.currentRSSI))
                metricLabel(String(localized: "Channel"), "\(viewModel.currentChannel)", .primary)
                metricLabel(String(localized: "Tx Rate"), String(format: "%.0f Mbps", viewModel.currentTxRate), .primary)
                if let latency = viewModel.gatewayLatency {
                    metricLabel(String(localized: "Latency"), String(format: "%.1f ms", latency), latencyColor(latency))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }

    private func metricLabel(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(color)
        }
    }

    // MARK: - Status bar

    private var statusBar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(timeFormatter.string(from: viewModel.elapsedTime) ?? "0:00")
                    .font(.system(size: 13, design: .monospaced))
            }

            HStack(spacing: 4) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text("\(viewModel.totalSamples) \(String(localized: "samples"))")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.swap")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text("\(viewModel.transitions.count) \(String(localized: "transitions"))")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if viewModel.state == .stopped, viewModel.totalSamples > 0 {
                Button {
                    viewModel.saveSession()
                } label: {
                    Label(String(localized: "Save"), systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if viewModel.state != .running {
                Button {
                    viewModel.loadSession()
                } label: {
                    Label(String(localized: "Load"), systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if viewModel.isRunning {
                Button(String(localized: "Stop")) {
                    viewModel.stopTest()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.small)
            } else {
                Button(String(localized: "Start")) {
                    viewModel.startTest()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!viewModel.canStart)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Trend chart

    private var trendChart: some View {
        let allSamples = segments.flatMap { $0.samples }.sorted { $0.timestamp < $1.timestamp }
        let totalSeconds = max(1, viewModel.elapsedTime)
        let bssidColors = buildBSSIDColorMap(from: viewModel.segments)
        return RoamingTimelineChart(
            segments: viewModel.segments,
            transitions: viewModel.transitions,
            allSamples: allSamples,
            bssidColors: bssidColors,
            elapsedTime: totalSeconds
        )
    }

    private var segments: [RoamingSegment] { viewModel.segments }

    // MARK: - Transition table

    private var transitionTable: some View {
        Group {
            if viewModel.transitions.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "arrow.triangle.swap")
                        .font(.title2)
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(String(localized: viewModel.isRunning ? "Waiting for AP transitions..." : "No AP transitions detected"))
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 0) {
                    // Header
                    Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                        GridRow {
                            tableHeader(String(localized: "Time"))
                            tableHeader(String(localized: "From BSSID"))
                            tableHeader(String(localized: "To BSSID"))
                            tableHeader(String(localized: "RSSI Before"))
                            tableHeader(String(localized: "RSSI After"))
                            tableHeader(String(localized: "Ch Before"))
                            tableHeader(String(localized: "Ch After"))
                        }
                        .background(.bar)
                    }

                    ScrollView {
                        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                            ForEach(Array(viewModel.transitions.enumerated()), id: \.element.id) { idx, t in
                                Divider()
                                GridRow {
                                    tableCell(tsLabel(t.timestamp))
                                    tableCell(t.fromBSSID, mono: true)
                                    tableCell(t.toBSSID, mono: true)
                                    tableCell("\(t.rssiBefore) dBm", color: rssiColor(t.rssiBefore))
                                    tableCell("\(t.rssiAfter) dBm", color: rssiColor(t.rssiAfter))
                                    tableCell("\(t.channelBefore)")
                                    tableCell("\(t.channelAfter)")
                                }
                                .background(idx.isMultiple(of: 2) ? .clear : Color.primary.opacity(0.04))
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                }
            }
        }
    }

    private func tableHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 5)
    }

    private func tableCell(_ text: String, mono: Bool = false, color: Color = .primary) -> some View {
        Text(text)
            .font(.system(size: 11, design: mono ? .monospaced : .default))
            .foregroundColor(color)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 5)
            .lineLimit(1)
    }

    private func tsLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }
}

// MARK: - Chart Canvas

private struct ChartCanvas: View {
    let segments: [RoamingSegment]
    let transitions: [APTransitionEvent]
    let allSamples: [RoamingSample]
    let chartWidth: CGFloat?
    let elapsedTime: TimeInterval
    let bssidColors: [String: Color]
    var timeOffset: TimeInterval = 0
    var sessionStartDate: Date = Date()
    var highlightedTime: TimeInterval?
    var highlightedSample: RoamingSample?

    var body: some View {
        Canvas { context, size in
            let plotLeft = leftAxisWidth
            let plotTop = topMargin
            let plotWidth = size.width - plotLeft - 8
            let plotBottom = size.height - bottomAxisHeight
            let plotHeight = plotBottom - plotTop

            guard plotWidth > 0, plotHeight > 0, !allSamples.isEmpty else { return }

            let rssiMin = min(-100, allSamples.map(\.rssi).min() ?? -100)
            let rssiMax = max(-30, allSamples.map(\.rssi).max() ?? -30)
            let rssiRange = Double(max(1, rssiMax - rssiMin))

            let totalSecs = max(1, elapsedTime)
            let scaleX = plotWidth / CGFloat(totalSecs)

            func xPos(_ ts: Date) -> CGFloat {
                plotLeft + CGFloat(ts.timeIntervalSince(sessionStartDate) - timeOffset) * scaleX
            }

            func yPos(_ rssi: Int) -> CGFloat {
                plotTop + CGFloat(rssiMax - rssi) / CGFloat(rssiRange) * plotHeight
            }

            // Grid lines
            let gridStep = 10
            let gridStart = ((rssiMin) / gridStep) * gridStep
            for rssi in stride(from: gridStart, through: rssiMax, by: gridStep) {
                let y = yPos(rssi)
                var line = Path()
                line.move(to: CGPoint(x: plotLeft, y: y))
                line.addLine(to: CGPoint(x: plotLeft + plotWidth, y: y))
                context.stroke(line, with: .color(.secondary.opacity(0.15)), lineWidth: 0.5)

                let label = Text("\(rssi)")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                let resolved = context.resolve(label)
                let labelSize = resolved.measure(in: CGSize(width: leftAxisWidth - 4, height: 20))
                context.draw(resolved, at: CGPoint(x: plotLeft - 6 - labelSize.width, y: y))
            }

            // Time axis labels
            let timeStep: TimeInterval = max(10, ceil(totalSecs / 6 / 10) * 10)
            var t: TimeInterval = 0
            while t <= totalSecs {
                let x = plotLeft + CGFloat(t) * scaleX
                let label = Text(timeFormatter.string(from: t + timeOffset) ?? "0")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                let resolved = context.resolve(label)
                context.draw(resolved, at: CGPoint(x: x, y: plotBottom + 6))
                t += timeStep
            }

            for (_, segment) in segments.enumerated() {
                let visibleSamples = segment.samples.filter { sample in
                    let t = sample.timestamp.timeIntervalSince(sessionStartDate) - timeOffset
                    return t >= 0 && t <= elapsedTime
                }
                guard visibleSamples.count >= 2 else { continue }
                let midIdx = visibleSamples.count / 2
                let midX = xPos(visibleSamples[midIdx].timestamp)
                let color = bssidColors[segment.bssid] ?? .blue
                let label = Text(segment.bssid)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(color)
                let resolved = context.resolve(label)
                let labelW = resolved.measure(in: CGSize(width: 200, height: 20)).width
                context.draw(resolved, at: CGPoint(x: min(midX, plotLeft + plotWidth - labelW / 2), y: topMargin - 8))
            }

            let clipRect = Path(CGRect(x: plotLeft, y: plotTop - 4, width: plotWidth, height: plotHeight + 8))
            context.clip(to: clipRect)

            for (_, segment) in segments.enumerated() {
                let samples = segment.samples.filter { sample in
                    let t = sample.timestamp.timeIntervalSince(sessionStartDate) - timeOffset
                    return t >= 0 && t <= elapsedTime
                }
                guard samples.count >= 2 else { continue }
                let color = bssidColors[segment.bssid] ?? .blue

                let points = samples.map { CGPoint(x: xPos($0.timestamp), y: yPos($0.rssi)) }

                // Filled area
                var areaPath = Path()
                areaPath.move(to: CGPoint(x: points[0].x, y: plotBottom))
                areaPath.addLine(to: points[0])
                addSpline(to: &areaPath, points: points)
                areaPath.addLine(to: CGPoint(x: points[points.count - 1].x, y: plotBottom))
                areaPath.closeSubpath()
                context.fill(areaPath, with: .color(color.opacity(0.12)))

                // Line
                var linePath = Path()
                linePath.move(to: points[0])
                addSpline(to: &linePath, points: points)
                context.stroke(linePath, with: .color(color), lineWidth: 2)
            }

            for transition in transitions {
                let x = xPos(transition.timestamp)
                guard x >= plotLeft, x <= plotLeft + plotWidth else { continue }
                var dash = Path()
                dash.move(to: CGPoint(x: x, y: plotTop))
                dash.addLine(to: CGPoint(x: x, y: plotBottom))
                context.stroke(dash, with: .color(.secondary.opacity(0.3)), style: .init(dash: [4, 4], dashPhase: 0))
            }

            if let highlightedTime {
                let x = plotLeft + CGFloat(max(0, min(totalSecs, highlightedTime - timeOffset))) * scaleX
                var hoverLine = Path()
                hoverLine.move(to: CGPoint(x: x, y: plotTop))
                hoverLine.addLine(to: CGPoint(x: x, y: plotBottom))
                context.stroke(hoverLine, with: .color(.primary.opacity(0.5)), style: .init(dash: [3, 3], dashPhase: 0))
            }

            if let highlightedSample {
                let x = xPos(highlightedSample.timestamp)
                let y = yPos(highlightedSample.rssi)
                let pointRect = CGRect(x: x - 4, y: y - 4, width: 8, height: 8)
                context.fill(Path(ellipseIn: pointRect), with: .color(.primary))
                context.stroke(Path(ellipseIn: pointRect), with: .color(.accentColor), lineWidth: 2)
            }
        }
    }
}

private func addSpline(to path: inout Path, points: [CGPoint]) {
    guard points.count >= 2 else { return }
    for i in 0..<(points.count - 1) {
        let p0 = i > 0 ? points[i - 1] : points[0]
        let p1 = points[i]
        let p2 = points[i + 1]
        let p3 = i + 2 < points.count ? points[i + 2] : points[points.count - 1]

        let cp1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
        let cp2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
        path.addCurve(to: p2, control1: cp1, control2: cp2)
    }
}

// MARK: - Timeline Chart with Range Selector

private let overviewHeight: CGFloat = 48
private let detailChartHeight: CGFloat = 160
private let defaultWindowDuration: TimeInterval = 30
private let minWindowDuration: TimeInterval = 5
private let selectorHandleHitWidth: CGFloat = 14
private let followTailSnapTolerance: CGFloat = 8

private enum SelectorDragMode {
    case idle
    case resizeLeft
    case panWindow
    case resizeRight
}

private enum SelectorHoverTarget: Equatable {
    case leftHandle
    case body
    case rightHandle
}

private struct SelectorDragState {
    let mode: SelectorDragMode
    let startRangeStart: CGFloat
    let startRangeEnd: CGFloat
    let startWindowDuration: TimeInterval
}

private struct RoamingTimelineChart: View {
    let segments: [RoamingSegment]
    let transitions: [APTransitionEvent]
    let allSamples: [RoamingSample]
    let bssidColors: [String: Color]
    let elapsedTime: TimeInterval

    @State private var rangeStart: CGFloat = 0
    @State private var rangeEnd: CGFloat = 1
    @State private var windowDuration: TimeInterval = defaultWindowDuration
    @State private var pinnedWindowStart: TimeInterval = 0
    @State private var dragState: SelectorDragState?
    @State private var isFollowingTail = true
    @State private var hoveredTarget: SelectorHoverTarget?
    @State private var hoveredDetailTime: TimeInterval?
    @State private var hoveredOverviewX: CGFloat?

    private var clampedWindowDuration: TimeInterval { min(windowDuration, max(1, elapsedTime)) }
    private var windowFraction: CGFloat {
        guard elapsedTime > 0 else { return 1 }
        return min(1, max(CGFloat(clampedWindowDuration / elapsedTime), 0.0001))
    }
    private var visibleStart: TimeInterval { isFollowingTail ? TimeInterval(rangeStart) * elapsedTime : pinnedWindowStart }
    private var visibleEnd: TimeInterval { min(elapsedTime, visibleStart + clampedWindowDuration) }
    private var activeHoverTime: TimeInterval? { hoveredDetailTime ?? hoveredOverviewX.map { TimeInterval($0 / max(overviewPlotWidth, 1)) * elapsedTime } }
    private var highlightedSample: RoamingSample? {
        guard let hoverTime = activeHoverTime, let sessionStart = allSamples.first?.timestamp else { return nil }
        return allSamples.min { lhs, rhs in
            abs(lhs.timestamp.timeIntervalSince(sessionStart) - hoverTime) < abs(rhs.timestamp.timeIntervalSince(sessionStart) - hoverTime)
        }
    }
    @State private var overviewPlotWidth: CGFloat = 1

    var body: some View {
        VStack(spacing: 0) {
            detailChart
            overviewChart
            overviewTimeAxis
        }
        .background(Color.primary.opacity(0.02))
        .onChange(of: elapsedTime) { _, newTotal in
            guard newTotal > 0 else {
                rangeStart = 0
                rangeEnd = 1
                pinnedWindowStart = 0
                return
            }

            windowDuration = min(max(windowDuration, minWindowDuration), max(minWindowDuration, newTotal))

            if isFollowingTail {
                snapToTail(totalTime: newTotal)
            } else {
                pinnedWindowStart = min(max(0, pinnedWindowStart), max(0, newTotal - clampedWindowDuration))
                rangeStart = min(1, max(0, CGFloat(pinnedWindowStart / newTotal)))
                rangeEnd = min(1, rangeStart + windowFraction)
            }
        }
        .onAppear {
            if elapsedTime > 0 {
                windowDuration = min(defaultWindowDuration, elapsedTime)
                snapToTail(totalTime: elapsedTime)
            }
        }
    }

    private func snapToTail(totalTime: TimeInterval) {
        guard totalTime > 0 else {
            rangeStart = 0
            rangeEnd = 1
            pinnedWindowStart = 0
            return
        }
        pinnedWindowStart = max(0, totalTime - clampedWindowDuration)
        rangeStart = max(0, CGFloat(pinnedWindowStart / totalTime))
        rangeEnd = min(1, rangeStart + windowFraction)
    }

    private func time(at locationX: CGFloat, width: CGFloat) -> TimeInterval {
        guard width > 0 else { return 0 }
        let fraction = min(1, max(0, locationX / width))
        return TimeInterval(fraction) * elapsedTime
    }

    private func isSnappedToTail(width: CGFloat) -> Bool {
        guard width > 0 else { return true }
        return (1 - rangeEnd) * width <= followTailSnapTolerance
    }

    private func hoverTarget(at x: CGFloat, width: CGFloat) -> SelectorHoverTarget? {
        let selLeft = min(width, max(0, rangeStart * width))
        let selRight = min(width, max(0, rangeEnd * width))
        let leftHitMin = max(0, selLeft - selectorHandleHitWidth)
        let leftHitMax = min(width, selLeft + selectorHandleHitWidth)
        if x >= leftHitMin, x <= leftHitMax {
            return .leftHandle
        }

        let rightHitMin = max(0, selRight - selectorHandleHitWidth)
        let rightHitMax = min(width, selRight + selectorHandleHitWidth)
        if x >= rightHitMin, x <= rightHitMax {
            return .rightHandle
        }

        if x >= selLeft, x <= selRight {
            return .body
        }

        return nil
    }

    private func beginDrag(at x: CGFloat, width: CGFloat) {
        let target = hoverTarget(at: x, width: width) ?? .body
        hoveredTarget = target
        let mode: SelectorDragMode = switch target {
        case .leftHandle: .resizeLeft
        case .body: .panWindow
        case .rightHandle: .resizeRight
        }
        dragState = SelectorDragState(
            mode: mode,
            startRangeStart: rangeStart,
            startRangeEnd: rangeEnd,
            startWindowDuration: clampedWindowDuration
        )
        isFollowingTail = false
    }

    private func updateDrag(translationX: CGFloat, width: CGFloat) {
        guard let dragState, width > 0, elapsedTime > 0 else { return }
        let delta = translationX / width

        switch dragState.mode {
        case .panWindow:
            let span = dragState.startRangeEnd - dragState.startRangeStart
            let maxStart = max(0, 1 - span)
            let newStart = max(0, min(maxStart, dragState.startRangeStart + delta))
            rangeStart = newStart
            rangeEnd = min(1, newStart + span)
            pinnedWindowStart = TimeInterval(rangeStart) * elapsedTime
            isFollowingTail = isSnappedToTail(width: width)

        case .resizeLeft:
            let anchorEnd = dragState.startRangeEnd
            let proposedStart = max(0, min(anchorEnd - CGFloat(minWindowDuration / elapsedTime), dragState.startRangeStart + delta))
            let proposedFraction = max(CGFloat(minWindowDuration / elapsedTime), anchorEnd - proposedStart)
            let proposedDuration = TimeInterval(proposedFraction) * elapsedTime
            windowDuration = min(elapsedTime, max(minWindowDuration, proposedDuration))
            rangeStart = max(0, anchorEnd - windowFraction)
            rangeEnd = min(1, rangeStart + windowFraction)
            pinnedWindowStart = TimeInterval(rangeStart) * elapsedTime
            isFollowingTail = isSnappedToTail(width: width)

        case .resizeRight:
            let anchorStart = dragState.startRangeStart
            let maxEnd = 1.0
            let proposedEnd = min(maxEnd, max(anchorStart + CGFloat(minWindowDuration / elapsedTime), dragState.startRangeEnd + delta))
            let proposedFraction = max(CGFloat(minWindowDuration / elapsedTime), proposedEnd - anchorStart)
            let proposedDuration = TimeInterval(proposedFraction) * elapsedTime
            windowDuration = min(elapsedTime, max(minWindowDuration, proposedDuration))
            rangeStart = anchorStart
            rangeEnd = min(1, rangeStart + windowFraction)
            pinnedWindowStart = TimeInterval(rangeStart) * elapsedTime
            isFollowingTail = isSnappedToTail(width: width)

        case .idle:
            break
        }
    }

    private func endDrag(width: CGFloat) {
        if isSnappedToTail(width: width) {
            isFollowingTail = true
            snapToTail(totalTime: elapsedTime)
        }
        dragState = nil
    }

    // MARK: Detail chart

    private var overviewTimeAxis: some View {
        let midTickCount = max(0, min(4, Int(overviewPlotWidth / 100)))
        var allTicks: [TimeInterval] = [0]
        if elapsedTime > 0, midTickCount > 0 {
            let step = elapsedTime / TimeInterval(midTickCount + 1)
            for i in 1...midTickCount {
                allTicks.append(step * TimeInterval(i))
            }
        }
        allTicks.append(max(0, elapsedTime))

        return HStack(spacing: 0) {
            ForEach(Array(allTicks.enumerated()), id: \.offset) { i, tick in
                if i > 0 { Spacer(minLength: 0) }
                Text(timeFormatter.string(from: tick) ?? "0")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    private var detailChart: some View {
        let sessionStart = allSamples.first?.timestamp ?? Date()
        let visibleSamples = allSamples.filter {
            let t = $0.timestamp.timeIntervalSince(sessionStart)
            return t >= visibleStart && t <= visibleEnd
        }

        guard let firstSample = visibleSamples.first, let lastSample = visibleSamples.last else {
            return AnyView(Spacer().frame(height: detailChartHeight + topMargin + bottomAxisHeight))
        }
        let dataStart = firstSample.timestamp.timeIntervalSince(sessionStart)
        let dataEnd = lastSample.timestamp.timeIntervalSince(sessionStart)
        let rangeSecs = max(0.1, dataEnd - dataStart)

        return AnyView(GeometryReader { geo in
            let plotWidth = max(1, geo.size.width - leftAxisWidth - 8)
            ZStack(alignment: .topLeading) {
                ChartCanvas(
                    segments: segments,
                    transitions: transitions,
                    allSamples: visibleSamples,
                    chartWidth: nil,
                    elapsedTime: rangeSecs,
                    bssidColors: bssidColors,
                    timeOffset: dataStart,
                    sessionStartDate: sessionStart,
                    highlightedTime: activeHoverTime,
                    highlightedSample: highlightedSample
                )

                if let highlightedSample, let hoverTime = activeHoverTime {
                    detailValueBadge(sample: highlightedSample, time: hoverTime, plotWidth: plotWidth)
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    let plotX = max(0, min(plotWidth, location.x - leftAxisWidth))
                    hoveredDetailTime = dataStart + TimeInterval(plotX / plotWidth) * rangeSecs
                case .ended:
                    hoveredDetailTime = nil
                }
            }
        }
        .frame(height: detailChartHeight + topMargin + bottomAxisHeight)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .clipped())
    }

    private func detailValueBadge(sample: RoamingSample, time: TimeInterval, plotWidth: CGFloat) -> some View {
        let timeText = timeFormatter.string(from: time) ?? "0:00"
        return HStack(spacing: 8) {
            Text(timeText)
            Text("RSSI \(sample.rssi) dBm")
            Text("Ch \(sample.channel)")
            Text(String(format: "Tx %.0f Mbps", sample.txRate))
            if let latency = sample.gatewayLatency {
                Text(String(format: "RTT %.1f ms", latency))
            }
        }
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .foregroundColor(.primary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.regularMaterial, in: Capsule())
        .padding(.leading, 12)
        .padding(.top, 6)
    }

    // MARK: Overview chart

    private var overviewChart: some View {
        GeometryReader { geo in
            let w = max(1, geo.size.width)
            let selLeft = min(w, max(0, rangeStart * w))
            let selRight = min(w, max(0, rangeEnd * w))
            let selWidth = max(0, selRight - selLeft)
            let bodyHovered = hoveredTarget == .body
            let leftHovered = hoveredTarget == .leftHandle
            let rightHovered = hoveredTarget == .rightHandle
            let dragging = dragState != nil

            ZStack(alignment: .leading) {
                OverviewCanvas(
                    segments: segments,
                    transitions: transitions,
                    bssidColors: bssidColors,
                    elapsedTime: elapsedTime,
                    highlightedTime: activeHoverTime
                )
                .frame(width: w, height: overviewHeight)
                .clipShape(RoundedRectangle(cornerRadius: 4))

                Rectangle()
                    .fill(.thinMaterial)
                    .frame(width: w, height: overviewHeight)

                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(bodyHovered || dragging ? 0.12 : 0.06))
                    .frame(width: max(selWidth, 0), height: overviewHeight)
                    .offset(x: selLeft)
                    .overlay(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.primary.opacity(dragging ? 0.5 : 0.25), lineWidth: dragging ? 1.5 : 1)
                            .frame(width: max(selWidth, 0), height: overviewHeight)
                            .offset(x: selLeft)
                    }
                    .overlay(alignment: .topLeading) {
                        if selWidth > 0 {
                            Rectangle()
                                .fill(Color.primary.opacity(0.3))
                                .frame(width: max(1, selWidth), height: 1)
                                .offset(x: selLeft, y: 0)
                        }
                    }

                selectorHandle(isActive: leftHovered || dragState?.mode == .panWindow)
                    .frame(width: selectorHandleHitWidth * 2, height: overviewHeight)
                    .offset(x: selLeft - selectorHandleHitWidth)

                selectorHandle(isActive: rightHovered || dragState?.mode == .panWindow)
                    .frame(width: selectorHandleHitWidth * 2, height: overviewHeight)
                    .offset(x: selRight - selectorHandleHitWidth)

                if selWidth > 0 {
                    edgeTimeBadge(time: visibleStart)
                        .offset(x: selLeft - 20, y: -overviewHeight / 2 - 8)
                    edgeTimeBadge(time: visibleEnd)
                        .offset(x: selRight - 20, y: -overviewHeight / 2 - 8)
                }

                if let hoveredOverviewX {
                    let markerTime = highlightedSample?.timestamp.timeIntervalSince(allSamples.first?.timestamp ?? Date()) ?? TimeInterval(hoveredOverviewX / max(w, 1)) * elapsedTime
                    let x = min(w, max(0, CGFloat(markerTime / max(elapsedTime, 0.1)) * w))
                    Rectangle()
                        .fill(Color.primary.opacity(0.4))
                        .frame(width: 1, height: overviewHeight)
                        .offset(x: x)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
            .onAppear {
                overviewPlotWidth = w
            }
            .onChange(of: w) { _, newWidth in
                overviewPlotWidth = newWidth
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    hoveredTarget = hoverTarget(at: location.x, width: w)
                    hoveredOverviewX = max(0, min(w, location.x))
                case .ended:
                    hoveredTarget = nil
                    hoveredOverviewX = nil
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if dragState == nil {
                            beginDrag(at: value.startLocation.x, width: w)
                        }
                        updateDrag(translationX: value.translation.width, width: w)
                        hoveredOverviewX = max(0, min(w, value.location.x))
                    }
                    .onEnded { _ in
                        endDrag(width: w)
                    }
            )
        }
        .frame(height: overviewHeight)
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
    }

    private func edgeTimeBadge(time: TimeInterval) -> some View {
        Text(timeFormatter.string(from: time) ?? "0:00")
            .font(.system(size: 9, design: .monospaced))
            .foregroundColor(.primary)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 3))
    }

    private func selectorHandle(isActive: Bool) -> some View {
        let color = Color.accentColor.opacity(isActive ? 0.9 : 0.4)
        return ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(.regularMaterial)
                .frame(width: 8, height: 22)
            VStack(spacing: 3) {
                Circle().fill(color).frame(width: 2.5, height: 2.5)
                Circle().fill(color).frame(width: 2.5, height: 2.5)
                Circle().fill(color).frame(width: 2.5, height: 2.5)
            }
        }
    }
}

// MARK: - Overview mini canvas

private struct OverviewCanvas: View {
    let segments: [RoamingSegment]
    let transitions: [APTransitionEvent]
    let bssidColors: [String: Color]
    let elapsedTime: TimeInterval
    let highlightedTime: TimeInterval?

    var body: some View {
        Canvas { context, size in
            guard !segments.isEmpty, elapsedTime > 0 else { return }

            var rssiVals: [Int] = []
            for seg in segments { rssiVals.append(contentsOf: seg.samples.map(\.rssi)) }
            let rssiMin = Double(min(-100, rssiVals.min() ?? -100))
            let rssiMax = Double(max(-30, rssiVals.max() ?? -30))
            let rssiRange = max(1, rssiMax - rssiMin)

            let startDate = segments.first?.samples.first?.timestamp ?? Date()

            func xPos(_ ts: Date) -> CGFloat {
                CGFloat(ts.timeIntervalSince(startDate) / elapsedTime) * size.width
            }
            func yPos(_ rssi: Int) -> CGFloat {
                size.height - CGFloat(Double(rssi) - rssiMin) / CGFloat(rssiRange) * size.height
            }

            for segment in segments {
                let samples = segment.samples
                guard samples.count >= 2 else { continue }
                let color = bssidColors[segment.bssid] ?? .blue

                var path = Path()
                path.move(to: CGPoint(x: xPos(samples[0].timestamp), y: yPos(samples[0].rssi)))
                for i in 1..<samples.count {
                    path.addLine(to: CGPoint(x: xPos(samples[i].timestamp), y: yPos(samples[i].rssi)))
                }
                context.stroke(path, with: .color(color), lineWidth: 1)
            }

            for t in transitions {
                let x = xPos(t.timestamp)
                var line = Path()
                line.move(to: CGPoint(x: x, y: 0))
                line.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(line, with: .color(.primary.opacity(0.15)), lineWidth: 0.5)
            }

            if let highlightedTime {
                let x = CGFloat(highlightedTime / elapsedTime) * size.width
                var hoverLine = Path()
                hoverLine.move(to: CGPoint(x: x, y: 0))
                hoverLine.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(hoverLine, with: .color(.primary.opacity(0.5)), style: .init(dash: [3, 3], dashPhase: 0))
            }
        }
    }
}

// MARK: - RSSI color

private func rssiColor(_ rssi: Int) -> Color {
    if rssi >= -50 { return .green }
    if rssi >= -70 { return .yellow }
    if rssi >= -85 { return .orange }
    return .red
}

private func latencyColor(_ ms: Double) -> Color {
    if ms < 5 { return .green }
    if ms < 20 { return .yellow }
    return .red
}
