# Debug Multi-AP Chart Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a `DebugChartView` multi-AP mode whose only difference from the Spectrum page chart is that its AP data source is manually configured debug data.

**Architecture:** Keep `WiFiBandChart`, `BandChartViewModel`, `BandChartRenderModel`, `BandChartLayout`, hover, selection, zoom, heatmap, labels, and RSSI animation unchanged. Add debug-only scenario models and an adapter that converts editable table rows into `ChartSeriesData`, then inject those series through `BandChartViewModel.debugInject(series:)`.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing, Xcode project targets, `UserDefaults`, existing chart engine.

## Global Constraints

- App build and tests must use `xcodebuild`, not `swift build` or `swift test`.
- All new documentation must live under `docs/`.
- Do not commit or push unless explicitly asked.
- New Swift source files must be added to both `WiFiLens` and `WiFiLensPro` targets.
- New test files must be added to the `WiFiLensTests` target sources.
- New code comments and docs must be English.
- Debug UI must remain behind `#if DEBUG`.
- The debug chart must reuse the same rendering mechanism as the Spectrum page; only the source data may differ.

---

## Files

- Create: `WiFiLens/Sources/WiFiLens/Debug/DebugMultiAPScenario.swift`
  - Owns debug-only scenario models, presets, persistence, and conversion to `ChartSeriesData`.
- Modify: `WiFiLens/Sources/WiFiLens/Debug/DebugChartView.swift`
  - Adds `Single AP` / `Multi AP` mode picker and the multi-AP chart-over-table editor.
- Create: `WiFiLens/Tests/WiFiLensTests/DebugMultiAPScenarioTests.swift`
  - Tests model coding, presets, conversion, and persistence fallback.
- Modify: `WiFiLens/WiFiLens.xcodeproj/project.pbxproj`
  - Adds the new source file to app and Pro targets; adds the test file to the test target.
- Modify: `AGENTS.md`
  - Adds this plan document to the docs table.

## Task 1: Debug Scenario Model and Adapter

**Files:**
- Create: `WiFiLens/Tests/WiFiLensTests/DebugMultiAPScenarioTests.swift`
- Create: `WiFiLens/Sources/WiFiLens/Debug/DebugMultiAPScenario.swift`
- Modify: `WiFiLens/WiFiLens.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces: `DebugScenario`, `DebugAPConfig`, `DebugTrend`, `DebugScenarioPreset`, `DebugScenarioBuilder`, `DebugScenarioStore`.
- Produces: `DebugScenarioBuilder.seriesSources(from:band:) -> [DebugChartSeriesSource]`.
- Produces: `DebugChartSeriesAdapter.seriesData(from:band:) -> [ChartSeriesData]`.
- Consumes: `ChannelBand`, `ChannelSpanCalculator`, `ChartSeriesData`, `ChartSeriesDomainData`, `ChartSeriesRenderState`, `Color(hex:)`.

- [ ] **Step 1: Write failing tests**

Add tests for:
- `DebugScenario` encode/decode preserves version, band, and AP rows.
- Disabled AP rows are not converted.
- Channel span conversion matches `ChannelSpanCalculator.channelBlock`.
- Hidden, visible, filtered, protocol, country, color, and trend fields map into `ChartSeriesData`.
- Invalid stored data falls back to the default preset.

- [ ] **Step 2: Run the test and verify RED**

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests
```

Expected: build fails because `DebugScenario` and related types do not exist yet.

- [ ] **Step 3: Implement model and adapter**

Add `#if DEBUG` models, default presets, clamping helpers, `UserDefaults` persistence, and the scenario-to-series conversion.

- [ ] **Step 4: Add files to Xcode project and verify GREEN**

Add the new Swift files to the project and run the same unit-only `xcodebuild test -only-testing:WiFiLensTests` command. Expected: tests pass or fail only with concrete implementation issues to fix.

## Task 2: Multi-AP Chart-Over-Table UI

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/Debug/DebugChartView.swift`

**Interfaces:**
- Consumes: `DebugScenario`, `DebugAPConfig`, `DebugScenarioPreset`, `DebugScenarioBuilder`, `DebugScenarioStore`.
- Consumes: existing `BandChartViewModel.debugInject(series:)` and `BandChartView`.

- [ ] **Step 1: Add mode state**

Add `DebugChartMode.singleAP` and `DebugChartMode.multiAP`, then wrap the current controls in the `singleAP` branch without changing the oscillator behavior.

- [ ] **Step 2: Add multi-AP state and lifecycle**

Load the stored scenario when entering multi-AP mode, keep a `BandChartViewModel` for the selected band, and route all edits through `applyScenario(save:)`.

- [ ] **Step 3: Build the vertical layout**

Render top controls, then `BandChartView`, then the editable AP table. The table must be below the chart and every edit must immediately update the chart.

- [ ] **Step 4: Implement row editing commands**

Support add, duplicate, delete, reset preset, band changes, and per-row bindings for enabled, SSID, channel, width, RSSI, color, hidden, visible, filtered, protocol flags, country, trend, and delta.

- [ ] **Step 5: Build and manually inspect compile output**

Run the app build command and fix SwiftUI type errors:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build
```

Expected: build succeeds.

## Task 3: Final Verification

**Files:**
- All changed files.

**Interfaces:**
- Verifies every explicit requirement from the design spec and user objective.

- [ ] **Step 1: Run targeted tests**

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests
```

Expected: unit test action succeeds. If the local macOS test runner cannot launch, run `build-for-testing` and report the runner failure separately from compile results.

- [ ] **Step 2: Run build**

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build
```

Expected: build succeeds.

- [ ] **Step 3: Audit requirements**

Confirm from code and tests:
- Multi-AP mode is inside `DebugChartView`.
- The UI is chart above, editable table below.
- Edits update `DebugScenario`, save to `UserDefaults`, convert to `[ChartSeriesData]`, and call `debugInject(series:)`.
- `WiFiBandChart` and `BandChartViewModel` production rendering path is reused.
- The Spectrum page rendering mechanism is not forked.
- JSON import/export is not implemented, but the schema is `Codable` and versioned.
