# Network Self-Check Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a manually triggered connectivity, DNS, and system proxy self-check page shared by the OSS and Pro editions.

**Architecture:** A focused `NetworkDiagnostics` domain defines three-state results and three injected checks. `DiagnosticRunner` executes checks in order and streams results to a main-actor view model, while a shared SwiftUI route renders the current execution and conclusion state.

**Tech Stack:** Swift 6, SwiftUI, Observation, Network.framework, CFNetwork/SystemConfiguration, Swift Testing, Xcode project targets.

## Global Constraints

- Support macOS 14 and later.
- Compile the feature into both OSS and Pro targets without using `EditionComposition` or the Pro submodule.
- Start diagnostics only after explicit user action.
- Keep completed statuses limited to Normal, Abnormal, and Indeterminate.
- Resolve only `example.com`; do not identify DoH or DoT.
- Do not download or evaluate PAC scripts.
- Add English, Japanese, and Simplified Chinese localizations manually with `"extractionState": "manual"`.
- Do not run UI test bundles.
- Do not commit changes without explicit user instruction; commit steps are omitted from this plan.

---

### Task 1: Diagnostic Models, Aggregation, and Ordered Runner

**Files:**
- Create: `WiFiLens/Sources/WiFiLens/NetworkDiagnostics/NetworkDiagnosticModels.swift`
- Create: `WiFiLens/Sources/WiFiLens/NetworkDiagnostics/DiagnosticRunner.swift`
- Create: `WiFiLens/Tests/WiFiLensTests/NetworkDiagnostics/DiagnosticRunnerTests.swift`

**Interfaces:**
- Produces: `NetworkDiagnosticStatus`, `NetworkDiagnosticCheckID`, `NetworkDiagnosticResult`, `NetworkDiagnosticConclusion`, `DiagnosticCheck.run()`, `DiagnosticRunner.run(onResult:)`, and `NetworkDiagnosticConclusion.evaluate(_:)`.

- [ ] Write tests using actor-backed spy checks to assert connectivity, DNS, and proxy execution order and incremental result publication.
- [ ] Write table-driven tests for Network Unavailable, Needs Attention, Network Normal, and incomplete-result aggregation.
- [ ] Run `xcodebuild ... -only-testing:WiFiLensTests/DiagnosticRunnerTests test` and confirm the missing types fail compilation.
- [ ] Implement the value models and this protocol exactly:

```swift
protocol DiagnosticCheck: Sendable {
    func run() async -> NetworkDiagnosticResult
}
```

- [ ] Implement `DiagnosticRunner` so it awaits each check, publishes each result, stops cleanly on cancellation, and returns ordered results.
- [ ] Run the focused tests and confirm they pass.

### Task 2: Connectivity and DNS Checks

**Files:**
- Create: `WiFiLens/Sources/WiFiLens/NetworkDiagnostics/NetworkConnectivityCheck.swift`
- Create: `WiFiLens/Sources/WiFiLens/NetworkDiagnostics/DNSResolutionCheck.swift`
- Create: `WiFiLens/Tests/WiFiLensTests/NetworkDiagnostics/ConnectivityAndDNSTests.swift`

**Interfaces:**
- Consumes: `DiagnosticCheck`, `NetworkDiagnosticResult`, and `NetworkDiagnosticCheckID` from Task 1.
- Produces: injected `NetworkPathObserving` and `DNSResolving` seams plus production checks with 3-second and 5-second timeouts.

- [ ] Write mapping tests for `satisfied`, `unsatisfied`, `requiresConnection`, timeout, and cancellation.
- [ ] Write DNS tests for nonempty addresses, explicit resolver failure, timeout, and cancellation using a fake `DNSResolving` implementation.
- [ ] Run the focused tests and confirm they fail for missing checks.
- [ ] Implement a one-shot `NWPathMonitor` adapter that cancels the monitor after its first result or timeout.
- [ ] Implement a system resolver adapter for `example.com` that performs DNS resolution without requiring HTTP success.
- [ ] Map explicit failures and indeterminate outcomes to localized result keys.
- [ ] Run the focused tests and confirm they pass.

