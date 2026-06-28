# Unified Wi-Fi Observation Pipeline — Migration Plan (Phases 6–10)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate all UI consumers to use the new observation pipeline, then remove old data paths.

**Architecture:** Replace direct system API calls (NetworkInfoService, GatewayPinger, CWWiFiClient) with pipeline/store/controller. ScannerViewModel retains ownership of scan loop, band chart VMs, and signal history — only data acquisition moves to the pipeline.

**Tech Stack:** Swift 6.0, SwiftUI, @Observable, CoreWLAN, Swift Testing

## Global Constraints

- macOS 14+, Swift 6.0
- Tests: `xcodebuild ... -only-testing:WiFiLensTests`
- Existing code must compile and pass tests after every task
- No comments in code unless user requests
- Each phase must be behaviorally equivalent before moving to next

## File Structure

### Modified Files (Phase 6 — Menu Bar)

| File | Change |
|------|--------|
| `Pro/MenuBar/MenuBarStatusViewModel.swift` | Replace direct NetworkInfoService/GatewayPinger with controller pipeline |
| `WiFiLens/WiFiLensTests/Observation/MenuBarMigrationTests.swift` | New: verify menu bar reads from store |

### Modified Files (Phase 7 — Roaming Test)

| File | Change |
|------|--------|
| `WiFiLens/Sources/WiFiLens/Roaming/RoamingTestViewModel.swift` | Replace CWWiFiClient + GatewayPinger with RoamingProbeProvider |
| `WiFiLens/WiFiLensTests/Observation/RoamingMigrationTests.swift` | New: verify roaming uses provider |

### Modified Files (Phase 8 — Overview Diagnosis)

| File | Change |
|------|--------|
| `WiFiLens/Sources/WiFiLens/App/OverviewView.swift` | Replace inline diagnose() with DiagnosticEvaluator via store |
| `WiFiLens/WiFiLensTests/Observation/DiagnosticMigrationTests.swift` | New: verify diagnosis from store matches old logic |

### Modified Files (Phase 9 — ScannerViewModel Refactor)

| File | Change |
|------|--------|
| `WiFiLens/Sources/WiFiLens/Scanner/ScannerViewModel.swift` | Delegate data acquisition to pipeline, keep scan loop + charts |
| `WiFiLens/Sources/WiFiLens/Observation/Pipeline/WiFiObservationPipeline.swift` | Add continuous scan support for ScannerViewModel |

### Modified Files (Phase 10 — Cleanup)

| File | Change |
|------|--------|
| `WiFiLens/Sources/WiFiLens/Scanner/ScannerViewModel.swift` | Remove old computation methods |
| `WiFiLens/Sources/WiFiLens/Interfaces/NetworkInfoService.swift` | Keep fetchAll() for InterfacesView, remove direct Wi-Fi status usage from other consumers |

---

## Task 1: Migrate Menu Bar to Observation Pipeline

**Files:**
- Modify: `Pro/MenuBar/MenuBarStatusViewModel.swift`
- Create: `WiFiLens/WiFiLensTests/Observation/MenuBarMigrationTests.swift`

**Interfaces:**
- Consumes: `WiFiObservationController`, `WiFiObservationStore` (from Phase 5)
- Produces: Menu bar reads from store instead of calling providers directly

- [ ] **Step 1: Read current MenuBarStatusViewModel**

Read `Pro/MenuBar/MenuBarStatusViewModel.swift` to understand current data flow.

- [ ] **Step 2: Add controller and store properties**

In `MenuBarStatusViewModel`, add:
```swift
let controller: WiFiObservationController
let store: WiFiObservationStore
```

Update `init()` to accept these or create defaults.

- [ ] **Step 3: Replace fetch() method**

Replace the current `fetch()` that calls `NetworkInfoService.fetchAll()` + `GatewayPinger.ping()` with:
```swift
func fetch() async {
    isLoading = true
    errorMessage = nil
    await controller.refreshCurrentConnection()
    isLoading = false

    guard let status = store.currentStatus, status.isConnected else {
        ssid = nil; bssid = nil; channel = nil; rssi = nil
        gatewayLatency = nil
        errorMessage = String(localized: "menubar.error.no_connection")
        return
    }

    ssid = status.ssid
    bssid = status.bssid
    channel = status.channel
    rssi = status.rssi
    gatewayLatency = store.gatewayLatency?.latencyMs
    lastUpdated = Date()
}
```

