# ChartLens Migration Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use compose:subagent (recommended) or compose:execute to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract the generic chart engine from WiFi Lens into a standalone Swift Package called ChartLens, and update WiFi Lens to depend on it.

**Architecture:** Convert the ChartLens Xcode project to an SPM package. Copy 8 core chart files, add `public` access modifiers, handle platform-specific code (NSCursor, .glassBackground). WiFi Lens references ChartLens as a local SPM dependency.

**Tech Stack:** Swift 6.0, SwiftUI, SPM, macOS 14+

---

### Task 1: Create ChartLens SPM Package Structure

**Files:**
- Create: `ChartLens/Package.swift`
- Create: `ChartLens/Sources/ChartLens/` (directory)
- Create: `ChartLens/Tests/ChartLensTests/` (directory)
- Delete: `ChartLens/ChartLens.xcodeproj/` (replace with SPM)

- [ ] **Step 1: Remove the placeholder Xcode project**

```bash
rm -rf /Users/kaoru/Developer/wifi-lens/ChartLens/ChartLens.xcodeproj
```

- [ ] **Step 2: Create directory structure**

```bash
mkdir -p /Users/kaoru/Developer/wifi-lens/ChartLens/Sources/ChartLens
mkdir -p /Users/kaoru/Developer/wifi-lens/ChartLens/Tests/ChartLensTests
```

- [ ] **Step 3: Create Package.swift**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ChartLens",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "ChartLens",
            targets: ["ChartLens"]
        ),
    ],
    targets: [
        .target(
            name: "ChartLens"
        ),
        .testTarget(
            name: "ChartLensTests",
            dependencies: ["ChartLens"]
        ),
    ]
)
```

- [ ] **Step 4: Verify package structure**

Run: `ls -R /Users/kaoru/Developer/wifi-lens/ChartLens/`
Expected: Package.swift, Sources/ChartLens/, Tests/ChartLensTests/

---

### Task 2: Copy Core Chart Files

**Files:**
- Copy from `WiFiLens/Sources/WiFiLens/Charts/` to `ChartLens/Sources/ChartLens/`:
  - `ChartTypes.swift`
  - `ChartView.swift`
  - `ChartGeometry.swift`
  - `ChartRendering.swift`
  - `SplineInterpolation.swift`
  - `DetailOverviewChart.swift`
  - `RangeSelectorView.swift`
  - `ChartTimeFormatting.swift`

- [ ] **Step 1: Copy files**

```bash
cp /Users/kaoru/Developer/wifi-lens/WiFiLens/Sources/WiFiLens/Charts/ChartTypes.swift \
   /Users/kaoru/Developer/wifi-lens/ChartLens/Sources/ChartLens/
cp /Users/kaoru/Developer/wifi-lens/WiFiLens/Sources/WiFiLens/Charts/ChartView.swift \
   /Users/kaoru/Developer/wifi-lens/ChartLens/Sources/ChartLens/
cp /Users/kaoru/Developer/wifi-lens/WiFiLens/Sources/WiFiLens/Charts/ChartGeometry.swift \
   /Users/kaoru/Developer/wifi-lens/ChartLens/Sources/ChartLens/
cp /Users/kaoru/Developer/wifi-lens/WiFiLens/Sources/WiFiLens/Charts/ChartRendering.swift \
   /Users/kaoru/Developer/wifi-lens/ChartLens/Sources/ChartLens/
cp /Users/kaoru/Developer/wifi-lens/WiFiLens/Sources/WiFiLens/Charts/SplineInterpolation.swift \
   /Users/kaoru/Developer/wifi-lens/ChartLens/Sources/ChartLens/
cp /Users/kaoru/Developer/wifi-lens/WiFiLens/Sources/WiFiLens/Charts/DetailOverviewChart.swift \
   /Users/kaoru/Developer/wifi-lens/ChartLens/Sources/ChartLens/
cp /Users/kaoru/Developer/wifi-lens/WiFiLens/Sources/WiFiLens/Charts/RangeSelectorView.swift \
   /Users/kaoru/Developer/wifi-lens/ChartLens/Sources/ChartLens/
cp /Users/kaoru/Developer/wifi-lens/WiFiLens/Sources/WiFiLens/Charts/ChartTimeFormatting.swift \
   /Users/kaoru/Developer/wifi-lens/ChartLens/Sources/ChartLens/