### Task 3: System Proxy Parsing and Reachability

**Files:**
- Create: `WiFiLens/Sources/WiFiLens/NetworkDiagnostics/SystemProxyCheck.swift`
- Create: `WiFiLens/Tests/WiFiLensTests/NetworkDiagnostics/SystemProxyCheckTests.swift`

**Interfaces:**
- Consumes: `DiagnosticCheck` and the shared result models.
- Produces: `SystemProxyConfiguration`, `ProxyEndpoint`, `SystemProxySettingsReading`, `ProxyEndpointConnecting`, and `SystemProxyCheck`.

- [ ] Write tests for no proxy, HTTP/HTTPS/SOCKS parsing, normalized endpoint deduplication, malformed enabled proxies, all endpoints reachable, any endpoint unreachable, PAC-only, automatic discovery, and mixed PAC plus explicit proxy states.
- [ ] Run the focused tests and confirm they fail for missing proxy types.
- [ ] Parse `CFNetworkCopySystemProxySettings()` into a value-semantic configuration.
- [ ] Connect to each unique explicit endpoint through `NWConnection` with a 3-second timeout and cancel each connection after a terminal state.
- [ ] Test independent endpoints concurrently and apply the design's result precedence.
- [ ] Run the focused tests and confirm they pass.

### Task 4: View Model and Shared Page

**Files:**
- Create: `WiFiLens/Sources/WiFiLens/NetworkDiagnostics/NetworkDiagnosticsViewModel.swift`
- Create: `WiFiLens/Sources/WiFiLens/NetworkDiagnostics/NetworkDiagnosticsView.swift`
- Create: `WiFiLens/Tests/WiFiLensTests/NetworkDiagnostics/NetworkDiagnosticsViewModelTests.swift`

**Interfaces:**
- Consumes: `DiagnosticRunner` and all production checks.
- Produces: `@MainActor @Observable NetworkDiagnosticsViewModel`, `NetworkDiagnosticExecutionPhase`, and `NetworkDiagnosticsView`.

- [ ] Write tests proving the initial idle state, overlapping-run protection, per-check progress, conclusion publication, reset before rerun, and cancellation without a conclusion.
- [ ] Run the focused tests and confirm they fail for the missing view model.
- [ ] Implement the view model with an injectable runner factory and an owned active `Task`.
- [ ] Implement the centered 640-point SwiftUI page with glass cards, localized status text, non-color status icons, VoiceOver labels, and Run Diagnostics/Run Again behavior.
- [ ] Run the focused tests and confirm they pass.

### Task 5: Shared Navigation, Localization, and Xcode Membership

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/App/SidebarView.swift`
- Modify: `WiFiLens/Sources/WiFiLens/WiFiLensApp.swift`
- Modify: `WiFiLens/Sources/WiFiLens/Resources/Localizable.xcstrings`
- Modify: `WiFiLens/WiFiLens.xcodeproj/project.pbxproj`
- Modify: `WiFiLens/WiFiLens.xcodeproj/xcshareddata/xcschemes/WiFiLensTests.xcscheme`
- Modify: `WiFiLens/Tests/WiFiLensTests/App/MenuBarWindowBehaviorTests.swift`

**Interfaces:**
- Consumes: `NetworkDiagnosticsView` and `NetworkDiagnosticsViewModel`.
- Produces: shared `.networkDiagnostics` sidebar route with no Wi-Fi, Location Services, Pro, or upsell requirement.

- [ ] Extend sidebar tests to assert the localized label, Tools placement inputs, and both route requirements are false.
- [ ] Add `.networkDiagnostics` after `.interfaces` in the Tools section and mount one page/model per main-window root.
- [ ] Add every `nav.network_diagnostics` and `network_diagnostics.*` string in English, Japanese, and Simplified Chinese.
- [ ] Add all new production files to both app targets and all new test files to the WiFiLensTests target and shared test scheme.
- [ ] Run `python3 -m json.tool WiFiLens/Sources/WiFiLens/Resources/Localizable.xcstrings` and confirm the catalog is valid JSON.

### Task 6: Verification and Documentation

**Files:**
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/TODO.md` only if an existing matching roadmap item needs its status updated.

