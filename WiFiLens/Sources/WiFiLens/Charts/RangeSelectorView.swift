import SwiftUI
import AppKit

// MARK: - Range Selector Types

enum SelectorDragMode {
    case idle
    case resizeLeft
    case panWindow
    case resizeRight
}

enum SelectorHoverTarget: Equatable {
    case leftHandle
    case body
    case rightHandle
}

struct SelectorDragState {
    let mode: SelectorDragMode
    let startRangeStart: CGFloat
    let startRangeEnd: CGFloat
    let startWindowDuration: TimeInterval
}

// MARK: - Inverted Selection Mask

struct InvertedRoundedSelectionShape: Shape {
    let selectionRect: CGRect
    let selectionCornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addPath(
            RoundedRectangle(cornerRadius: selectionCornerRadius)
                .path(in: selectionRect),
            transform: .identity
        )
        return path
    }
}

// MARK: - Selector Handle

struct SelectorHandle: View {
    let isActive: Bool

    var body: some View {
        let color = Color.accentColor.opacity(isActive ? 0.9 : 0.4)
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(.regularMaterial)
                .frame(width: 10, height: 28)
            VStack(spacing: 3.5) {
                Circle().fill(color).frame(width: 3, height: 3)
                Circle().fill(color).frame(width: 3, height: 3)
                Circle().fill(color).frame(width: 3, height: 3)
            }
        }
    }
}

// MARK: - Timeline Range Selector

private let selectorHandleHitWidth: CGFloat = 14
private let followTailSnapTolerance: CGFloat = 8

struct TimelineRangeSelector<Content: View>: View {
    let totalDuration: TimeInterval
    let minWindow: TimeInterval
    let defaultWindow: TimeInterval
    let overviewHeight: CGFloat
    @ViewBuilder let overview: () -> Content
    var timeFormatter: (TimeInterval) -> String = { seconds in
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return "\(m):\(String(format: "%02d", s))"
    }
    var onRangeChange: ((start: TimeInterval, end: TimeInterval)) -> Void = { _ in }
    var onHoverTime: (TimeInterval?) -> Void = { _ in }

    @State private var rangeStart: CGFloat = 0
    @State private var rangeEnd: CGFloat = 1
    @State private var windowDuration: TimeInterval
    @State private var pinnedWindowStart: TimeInterval = 0
    @State private var isFollowingTail = true
    @State private var dragState: SelectorDragState?
    @State private var hoveredTarget: SelectorHoverTarget?
    @State private var hoveredOverviewX: CGFloat?
    @State private var overviewPlotWidth: CGFloat = 1
    @State private var hasInitialized = false

    init(
        totalDuration: TimeInterval,
        minWindow: TimeInterval = 5,
        defaultWindow: TimeInterval = 30,
        overviewHeight: CGFloat = 48,
        @ViewBuilder overview: @escaping () -> Content,
        timeFormatter: @escaping (TimeInterval) -> String = { seconds in
            let m = Int(seconds) / 60
            let s = Int(seconds) % 60
            return "\(m):\(String(format: "%02d", s))"
        },
        onRangeChange: @escaping ((start: TimeInterval, end: TimeInterval)) -> Void = { _ in },
        onHoverTime: @escaping (TimeInterval?) -> Void = { _ in }
    ) {
        self.totalDuration = totalDuration
        self.minWindow = minWindow
        self.defaultWindow = defaultWindow
        self.overviewHeight = overviewHeight
        self.overview = overview
        self.timeFormatter = timeFormatter
        self.onRangeChange = onRangeChange
        self.onHoverTime = onHoverTime
        _windowDuration = State(initialValue: min(defaultWindow, totalDuration))
    }

