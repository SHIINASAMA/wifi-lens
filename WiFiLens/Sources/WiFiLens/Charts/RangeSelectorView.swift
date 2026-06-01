import SwiftUI
import AppKit

// MARK: - Range Selector Types

enum SelectorDragMode { case idle, resizeLeft, panWindow, resizeRight }

enum SelectorHoverTarget: Equatable { case leftHandle, body, rightHandle }

struct SelectorDragState {
    let mode: SelectorDragMode
    let startRangeStart: CGFloat
    let startRangeEnd: CGFloat
    let startWindowSpan: Double
}

// MARK: - Inverted Selection Mask

private struct InvertedRoundedSelectionShape: Shape {
    let selectionRect: CGRect
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addPath(RoundedRectangle(cornerRadius: cornerRadius).path(in: selectionRect), transform: .identity)
        return path
    }
}

// MARK: - Selector Handle

private struct SelectorHandle: View {
    let isActive: Bool
    var body: some View {
        let color = Color.accentColor.opacity(isActive ? 0.9 : 0.4)
        ZStack {
            RoundedRectangle(cornerRadius: 5).fill(.regularMaterial).frame(width: 10, height: 28)
            VStack(spacing: 3.5) {
                Circle().fill(color).frame(width: 3, height: 3)
                Circle().fill(color).frame(width: 3, height: 3)
                Circle().fill(color).frame(width: 3, height: 3)
            }
        }
    }
}

// MARK: - Range Selector

private let handleHitWidth: CGFloat = 14
private let followEdgeSnapTolerance: CGFloat = 8

/// A horizontal overview strip with a draggable, resizable window that selects a
/// sub-range of a continuous domain. Domain-agnostic — works for time, frequency,
/// channel numbers, or any `Double` range.
struct RangeSelector<Content: View>: View {
    /// The full domain range.
    let domain: ClosedRange<Double>
    /// Minimum selectable window span in domain units.
    let minWindowSpan: Double
    /// Default initial window span.
    let defaultWindowSpan: Double
    /// Height of the overview strip.
    let overviewHeight: CGFloat
    /// Overview content (compressed chart).
    @ViewBuilder let overview: () -> Content
    /// Formats domain values into edge badge labels.
    var edgeLabel: (Double) -> String = { String(format: "%.0f", $0) }
    /// Called when the visible window changes.
    var onWindowChange: ((start: Double, end: Double)) -> Void = { _ in }
    /// Called when the user hovers over a domain position.
    var onHover: (Double?) -> Void = { _ in }
    /// When true, the window auto-follows the max edge of the domain (e.g. for live data).
    var followMax: Bool = false

    @State private var rangeStart: CGFloat = 0
    @State private var rangeEnd: CGFloat = 1
    @State private var windowSpan: Double
    @State private var pinnedWindowStart: Double = 0
    @State private var isFollowingMax: Bool
    @State private var dragState: SelectorDragState?
    @State private var hoveredTarget: SelectorHoverTarget?
    @State private var hoveredX: CGFloat?
    @State private var hasInitialized = false

    init(
        domain: ClosedRange<Double>,
        minWindowSpan: Double = 1,
        defaultWindowSpan: Double = 30,
        overviewHeight: CGFloat = 48,
        @ViewBuilder overview: @escaping () -> Content,
        edgeLabel: @escaping (Double) -> String = { String(format: "%.0f", $0) },
        onWindowChange: @escaping ((start: Double, end: Double)) -> Void = { _ in },
        onHover: @escaping (Double?) -> Void = { _ in },
        followMax: Bool = false
    ) {
        self.domain = domain
        self.minWindowSpan = minWindowSpan
        self.defaultWindowSpan = defaultWindowSpan
        self.overviewHeight = overviewHeight
        self.overview = overview
        self.edgeLabel = edgeLabel
        self.onWindowChange = onWindowChange
        self.onHover = onHover
        self.followMax = followMax
        _windowSpan = State(initialValue: min(defaultWindowSpan, domain.span))
        _isFollowingMax = State(initialValue: followMax)
    }

    private var domainSpan: Double { max(1e-6, domain.upperBound - domain.lowerBound) }
    private var clampedWindowSpan: Double { min(windowSpan, max(minWindowSpan, domainSpan)) }
    private var windowFraction: CGFloat { min(1, max(CGFloat(clampedWindowSpan / domainSpan), 0.0001)) }
    var windowStart: Double { isFollowingMax ? domain.upperBound - clampedWindowSpan : pinnedWindowStart }
    var windowEnd: Double { min(domain.upperBound, windowStart + clampedWindowSpan) }