**Interfaces:**
- Consumes: the completed shared feature.
- Produces: architecture documentation and verified OSS/Pro-compatible project state.

- [ ] Document the NetworkDiagnostics source area, manual run flow, system adapters, and OSS/Pro sharing in `docs/ARCHITECTURE.md`.
- [ ] Run `git diff --check` and resolve whitespace errors.
- [ ] Run `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests` and confirm success.
- [ ] Run `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build` and confirm success.
- [ ] Inspect `git status --short` and preserve the user's existing `WiFiLens/Configs/Base.xcconfig` modification.

---

## Progressive Disclosure Revision

### Task 7: Per-Check Minimum Presentation Duration

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/NetworkDiagnostics/DiagnosticRunner.swift`
- Modify: `WiFiLens/Sources/WiFiLens/NetworkDiagnostics/NetworkDiagnosticsViewModel.swift`
- Test: `WiFiLens/Tests/WiFiLensTests/NetworkDiagnostics/NetworkDiagnosticsTests.swift`

**Interfaces:**
- Consumes: the existing ordered `DiagnosticRunner` and view-model production check list.
- Produces: `DiagnosticRunner.minimumStepDuration: Duration`, defaulting to zero for isolated runner tests; the production view model passes `.milliseconds(800)`.

- [ ] Add a runner test with an immediate check and a 50-millisecond minimum, measure the run with `ContinuousClock`, and assert that publication does not finish before the minimum.
- [ ] Run `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests/NetworkDiagnosticsTests` and confirm the duration assertion fails because the runner has no minimum-duration input.
- [ ] Add `minimumStepDuration` to `DiagnosticRunner`; record `ContinuousClock.now` before each check, sleep until the start instant advanced by the minimum after the real result arrives, then publish the result. Preserve cancellation checks before publication.
- [ ] Configure `NetworkDiagnosticsViewModel` with an injected `minimumStepDuration` whose production default is `.milliseconds(800)` and whose unit tests pass `.zero`.
- [ ] Run the focused tests and confirm the duration, order, overlap, and rerun tests pass.

### Task 8: Progressive Result Disclosure

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/NetworkDiagnostics/NetworkDiagnosticsView.swift`
- Modify: `WiFiLens/Sources/WiFiLens/Resources/Localizable.xcstrings` only if new progress or disclosure copy is required.
- Test: `WiFiLens/Tests/WiFiLensTests/NetworkDiagnostics/NetworkDiagnosticsTests.swift`

**Interfaces:**
- Consumes: `NetworkDiagnosticsPagePhase`, execution phases, ordered check identifiers, and completed results.
- Produces: `NetworkDiagnosticsPresentation.visibleCheckIDs(phase:executionPhases:results:)` and `defaultExpandedCheckIDs(results:)`, plus disclosure rows in the view.

- [ ] Add table-driven tests proving idle exposes no checks, running exposes completed plus active checks but not future checks, and completed exposes all result identifiers.
- [ ] Add tests proving Normal results are collapsed by default while Abnormal and Indeterminate results are expanded.
- [ ] Run the focused tests and confirm they fail because `NetworkDiagnosticsPresentation` does not exist.
- [ ] Implement the pure presentation helpers and use them to drive the view's `ForEach`.
- [ ] Add a compact progress indicator while running. Render the active item expanded, Normal completed items as disclosure rows collapsed by default, and non-Normal items expanded by default. Reset local disclosure state whenever a new run starts.
- [ ] Keep the idle page limited to its explanation and Run Diagnostics button; show the conclusion only after completion and retain Run Again behavior.
- [ ] Run the focused tests, validate the localization catalog with `python3 -m json.tool`, and confirm all checks pass.
- [ ] Run the full WiFiLensTests bundle, then build both `WiFi Lens` and `WiFi Lens Pro` Debug schemes. Do not run UI tests.