    private var clampedWindowDuration: TimeInterval { min(windowDuration, max(1, totalDuration)) }
    private var windowFraction: CGFloat {
        guard totalDuration > 0 else { return 1 }
        return min(1, max(CGFloat(clampedWindowDuration / totalDuration), 0.0001))
    }
    var visibleStart: TimeInterval { isFollowingTail ? TimeInterval(rangeStart) * totalDuration : pinnedWindowStart }
    var visibleEnd: TimeInterval { min(totalDuration, visibleStart + clampedWindowDuration) }

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
                overview()
                    .frame(width: w, height: overviewHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Color.black.opacity(0.38)
                    .frame(width: w, height: overviewHeight)
                    .mask(
                        InvertedRoundedSelectionShape(selectionRect: selectionRect, selectionCornerRadius: 6)
                            .fill(style: FillStyle(eoFill: true))
                    )

                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.primary.opacity(dragging ? 0.5 : 0.25), lineWidth: dragging ? 1.5 : 1)
                    .frame(width: max(selWidth, 0), height: overviewHeight)
                    .offset(x: selLeft)

                SelectorHandle(isActive: leftHovered || dragState?.mode == .panWindow)
                    .frame(width: selectorHandleHitWidth * 2, height: overviewHeight)
                    .offset(x: selLeft - selectorHandleHitWidth)
                    .onHover { inside in
                        if inside { NSCursor.resizeLeftRight.push() }
                        else { NSCursor.resizeLeftRight.pop() }
                    }

                SelectorHandle(isActive: rightHovered || dragState?.mode == .panWindow)
                    .frame(width: selectorHandleHitWidth * 2, height: overviewHeight)
                    .offset(x: selRight - selectorHandleHitWidth)
                    .onHover { inside in
                        if inside { NSCursor.resizeLeftRight.push() }
                        else { NSCursor.resizeLeftRight.pop() }
                    }

                if selWidth > 0 {
                    edgeBadge(time: visibleStart)
                        .offset(x: selLeft - 20, y: -overviewHeight / 2 - 8)
                    edgeBadge(time: visibleEnd)
                        .offset(x: selRight - 20, y: -overviewHeight / 2 - 8)
                }