- [ ] **Step 4: Replace qualityLevel computed property**

Replace inline RSSI thresholds with:
```swift
var qualityLevel: QualityLevel {
    guard let level = store.quality?.level else { return .unknown }
    switch level {
    case .good: return .good
    case .fair: return .fair
    case .poor: return .poor
    case .unknown: return .unknown
    }
}
```

- [ ] **Step 5: Replace signalLabel and latencyLabel**

```swift
var signalLabel: String { store.quality?.signalLabel ?? "—" }
var latencyLabel: String { store.quality?.latencyLabel ?? "—" }
```

- [ ] **Step 6: Write migration test**

Create `WiFiLens/WiFiLensTests/Observation/MenuBarMigrationTests.swift`:
```swift
import Testing
@testable import WiFi_Lens

@Suite("MenuBar Migration")
struct MenuBarMigrationTests {
    @Test("qualityLevel reads from store quality result")
    func qualityFromStore() async {
        let store = WiFiObservationStore()
        let controller = WiFiObservationController(store: store)
        let vm = MenuBarStatusViewModel(controller: controller, store: store)

        store.quality = WiFiQualityResult(level: .good, signalLabel: "Strong", latencyLabel: "Normal", summary: "Good")
        #expect(vm.qualityLevel == .good)
    }
}
```

- [ ] **Step 7: Add test to Xcode project, build and test**

```bash
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests
```

- [ ] **Step 8: Commit**

```bash
git add Pro/MenuBar/MenuBarStatusViewModel.swift WiFiLens/WiFiLensTests/Observation/MenuBarMigrationTests.swift
git commit -m "refactor: migrate menu bar to observation pipeline"
```

---

## Task 2: Migrate Roaming Test to Observation Pipeline

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/Roaming/RoamingTestViewModel.swift`
- Create: `WiFiLens/WiFiLensTests/Observation/RoamingMigrationTests.swift`

**Interfaces:**
- Consumes: `RoamingProbeProvider`, `RoamingEventDetector`, `GatewayLatencyProvider` (from Phase 4)
- Produces: Roaming test uses same models as pipeline

- [ ] **Step 1: Read current RoamingTestViewModel**

Read `WiFiLens/Sources/WiFiLens/Roaming/RoamingTestViewModel.swift` to understand the 4 CWWiFiClient call sites and the tick() loop.

- [ ] **Step 2: Add provider properties**

Add to `RoamingTestViewModel`:
```swift
let roamingProvider: RoamingProbeProviding
let latencyProvider: GatewayLatencyProviding
```

Update `init()` to accept these or create defaults.

- [ ] **Step 3: Replace checkReadiness()**

Replace `CWWiFiClient.shared().interface()` with:
```swift
func checkReadiness() {
    state = .idle
    errorMessage = nil
    Task {
        let status = await roamingProvider.fetchCurrentProbe()
        guard status.isConnected, let ssid = status.ssid else {
            errorMessage = String(localized: "roaming.error.no_connection")
            return
        }
        currentSSID = ssid
        currentBSSID = status.bssid
        currentRSSI = status.rssi ?? 0
        currentChannel = status.channel ?? 0
        currentTxRate = status.txRate ?? 0
        currentPhyMode = status.phyMode
        state = .ready
    }
}
```

- [ ] **Step 4: Replace tick() polling**

Replace the `CWWiFiClient.shared().interface()` call in `tick()` with `roamingProvider.fetchCurrentProbe()`. Replace `pinger.ping()` with `latencyProvider.measure()`.

- [ ] **Step 5: Replace refreshConnectionInfo()**

Use `roamingProvider.fetchCurrentProbe()` + `latencyProvider.measure()`.

- [ ] **Step 6: Write migration test**

Create `WiFiLens/WiFiLensTests/Observation/RoamingMigrationTests.swift`:
```swift
import Testing
@testable import WiFi_Lens