### Task 9: Scan-and-Report Layout Revision

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/NetworkDiagnostics/NetworkDiagnosticsViewModel.swift`
- Modify: `WiFiLens/Sources/WiFiLens/NetworkDiagnostics/NetworkDiagnosticsView.swift`
- Modify: `WiFiLens/Sources/WiFiLens/Resources/Localizable.xcstrings`
- Test: `WiFiLens/Tests/WiFiLensTests/NetworkDiagnostics/NetworkDiagnosticsTests.swift`

**Interfaces:**
- Consumes: ordered check identifiers, view-model execution phases, completed result dictionary, and existing 0.8-second pacing.
- Produces: ordered report results, Normal result count, non-Normal results, a single running scan panel, one bounded completion panel, and a full-report sheet.

- [ ] Add failing presentation tests asserting report results retain check order, Normal results are counted, and only Abnormal or Indeterminate results are returned as issues.
- [ ] Replace the prior visible-card and default-disclosure helpers with ordered report and summary helpers, then run the focused tests.
- [ ] Replace the running card list with one scan panel showing only the active check and overall progress.
- [ ] Replace the completed card list with one result panel showing the conclusion, issue summaries, Normal count, and View Full Report action.
- [ ] Add a scrollable full-report sheet whose rows always expose title, status, and summary and whose Close button dismisses the sheet.
- [ ] Add all new strings through the repository i18n script, validate JSON, and confirm every catalog language is complete.
- [ ] Run the full WiFiLensTests bundle and build both `WiFi Lens` and `WiFi Lens Pro` Debug schemes without running UI tests.

### Task 10: Adaptive Desktop Control-Rail Layout

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/NetworkDiagnostics/NetworkDiagnosticsView.swift`
- Modify: `WiFiLens/Sources/WiFiLens/Resources/Localizable.xcstrings`
- Modify: `docs/ARCHITECTURE.md`
- Test: `WiFiLens/Tests/WiFiLensTests/NetworkDiagnostics/NetworkDiagnosticsTests.swift`

**Interfaces:**
- Consumes: the existing idle, running, completed, and report states without changing diagnostic execution.
- Produces: `NetworkDiagnosticsLayoutMode`, `NetworkDiagnosticsLayoutModel.mode(for:)`, a lightweight control rail, a flexible workspace, adaptive issue columns, and a native report table.

- [ ] Add failing boundary tests proving widths below the content-derived threshold stack the rail and workspace, while widths at or above it use the side-by-side layout.
- [ ] Implement the pure layout model and use it to select a top-aligned `HStack` or `VStack` inside the available detail width.
- [ ] Move feature explanation, run state, and primary action into an unbacked 220–280 point control rail.
- [ ] Rebuild ready, scanning, and completed content as flexible leading-aligned workspace surfaces with no page maximum width or fixed workspace height.
- [ ] Render issue summaries with `LazyVGrid` adaptive columns and keep the full result surface flexible.
- [ ] Replace the report scroll rows with a native macOS `Table` and add localized Check, Status, and Result column titles.
- [ ] Validate localization completeness, run the full WiFiLensTests bundle, and build both Debug app schemes without UI tests.