```

- [ ] **Step 2: Verify files copied**

Run: `ls /Users/kaoru/Developer/wifi-lens/ChartLens/Sources/ChartLens/`
Expected: 8 .swift files

---

### Task 3: Add Public Access Modifiers

All types, functions, and properties in the core chart files need `public` access for external consumers.

**Files:**
- Modify: `ChartLens/Sources/ChartLens/ChartTypes.swift`
- Modify: `ChartLens/Sources/ChartLens/ChartView.swift`
- Modify: `ChartLens/Sources/ChartLens/ChartGeometry.swift`
- Modify: `ChartLens/Sources/ChartLens/ChartRendering.swift`
- Modify: `ChartLens/Sources/ChartLens/SplineInterpolation.swift`
- Modify: `ChartLens/Sources/ChartLens/DetailOverviewChart.swift`
- Modify: `ChartLens/Sources/ChartLens/RangeSelectorView.swift`
- Modify: `ChartLens/Sources/ChartLens/ChartTimeFormatting.swift`

- [ ] **Step 1: Make ChartTypes.swift public**

Add `public` to: `ChartPoint`, `ChartSeries`, `ChartSeriesStyle`, `Interpolation`, `ChartAxisConfig`, `XTick`, `ChartStyle`, `ChartRegions`, `ChartAxisLabelRects`, `ChartInteraction`. All struct properties need `public` too.

- [ ] **Step 2: Make ChartView.swift public**

Add `public` to: `Chart<Overlay>` struct and its initializers.

- [ ] **Step 3: Make ChartGeometry.swift public**

Add `public` to: `ChartAxisLabelRects`, `ChartRegions`, `ChartGeometry` and all their properties/init/methods.

- [ ] **Step 4: Make ChartRendering.swift public**

Add `public` to all free functions: `drawAxes`, `drawYAxisGrid`, `drawAreaAndLine`, `evenlySpacedTickIndices`.

- [ ] **Step 5: Make SplineInterpolation.swift public**

Add `public` to: `addCatmullRomSpline`, `catmullRomSpline`, `clampedCubicSpline`.

- [ ] **Step 6: Make DetailOverviewChart.swift public**

Add `public` to: `DetailOverviewChart` struct and its initializers.

- [ ] **Step 7: Make RangeSelectorView.swift public**

Add `public` to: `SelectorDragMode`, `SelectorHoverTarget`, `SelectorDragState`, `RangeSelector` struct and its initializers. Also add `public` to the `ClosedRange.span` extension.

- [ ] **Step 8: Make ChartTimeFormatting.swift public**

Add `public` to: `chartDurationLabel`.

---

### Task 4: Handle Platform-Specific Code

**Files:**
- Modify: `ChartLens/Sources/ChartLens/RangeSelectorView.swift`

- [ ] **Step 1: Wrap NSCursor with #if os(macOS)**

Replace the two `NSCursor` blocks in `RangeSelectorView.swift` (lines 144-146 and 151-153) with:

```swift
#if os(macOS)
.onHover { inside in
    inside ? NSCursor.resizeLeftRight.push() : NSCursor.resizeLeftRight.pop()
}
#endif
```

- [ ] **Step 2: Replace .glassBackground with conditional**

In `edgeBadge` method (line 228), replace `.glassBackground(.regular, in: RoundedRectangle(cornerRadius: 3))` with:

```swift
#if os(macOS)
.glassBackground(.regular, in: RoundedRectangle(cornerRadius: 3))
#else
.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 3))
#endif
```

---

### Task 5: Add ChartLens Tests

**Files:**
- Create: `ChartLens/Tests/ChartLensTests/ChartGeometryTests.swift`
- Create: `ChartLens/Tests/ChartLensTests/SplineInterpolationTests.swift`
- Create: `ChartLens/Tests/ChartLensTests/ChartTimeFormattingTests.swift`

- [ ] **Step 1: Create ChartGeometryTests.swift**

Copy relevant tests from `WiFiLens/Tests/WiFiLensTests/ChartViewTests.swift` — the `ChartGeometryTests` suite and `SpectrumSectionLayoutTests` stays in WiFiLens (it tests WiFi-specific layout). Change `@testable import WiFi_Lens` to `@testable import ChartLens`.

- [ ] **Step 2: Create SplineInterpolationTests.swift**

Copy `SplineInterpolationTests` from `ChartUtilityTests.swift`. Change import.

- [ ] **Step 3: Create ChartTimeFormattingTests.swift**

Copy `ChartTimeFormattingTests` from `ChartUtilityTests.swift`. Change import.

- [ ] **Step 4: Verify ChartLens tests pass**

Run: `cd /Users/kaoru/Developer/wifi-lens/ChartLens && swift test`
Expected: All tests pass

---

### Task 6: Add ChartLens as Local SPM Dependency to WiFi Lens

**Files:**
- Modify: `WiFiLens/WiFiLens.xcodeproj/project.pbxproj` (add local package reference)

- [ ] **Step 1: Add local package dependency via xcodebuild**

This must be done in Xcode. The local package path is `../ChartLens` relative to the WiFiLens project.

Alternatively, manually add to pbxproj:
- Add `XCLocalSwiftPackageReference` section pointing to `../ChartLens`
- Add `XCSwiftPackageProductDependency` for `ChartLens`
- Add to the WiFiLens target's `packageProductDependencies`

- [ ] **Step 2: Verify WiFiLens can resolve the dependency**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' resolve`
Expected: No errors