@Suite("Roaming Migration")
struct RoamingMigrationTests {
    @Test("RoamingTestViewModel uses provider instead of CWWiFiClient")
    func usesProvider() async {
        let provider = MockRoamingProbeProvider(result: WiFiCurrentStatus(
            timestamp: Date(), ssid: "Test", bssid: "AA:BB", channel: 36,
            rssi: -50, isConnected: true, isWiFiPowerOn: true
        ))
        let vm = RoamingTestViewModel(roamingProvider: provider)
        vm.checkReadiness()
        // Allow async Task to complete
        try? await Task.sleep(for: .milliseconds(100))
        #expect(vm.state == .ready)
        #expect(vm.currentSSID == "Test")
    }
}
```

- [ ] **Step 7: Add MockRoamingProbeProvider to MockProviders.swift**

```swift
struct MockRoamingProbeProvider: RoamingProbeProviding {
    var result: WiFiCurrentStatus
    func fetchCurrentProbe() async -> WiFiCurrentStatus { result }
}
```

- [ ] **Step 8: Add test to Xcode project, build and test**

- [ ] **Step 9: Commit**

```bash
git add WiFiLens/Sources/WiFiLens/Roaming/RoamingTestViewModel.swift WiFiLens/Tests/WiFiLensTests/Observation/MockProviders.swift WiFiLens/Tests/WiFiLensTests/Observation/RoamingMigrationTests.swift
git commit -m "refactor: migrate roaming test to observation pipeline"
```

---

## Task 3: Migrate Overview Diagnosis to Observation Pipeline

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/App/OverviewView.swift`
- Create: `WiFiLens/WiFiLensTests/Observation/DiagnosticMigrationTests.swift`

**Interfaces:**
- Consumes: `DiagnosticEvaluator` (from Phase 4), `WiFiObservationStore` (from Phase 5)
- Produces: OverviewView reads diagnosis from store instead of computing inline

- [ ] **Step 1: Read current OverviewView.diagnose()**

Read `WiFiLens/Sources/WiFiLens/App/OverviewView.swift` lines 218-295 to understand the inline diagnosis logic.

- [ ] **Step 2: Add store property to OverviewView**

Add `let store: WiFiObservationStore` parameter to OverviewView.

- [ ] **Step 3: Replace diagnose() calls**

Find all calls to `diagnose(wifi)` and replace with reading from store:
```swift
let diagnosis = store.diagnosis ?? DiagnosticResult.unknown
```

- [ ] **Step 4: Remove inline Diagnosis struct and diagnose() method**

Delete the private `Diagnosis` struct (lines 218-223) and the `diagnose(_:)` method (lines 225-295).

- [ ] **Step 5: Write migration test**

Create `WiFiLens/WiFiLensTests/Observation/DiagnosticMigrationTests.swift`:
```swift
import Testing
@testable import WiFi_Lens

@Suite("Diagnostic Migration")
struct DiagnosticMigrationTests {
    @Test("DiagnosticEvaluator produces same result as old inline logic")
    func matchesOldLogic() {
        let status = WiFiCurrentStatus(
            timestamp: Date(), ssid: "Net", bssid: "AA:BB", channel: 36,
            rssi: -45, security: "WPA3", isConnected: true, isWiFiPowerOn: true
        )
        let quality = WiFiQualityResult(level: .good, signalLabel: "Strong", latencyLabel: "Normal", summary: "Good")
        let result = DiagnosticEvaluator.evaluate(currentStatus: status, quality: quality)
        #expect(result.severity == .excellent)
        #expect(result.icon == "star.fill")
    }
}
```

- [ ] **Step 6: Add test to Xcode project, build and test**

- [ ] **Step 7: Commit**

```bash
git add WiFiLens/Sources/WiFiLens/App/OverviewView.swift WiFiLens/Tests/WiFiLensTests/Observation/DiagnosticMigrationTests.swift
git commit -m "refactor: migrate overview diagnosis to observation pipeline"
```

---