### Task 11: Full-Width Diagnostic Workbench

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/NetworkDiagnostics/NetworkDiagnosticsViewModel.swift`
- Modify: `WiFiLens/Sources/WiFiLens/NetworkDiagnostics/NetworkDiagnosticsView.swift`
- Modify: `WiFiLens/Sources/WiFiLens/Resources/Localizable.xcstrings`
- Modify: `docs/ARCHITECTURE.md`
- Test: `WiFiLens/Tests/WiFiLensTests/NetworkDiagnostics/NetworkDiagnosticsTests.swift`

**Interfaces:**
- Consumes: existing ordered checks, execution phases, results, conclusion, and per-check pacing.
- Produces: `NetworkDiagnosticsWorkbenchLayout`, regular/condensed/compact modes, ordered visible workbench rows, a command bar, inline progress/conclusion strip, and an adaptive native table.

- [ ] Replace the prior control-rail boundary test with failing tests for regular, condensed, and compact table boundaries.
- [ ] Add failing tests proving running rows include completed and active checks but omit waiting checks, while completed rows include every result.
- [ ] Replace the control-rail layout model with the workbench layout and row-presentation helpers.
- [ ] Replace the page with a full-width command bar, inline state strip, and native result table that consumes remaining height.
- [ ] Implement three-column, two-column, and single-column table variants selected from available width.
- [ ] Remove the separate report sheet and expose result summaries directly in every completed table row.
- [ ] Validate localization completeness, run all unit tests, and build OSS and Pro Debug schemes without UI tests.

### Task 12: Comfortable Native Result Table

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/NetworkDiagnostics/NetworkDiagnosticsViewModel.swift`
- Modify: `WiFiLens/Sources/WiFiLens/NetworkDiagnostics/NetworkDiagnosticsView.swift`
- Test: `WiFiLens/Tests/WiFiLensTests/NetworkDiagnostics/NetworkDiagnosticsTests.swift`
- Modify: `docs/ARCHITECTURE.md`

**Interfaces:**
- Consumes: `NetworkDiagnosticsWorkbenchLayoutMode`, `NetworkDiagnosticsWorkbenchRow`, and the existing regular, condensed, and compact table variants.
- Produces: `NetworkDiagnosticsTablePresentation.minimumRowHeight`, a 54-point comfortable row layout, disabled alternating row backgrounds, and non-duplicated active-state copy.

- [x] Add a failing presentation test asserting `NetworkDiagnosticsTablePresentation.minimumRowHeight == 54` and that its row-background mode disables alternating rows.
- [x] Run `xcodebuild -quiet -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests/NetworkDiagnosticsTests` and confirm the new presentation type is missing.
- [x] Add the presentation constants to `NetworkDiagnosticsViewModel.swift` so visual policy remains testable without rendering SwiftUI.
- [x] Apply the 54-point minimum through `defaultMinListRowHeight`, disable alternating table backgrounds, and keep unused table space visually empty.
- [x] Refine every table mode so check icons are secondary, status remains compact and accessible, summaries use primary contrast and wrap naturally, and the active row shows Checking only once.
- [x] Update `docs/ARCHITECTURE.md` with the comfortable-density and empty-space policy.
- [x] Run the focused diagnostics tests and confirm they pass.
- [x] Validate `git diff --check`, run the complete WiFiLensTests bundle, and build both `WiFi Lens` and `WiFi Lens Pro` Debug schemes without UI tests.
- [x] Do not commit or push; repository policy requires explicit user authorization.

### Task 13: Outcome-Oriented Result Copy

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/Resources/Localizable.xcstrings`
- Test: `WiFiLens/Tests/WiFiLensTests/NetworkDiagnostics/NetworkDiagnosticsTests.swift`

**Interfaces:**
- Consumes: the existing ten `network_diagnostics.connectivity.*.summary`, `network_diagnostics.dns.*.summary`, and `network_diagnostics.proxy.*.summary` localization keys.
- Produces: concise Normal outcomes, actionable Abnormal outcomes, neutral Indeterminate outcomes, and no user-facing DNS test-domain disclosure.

- [x] Add a failing test that runs a successful `DNSResolutionCheck` and asserts its summary does not contain `example.com`.
- [x] Replace the ten summary translations in English, German, Spanish, Japanese, and Simplified Chinese while preserving the existing localization keys and diagnostic states.
- [x] Run the focused diagnostics tests and confirm they pass.
- [x] Validate the string catalog JSON and scan it for missing translations.
- [x] Run the complete WiFiLensTests bundle and build both app schemes without UI tests.
- [x] Do not commit or push.