    var body: some View {
        GeometryReader { geo in
            let w = max(1, geo.size.width)
            let selLeft = min(w, max(0, rangeStart * w))
            let selRight = min(w, max(0, rangeEnd * w))
            let selWidth = max(0, selRight - selLeft)
            let leftHovered = hoveredTarget == .leftHandle
            let rightHovered = hoveredTarget == .rightHandle
            let dragging = dragState != nil
            let selectionRect = CGRect(x: selLeft, y: 0, width: selWidth, height: overviewHeight)

            ZStack(alignment: .leading) {
                overview().frame(width: w, height: overviewHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Color.black.opacity(0.38)
                    .frame(width: w, height: overviewHeight)
                    .mask(InvertedRoundedSelectionShape(selectionRect: selectionRect, cornerRadius: 6)
                        .fill(style: FillStyle(eoFill: true)))

                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.primary.opacity(dragging ? 0.5 : 0.25), lineWidth: dragging ? 1.5 : 1)
                    .frame(width: max(selWidth, 0), height: overviewHeight)
                    .offset(x: selLeft)

                SelectorHandle(isActive: leftHovered || dragState?.mode == .panWindow)
                    .frame(width: handleHitWidth * 2, height: overviewHeight)
                    .offset(x: selLeft - handleHitWidth)
                    .onHover { inside in
                        inside ? NSCursor.resizeLeftRight.push() : NSCursor.resizeLeftRight.pop()
                    }

                SelectorHandle(isActive: rightHovered || dragState?.mode == .panWindow)
                    .frame(width: handleHitWidth * 2, height: overviewHeight)
                    .offset(x: selRight - handleHitWidth)
                    .onHover { inside in
                        inside ? NSCursor.resizeLeftRight.push() : NSCursor.resizeLeftRight.pop()
                    }

                if selWidth > 0 {
                    edgeBadge(value: windowStart)
                        .offset(x: selLeft - 20, y: -overviewHeight / 2 - 8)
                    edgeBadge(value: windowEnd)
                        .offset(x: selRight - 20, y: -overviewHeight / 2 - 8)
                }

                if let hoveredX {
                    let markerValue = domain.lowerBound + Double(hoveredX / max(w, 1)) * domainSpan
                    Rectangle()
                        .fill(Color.primary.opacity(0.4))
                        .frame(width: 1, height: overviewHeight)
                        .offset(x: min(w, max(0, CGFloat((markerValue - domain.lowerBound) / domainSpan) * w)))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5))
            .contentShape(Rectangle())
            .onAppear {
                if !hasInitialized, domainSpan > 0 {
                    hasInitialized = true
                    windowSpan = min(defaultWindowSpan, domainSpan)
                    snapToMax()
                    reportWindow()
                }
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    let x = location.x
                    hoveredTarget = (x >= selLeft && x <= selRight) ? findTarget(at: x, width: w) : nil
                    hoveredX = (x >= selLeft && x <= selRight) ? x : nil
                case .ended:
                    hoveredTarget = nil; hoveredX = nil
                }
                onHover(hoveredX.map { domain.lowerBound + Double($0 / max(w, 1)) * domainSpan })
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if dragState == nil { beginDrag(at: value.startLocation.x, width: w) }
                        updateDrag(translationX: value.translation.width, width: w)
                        reportWindow()
                    }
                    .onEnded { _ in
                        endDrag(width: w)
                        reportWindow()
                    }
            )
        }
        .frame(height: overviewHeight)
        .onChange(of: domain.upperBound) { _, _ in
            guard domainSpan > 0 else { rangeStart = 0; rangeEnd = 1; pinnedWindowStart = 0; reportWindow(); return }
            windowSpan = isFollowingMax
                ? min(defaultWindowSpan, max(minWindowSpan, domainSpan))
                : min(max(windowSpan, minWindowSpan), max(minWindowSpan, domainSpan))
            if isFollowingMax { snapToMax() }
            else {
                pinnedWindowStart = min(max(domain.lowerBound, pinnedWindowStart), max(domain.lowerBound, domain.upperBound - clampedWindowSpan))
                rangeStart = CGFloat((pinnedWindowStart - domain.lowerBound) / domainSpan)
                rangeEnd = min(1, rangeStart + windowFraction)
            }
            reportWindow()
        }
    }

    // MARK: - Private helpers

    private func edgeBadge(value: Double) -> some View {
        Text(edgeLabel(value))
            .font(.system(size: 9, design: .monospaced))
            .foregroundColor(.primary)
            .padding(.horizontal, 4).padding(.vertical, 2)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 3))
    }

    private func snapToMax() {
        guard domainSpan > 0 else { rangeStart = 0; rangeEnd = 1; pinnedWindowStart = domain.lowerBound; return }
        pinnedWindowStart = max(domain.lowerBound, domain.upperBound - clampedWindowSpan)
        rangeStart = CGFloat((pinnedWindowStart - domain.lowerBound) / domainSpan)
        rangeEnd = min(1, rangeStart + windowFraction)
    }

    private func isSnappedToMax(width: CGFloat) -> Bool {
        guard width > 0 else { return true }
        return (1 - rangeEnd) * width <= followEdgeSnapTolerance
    }

    private func findTarget(at x: CGFloat, width: CGFloat) -> SelectorHoverTarget? {
        let sl = min(width, max(0, rangeStart * width))
        let sr = min(width, max(0, rangeEnd * width))
        if x >= max(0, sl - handleHitWidth), x <= min(width, sl + handleHitWidth) { return .leftHandle }
        if x >= max(0, sr - handleHitWidth), x <= min(width, sr + handleHitWidth) { return .rightHandle }
        if x >= sl, x <= sr { return .body }
        return nil
    }

    private func beginDrag(at x: CGFloat, width: CGFloat) {
        guard let target = findTarget(at: x, width: width) else { return }
        hoveredTarget = target
        dragState = SelectorDragState(
            mode: { switch target { case .leftHandle: .resizeLeft; case .body: .panWindow; case .rightHandle: .resizeRight } }(),
            startRangeStart: rangeStart, startRangeEnd: rangeEnd,
            startWindowSpan: clampedWindowSpan
        )
        isFollowingMax = false; hoveredX = nil
    }

    private func updateDrag(translationX: CGFloat, width: CGFloat) {
        guard let ds = dragState, width > 0, domainSpan > 0 else { return }
        let delta = translationX / width

        switch ds.mode {
        case .panWindow:
            let span = ds.startRangeEnd - ds.startRangeStart
            let newStart = max(0, min(1 - span, ds.startRangeStart + delta))
            rangeStart = newStart; rangeEnd = min(1, newStart + span)
            pinnedWindowStart = domain.lowerBound + Double(rangeStart) * domainSpan
            if followMax { isFollowingMax = isSnappedToMax(width: width) }

        case .resizeLeft:
            let anchorEnd = ds.startRangeEnd
            let minFrac = CGFloat(minWindowSpan / domainSpan)
            let proposedStart = max(0, min(anchorEnd - minFrac, ds.startRangeStart + delta))
            let proposedFrac = max(minFrac, anchorEnd - proposedStart)
            windowSpan = min(domainSpan, max(minWindowSpan, Double(proposedFrac) * domainSpan))
            rangeStart = max(0, anchorEnd - windowFraction)
            rangeEnd = min(1, rangeStart + windowFraction)
            pinnedWindowStart = domain.lowerBound + Double(rangeStart) * domainSpan
            if followMax { isFollowingMax = isSnappedToMax(width: width) }

        case .resizeRight:
            let anchorStart = ds.startRangeStart
            let minFrac = CGFloat(minWindowSpan / domainSpan)
            let proposedEnd = min(1.0, max(anchorStart + minFrac, ds.startRangeEnd + delta))
            let proposedFrac = max(minFrac, proposedEnd - anchorStart)
            windowSpan = min(domainSpan, max(minWindowSpan, Double(proposedFrac) * domainSpan))
            rangeStart = anchorStart; rangeEnd = min(1, rangeStart + windowFraction)
            pinnedWindowStart = domain.lowerBound + Double(rangeStart) * domainSpan
            if followMax { isFollowingMax = isSnappedToMax(width: width) }

        case .idle: break
        }
    }

    private func endDrag(width: CGFloat) {
        if followMax, isSnappedToMax(width: width) { isFollowingMax = true; snapToMax() }
        dragState = nil
    }

    private func reportWindow() {
        onWindowChange((start: windowStart, end: windowEnd))
    }
}

extension ClosedRange where Bound == Double {
    var span: Double { upperBound - lowerBound }
}