                if let hoveredOverviewX {
                    let markerTime = TimeInterval(hoveredOverviewX / max(w, 1)) * totalDuration
                    Rectangle()
                        .fill(Color.primary.opacity(0.4))
                        .frame(width: 1, height: overviewHeight)
                        .offset(x: min(w, max(0, CGFloat(markerTime / max(totalDuration, 0.1)) * w)))
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
                if !hasInitialized, totalDuration > 0 {
                    hasInitialized = true
                    windowDuration = min(defaultWindow, totalDuration)
                    snapToTail(totalTime: totalDuration)
                    reportRange()
                }
            }
            .onChange(of: w) { _, newWidth in
                overviewPlotWidth = newWidth
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    let x = location.x
                    if x >= selLeft, x <= selRight {
                        hoveredTarget = hoverTarget(at: x, width: w)
                        hoveredOverviewX = x
                    } else {
                        hoveredTarget = nil
                        hoveredOverviewX = nil
                    }
                case .ended:
                    hoveredTarget = nil
                    hoveredOverviewX = nil
                }
                onHoverTime(hoveredOverviewX.map { TimeInterval($0 / max(w, 1)) * totalDuration })
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if dragState == nil {
                            beginDrag(at: value.startLocation.x, width: w)
                        }
                        updateDrag(translationX: value.translation.width, width: w)
                        reportRange()
                    }
                    .onEnded { _ in
                        endDrag(width: w)
                        reportRange()
                    }
            )
        }
        .frame(height: overviewHeight)
        .onChange(of: totalDuration) { _, newTotal in
            guard newTotal > 0 else {
                rangeStart = 0
                rangeEnd = 1
                pinnedWindowStart = 0
                reportRange()
                return
            }
            windowDuration = min(max(windowDuration, minWindow), max(minWindow, newTotal))
            if isFollowingTail {
                snapToTail(totalTime: newTotal)
            } else {
                pinnedWindowStart = min(max(0, pinnedWindowStart), max(0, newTotal - clampedWindowDuration))
                rangeStart = min(1, max(0, CGFloat(pinnedWindowStart / newTotal)))
                rangeEnd = min(1, rangeStart + windowFraction)
            }
            reportRange()
        }
    }

    private func edgeBadge(time: TimeInterval) -> some View {
        Text(timeFormatter(time))
            .font(.system(size: 9, design: .monospaced))
            .foregroundColor(.primary)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 3))
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

    private func isSnappedToTail(width: CGFloat) -> Bool {
        guard width > 0 else { return true }
        return (1 - rangeEnd) * width <= followTailSnapTolerance
    }

    private func hoverTarget(at x: CGFloat, width: CGFloat) -> SelectorHoverTarget? {
        let selLeft = min(width, max(0, rangeStart * width))
        let selRight = min(width, max(0, rangeEnd * width))
        let leftHitMin = max(0, selLeft - selectorHandleHitWidth)
        let leftHitMax = min(width, selLeft + selectorHandleHitWidth)
        if x >= leftHitMin, x <= leftHitMax { return .leftHandle }
        let rightHitMin = max(0, selRight - selectorHandleHitWidth)
        let rightHitMax = min(width, selRight + selectorHandleHitWidth)
        if x >= rightHitMin, x <= rightHitMax { return .rightHandle }
        if x >= selLeft, x <= selRight { return .body }
        return nil
    }

    private func beginDrag(at x: CGFloat, width: CGFloat) {
        guard let target = hoverTarget(at: x, width: width) else { return }
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
        hoveredOverviewX = nil
    }

    private func updateDrag(translationX: CGFloat, width: CGFloat) {
        guard let dragState, width > 0, totalDuration > 0 else { return }
        let delta = translationX / width

        switch dragState.mode {
        case .panWindow:
            let span = dragState.startRangeEnd - dragState.startRangeStart
            let maxStart = max(0, 1 - span)
            let newStart = max(0, min(maxStart, dragState.startRangeStart + delta))
            rangeStart = newStart
            rangeEnd = min(1, newStart + span)
            pinnedWindowStart = TimeInterval(rangeStart) * totalDuration
            isFollowingTail = isSnappedToTail(width: width)

        case .resizeLeft:
            let anchorEnd = dragState.startRangeEnd
            let proposedStart = max(0, min(anchorEnd - CGFloat(minWindow / totalDuration), dragState.startRangeStart + delta))
            let proposedFraction = max(CGFloat(minWindow / totalDuration), anchorEnd - proposedStart)
            let proposedDuration = TimeInterval(proposedFraction) * totalDuration
            windowDuration = min(totalDuration, max(minWindow, proposedDuration))
            rangeStart = max(0, anchorEnd - windowFraction)
            rangeEnd = min(1, rangeStart + windowFraction)
            pinnedWindowStart = TimeInterval(rangeStart) * totalDuration
            isFollowingTail = isSnappedToTail(width: width)

        case .resizeRight:
            let anchorStart = dragState.startRangeStart
            let maxEnd = 1.0
            let proposedEnd = min(maxEnd, max(anchorStart + CGFloat(minWindow / totalDuration), dragState.startRangeEnd + delta))
            let proposedFraction = max(CGFloat(minWindow / totalDuration), proposedEnd - anchorStart)
            let proposedDuration = TimeInterval(proposedFraction) * totalDuration
            windowDuration = min(totalDuration, max(minWindow, proposedDuration))
            rangeStart = anchorStart
            rangeEnd = min(1, rangeStart + windowFraction)
            pinnedWindowStart = TimeInterval(rangeStart) * totalDuration
            isFollowingTail = isSnappedToTail(width: width)

        case .idle:
            break
        }
    }

    private func endDrag(width: CGFloat) {
        if isSnappedToTail(width: width) {
            isFollowingTail = true
            snapToTail(totalTime: totalDuration)
        }
        dragState = nil
    }

    private func reportRange() {
        onRangeChange((start: visibleStart, end: visibleEnd))
    }
}
