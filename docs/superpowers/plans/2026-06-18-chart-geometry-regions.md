# Chart Geometry Regions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add chart-engine-level geometry regions so chart annotations are laid out within explicit bounds instead of escaping into axis labels or surrounding controls.

**Architecture:** Extend the existing chart engine without replacing it. `ChartStyle` declares region inputs, `Chart` computes a richer `ChartGeometry`, Canvas rendering continues to use the plot rect, and business overlays consume `annotationRect` for bounded placement.

**Tech Stack:** Swift 6.0, SwiftUI, Swift Testing, existing `Chart` / `ChartGeometry` / `BandChartLayout` pipeline.

## Global Constraints

- App builds must use `xcodebuild`; do not use `swift build` or `swift test`.
- Default verification is Debug build plus `-only-testing:WiFiLensTests`.
- Do not run UI test bundles unless explicitly requested.
- Documentation belongs under `docs/`; update `AGENTS.md` when adding new docs.
- English is required for docs, code comments, and commit messages.
- Do not commit unless the user explicitly authorizes it.
- Keep `chartRect` source compatibility by making it an alias of the new plot rect.
- Do not rewrite the renderer or replace it with Swift Charts.

---

## File Structure

- Modify `WiFiLens/Sources/WiFiLens/Charts/ChartGeometry.swift`
  - Owns named chart regions and data/screen coordinate mapping.
- Modify `WiFiLens/Sources/WiFiLens/Charts/ChartTypes.swift`
  - Adds `ChartStyle` inputs for annotation region construction.
- Modify `WiFiLens/Sources/WiFiLens/Charts/ChartView.swift`
  - Computes complete `ChartGeometry` and keeps Canvas rendering on the plot rect.
- Modify `WiFiLens/Sources/WiFiLens/Spectrum/BandChartLayout.swift`
  - Accepts explicit annotation bounds and searches legal label positions inside them.
- Modify `WiFiLens/Sources/WiFiLens/Spectrum/BandChartView.swift`
  - Passes `geo.annotationRect` to the Spectrum label layout.
- Modify `WiFiLens/Tests/WiFiLensTests/ChartViewTests.swift`
  - Adds engine-level geometry region tests.
- Modify `WiFiLens/Tests/WiFiLensTests/BandChartViewModelTests.swift`
  - Adds Spectrum label-boundary regression tests.
- Modify `docs/CHARTS.md`
  - Documents geometry regions and overlay rules.
- Modify `AGENTS.md`
  - Adds this implementation plan to the docs table.

---

### Task 1: Add Chart Geometry Regions

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/Charts/ChartGeometry.swift`
- Modify: `WiFiLens/Sources/WiFiLens/Charts/ChartTypes.swift`
- Modify: `WiFiLens/Tests/WiFiLensTests/ChartViewTests.swift`

**Interfaces:**
- Produces: `ChartAxisLabelRects`, `ChartGeometry.frameRect`, `ChartGeometry.plotRect`, `ChartGeometry.annotationRect`, `ChartGeometry.axisLabelRects`, `ChartGeometry.contentClipRect`, `ChartGeometry.chartRect`.
- Produces: `ChartStyle.annotationPadding`, `ChartStyle.annotationAvoidsAxisLabels`.
- Consumes: Existing `ChartStyle.chartRect(size:)` behavior and existing `ChartGeometry(chartRect:xMin:xMax:yMin:yMax:)` call sites.

- [ ] **Step 1: Write failing compatibility and region tests**

Add these tests to `ChartGeometryTests` in `WiFiLens/Tests/WiFiLensTests/ChartViewTests.swift`:

```swift
@Test func chartGeometryKeepsChartRectAsPlotRectAlias() {
    let plot = CGRect(x: 40, y: 8, width: 352, height: 200)
    let geo = ChartGeometry(
        frameRect: CGRect(x: 0, y: 0, width: 400, height: 240),
        plotRect: plot,
        annotationRect: plot,
        axisLabelRects: ChartAxisLabelRects(
            yAxis: CGRect(x: 0, y: 8, width: 40, height: 200),
            xAxis: CGRect(x: 40, y: 208, width: 352, height: 24)
        ),
        contentClipRect: CGRect(x: 0, y: 0, width: 400, height: 240),
        xMin: 0,
        xMax: 60,
        yMin: -100,
        yMax: 0
    )

    #expect(geo.plotRect == plot)
    #expect(geo.chartRect == plot)
    #expect(geo.frameRect.contains(geo.annotationRect))
}

