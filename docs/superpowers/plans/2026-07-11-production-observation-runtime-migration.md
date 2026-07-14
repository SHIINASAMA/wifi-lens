# Production Observation Runtime Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the normalized observation runtime the single production implementation for scan-cycle analysis and Store publication, then remove duplicate Scanner orchestration.

**Architecture:** Move production scan-cycle construction behind `WiFiObservationPipeline` and `WiFiObservationRuntime`. The runtime owns the scan stream and publishes complete immutable cycles; `ScannerViewModel` forwards lifecycle/configuration and remains responsible for filters, signal history, charts, tables, and existing Recording/MCP compatibility projections.

**Tech Stack:** Swift 6.0, AsyncStream, Swift Concurrency, CoreWLAN adapters, Swift Testing, SwiftUI, Xcode project target membership

## Global Constraints

- Milestone 1 must be complete and green before starting this plan.
- macOS 14+ and Swift 6.0.
- Do not run UI test bundles.
- Preserve current target AP, supported-band, device-capability, regulatory override, scan interval, Wi-Fi power, and authorization behavior.
- Preserve filter, chart, table, signal-history, Recording, and MCP public behavior.
- Recording and MCP are not redesigned in this plan.
- Do not introduce a fallback production observation path.
- Delete code only after reference audit, deletion test, unit tests, and both builds prove replacement.
- Do not commit without explicit user authorization.

---

## File Map

| File | Responsibility |
|---|---|
| `WiFiLens/Sources/WiFiLens/Observation/Pipeline/WiFiObservationPipeline.swift` | Authoritative scan-cycle analysis from raw networks and production context |
| `WiFiLens/Sources/WiFiLens/Observation/Runtime/WiFiObservationRuntime.swift` | Scan stream lifecycle, capability cache, observation production and publication |
| `WiFiLens/Sources/WiFiLens/Scanner/WiFiScanner.swift` | Testable scan-stream protocol adapter |
| `WiFiLens/Sources/WiFiLens/Scanner/ScannerViewModel.swift` | Runtime lifecycle forwarding and downstream presentation projections |
| `WiFiLens/Tests/WiFiLensTests/Observation/PipelineTests.swift` | Production semantic fixtures for target AP, bands, overrides, partial failures |
| `WiFiLens/Tests/WiFiLensTests/Observation/RuntimeTests.swift` | Scan lifecycle, interval restart, cancellation, publication integration |
| `WiFiLens/Sources/WiFiLens/Observation/Controller/WiFiObservationController.swift` | Removed after deletion test |
| `WiFiLens/Tests/WiFiLensTests/Observation/ControllerTests.swift` | Removed with shallow controller |

---

### Task 1: Make Scan-Cycle Analysis the Pipeline's Tested Interface

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/Observation/Pipeline/WiFiObservationPipeline.swift`
- Modify: `WiFiLens/Tests/WiFiLensTests/Observation/PipelineTests.swift`
- Modify: `WiFiLens/Tests/WiFiLensTests/Observation/MockProviders.swift`

**Interfaces:**
- Consumes: raw `[WiFiNetwork]`, cached device capabilities, current connection provider, gateway latency provider, regulatory overrides
- Produces: `WiFiObservationCycleResult`

- [ ] **Step 1: Add production-cycle types and failing tests**

Define the intended shared value shapes in the test first:

```swift
struct WiFiObservationCycleContext: Sendable {
    let timestamp: Date
    let interfaceName: String?
    let supportedBands: Set<ChannelBand>
    let supportedChannelsRaw: [(Int, Int)]
    let deviceSupportedChannels: Set<String>
    let deviceCapabilities: DevicePHYCapabilities
    let userRegionOverride: RegulatoryDomain?
    let userDefaultsRegionOverride: RegulatoryDomain?
}

