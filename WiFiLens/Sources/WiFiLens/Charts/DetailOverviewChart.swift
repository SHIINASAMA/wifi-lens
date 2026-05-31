import SwiftUI

// MARK: - Detail + Overview Chart

/// A linked pair of charts: a detail view showing a zoomed window, and an overview
/// strip with a `RangeSelector` for panning/resizing the window. Domain-agnostic —
/// works with time, frequency, channel numbers, or any continuous `Double` domain.
struct DetailOverviewChart<DetailOverlay: View, OverviewOverlay: View>: View {
    let series: [ChartSeries]
    var domain: ClosedRange<Double> = 0...1
    var minWindowSpan: Double = 5
    var defaultWindowSpan: Double = 30
    var detailHeight: CGFloat = 280
    var overviewHeight: CGFloat = 48
    var followMax: Bool = false

    var detailStyle: ChartStyle = .init(leftAxisWidth: 40, bottomAxisHeight: 24, marginTop: 40, marginRight: 8, marginBottom: 4)
    var overviewStyle: ChartStyle = .init(leftAxisWidth: 0, bottomAxisHeight: 0, marginTop: 0, marginRight: 0, marginBottom: 0)
    var detailAxis: ChartAxisConfig = .init()
    var overviewAxis: ChartAxisConfig = .init()

    /// Formats domain values into axis labels.
    var domainLabel: (Double) -> String = { String(format: "%.0f", $0) }

    /// Detail chart overlays (e.g. transition markers, hover highlights, data labels).
    @ViewBuilder var detailOverlay: (ClosedRange<Double>) -> DetailOverlay
    /// Overview chart overlays.
    @ViewBuilder var overviewOverlay: () -> OverviewOverlay

    /// Called with the domain value under the cursor.
    var onHover: (Double?) -> Void = { _ in }

    @State private var windowStart: Double = 0
    @State private var windowEnd: Double = 30

    var body: some View {
        VStack(spacing: 0) {
            detailChart
            overviewStrip
        }
        .onAppear {
            windowStart = domain.lowerBound
            windowEnd = min(domain.upperBound, domain.lowerBound + min(defaultWindowSpan, domain.span))
        }
    }

    // MARK: - Detail Chart

    private var detailChart: some View {
        let window = windowStart...windowEnd
        return Chart(
            series: seriesInWindow(window),
            axis: detailAxisForWindow(window),
            style: detailStyle
        ) { geo, _ in detailOverlay(window) }
        .frame(height: detailHeight)
    }

    private func seriesInWindow(_ window: ClosedRange<Double>) -> [ChartSeries] {
        series.map { s in
            ChartSeries(id: s.id, points: s.points.filter { window.contains($0.x) }, style: s.style)
        }
    }

    private func detailAxisForWindow(_ window: ClosedRange<Double>) -> ChartAxisConfig {
        var a = detailAxis
        a.xMin = window.lowerBound; a.xMax = window.upperBound
        if a.xTicks.isEmpty {
            let step = max(1, (window.upperBound - window.lowerBound) / 6)
            var ticks: [ChartAxisConfig.XTick] = []
            var t = ceil(window.lowerBound / step) * step
            while t <= window.upperBound {
                ticks.append(ChartAxisConfig.XTick(position: t, label: domainLabel(t)))
                t += step
            }
            a.xTicks = ticks
        }
        return a
    }

    // MARK: - Overview Strip

    private var overviewStrip: some View {
        VStack(spacing: 0) {
            RangeSelector(
                domain: domain,
                minWindowSpan: minWindowSpan,
                defaultWindowSpan: defaultWindowSpan,
                overviewHeight: overviewHeight,
                overview: {
                    Chart(series: series, axis: overviewAxis, style: overviewStyle) { _, _ in overviewOverlay() }
                },
                edgeLabel: domainLabel,
                onWindowChange: { range in
                    windowStart = range.start
                    windowEnd = range.end
                },
                onHover: onHover,
                followMax: followMax
            )
            .padding(.horizontal, 8)
            .padding(.bottom, 6)

            // Overview time axis
            overviewTimeAxis
        }
    }

    private var overviewTimeAxis: some View {
        let step = max(1, (domain.upperBound - domain.lowerBound) / 4)
        var ticks: [Double] = [domain.lowerBound]
        var t = ceil(domain.lowerBound / step) * step
        while t < domain.upperBound { ticks.append(t); t += step }
        ticks.append(domain.upperBound)

        return HStack(spacing: 0) {
            ForEach(Array(ticks.enumerated()), id: \.offset) { i, tick in
                if i > 0 { Spacer(minLength: 0) }
                Text(domainLabel(tick))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }
}

// MARK: - Convenience (no overlays)

extension DetailOverviewChart where DetailOverlay == EmptyView, OverviewOverlay == EmptyView {
    init(
        series: [ChartSeries],
        domain: ClosedRange<Double> = 0...1,
        minWindowSpan: Double = 5,
        defaultWindowSpan: Double = 30,
        detailHeight: CGFloat = 280,
        overviewHeight: CGFloat = 48,
        followMax: Bool = false,
        detailStyle: ChartStyle = .init(leftAxisWidth: 40, bottomAxisHeight: 24, marginTop: 40, marginRight: 8, marginBottom: 4),
        overviewStyle: ChartStyle = .init(leftAxisWidth: 0, bottomAxisHeight: 0, marginTop: 0, marginRight: 0, marginBottom: 0),
        detailAxis: ChartAxisConfig = .init(),
        domainLabel: @escaping (Double) -> String = { String(format: "%.0f", $0) },
        onHover: @escaping (Double?) -> Void = { _ in }
    ) {
        self.series = series
        self.domain = domain
        self.minWindowSpan = minWindowSpan
        self.defaultWindowSpan = defaultWindowSpan
        self.detailHeight = detailHeight
        self.overviewHeight = overviewHeight
        self.followMax = followMax
        self.detailStyle = detailStyle
        self.overviewStyle = overviewStyle
        self.detailAxis = detailAxis
        self.domainLabel = domainLabel
        self.onHover = onHover
        self.detailOverlay = { _ in EmptyView() }
        self.overviewOverlay = { EmptyView() }
    }
}