@Test func chartStyleAnnotationRectStaysInsideFrame() {
    let style = ChartStyle(
        leftAxisWidth: 40,
        bottomAxisHeight: 24,
        marginTop: 8,
        marginRight: 8,
        marginBottom: 4,
        annotationPadding: EdgeInsets(top: 6, leading: 4, bottom: 2, trailing: 4)
    )

    let frame = CGRect(x: 0, y: 0, width: 400, height: 300)
    let regions = style.regions(size: frame.size)

    #expect(regions.frameRect == frame)
    #expect(regions.plotRect == style.chartRect(size: frame.size))
    #expect(frame.contains(regions.annotationRect))
    #expect(regions.annotationRect.minX >= regions.plotRect.minX)
    #expect(regions.annotationRect.minY >= regions.plotRect.minY)
}

@Test func chartStyleRegionsClampCollapsedSizes() {
    let style = ChartStyle(
        leftAxisWidth: 40,
        bottomAxisHeight: 24,
        marginTop: 8,
        marginRight: 8,
        marginBottom: 4,
        annotationPadding: EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
    )

    let regions = style.regions(size: CGSize(width: 10, height: 10))

    #expect(regions.frameRect.width >= 0)
    #expect(regions.frameRect.height >= 0)
    #expect(regions.plotRect.width >= 0)
    #expect(regions.plotRect.height >= 0)
    #expect(regions.annotationRect.width >= 0)
    #expect(regions.annotationRect.height >= 0)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests
```

Expected: build fails because `ChartGeometry` does not have `frameRect`, `plotRect`, `annotationRect`, `axisLabelRects`, or `contentClipRect`, and `ChartStyle` does not have `regions(size:)`.

- [ ] **Step 3: Implement region types and compatibility initializer**

Replace `WiFiLens/Sources/WiFiLens/Charts/ChartGeometry.swift` with:

```swift
import Foundation

struct ChartAxisLabelRects: Equatable {
    let yAxis: CGRect
    let xAxis: CGRect
}

struct ChartRegions: Equatable {
    let frameRect: CGRect
    let plotRect: CGRect
    let annotationRect: CGRect
    let axisLabelRects: ChartAxisLabelRects
    let contentClipRect: CGRect
}

/// Coordinate mapping between data space and chart pixel space.
struct ChartGeometry {
    let frameRect: CGRect
    let plotRect: CGRect
    let annotationRect: CGRect
    let axisLabelRects: ChartAxisLabelRects
    let contentClipRect: CGRect
    let xMin: Double
    let xMax: Double
    let yMin: Double
    let yMax: Double

    var chartRect: CGRect { plotRect }
    var scaleX: CGFloat { plotRect.width / max(1e-6, xMax - xMin) }
    var scaleY: CGFloat { plotRect.height / max(1e-6, yMax - yMin) }

    init(
        frameRect: CGRect,
        plotRect: CGRect,
        annotationRect: CGRect,
        axisLabelRects: ChartAxisLabelRects,
        contentClipRect: CGRect,
        xMin: Double,
        xMax: Double,
        yMin: Double,
        yMax: Double
    ) {
        self.frameRect = frameRect
        self.plotRect = plotRect
        self.annotationRect = annotationRect
        self.axisLabelRects = axisLabelRects
        self.contentClipRect = contentClipRect
        self.xMin = xMin
        self.xMax = xMax
        self.yMin = yMin
        self.yMax = yMax
    }

    init(chartRect: CGRect, xMin: Double, xMax: Double, yMin: Double, yMax: Double) {
        self.init(
            frameRect: chartRect,
            plotRect: chartRect,
            annotationRect: chartRect,
            axisLabelRects: ChartAxisLabelRects(yAxis: .zero, xAxis: .zero),
            contentClipRect: chartRect,
            xMin: xMin,
            xMax: xMax,
            yMin: yMin,
            yMax: yMax
        )
    }

    func dataToPoint(x: Double, y: Double) -> CGPoint {
        CGPoint(
            x: plotRect.minX + (x - xMin) * scaleX,
            y: plotRect.maxY - (y - yMin) * scaleY
        )
    }

    func pointToData(screenPoint: CGPoint) -> (x: Double, y: Double) {
        let x = xMin + (screenPoint.x - plotRect.minX) / scaleX
        let y = yMin + (plotRect.maxY - screenPoint.y) / scaleY
        return (x, y)
    }
}
```

- [ ] **Step 4: Add `ChartStyle` region construction**

Update `ChartStyle` in `WiFiLens/Sources/WiFiLens/Charts/ChartTypes.swift`:

```swift
struct ChartStyle {
    var leftAxisWidth: CGFloat = 36
    var bottomAxisHeight: CGFloat = 20
    var marginTop: CGFloat = 8
    var marginRight: CGFloat = 8
    var marginBottom: CGFloat = 4
    var annotationPadding: EdgeInsets = .init(top: 0, leading: 0, bottom: 0, trailing: 0)
    var annotationAvoidsAxisLabels: Bool = true

    func chartRect(size: CGSize) -> CGRect {
        regions(size: size).plotRect
    }

    func regions(size: CGSize) -> ChartRegions {
        let frameRect = CGRect(origin: .zero, size: CGSize(width: max(0, size.width), height: max(0, size.height)))
        let plotRect = CGRect(
            x: leftAxisWidth,
            y: marginTop,
            width: max(0, frameRect.width - leftAxisWidth - marginRight),
            height: max(0, frameRect.height - bottomAxisHeight - marginTop - marginBottom)
        )
        let yAxisRect = CGRect(
            x: frameRect.minX,
            y: plotRect.minY,
            width: max(0, plotRect.minX - frameRect.minX),
            height: plotRect.height
        )
        let xAxisRect = CGRect(
            x: plotRect.minX,
            y: plotRect.maxY,
            width: plotRect.width,
            height: max(0, frameRect.maxY - plotRect.maxY)
        )
        let baseAnnotationRect = annotationAvoidsAxisLabels ? plotRect : frameRect
        let adjustedAnnotationRect = CGRect(
            x: baseAnnotationRect.minX + annotationPadding.leading,
            y: baseAnnotationRect.minY + annotationPadding.top,
            width: max(0, baseAnnotationRect.width - annotationPadding.leading - annotationPadding.trailing),
            height: max(0, baseAnnotationRect.height - annotationPadding.top - annotationPadding.bottom)
        )

        return ChartRegions(
            frameRect: frameRect,
            plotRect: plotRect,
            annotationRect: adjustedAnnotationRect,
            axisLabelRects: ChartAxisLabelRects(yAxis: yAxisRect, xAxis: xAxisRect),
            contentClipRect: frameRect
        )
    }
}
```

If the local Swift version rejects `EdgeInsets` stored in this file, keep `import SwiftUI` at the top of `ChartTypes.swift`; it already imports SwiftUI.

- [ ] **Step 5: Run tests to verify Task 1 passes**

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests
```

Expected: all existing tests plus the new region tests pass.

- [ ] **Step 6: Review checkpoint**

Do not commit unless the user explicitly authorizes it. If authorized, use:

```sh
git add WiFiLens/Sources/WiFiLens/Charts/ChartGeometry.swift WiFiLens/Sources/WiFiLens/Charts/ChartTypes.swift WiFiLens/Tests/WiFiLensTests/ChartViewTests.swift
git commit -m "refactor: add chart geometry regions"
```

---

### Task 2: Make Chart Compute Complete Geometry

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/Charts/ChartView.swift`
- Modify: `WiFiLens/Tests/WiFiLensTests/ChartViewTests.swift`

**Interfaces:**
- Consumes: `ChartStyle.regions(size:) -> ChartRegions` from Task 1.
- Produces: `Chart.computeGeo(size:)` returns `ChartGeometry` with frame, plot, annotation, axis label, and clip regions populated.

- [ ] **Step 1: Write failing geometry propagation test**

Add this test to `ChartGeometryTests`:

```swift
@Test func chartGeometryMappingUsesPlotRect() {
    let geo = ChartGeometry(
        frameRect: CGRect(x: 0, y: 0, width: 500, height: 300),
        plotRect: CGRect(x: 50, y: 30, width: 400, height: 200),
        annotationRect: CGRect(x: 60, y: 40, width: 380, height: 180),
        axisLabelRects: ChartAxisLabelRects(
            yAxis: CGRect(x: 0, y: 30, width: 50, height: 200),
            xAxis: CGRect(x: 50, y: 230, width: 400, height: 70)
        ),
        contentClipRect: CGRect(x: 0, y: 0, width: 500, height: 300),
        xMin: 0,
        xMax: 100,
        yMin: -100,
        yMax: 0
    )

    let point = geo.dataToPoint(x: 50, y: -50)
    #expect(abs(point.x - 250) < 0.001)
    #expect(abs(point.y - 130) < 0.001)

    let data = geo.pointToData(screenPoint: point)
    #expect(abs(data.x - 50) < 0.001)
    #expect(abs(data.y - -50) < 0.001)
}
```

- [ ] **Step 2: Run tests to verify behavior before `ChartView` migration**

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests
```

Expected: mapping test passes if Task 1 was implemented correctly. Existing runtime behavior still computes compatibility-only geometry in `ChartView`.

- [ ] **Step 3: Update `Chart.computeGeo(size:)`**

In `WiFiLens/Sources/WiFiLens/Charts/ChartView.swift`, replace:

```swift
let chartRect = style.chartRect(size: size)
let (yMin, yMax) = computeYRange()
let xMin = computeXMin()
let xMax = computeXMax()
return ChartGeometry(chartRect: chartRect, xMin: xMin, xMax: xMax, yMin: yMin, yMax: yMax)
```

with:

```swift
let regions = style.regions(size: size)
let (yMin, yMax) = computeYRange()
let xMin = computeXMin()
let xMax = computeXMax()
return ChartGeometry(
    frameRect: regions.frameRect,
    plotRect: regions.plotRect,
    annotationRect: regions.annotationRect,
    axisLabelRects: regions.axisLabelRects,
    contentClipRect: regions.contentClipRect,
    xMin: xMin,
    xMax: xMax,
    yMin: yMin,
    yMax: yMax
)
```

Keep `drawContent(context:geo:)` using `geo.chartRect` for now. That alias intentionally preserves plot rendering semantics.

- [ ] **Step 4: Run tests to verify no renderer regression**

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests
```

Expected: all unit tests pass.

- [ ] **Step 5: Review checkpoint**

Do not commit unless the user explicitly authorizes it. If authorized, use:

```sh
git add WiFiLens/Sources/WiFiLens/Charts/ChartView.swift WiFiLens/Tests/WiFiLensTests/ChartViewTests.swift
git commit -m "refactor: compute chart annotation regions"
```

---

### Task 3: Move Spectrum AP Labels Onto Annotation Bounds

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/Spectrum/BandChartLayout.swift`
- Modify: `WiFiLens/Sources/WiFiLens/Spectrum/BandChartView.swift`
- Modify: `WiFiLens/Tests/WiFiLensTests/BandChartViewModelTests.swift`

**Interfaces:**
- Consumes: `ChartGeometry.annotationRect` from Task 2.
- Produces: `BandChartLayout.placeLabels(seriesData:plotRect:annotationRect:xMin:scaleX:scaleY:yMin:selectedNetworkID:)`.
- Produces: deterministic label lane search that never returns label centers whose estimated label rect falls outside `annotationRect`.

- [ ] **Step 1: Write failing Spectrum label boundary tests**

Add these tests near existing `placeLabelsKeepsSelectedSeries()` in `WiFiLens/Tests/WiFiLensTests/BandChartViewModelTests.swift`:

```swift
@Test func placeLabelsKeepLeftAndTopEdgeInsideAnnotationRect() throws {
    let series = makeSeries(
        id: "left-edge",
        ssid: "DIRECT-XX-HP Laser XXXXnw",
        channel: 1,
        rssi: -40
    )
    let plotRect = CGRect(x: 38, y: 6, width: 320, height: 160)
    let annotationRect = CGRect(x: 58, y: 26, width: 280, height: 120)

    let labels = BandChartLayout.placeLabels(
        seriesData: [series],
        plotRect: plotRect,
        annotationRect: annotationRect,
        xMin: 1,
        scaleX: 24,
        scaleY: 160 / 60,
        yMin: Double(Constants.rssiNoiseFloor),
        selectedNetworkID: nil
    )

    let label = try #require(labels.first)
    let rect = BandChartLayout.estimatedLabelRect(for: label)
    #expect(annotationRect.contains(rect))
}

@Test func placeLabelsUseDownwardLaneNearTopBoundary() throws {
    let first = makeSeries(id: "first", ssid: "Collision-A", channel: 52, rssi: -40)
    let second = makeSeries(id: "second", ssid: "Collision-B", channel: 52, rssi: -41)
    let plotRect = CGRect(x: 38, y: 6, width: 360, height: 180)
    let annotationRect = CGRect(x: 58, y: 26, width: 320, height: 140)

    let labels = BandChartLayout.placeLabels(
        seriesData: [first, second],
        plotRect: plotRect,
        annotationRect: annotationRect,
        xMin: 36,
        scaleX: 8,
        scaleY: 180 / 60,
        yMin: Double(Constants.rssiNoiseFloor),
        selectedNetworkID: nil
    )

    #expect(labels.count == 2)
    let rects = labels.map { BandChartLayout.estimatedLabelRect(for: $0) }
    #expect(rects.allSatisfy { annotationRect.contains($0) })
    #expect(!rects[0].intersects(rects[1]))
}
```

This plan intentionally exposes `estimatedLabelRect(for:)` as an internal static helper so unit tests can verify the same estimate used by the layout algorithm.

- [ ] **Step 2: Run tests to verify they fail**

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests
```

Expected: build fails because the new `placeLabels` signature and `estimatedLabelRect(for:)` do not exist.

- [ ] **Step 3: Replace `placeLabels` with bounded placement**

In `WiFiLens/Sources/WiFiLens/Spectrum/BandChartLayout.swift`, replace the existing `placeLabels(...)` implementation with:

```swift
static func placeLabels(
    seriesData: [ChartSeriesData],
    plotRect: CGRect,
    annotationRect: CGRect,
    xMin: Double,
    scaleX: CGFloat,
    scaleY: CGFloat,
    yMin: Double,
    selectedNetworkID: String?
) -> [LabelPlacement] {
    let labelEstHeight: CGFloat = 14
    let lineHeight: CGFloat = labelEstHeight + 2
    let hasSelection = selectedNetworkID != nil

    let candidates = seriesData
        .filter { ($0.isVisible && !$0.isFilteredOut) || $0.id == selectedNetworkID }
        .sorted { a, b in
            if a.id == selectedNetworkID { return true }
            if b.id == selectedNetworkID { return false }
            return a.rssi > b.rssi
        }

    var placed: [LabelPlacement] = []
    var occupied: [CGRect] = []

    for series in candidates {
        let isSelected = series.id == selectedNetworkID
        let opacity: Double = hasSelection ? (isSelected ? 1.0 : 0.25) : 1.0
        let labelSize = estimatedLabelSize(for: series)
        let rawX = plotRect.minX + (series.apex - xMin) * scaleX
        let rawY = plotRect.maxY - (series.displayRSSI - yMin) * scaleY - 8
        let clampedX = clamp(rawX, min: annotationRect.minX + labelSize.width / 2, max: annotationRect.maxX - labelSize.width / 2)
        let candidateYs = labelCandidateYs(
            naturalY: rawY,
            labelHeight: labelSize.height,
            lineHeight: lineHeight,
            bounds: annotationRect
        )

        var accepted: LabelPlacement?
        for candidateY in candidateYs {
            let label = LabelPlacement(series: series, x: clampedX, y: candidateY, opacity: opacity)
            let rect = estimatedLabelRect(for: label, size: labelSize)
            guard annotationRect.contains(rect) else { continue }
            guard !occupied.contains(where: { $0.intersects(rect) }) else { continue }
            accepted = label
            occupied.append(rect)
            break
        }

        if let accepted {
            placed.append(accepted)
        } else if isSelected {
            let fallbackY = clamp(rawY, min: annotationRect.minY + labelSize.height, max: annotationRect.maxY)
            let fallback = LabelPlacement(series: series, x: clampedX, y: fallbackY, opacity: opacity)
            placed.append(fallback)
            occupied.append(estimatedLabelRect(for: fallback, size: labelSize))
        }
    }

    return placed
}

static func estimatedLabelRect(for label: LabelPlacement) -> CGRect {
    estimatedLabelRect(for: label, size: estimatedLabelSize(for: label.series))
}

private static func estimatedLabelRect(for label: LabelPlacement, size: CGSize) -> CGRect {
    CGRect(
        x: label.x - size.width / 2,
        y: label.y - size.height,
        width: size.width,
        height: size.height
    )
}

private static func estimatedLabelSize(for series: ChartSeriesData) -> CGSize {
    let labelCharacterCount = "\(series.channel) \(series.displaySSID)\(estimatedTrendSuffix(for: series))".count
    let width = min(max(100, CGFloat(labelCharacterCount) * 6.5), 220)
    return CGSize(width: width, height: 14)
}

private static func estimatedTrendSuffix(for series: ChartSeriesData) -> String {
    guard !series.trendArrow.isEmpty else { return "" }
    let delta = series.trendDelta == 0 ? "" : " \(series.trendDelta > 0 ? "+" : "")\(series.trendDelta)"
    return " \(series.trendArrow)\(delta)"
}

private static func labelCandidateYs(
    naturalY: CGFloat,
    labelHeight: CGFloat,
    lineHeight: CGFloat,
    bounds: CGRect
) -> [CGFloat] {
    let minY = bounds.minY + labelHeight
    let maxY = bounds.maxY
    let clampedNaturalY = clamp(naturalY, min: minY, max: maxY)
    var values: [CGFloat] = [clampedNaturalY]

    for lane in 1...6 {
        let down = clampedNaturalY + CGFloat(lane) * lineHeight
        let up = clampedNaturalY - CGFloat(lane) * lineHeight
        if down <= maxY { values.append(down) }
        if up >= minY { values.append(up) }
    }

    return values
}

private static func clamp(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
    guard minValue <= maxValue else { return (minValue + maxValue) / 2 }
    return Swift.min(Swift.max(value, minValue), maxValue)
}
```

This keeps label placement deterministic and bounded. It intentionally tries downward lanes before upward lanes after the natural position, because top-boundary collisions are the bug being fixed.

- [ ] **Step 4: Update `WiFiBandChart` call sites**

In `WiFiLens/Sources/WiFiLens/Spectrum/BandChartView.swift`, update `dataLabelOverlay(geo:)`.

Replace:

```swift
let labels = BandChartLayout.placeLabels(
    seriesData: seriesList, chartRect: geo.chartRect,
    xMin: geo.xMin, scaleX: geo.scaleX, scaleY: geo.scaleY,
    yMin: geo.yMin, selectedNetworkID: selectedNetworkID
)
```

with:

```swift
let labels = BandChartLayout.placeLabels(
    seriesData: seriesList,
    plotRect: geo.plotRect,
    annotationRect: geo.annotationRect,
    xMin: geo.xMin,
    scaleX: geo.scaleX,
    scaleY: geo.scaleY,
    yMin: geo.yMin,
    selectedNetworkID: selectedNetworkID
)
```

If other call sites still use the old signature, update them the same way by passing `geo.plotRect` and `geo.annotationRect`.

- [ ] **Step 5: Run tests to verify bounded label behavior**

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests
```

Expected: all unit tests pass, including the new Spectrum label boundary tests.

- [ ] **Step 6: Review checkpoint**

Do not commit unless the user explicitly authorizes it. If authorized, use:

```sh
git add WiFiLens/Sources/WiFiLens/Spectrum/BandChartLayout.swift WiFiLens/Sources/WiFiLens/Spectrum/BandChartView.swift WiFiLens/Tests/WiFiLensTests/BandChartViewModelTests.swift
git commit -m "fix: bound spectrum chart labels to annotation region"
```

---

### Task 4: Document Regions and Verify the Whole Change

**Files:**
- Modify: `docs/CHARTS.md`
- Modify: `AGENTS.md`

**Interfaces:**
- Consumes: implemented `ChartGeometry` regions and Spectrum bounded placement from Tasks 1-3.
- Produces: documented chart geometry contract for future chart overlays.

- [ ] **Step 1: Update chart documentation**

Add this section to `docs/CHARTS.md` near the existing chart engine architecture section:

```markdown
## Geometry Regions

The chart engine separates plot geometry from annotation geometry.

| Region | Owner | Purpose |
|--------|-------|---------|
| `frameRect` | `Chart` | Full local coordinate space owned by the chart view |
| `plotRect` | `ChartStyle` / `Chart` | Grid, axis lines, series curves, and fills |
| `chartRect` | Compatibility alias | Alias of `plotRect` for existing callers |
| `axisLabelRects` | `Chart` | Reserved areas for X and Y tick labels |
| `annotationRect` | `Chart` | Legal placement area for chart-owned labels and annotations |
| `contentClipRect` | `Chart` | Default clipping boundary for chart-owned overlay content |

Business overlays should use `annotationRect` for persistent labels and callouts. They should not infer label bounds from `plotRect` or duplicate axis-margin calculations. Domain-specific layout code remains responsible for collision resolution, but it must solve placement inside the annotation bounds supplied by `ChartGeometry`.
```

- [ ] **Step 2: Update `AGENTS.md` docs table**

Add this row if it is not already present:

```markdown
| `docs/superpowers/plans/2026-06-18-chart-geometry-regions.md` | Implementation plan for chart geometry regions and annotation bounds |
```

- [ ] **Step 3: Run full unit verification**

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests
```

Expected: `WiFiLensTests` passes with zero failures.

- [ ] **Step 4: Run Debug build verification**

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build
```

Expected: build succeeds.

- [ ] **Step 5: Inspect final diff**

Run:

```sh
git status --short
git diff --stat
```

Expected: changes are limited to chart engine files, Spectrum label layout/call site, tests, and docs.

- [ ] **Step 6: Review checkpoint**

Do not commit unless the user explicitly authorizes it. If authorized, use:

```sh
git add docs/CHARTS.md AGENTS.md docs/superpowers/plans/2026-06-18-chart-geometry-regions.md
git commit -m "docs: document chart geometry regions plan"
```

## Implementation Order

Execute tasks in order. Do not start Task 3 until Task 1 and Task 2 tests pass. Task 3 depends on `ChartGeometry.annotationRect` being populated by `Chart`. Task 4 is documentation and verification only.

## Expected Final Verification

The final implementation is complete only after both commands pass:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build
```

No UI tests are required for this plan unless the user explicitly asks for UI tests.