struct WiFiObservationCycleResult: Sendable {
    let observation: WiFiObservation
    let inferredRegion: RegionInferenceResult
}
```

Add tests proving that a cycle:

- marks the actual current BSSID in its environment snapshot;
- passes the actual current channel and target AP to channel analysis;
- uses `context.supportedBands` rather than `["24", "5", "6"]`;
- applies explicit user override before defaults override;
- passes cached device channels and capabilities to recommendation;
- produces current status, same-cycle latency, quality, diagnosis, analysis, and recommendation in one observation;
- preserves a valid current status when environment data contains an error.

- [ ] **Step 2: Verify RED**

Run focused Pipeline tests. Expected: compilation fails because the cycle types and method are absent.

- [ ] **Step 3: Implement `produceCycle`**

Extend `WiFiObservationPipelining` with:

```swift
func produceCycle(
    networks: [WiFiNetwork],
    context: WiFiObservationCycleContext
) async -> WiFiObservationCycleResult
```

The implementation must:

1. fetch `WiFiCurrentStatus` once;
2. measure gateway latency once using that status's router IP;
3. adapt the supplied raw networks once with `NetworkObservationAdapter`;
4. build one `WiFiEnvironmentSnapshot` using `context.timestamp` and `interfaceName`;
5. construct the target AP from the same current status;
6. call `ChannelOccupancyAnalyzer` with real supported bands and target AP;
7. resolve region from explicit override, defaults override, supported channels, and adapted country codes;
8. compute recommendation from real device channels and capabilities;
9. compute quality and diagnosis;
10. return one observation and the inferred region.

Keep existing refresh methods temporarily, implemented in terms of existing providers, until the runtime migration and deletion audit determine whether callers remain.

- [ ] **Step 4: Run Pipeline tests GREEN**

Run the focused Pipeline suite. Expected: all old and new tests pass.

---

### Task 2: Move the Scan Stream and Capability Cache into the Runtime

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/Scanner/WiFiScanner.swift`
- Modify: `WiFiLens/Sources/WiFiLens/Observation/Runtime/WiFiObservationRuntime.swift`
- Modify: `WiFiLens/Tests/WiFiLensTests/Observation/RuntimeTests.swift`

**Interfaces:**
- Consumes: `WiFiObservationPipelining.produceCycle`, scan interval, regulatory configuration
- Produces: runtime scan lifecycle and `WiFiObservationScanOutput`

- [ ] **Step 1: Add a testable scan source boundary**

Add a shared `WiFiScanStreaming` protocol covering the existing actor operations:

```swift
protocol WiFiScanStreaming: Sendable {
    func startScanning(interval: Duration) async -> AsyncStream<WiFiScanEvent>
    func stopScanning() async
    func interfaceName() async -> String?
    func supportedBands() async -> Set<ChannelBand>
    func supportedChannels() async -> [(ChannelBand, Int)]
    func supportedWLANChannelsRaw() async -> [(Int, Int)]
    func devicePHYCapabilities() async -> DevicePHYCapabilities
}
```

Make `WiFiScanner` conform without changing scan behavior.

- [ ] **Step 2: Add failing runtime scan tests**

Create a scripted mock scan source that yields two network arrays and records requested intervals and stop calls. Add tests proving:

- runtime initializes supported bands, raw channels, and device capabilities once per start;
- every network event calls `produceCycle` and publishes its result;
- scan failure publishes an observation error without fabricating current-status transitions;
- stop cancels the stream and invokes `stopScanning`;
- restart uses the new interval and does not leave two active streams.

- [ ] **Step 3: Add runtime production configuration and output**

```swift
struct WiFiObservationRuntimeConfiguration: Sendable {
    var scanInterval: Duration
    var userRegionOverride: RegulatoryDomain?
    var userDefaultsRegionOverride: RegulatoryDomain?
}

struct WiFiObservationScanOutput: Sendable {
    let rawNetworks: [WiFiNetwork]
    let cycle: WiFiObservationCycleResult
}
```

Add runtime operations:

```swift
func startScanning(
    configuration: WiFiObservationRuntimeConfiguration,
    onOutput: @escaping @MainActor (WiFiObservationScanOutput) -> Void
) async
func restartScanning(configuration: WiFiObservationRuntimeConfiguration)
func stopScanning() async
```

The runtime must own the active scan task, cache device capabilities before consuming the stream, call `pipeline.produceCycle`, accept the result observation, then invoke the output projection callback.

- [ ] **Step 4: Run runtime scan tests GREEN**

Run Runtime tests. Expected: ordered publication and scan lifecycle tests pass.

---