---

### Task 7: Update WiFi Lens to Import ChartLens

**Files:**
- Modify: All files in `WiFiLens/Sources/WiFiLens/Charts/` (add `import ChartLens`)
- Modify: All WiFi-specific chart consumers that use chart types

- [ ] **Step 1: Add `import ChartLens` to all chart consumer files**

Files that need the import:
- `BandChartView.swift`
- `BandChartLayout.swift`
- `BandChartViewModel.swift`
- `BandChartRenderModel.swift`
- `ChartSeriesData.swift`
- `TrendChartView.swift`
- `BLETrendChartView.swift`
- `ThroughputChartView.swift`
- `DebugChartView.swift`
- `DebugRoamingChartView.swift`
- `SnapshotToChartAdapter.swift`
- `RecordingTimelineChart.swift`

- [ ] **Step 2: Build WiFiLens to verify no missing symbols**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build`
Expected: Build succeeds

---

### Task 8: Remove Duplicate Chart Files from WiFi Lens

**Files:**
- Delete from `WiFiLens/Sources/WiFiLens/Charts/`:
  - `ChartTypes.swift`
  - `ChartView.swift`
  - `ChartGeometry.swift`
  - `ChartRendering.swift`
  - `SplineInterpolation.swift`
  - `DetailOverviewChart.swift`
  - `RangeSelectorView.swift`
  - `ChartTimeFormatting.swift`

- [ ] **Step 1: Remove chart files from WiFiLens Charts directory**

```bash
rm /Users/kaoru/Developer/wifi-lens/WiFiLens/Sources/WiFiLens/Charts/ChartTypes.swift
rm /Users/kaoru/Developer/wifi-lens/WiFiLens/Sources/WiFiLens/Charts/ChartView.swift
rm /Users/kaoru/Developer/wifi-lens/WiFiLens/Sources/WiFiLens/Charts/ChartGeometry.swift
rm /Users/kaoru/Developer/wifi-lens/WiFiLens/Sources/WiFiLens/Charts/ChartRendering.swift
rm /Users/kaoru/Developer/wifi-lens/WiFiLens/Sources/WiFiLens/Charts/SplineInterpolation.swift
rm /Users/kaoru/Developer/wifi-lens/WiFiLens/Sources/WiFiLens/Charts/DetailOverviewChart.swift
rm /Users/kaoru/Developer/wifi-lens/WiFiLens/Sources/WiFiLens/Charts/RangeSelectorView.swift
rm /Users/kaoru/Developer/wifi-lens/WiFiLens/Sources/WiFiLens/Charts/ChartTimeFormatting.swift
```

- [ ] **Step 2: Remove file references from WiFiLens pbxproj**

Remove PBXBuildFile, PBXFileReference, PBXGroup children, and PBXSourcesBuildPhase entries for the 8 removed files.

- [ ] **Step 3: Build WiFiLens to verify it compiles with ChartLens types**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build`
Expected: Build succeeds (types come from ChartLens)

---

### Task 9: Update WiFi Lens Chart Tests

**Files:**
- Modify: `WiFiLens/Tests/WiFiLensTests/ChartViewTests.swift`
- Modify: `WiFiLens/Tests/WiFiLensTests/ChartUtilityTests.swift`

- [ ] **Step 1: Remove tests that moved to ChartLens**

Remove `ChartGeometryTests` from `ChartViewTests.swift` (keep `SpectrumSectionLayoutTests`).
Remove `SplineInterpolationTests` and `ChartTimeFormattingTests` from `ChartUtilityTests.swift`.

- [ ] **Step 2: Add `import ChartLens` to remaining test files**

Add `import ChartLens` to `ChartViewTests.swift` and `ChartUtilityTests.swift` if they reference chart types.

- [ ] **Step 3: Verify WiFiLens tests pass**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests`
Expected: All tests pass

---

### Task 10: Final Verification

- [ ] **Step 1: Build ChartLens package**

Run: `cd /Users/kaoru/Developer/wifi-lens/ChartLens && swift build`
Expected: Build succeeds

- [ ] **Step 2: Run ChartLens tests**

Run: `cd /Users/kaoru/Developer/wifi-lens/ChartLens && swift test`
Expected: All tests pass

- [ ] **Step 3: Build WiFiLens**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build`
Expected: Build succeeds

- [ ] **Step 4: Run WiFiLens tests**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests`
Expected: All tests pass (minus any pre-existing failures)
