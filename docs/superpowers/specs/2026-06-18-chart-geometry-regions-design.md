# Chart Geometry Regions Design

## Goal

Define a chart-engine-level geometry contract so every chart-owned drawing layer has an explicit boundary. The immediate bug is AP labels escaping into the toolbar and Y-axis label area, but the fix should not be specific to `WiFiBandChart`. The universal chart pipeline should expose enough layout regions for business overlays to place annotations without guessing margins or duplicating chart internals.

The design must preserve the existing chart rendering pipeline and evolve it conservatively:

```
ChartStyle
  -> Chart computes ChartGeometry
  -> Canvas renders grid, axes, and series
  -> overlay receives ChartGeometry
  -> business overlays place annotations within declared bounds
```

## Non-Goals

- Do not rewrite the chart renderer.
- Do not introduce Swift Charts.
- Do not fix only `WiFiBandChart` with local padding or hard-coded toolbar offsets.
- Do not require all existing charts to migrate in one change.
- Do not implement a full text layout engine.
- Do not make toolbar or page layout part of the chart engine.

## Existing Context

The project already owns a lightweight universal chart engine under `WiFiLens/Sources/WiFiLens/Charts/`:

- `Chart` renders series, grid lines, axes, and injected overlays.
- `ChartStyle` defines layout inputs such as `leftAxisWidth`, `bottomAxisHeight`, and margins.
- `ChartGeometry` maps between data-space and screen-space using one `chartRect`.
- `ChartAxisConfig` controls ticks, axis labels, grid visibility, clipping, and axis formatting.
- Spectrum charts inject business overlays for AP labels and heatmaps through the `Chart` overlay closure.

The existing `chartRect` is effectively the plot rect: the area where data curves, grid lines, and axis lines are drawn. It is not a complete description of the chart's renderable regions.

That distinction matters because the chart currently mixes several drawing layers:

| Layer | Current Boundary |
|-------|------------------|
| Grid lines | `chartRect` |
| Axis lines | `chartRect` edges |
| Series curves and fills | `chartRect` when `clipToRect` is enabled |
| Y-axis tick labels | Drawn left of `chartRect` |
| X-axis tick labels | Drawn below `chartRect` |
| SwiftUI overlays | Receive `chartRect`, but are not clipped by Canvas clipping |
| Spectrum AP labels | Positioned by `BandChartLayout.placeLabels(...)` with no engine-owned annotation bounds |

This is why chart-owned overlays can visually escape into external controls even when the Canvas series itself is clipped.

## Problem

The chart engine exposes a data plot boundary but not an annotation boundary. Business overlays therefore infer their own placement rules from `chartRect` and local constants. This creates several failure modes:

- AP labels can overlap Y-axis tick labels.
- Top labels can overlap toolbar controls when the chart content is close to the top of its view.
- Long labels can extend past the chart frame because only their center point is considered.
- Collision handling can push labels out of bounds because there is no declared region in which collisions must be solved.
- Future chart overlays can repeat the same bug because the engine contract does not define where overlays may draw.

The root cause is not insufficient headroom in one spectrum chart. The root cause is the lack of a render-region contract in the shared chart geometry.

## Design Principles

1. Chart-owned drawing must have explicit bounds.
2. Business overlays should consume geometry, not reverse-engineer chart margins.
3. Existing chart consumers should keep working during migration.
4. The engine should define boundaries; domain-specific layout code should solve placement inside those boundaries.
5. Clipping and placement are related but separate. A clipped overlay may still be badly placed; placement should prefer legal positions first.
6. Boundaries should be testable without launching UI tests.

## Geometry Model

Extend `ChartGeometry` from a single plot rectangle into a set of named regions:

```swift
struct ChartGeometry {
    let frameRect: CGRect
    let plotRect: CGRect
    let annotationRect: CGRect
    let axisLabelRects: ChartAxisLabelRects
    let contentClipRect: CGRect

    var chartRect: CGRect { plotRect }

    let xMin: Double
    let xMax: Double
    let yMin: Double
    let yMax: Double
}

struct ChartAxisLabelRects {
    let yAxis: CGRect
    let xAxis: CGRect
}
```

### `frameRect`

The full local coordinate space owned by `Chart`. No chart-owned rendering should intentionally exceed this rect.

For a `GeometryReader`, this is typically:

```swift
CGRect(origin: .zero, size: geometry.size)
```

### `plotRect`

The current `chartRect`: the data plot area. Grid lines, axis lines, and series rendering use this rect.

`chartRect` should remain as a compatibility alias for `plotRect` to avoid a large migration.

### `axisLabelRects`

Reserved areas for axis labels. The Y-axis label rect covers the left label column, and the X-axis label rect covers the bottom label row. These rects are owned by the chart engine because the engine draws the axis labels.

Business annotations should avoid these rects unless a chart explicitly opts into allowing overlap.

### `annotationRect`

The legal placement region for chart-owned annotations such as labels, callouts, markers, and lightweight overlays. Domain-specific layout algorithms must place their estimated annotation rectangles inside this region.

The default `annotationRect` should:

- be inside `frameRect`;
- exclude axis label reserved areas by default;
- include the `plotRect` plus configurable internal padding when the style allows it;
- never require knowledge of toolbar or page controls outside the `Chart` view.

### `contentClipRect`

The default clipping boundary for chart-owned overlay content. The initial value can equal `frameRect` or `annotationRect` depending on the layer. This field gives the engine a single place to express clipping policy without forcing every overlay to invent a local clipping rectangle.

## Style Inputs

Add chart style inputs that describe region construction without hard-coding spectrum-specific numbers:

```swift
struct ChartStyle {
    var leftAxisWidth: CGFloat
    var bottomAxisHeight: CGFloat
    var marginTop: CGFloat
    var marginRight: CGFloat
    var marginBottom: CGFloat

    var annotationPadding: EdgeInsets = .init(top: 0, leading: 0, bottom: 0, trailing: 0)
    var annotationAvoidsAxisLabels: Bool = true
}
```

The first implementation can keep these defaults neutral so existing charts render the same unless a chart opts into annotation bounds.

Spectrum charts can then request a larger top annotation inset or chart-level top margin through style configuration, but the mechanism remains chart-engine owned.

## Boundary Semantics

The engine should follow these rules:

- Series, grid, and axis lines are drawn in `plotRect`.
- Axis labels are drawn in `axisLabelRects`.
- Overlay builders receive a `ChartGeometry` containing all regions.
- Domain overlays place labels and annotations inside `annotationRect`.
- Overlay clipping should be available at the chart layer, but business layout must still attempt to fit annotations before clipping.
- If a domain overlay cannot place an optional annotation inside `annotationRect`, it may hide or degrade that annotation.
- Required annotations may degrade to a shorter representation, reduced opacity, or a marker-only state, but should still remain inside `annotationRect`.

## Spectrum Label Placement

`BandChartLayout.placeLabels(...)` should be adapted to take explicit bounds from the engine:

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
) -> [LabelPlacement]
```

Its responsibility should be limited to AP-label-specific placement:

- estimate each label's rendered rectangle;
- place labels near the AP apex when possible;
- solve collisions only inside `annotationRect`;
- avoid pushing labels outside the allowed bounds;
- hide optional labels when no legal placement exists;
- preserve selected labels by degrading placement or representation rather than drawing out of bounds.

This keeps the AP-specific collision algorithm in Spectrum while moving the boundary definition to the chart engine.

## Collision Strategy

The existing label collision logic only tries upward lanes. That fails near the top boundary because every collision move makes the label less legal.

The updated strategy should search candidate positions within `annotationRect`:

1. Natural position above the curve apex.
2. Nearby vertical lanes above and below the natural position.
3. Horizontally clamped position for labels near left and right edges.
4. Shortened or marker-only fallback for required labels when no full label fits.

The first implementation does not need sophisticated force-directed layout. A deterministic lane search is enough if every candidate is tested against:

- `annotationRect.contains(labelRect)`;
- no collision with already occupied label rects;
- optional avoidance of axis label rects if they are not already excluded from `annotationRect`.

## API Compatibility

The migration should be incremental:

1. Add new fields to `ChartGeometry`.
2. Keep `chartRect` as an alias to `plotRect`.
3. Update `Chart.computeGeo(size:)` to populate the new regions.
4. Leave existing overlay consumers working because they still read `geo.chartRect`.
5. Migrate Spectrum overlays to use `geo.annotationRect`.
6. Migrate other overlays only when they need annotation-aware behavior.

This avoids a large cross-project edit while still establishing the correct engine contract.

## Error Handling and Fallbacks

Region computation should be resilient to small or collapsed chart sizes:

- Rect widths and heights must be clamped to zero or greater.
- `annotationRect` must never produce NaN or negative dimensions.
- If `annotationRect` is too small for a label, optional labels should be omitted.
- Selected or hovered labels should prefer compact fallback over escaping the bounds.

No user-facing error is needed. These are layout constraints, not runtime failures.

## Testing

Add focused Swift Testing coverage for pure geometry and layout behavior:

- `ChartStyle` computes `plotRect` compatibly with the previous `chartRect`.
- `ChartGeometry.chartRect` remains an alias of `plotRect`.
- `annotationRect` stays inside `frameRect`.
- `annotationRect` excludes axis label areas when `annotationAvoidsAxisLabels == true`.
- Collapsed sizes produce non-negative rect dimensions.
- Spectrum label placement keeps estimated label rects inside `annotationRect`.
- Left-edge and top-edge AP labels do not escape into axis or toolbar-adjacent space.
- Collision search near the top boundary tries legal downward lanes instead of pushing labels further upward.

Existing build and unit test verification remains:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build
```

Do not add UI tests for this unless specifically requested. The geometry and label-placement contract can be covered at the unit-test level.

## Documentation Updates

After implementation, update `docs/CHARTS.md` to document:

- the difference between `frameRect`, `plotRect`, `axisLabelRects`, and `annotationRect`;
- which chart layers use each region;
- how business overlays should consume annotation bounds;
- migration guidance for existing overlays that still read `chartRect`.

## Deferred Details

### Tooltip Bounds

The first implementation keeps tooltip behavior unchanged unless a tooltip currently escapes the `Chart` frame. Persistent labels use `annotationRect`; tooltip-specific placement can be revisited later with a separate `popoverRect` if needed.

### Axis Label Avoidance

The first implementation avoids axis labels for annotations by default. Future charts may add an explicit opt-in for intentional overlap, but no existing chart should depend on that behavior.

### Text Measurement

The first implementation uses estimated text sizes for unit-testable layout. Exact SwiftUI text measurement is not required for this fix. If estimates prove too inaccurate, a later chart text-measurement helper can be added behind the same placement API.

## Success Criteria

- The chart engine exposes named geometry regions instead of only `chartRect`.
- Existing chart consumers continue to compile through the `chartRect` compatibility alias.
- Spectrum AP labels consume engine-provided annotation bounds.
- AP labels no longer escape into the toolbar-adjacent area or Y-axis label area in the debug multi-AP collision scenario.
- Unit tests verify region computation and bounded annotation placement.