### Task 3: Convert ScannerViewModel to Runtime Lifecycle and Projection

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/Scanner/ScannerViewModel.swift`
- Modify: relevant Scanner and spectrum tests already in `WiFiLensTests`

**Interfaces:**
- Consumes: runtime start/restart/stop and `WiFiObservationScanOutput`
- Produces: unchanged UI-facing Scanner properties and commands

- [ ] **Step 1: Add lifecycle and projection regression tests**

Use an injected runtime or runtime test double to prove:

- `scanIntervalSeconds` forwards a restart with the new interval while scanning;
- Wi-Fi power off stops runtime scanning;
- authorization loss stops runtime scanning;
- a runtime output updates raw-network presentation, signal history, channel qualities, recommendations, inferred region, and interface state;
- filter query, AP visibility, and per-panel lock state survive new outputs;
- Recording's one-second override still changes the production scan interval.

- [ ] **Step 2: Replace Scanner scan-loop ownership**

Remove `scanTask`, direct `scanner.startScanning`, and direct `scanner.stopScanning` calls from `ScannerViewModel`. Make `startScanLoop`, `restartScanLoop`, and `stop` forward to the runtime while preserving throughput-monitor behavior and existing public state.

- [ ] **Step 3: Move observation production out of Scanner**

Delete Scanner's inline construction of environment snapshot, current status, latency, quality, diagnosis, channel analysis, recommendation, and observation publication.

Handle `WiFiObservationScanOutput` by:

- passing `rawNetworks` through the existing `applyNetworks` projection path;
- assigning `channelQualities`, `channelRecommendations`, and `regulatoryPipeline.inferredRegion` from the cycle result;
- retaining signal-history, filter, chart, table, visibility, selected-network, MCP provider, and Recording compatibility behavior.

- [ ] **Step 4: Run Scanner, filter, chart, Recording mode, and Runtime tests**

Expected: all focused tests pass with no direct production observation construction in `ScannerViewModel`.

---

### Task 4: Remove Replaced Orchestration After the Deletion Test

**Files:**
- Delete: `WiFiLens/Sources/WiFiLens/Observation/Controller/WiFiObservationController.swift`
- Delete: `WiFiLens/Tests/WiFiLensTests/Observation/ControllerTests.swift`
- Modify: `WiFiLens/WiFiLens.xcodeproj/project.pbxproj`
- Modify: `WiFiLens/Sources/WiFiLens/Observation/Pipeline/WiFiObservationPipeline.swift`

**Interfaces:**
- Consumes: completed production Runtime path
- Produces: one production observation orchestration path

- [ ] **Step 1: Run reference and responsibility audits**

```sh
rg -n 'WiFiObservationController|refreshFullObservation|refreshEnvironmentScan|refreshCurrentConnection' WiFiLens Pro -g '*.swift'
rg -n 'ChannelOccupancyAnalyzer|ChannelRecommendationEngine|DiagnosticEvaluator|WiFiQualityEvaluator|store\.apply' WiFiLens/Sources/WiFiLens/Scanner/ScannerViewModel.swift
```

Classify every hit. Provider/analyzer/filter references with independent responsibilities remain; replaced orchestration must have no production caller.

- [ ] **Step 2: Delete the shallow Controller and its tests**

Remove both files and all PBX file references, build files, group entries, and Sources entries.

- [ ] **Step 3: Remove obsolete Pipeline refresh surfaces only if unreferenced**

If the three legacy refresh methods have no production or test consumer after `produceCycle` migration, remove them and narrow `WiFiObservationPipelining` to the production cycle interface. Update mocks and tests to that exact interface. If a real independent caller remains, retain the method and record the caller in the final review rather than deleting it mechanically.

- [ ] **Step 4: Prove the deletion test**

Run Pipeline, Runtime, Scanner, filter, chart, Recording mode, OSS full unit, and Pro full unit tests. Expected: all pass without reintroducing orchestration into Scanner.

---

### Task 5: Final Architecture Documentation and Verification

**Files:**
- Modify: `docs/ARCHITECTURE.md`
- Modify: `Pro/docs/ARCHITECTURE.md`
- Modify: older observation design/plan status where claims are obsolete

**Interfaces:**
- Consumes: final runtime implementation
- Produces: accurate architecture documentation and completion evidence

- [ ] **Step 1: Update shared architecture documentation**

Document Runtime ownership, immutable publication, Store projection, Scanner presentation responsibilities, and deferred Recording/MCP migration.

- [ ] **Step 2: Update Pro architecture documentation**

Replace the stale module inventory with the actual Events, Timeline, Menu Bar, Recording, Session, and snapshot-export modules. Document the Pro observation consumer and target boundary.

- [ ] **Step 3: Run the full completion audit**

Verify every acceptance criterion in the design against source references and command output. Required commands include:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens Pro" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensProTests
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens Pro" -configuration Debug -destination 'platform=macOS' build
git diff --check
```

- [ ] **Step 4: Run final boundary searches**

Expected final evidence:

- no Pro event source in the OSS Sources phase;
- no mutable Store reconstruction in Pro Events;
- no direct observation production orchestration in Scanner;
- one runtime production producer;
- filters and downstream projections remain present;
- Recording and MCP public structures remain compatible;
- no UI test bundle executed.