## Task 4: Refactor ScannerViewModel Data Acquisition

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/Scanner/ScannerViewModel.swift`
- Modify: `WiFiLens/Sources/WiFiLens/Observation/Pipeline/WiFiObservationPipeline.swift`

**Interfaces:**
- Consumes: `WiFiObservationController`, `WiFiObservationStore` (from Phase 5)
- Produces: ScannerViewModel delegates data acquisition to pipeline, keeps scan loop + charts

- [ ] **Step 1: Read current ScannerViewModel scan loop**

Read `WiFiLens/Sources/WiFiLens/Scanner/ScannerViewModel.swift` lines 260-308 (startScanLoop) and 439-503 (compute methods).

- [ ] **Step 2: Add controller and store to ScannerViewModel**

Add:
```swift
let controller: WiFiObservationController
let store: WiFiObservationStore
```

Update `init()`.

- [ ] **Step 3: Replace computeChannelQualities()**

The scan loop currently calls `computeChannelQualities()` which builds `APInfo` from `lastNetworks` and calls `ChannelQualityCalculator.compute()`. Replace with reading from store:
```swift
// After scan loop receives .networks:
await controller.refreshEnvironmentScan()
// store.channelAnalysis now has the results
```

But we need to keep the scan loop running. The pipeline's `refreshEnvironmentScan()` does a single-shot scan. We need to adapt: the scan loop feeds `WiFiNetwork` arrays, which should be converted to `WiFiEnvironmentSnapshot` and analyzed.

Better approach: keep the scan loop, but after each scan event, use the new analyzers directly:
```swift
// In the scan loop, after receiving networks:
let snapshot = WiFiEnvironmentSnapshot(
    timestamp: Date(),
    interfaceName: interfaceName,
    networks: NetworkObservationAdapter.adaptAll(networks, currentBSSID: currentBSSID)
)
let channelAnalysis = ChannelOccupancyAnalyzer.analyze(
    snapshot: snapshot, currentChannel: currentChannel,
    supportedBands: ["24", "5", "6"], targetAP: targetAP
)
// Store results
```

- [ ] **Step 4: Replace computeChannelRecommendations()**

Replace with:
```swift
let channelRecommendation = ChannelRecommendationEngine.recommend(
    channelAnalysis: channelAnalysis, snapshot: snapshot,
    inferredRegion: inferredRegion, deviceSupportedChannels: deviceSupportedChannels,
    deviceCapabilities: deviceCapabilities
)
```

- [ ] **Step 5: Update store after each scan cycle**

After computing analysis and recommendations, update the store:
```swift
store.channelAnalysis = channelAnalysis
store.channelRecommendation = channelRecommendation
store.latestEnvironmentSnapshot = snapshot
```

- [ ] **Step 6: Remove old computation methods**

Delete `computeChannelQualities()` (lines 439-489) and `computeChannelRecommendations()` (lines 492-503) from ScannerViewModel.

- [ ] **Step 7: Build and test**

```bash
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests
```

- [ ] **Step 8: Commit**

```bash
git add WiFiLens/Sources/WiFiLens/Scanner/ScannerViewModel.swift
git commit -m "refactor: ScannerViewModel uses pipeline analyzers for channel quality"
```

---

## Task 5: Cleanup and Verify

**Files:**
- Verify: All modified files compile and pass tests
- Cleanup: Remove any dead code from migration

- [ ] **Step 1: Full build verification**

```bash
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build
```

- [ ] **Step 2: Full test verification**

```bash
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests
```

- [ ] **Step 3: Verify old code paths are removed or unreachable**

Check that:
- MenuBarStatusViewModel no longer calls NetworkInfoService.fetchAll() directly
- RoamingTestViewModel no longer accesses CWWiFiClient.shared().interface() directly
- OverviewView no longer has inline diagnose() method
- ScannerViewModel no longer has computeChannelQualities() or computeChannelRecommendations()

- [ ] **Step 4: Update docs if needed**

Update `docs/ARCHITECTURE.md` to reflect the new data flow.

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "chore: complete observation pipeline migration, cleanup old code paths"
```

---

## Summary

After these 5 tasks:

| Phase | What changes | Old code removed |
|-------|-------------|-----------------|
| Task 1 | Menu bar reads from store | NetworkInfoService/GatewayPinger direct calls in MenuBarStatusViewModel |
| Task 2 | Roaming test uses provider | CWWiFiClient.shared().interface() in RoamingTestViewModel |
| Task 3 | Overview uses DiagnosticEvaluator | Inline diagnose() in OverviewView |
| Task 4 | ScannerViewModel uses analyzers | computeChannelQualities/Recommendations in ScannerViewModel |
| Task 5 | Cleanup and verification | Dead code removal |

**What ScannerViewModel still owns after migration:**
- WiFiScanner lifecycle (scan loop)
- BandChartViewModel coordination
- SignalHistoryStore
- SSIDColorHasher
- MCPServer
- ThroughputMonitor
- WiFiPowerMonitor
- LocationPermissionManager
- UI state (filter, selection, hidden networks)

These are presentation-layer concerns that belong in the ViewModel, not the data pipeline.
