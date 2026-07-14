# Unified Wi-Fi Observation Pipeline — Design Spec

**Date:** 2026-06-22
**Status:** Superseded (historical design; not the production architecture)
**Scope:** Data layer refactoring — models, providers, analyzers, pipeline, store

> **Superseded:** The additive controller architecture described below is retained for historical context. The production architecture is defined by [Observation Runtime Migration Design](./2026-07-11-observation-runtime-migration-design.md) and implemented through the linked 2026-07-11 runtime migration plans. In particular, `WiFiObservationController` has been removed, `WiFiObservationRuntime` owns the production scan lifecycle, and `WiFiObservationPipeline` is a single-cycle producer.

---

## 1. Problem Statement

Wi-Fi data is currently fetched, parsed, transformed, and evaluated independently in multiple places:

| Location | What it does | File |
|----------|-------------|------|
| `WiFiScanner` actor | CoreWLAN full scan → `[WiFiNetwork]` | `Scanner/WiFiScanner.swift` |
| `NetworkInfoService` | Current connection via `SCDynamicStore` + `CWWiFiClient` → `[NetworkInterfaceInfo]` | `Interfaces/NetworkInfoService.swift` |
| `GatewayPinger` actor | Ping router → `Double?` latency | `Utilities/GatewayPinger.swift` |
| `RoamingTestViewModel` | Direct `CWWiFiClient.shared().interface()` access, own 1s timer, own `GatewayPinger` | `Roaming/RoamingTestViewModel.swift` |
| `ScannerViewModel.applyNetworks()` | Records to `SignalHistoryStore`, builds trend/snapshot dicts, distributes to 3x `BandChartViewModel` | `Scanner/ScannerViewModel.swift:362` |
| `ScannerViewModel.computeChannelQualities()` | Re-parses IE data, builds `APInfo`, calls `ChannelQualityCalculator.compute()` | `Scanner/ScannerViewModel.swift:439` |
| `ScannerViewModel.computeChannelRecommendations()` | Calls `RegulatoryPipeline` then `RecommendationReasonCalculator` | `Scanner/ScannerViewModel.swift:492` |
| `BandChartViewModel.computeScore()` | Per-AP quality score (RSSI 40%, congestion 30%, K/R/V 20%, width 10%) | `Spectrum/BandChartViewModel.swift:179` |
| `ChannelQualityCalculator.compute()` | Per-channel interference scoring + counterfactual recommendation selection | `Channels/ChannelQualityCalculator.swift:195` |
| `OverviewView.diagnose()` | Inline RSSI/channel/security/PHY evaluation → `Diagnosis` | `App/OverviewView.swift:225` |
| `MenuBarStatusViewModel.fetch()` | Independent `NetworkInfoService.fetchAll()` + `GatewayPinger.ping()` | `Pro/MenuBar/MenuBarStatusViewModel.swift:103` |
| `RegulatoryPipeline.computeRecommendations()` | Region inference + regulatory filter — re-parses IE data for country codes | `Regulatory/RegulatoryPipeline.swift:14` |

**Core symptoms:**
1. IE data is parsed 4+ times per scan cycle (applyNetworks, computeChannelQualities, RegulatoryPipeline, ChannelSpanCalculator)
2. Three independent quality evaluation paths produce potentially inconsistent results
3. `ScannerViewModel` is a 535-line monolith owning scanning, parsing, analysis, recommendation, history, charts, regulatory logic, and MCP
4. Menu bar and roaming test are completely independent data islands
5. No formal pipeline — data flows are ad-hoc method calls

---

## 2. Target Data Flow

```
Raw Sources                     Providers                    Pipeline                      Analyzers                     Store + Controller            Consumers
─────────────                   ─────────                    ────────                      ────────                      ────────────────              ─────────
CoreWLAN scan          ──→  WiFiEnvironmentScanProvider  ──┐
NetworkInfoService     ──→  WiFiCurrentConnectionProvider ──┤──→ WiFiObservationPipeline ──→ WiFiQualityEvaluator      ──→ WiFiObservationStore  ──→ Menu Bar
GatewayPinger          ──→  GatewayLatencyProvider       ──┤                          ──→ ChannelOccupancyAnalyzer  ──→ WiFiObservationController ──→ Scanner
CWWiFiClient (roaming) ──→  RoamingProbeProvider         ──┤                          ──→ RegulatoryDomainResolver  ──→                       ──→ Channel Analysis
                                                                       (parse once)   ──→ ChannelRecommendationEngine──→                       ──→ Recommendations
                                                                                         ──→ DiagnosticEvaluator       ──→                       ──→ Diagnostics
                                                                                         ──→ RoamingEventDetector     ──→                       ──→ Reports/Export
                                                                                         ──→ SignalQualityEvaluator   ──→                       ──→ Pro Monitoring
```

**Invariants:**
- IE data is parsed **once** per scanned network per scan cycle, at the provider layer
- Parsed results are stored in `WiFiNetworkObservation.capabilities`; raw IE data may be retained for debugging, export, parser upgrades, and migration
- Normal consumers **must** read from `capabilities` — re-parsing raw IE data is prohibited outside the provider layer
- Quality evaluation is **centralized** — same input always produces same output
- Consumers never call CoreWLAN, GatewayPinger, or NetworkInfoService directly
- Full environment scan is **never** triggered by current-connection refresh

---

## 3. Normalized Model Layer

### 3.1 WiFiCurrentStatus

Replaces `NetworkInterfaceInfo` for Wi-Fi-specific current connection data. Non-Wi-Fi interface fields (ethernet MAC, DNS, subnet) remain in `NetworkInterfaceInfo` for the Interfaces view.

```swift
struct WiFiCurrentStatus: Equatable, Sendable {
    var timestamp: Date
    var interfaceName: String?
    var ssid: String?
    var bssid: String?
    var channel: Int?
    var band: ChannelBand?
    var rssi: Int?
    var noise: Int?
    var txRate: Double?
    var phyMode: String?
    var security: String?
    var routerIP: String?
    var isConnected: Bool
    var isWiFiPowerOn: Bool
    var error: WiFiObservationError?
}
```

**Source:** `NetworkInfoService.fetch()` (Wi-Fi interface only) + `WiFiPowerMonitor` state.
**Used by:** Menu bar, overview, quality evaluation, history sampling, event detection.

### 3.2 WiFiNetworkCapabilities (parsed IE data)

Centralizes IE parsing. One `IEParser.parse()` call per network per scan cycle, stored here.

```swift
struct WiFiNetworkCapabilities: Equatable, Sendable {
    var phyMode: String           // "n"/"ac"/"ax"/"be"
    var channelWidth: Int         // 20/40/80/160
    var supports80211k: Bool
    var supports80211r: Bool
    var supports80211v: Bool
    var supportsWPA3: Bool
    var countryCode: String?
    var isHiddenSSID: Bool
    var mcs: String?
    var nss: String?
    var security: String?
}
```

**Source:** `IEParser.parse(data:)` — called once per network in the environment scan provider.
**Used by:** ChannelSpanCalculator, ChannelQualityCalculator, RegulatoryDomainResolver, chart rendering, security display.
**Rule:** Consumers must read from `capabilities`. Re-parsing raw IE data outside the provider layer is prohibited.

### 3.3 WiFiNetworkObservation

Replaces `WiFiNetwork` for the normalized pipeline. Holds parsed capabilities inline.

```swift
struct WiFiNetworkObservation: Identifiable, Equatable, Sendable {
    var id: String               // BSSID preferred; fallback: scan-local stable ID (see below)
    var ssid: String?
    var bssid: String
    var rssi: Int
    var channel: WiFiChannel
    var isIBSS: Bool
    var capabilities: WiFiNetworkCapabilities  // parsed once, stored here
    var rawIEData: Data?          // retained for debugging, export, parser upgrades, migration
    var isCurrentNetwork: Bool
}
```

**ID strategy:**
- **Primary:** BSSID (stable across scans for the same AP)
- **Fallback when BSSID unavailable:** Scan-local stable ID — a deterministic hash of SSID + channel number + security + PHY mode within a single scan cycle. This is explicitly **not** stable across scans; it prevents duplicate entries within one snapshot.
- **Prohibited:** Using RSSI in the ID (RSSI changes frequently and makes the ID unstable).

**Source:** `WiFiEnvironmentScanProvider.scanEnvironment()`.
**Used by:** Band charts, channel analysis, recommendations, table display, MCP.
**Note:** `rawIEData` is retained but normal consumers must not parse it directly. It exists for debugging, export, parser upgrades, and migration bridging.

### 3.4 WiFiEnvironmentSnapshot

One complete scan result.

```swift
struct WiFiEnvironmentSnapshot: Equatable, Sendable {
    var timestamp: Date
    var interfaceName: String?
    var networks: [WiFiNetworkObservation]
    var scanDurationMs: Double?
    var error: WiFiObservationError?
}
```

**Source:** `WiFiEnvironmentScanProvider.scanEnvironment()`.
**Used by:** Channel analysis, recommendations, band charts, spectrum, export.

### 3.5 GatewayLatencyResult

```swift
struct GatewayLatencyResult: Equatable, Sendable {
    var timestamp: Date
    var routerIP: String?
    var latencyMs: Double?
    var packetLoss: Double?
    var error: WiFiObservationError?
}
```

**Source:** `GatewayLatencyProvider.measure()`.
**Used by:** Quality evaluation, menu bar, roaming, reports.

### 3.6 WiFiObservation (aggregated refresh result)

One observation = one pipeline refresh cycle.

```swift
struct WiFiObservation: Equatable, Sendable {
    var timestamp: Date
    var currentStatus: WiFiCurrentStatus?
    var environmentSnapshot: WiFiEnvironmentSnapshot?
    var gatewayLatency: GatewayLatencyResult?
    var quality: WiFiQualityResult?
    var channelAnalysis: [ChannelQuality]?
    var channelRecommendation: [ChannelRecommendation]?
    var diagnosis: DiagnosticResult?
    var events: [WiFiObservationEvent]
    var errors: [WiFiObservationError]
}
```

### 3.7 WiFiQualityResult

Replaces the ad-hoc quality logic scattered across `MenuBarStatusViewModel.qualityLevel`, `BandChartViewModel.computeScore()`, and `OverviewView.diagnose()`.

```swift
struct WiFiQualityResult: Equatable, Sendable {
    var level: WiFiQualityLevel
    var signalLabel: String
    var latencyLabel: String
    var summary: String
}

enum WiFiQualityLevel: String, Sendable {
    case good, fair, poor, unknown
}
```

**Source:** `WiFiQualityEvaluator.evaluate()`.
**Used by:** Menu bar, overview, history, reports.

### 3.8 DiagnosticResult

Replaces `OverviewView.diagnose()`.

```swift
struct DiagnosticResult: Equatable, Sendable {
    var icon: String
    var title: String
    var message: String
    var severity: DiagnosticSeverity
}

enum DiagnosticSeverity: Sendable {
    case excellent, warning, critical, ok
}
```

### 3.9 WiFiObservationEvent

Replaces ad-hoc event detection in `RoamingTestViewModel` and `ConnectionRecorder`.

```swift
struct WiFiObservationEvent: Identifiable, Equatable, Sendable {
    let id: UUID
    var timestamp: Date
    var type: EventType
    var details: String

    enum EventType: Sendable {
        case bssidChange(from: String, to: String)
        case disconnection
        case reconnection
        case signalDrop(from: Int, to: Int)
        case latencySpike(from: Double, to: Double)
        case channelChange(from: Int, to: Int)
    }
}
```

### 3.10 WiFiObservationError

```swift
enum WiFiObservationError: Error, Equatable, Sendable {
    case noWiFiInterface
    case wifiPowerOff
    case noWiFiConnection
    case missingSSID
    case missingBSSID
    case missingRouterIP
    case locationPermissionRequired
    case currentStatusFetchFailed(String)
    case environmentScanFailed(String)
    case gatewayPingFailed(String)
    case analyzerFailed(String)
}
```

---

## 4. Provider Layer

Providers wrap raw system APIs. They return normalized models. They do not save, analyze, or format.

### 4.1 WiFiCurrentConnectionProvider

```swift
protocol WiFiCurrentConnectionProviding {
    func fetchCurrentStatus() async -> WiFiCurrentStatus
}
```

**Wraps:** `NetworkInfoService.fetch()` + `WiFiPowerMonitor.currentState`.
**Does NOT:** scan environment, ping gateway, compute quality.

### 4.2 WiFiEnvironmentScanProvider

```swift
protocol WiFiEnvironmentScanProviding {
    func scanEnvironment() async -> WiFiEnvironmentSnapshot
}
```

**Wraps:** `WiFiScanner.startScanning()` (single-shot) + `IEParser.parse()` (once per network).
**Does NOT:** ping gateway, evaluate quality, compute recommendations.
**Key invariant:** IE parsing happens here. `WiFiNetworkObservation.capabilities` is populated at this layer.

### 4.3 GatewayLatencyProvider

```swift
protocol GatewayLatencyProviding {
    func measure(routerIP: String?) async -> GatewayLatencyResult
}
```

**Wraps:** `GatewayPinger.ping()`.

### 4.4 RoamingProbeProvider

```swift
protocol RoamingProbeProviding {
    func fetchCurrentProbe() async -> WiFiCurrentStatus
}
```

**Wraps:** `CWWiFiClient.shared().interface()` — the direct access currently in `RoamingTestViewModel`.
**Purpose:** High-frequency (1-second) current-status sampling for roaming tests. Uses the same `WiFiCurrentStatus` model as `WiFiCurrentConnectionProvider`.
**Constraint:** Must NOT trigger environment scan. This is current-connection sampling only.
**Differentiation from WiFiCurrentConnectionProvider:** May use a lighter/faster path (skip router IP resolution, skip non-essential fields) optimized for 1-second polling during active roaming tests.

---

## 5. Analyzer / Evaluator Layer

Analyzers take normalized model inputs and produce normalized model outputs. They are pure functions (or stateless objects). They do not fetch data or save results.

### 5.1 WiFiQualityEvaluator

**Replaces:** `MenuBarStatusViewModel.qualityLevel` (L20-25), `BandChartViewModel.computeScore()` (L179-191), and the signal-strength portion of `OverviewView.diagnose()`.

```swift
enum WiFiQualityEvaluator {
    static func evaluate(
        currentStatus: WiFiCurrentStatus,
        gatewayLatency: GatewayLatencyResult?
    ) -> WiFiQualityResult
}
```

**Inputs:** `WiFiCurrentStatus` + `GatewayLatencyResult`.
**Output:** `WiFiQualityResult` with level, signal label, latency label, summary.

### 5.2 ChannelOccupancyAnalyzer

**Replaces:** `ScannerViewModel.computeChannelQualities()` (L439-489) which manually builds `APInfo` and calls `ChannelQualityCalculator`.

```swift
enum ChannelOccupancyAnalyzer {
    static func analyze(
        snapshot: WiFiEnvironmentSnapshot,
        currentChannel: Int?,
        supportedBands: Set<String>,
        targetAP: ChannelQualityCalculator.TargetAP?
    ) -> [ChannelQuality]
}
```

**Key change:** Consumes `WiFiNetworkObservation.capabilities` instead of re-parsing `ieData`. The `APInfo` construction (channel width extraction via `capabilities.channelWidth`, span calculation) moves here. Raw `rawIEData` is available but must not be re-parsed.

### 5.3 RegulatoryDomainResolver

**Replaces:** `RegulatoryPipeline` as an owned class in `ScannerViewModel`. Region inference remains a separate concern.

```swift
enum RegulatoryDomainResolver {
    static func resolve(
        userOverride: RegulatoryDomain?,
        userDefaultsOverride: RegulatoryDomain?,
        systemLocale: Locale,
        supportedChannelsRaw: [(Int, Int)],
        apCountryCodes: [String]
    ) -> RegionInferenceResult
}
```

**Responsibilities:**
- Multi-source region inference (locale, channel fingerprint, AP beacons, user override)
- Conflict resolution with confidence scoring
- Returns `RegionInferenceResult` for downstream regulatory filtering

**Does NOT:** filter channels, apply device compatibility, or compute recommendations. Those remain in `ChannelRecommendationEngine`.

### 5.4 ChannelRecommendationEngine

**Replaces:** `ScannerViewModel.computeChannelRecommendations()` (L492-503).

```swift
enum ChannelRecommendationEngine {
    static func recommend(
        channelAnalysis: [ChannelQuality],
        snapshot: WiFiEnvironmentSnapshot,
        inferredRegion: RegionInferenceResult,
        deviceSupportedChannels: Set<String>,
        deviceCapabilities: DevicePHYCapabilities
    ) -> [ChannelRecommendation]
}
```

**Responsibilities:**
- Apply regulatory filter (`RegulatoryFilter.apply()`)
- Apply device compatibility check
- Apply user overrides
- Compute recommendation reasons (`RecommendationReasonCalculator`)
- Sort by classification tier

**Dependencies:** Takes `RegionInferenceResult` from `RegulatoryDomainResolver` (not own region inference).

### 5.4 DiagnosticEvaluator

**Replaces:** `OverviewView.diagnose()` (L225-295).

```swift
enum DiagnosticEvaluator {
    static func evaluate(
        currentStatus: WiFiCurrentStatus,
        quality: WiFiQualityResult?,
        channelAnalysis: [ChannelQuality]?,
        channelRecommendations: [ChannelRecommendation]?
    ) -> DiagnosticResult
}
```

### 5.5 RoamingEventDetector

**Replaces:** Ad-hoc BSSID tracking in `RoamingTestViewModel` (L46-50, L99+).

```swift
enum RoamingEventDetector {
    static func detect(
        previous: WiFiCurrentStatus?,
        current: WiFiCurrentStatus
    ) -> [WiFiObservationEvent]
}
```

---

## 6. Pipeline Layer

The pipeline orchestrates providers and analyzers. It has three refresh modes.

### 6.1 WiFiObservationPipeline

```swift
protocol WiFiObservationPipelining {
    func refreshCurrentConnection() async -> WiFiObservation
    func refreshEnvironmentScan() async -> WiFiObservation
    func refreshFullObservation() async -> WiFiObservation
}
```

**refreshCurrentConnection():**
1. `WiFiCurrentConnectionProvider.fetchCurrentStatus()` → `WiFiCurrentStatus`
2. `GatewayLatencyProvider.measure(routerIP:)` → `GatewayLatencyResult`
3. `WiFiQualityEvaluator.evaluate()` → `WiFiQualityResult`
4. Returns `WiFiObservation` with currentStatus + gatewayLatency + quality
5. Does NOT scan environment

**refreshEnvironmentScan():**
1. `WiFiEnvironmentScanProvider.scanEnvironment()` → `WiFiEnvironmentSnapshot`
2. `ChannelOccupancyAnalyzer.analyze()` → `[ChannelQuality]`
3. `ChannelRecommendationEngine.recommend()` → `[ChannelRecommendation]`
4. Returns `WiFiObservation` with environmentSnapshot + channelAnalysis + channelRecommendation
5. May include currentStatus from latest cached value (not re-fetched)
6. Does NOT ping gateway

**refreshFullObservation():**
1. All of refreshCurrentConnection()
2. All of refreshEnvironmentScan()
3. `DiagnosticEvaluator.evaluate()` → `DiagnosticResult`
4. Returns complete `WiFiObservation`

---

## 7. Store + Controller Layer

### 7.1 WiFiObservationStore

The store holds published state. It does not orchestrate refreshes.

```swift
@MainActor
final class WiFiObservationStore: ObservableObject {
    @Published var currentStatus: WiFiCurrentStatus?
    @Published var gatewayLatency: GatewayLatencyResult?
    @Published var quality: WiFiQualityResult?

    @Published var latestEnvironmentSnapshot: WiFiEnvironmentSnapshot?
    @Published var channelAnalysis: [ChannelQuality]?
    @Published var channelRecommendation: [ChannelRecommendation]?

    @Published var diagnosis: DiagnosticResult?
    @Published var recentEvents: [WiFiObservationEvent]

    @Published var isRefreshingCurrent: Bool
    @Published var isScanningEnvironment: Bool
    @Published var lastUpdated: Date?
    @Published var errors: [WiFiObservationError]
}
```

**Responsibilities:**
- Hold `@Published` properties for UI consumption
- Track loading states
- Maintain recent events buffer
- Deduplicate events

**Does NOT:**
- Call pipeline, providers, or analyzers
- Call CoreWLAN, GatewayPinger, or NetworkInfoService directly
- Own `BandChartViewModel`

### 7.2 WiFiObservationController

The controller orchestrates pipeline refreshes and applies results to the store. Separating controller from store keeps the store as a pure state container.

```swift
@MainActor
final class WiFiObservationController {
    let pipeline: WiFiObservationPipelining
    let store: WiFiObservationStore

    func refreshCurrentConnection() async {
        store.isRefreshingCurrent = true
        let observation = await pipeline.refreshCurrentConnection()
        store.apply(observation)
        store.isRefreshingCurrent = false
    }

    func refreshEnvironmentScan() async {
        store.isScanningEnvironment = true
        let observation = await pipeline.refreshEnvironmentScan()
        store.apply(observation)
        store.isScanningEnvironment = false
    }

    func refreshFullObservation() async {
        store.isRefreshingCurrent = true
        store.isScanningEnvironment = true
        let observation = await pipeline.refreshFullObservation()
        store.apply(observation)
        store.isRefreshingCurrent = false
        store.isScanningEnvironment = false
    }
}
```

### 7.3 SignalHistoryStore Ownership

| Scope | Ownership | Notes |
|-------|-----------|-------|
| UI short-term chart history (animation, trend arrows) | Stays in `ScannerViewModel` or `BandChartViewModel` | UI concern — drives 60fps animation, not persistent data |
| Pro monitoring history (samples, events) | Moves to persistence layer via `WiFiObservationStore` | `historySamples` and `recentEvents` in store; `ConnectionRecorder` replaced by store-based sampling |

**Rule:** Short-term in-memory signal history for chart rendering may remain local to the view layer during the initial migration. Pro long-term monitoring history must go through the observation store and be persisted by the Pro recording infrastructure.

---

## 8. ScannerViewModel Decomposition

`ScannerViewModel` (535 lines) currently owns:
- WiFiScanner lifecycle
- Location permission
- SignalHistoryStore
- 3x BandChartViewModel
- RegulatoryPipeline
- Channel quality computation
- Channel recommendation computation
- MCP server data provider
- ThroughputMonitor
- WiFiPowerMonitor
- UI state (accessState, hiddenBSSIDs, filterQuery, selectedNetworkID)

**After refactoring, ScannerViewModel becomes:**

```swift
@MainActor
@Observable
final class ScannerViewModel {
    let controller: WiFiObservationController
    let store: WiFiObservationStore

    // UI state only
    var hiddenBSSIDs: Set<String>
    var hiddenBands: Set<String>
    var hideHiddenSSIDs: Bool
    var globalFilterQuery: String
    var selectedNetworkID: String?

    // Derived from store (not owned)
    var band24: BandChartViewModel
    var band5: BandChartViewModel
    var band6: BandChartViewModel
}
```

**What moves out:**
| Responsibility | Destination |
|---------------|-------------|
| `WiFiScanner` lifecycle | `WiFiEnvironmentScanProvider` |
| `NetworkInfoService` calls | `WiFiCurrentConnectionProvider` |
| `GatewayPinger` calls | `GatewayLatencyProvider` |
| `computeChannelQualities()` | `ChannelOccupancyAnalyzer` |
| `computeChannelRecommendations()` | `ChannelRecommendationEngine` |
| `SignalHistoryStore` | Stays in ViewModel (UI concern — animation, trends) or moves to store |
| `MCPServer` data provider | Reads from `WiFiObservationStore` |
| `ThroughputMonitor` | Independent — stays (not Wi-Fi observation data) |
| `WiFiPowerMonitor` | Used by providers, state propagated to store |

**What stays:**
- UI state (filter, selection, hidden networks)
- BandChartViewModel coordination (animation, rendering state)
- `applyNetworks()` → becomes a reaction to store updates, distributing to band VMs

---

## 9. Menu Bar Integration

**Current:** `MenuBarStatusViewModel.fetch()` calls `NetworkInfoService.fetchAll()` + `GatewayPinger.ping()` independently, computes `qualityLevel` inline.

**After:**
```swift
@MainActor
final class MenuBarStatusViewModel: ObservableObject {
    let controller: WiFiObservationController
    let store: WiFiObservationStore  // reads published state from here

    func fetch() async {
        await controller.refreshCurrentConnection()
        // store.currentStatus, store.quality, store.gatewayLatency update automatically
    }
}
```

- `qualityLevel` → reads `store.quality?.level`
- `signalLabel` → reads `store.quality?.signalLabel`
- `latencyLabel` → reads `store.quality?.latencyLabel`
- No direct `NetworkInfoService` or `GatewayPinger` calls
- Refresh interval: 30–60s for current connection, NOT full scan

---

## 10. Roaming Test Integration

**Current:** `RoamingTestViewModel` directly accesses `CWWiFiClient.shared().interface()`, owns its own `GatewayPinger`, tracks BSSID changes with manual state.

**After:**
```swift
@MainActor
@Observable
final class RoamingTestViewModel {
    let roamingProvider: RoamingProbeProviding  // or pipeline with 1s sampling
    let eventDetector: RoamingEventDetector.Type

    // State
    var segments: [RoamingSegment]
    var transitions: [APTransitionEvent]
    var elapsedTime: TimeInterval

    // Uses WiFiCurrentStatus from provider, detects events via RoamingEventDetector
}
```

- BSSID tracking → `RoamingEventDetector.detect(previous:current:)`
- Gateway latency → `GatewayLatencyProvider` (same as pipeline)
- No direct `CWWiFiClient` access
- Roaming events become `WiFiObservationEvent`

---

## 11. IE Parsing Centralization

**Current problem:** `IEParser.parse(data:)` is called in:
1. `ScannerViewModel.applyNetworks()` → `makeSnapshot()` (L369)
2. `ScannerViewModel.computeChannelQualities()` (L453)
3. `RegulatoryPipeline.computeRecommendations()` (L21)
4. `ChannelSpanCalculator.toSeriesData()` (implicit via `WiFiNetwork`)

**After:** `IEParser.parse()` is called **once** per network in `WiFiEnvironmentScanProvider.scanEnvironment()`. The result is stored in `WiFiNetworkObservation.capabilities`. All downstream consumers read from `capabilities`:

| Consumer | Reads from capabilities |
|----------|----------------------|
| `ChannelOccupancyAnalyzer` | `phyMode`, `channelWidth` for APInfo construction |
| `ChannelSpanCalculator.toSeriesData()` | `phyMode`, `channelWidth`, `supports80211k/r/v`, `countryCode` |
| `RegulatoryDomainResolver` | `countryCode` for region inference |
| Band chart security display | `security` |
| Table display | `phyMode`, `channelWidth`, `mcs`, `nss`, `supports80211k/r/v`, `countryCode` |

---

## 12. Quality Evaluation Centralization

**Current three paths:**

| Path | Location | Formula |
|------|----------|---------|
| Per-AP score | `BandChartViewModel.computeScore()` | RSSI 40% + congestion 30% + K/R/V 20% + width 10% |
| Per-channel score | `ChannelQualityCalculator.compute()` | Interference model with overlap factors |
| Overview diagnosis | `OverviewView.diagnose()` | RSSI thresholds + channel score + security + PHY |

**After:**
- `WiFiQualityEvaluator` → replaces menu bar `qualityLevel` + overview signal/latency judgment
- `ChannelOccupancyAnalyzer` → replaces `ScannerViewModel.computeChannelQualities()` (wraps `ChannelQualityCalculator`)
- `DiagnosticEvaluator` → replaces `OverviewView.diagnose()`
- `BandChartViewModel.computeScore()` → **keeps its per-AP formula** (it's chart-specific visual scoring, not a system-wide quality judgment)

---

## 13. Refresh Mode Constraints

| Mode | Triggers | Providers called | Analyzers called |
|------|----------|-----------------|-----------------|
| `refreshCurrentConnection` | Menu bar open, manual refresh, background sampling, overview | CurrentConnection + GatewayLatency | QualityEvaluator |
| `refreshEnvironmentScan` | Scanner page open, manual scan, channel analysis, recommendation | EnvironmentScan | ChannelOccupancy + ChannelRecommendation |
| `refreshFullObservation` | Full diagnosis, report export, diagnostic page | All providers | All analyzers |

**Hard rule:** `refreshCurrentConnection` must never implicitly trigger a full environment scan. The menu bar's 30s timer calls `refreshCurrentConnection` only.

---

## 14. OSS / Pro Boundary

| Component | OSS | Pro |
|-----------|-----|-----|
| Models | ✓ | ✓ |
| Providers | ✓ | ✓ |
| Pipeline | ✓ | ✓ |
| Analyzers | ✓ | ✓ |
| Store | ✓ | ✓ |
| Real-time scan/analysis | ✓ | ✓ |
| Menu bar monitor | — | ✓ |
| Background sampling (5min) | — | ✓ |
| History persistence | — | ✓ |
| Trend charts | — | ✓ |
| Event timeline | — | ✓ |
| Report export | ✓ (basic) | ✓ (enhanced) |

---

## 15. Migration Phases

### Phase 1: Add normalized models
- Add `WiFiCurrentStatus`, `WiFiNetworkCapabilities`, `WiFiNetworkObservation`, `WiFiEnvironmentSnapshot`, `GatewayLatencyResult`, `WiFiObservation`, `WiFiQualityResult`, `DiagnosticResult`, `WiFiObservationEvent`, `WiFiObservationError`
- Add adapters: `NetworkInterfaceInfo` → `WiFiCurrentStatus`, `WiFiNetwork` → `WiFiNetworkObservation`
- **No existing code changes.** Old code compiles and works via adapters.

### Phase 2: Centralize IE parsing
- Add `WiFiNetworkCapabilities` to `WiFiEnvironmentScanProvider`
- `WiFiNetworkObservation` carries parsed capabilities
- `ChannelOccupancyAnalyzer` consumes `capabilities` instead of raw `ieData`
- `RegulatoryPipeline` consumes `capabilities.countryCode` instead of re-parsing
- `ChannelSpanCalculator.toSeriesData()` accepts `WiFiNetworkObservation` (or adapter)
- **Old `WiFiNetwork` with `ieData` still exists.** Adapter bridges both paths.

### Phase 3: Add providers
- `WiFiCurrentConnectionProvider` wrapping `NetworkInfoService`
- `WiFiEnvironmentScanProvider` wrapping `WiFiScanner` + IE parsing
- `GatewayLatencyProvider` wrapping `GatewayPinger`
- `RoamingProbeProvider` wrapping `CWWiFiClient`
- **Old direct calls still work.** Providers are additive.

### Phase 4: Add analyzers
- `WiFiQualityEvaluator` (new)
- `ChannelOccupancyAnalyzer` wrapping `ChannelQualityCalculator`
- `RegulatoryDomainResolver` replacing `RegulatoryPipeline` ownership
- `ChannelRecommendationEngine` using `RegulatoryDomainResolver` output + `RegulatoryFilter` + `RecommendationReasonCalculator`
- `DiagnosticEvaluator` (new)
- `RoamingEventDetector` (new)
- **Old computation still works.** Analyzers are additive.

### Phase 5: Add pipeline + controller + store
- `WiFiObservationPipeline` implementing three refresh modes
- `WiFiObservationController` orchestrating pipeline → store flow
- `WiFiObservationStore` holding latest observation state
- **Pipeline/controller not yet consumed by any UI.** Additive.

### Phase 6: Migrate menu bar
- `MenuBarStatusViewModel` reads from store instead of calling providers directly
- `qualityLevel` / `signalLabel` / `latencyLabel` read from `store.quality`
- Remove direct `NetworkInfoService` and `GatewayPinger` calls from menu bar
- **Main window unchanged.**

### Phase 7: Migrate scanner
- `ScannerViewModel` uses `WiFiObservationController` for data acquisition
- `computeChannelQualities()` and `computeChannelRecommendations()` removed
- `applyNetworks()` becomes a reaction to `store.latestEnvironmentSnapshot` changes
- `RegulatoryPipeline` ownership removed from ScannerViewModel
- **Behavior equivalent.** Same scan → analyze → display flow, just routed through pipeline.

### Phase 8: Migrate roaming test
- `RoamingTestViewModel` uses `RoamingProbeProvider` + `RoamingEventDetector`
- Remove direct `CWWiFiClient.shared().interface()` calls
- Remove owned `GatewayPinger` instance
- **Behavior equivalent.**

### Phase 9: Migrate diagnostics / reports / export
- `OverviewView.diagnose()` → `DiagnosticEvaluator`
- Report data reads from store
- Export reads from store + snapshots
- **Behavior equivalent.**

### Phase 10: Cleanup
- Remove `WiFiNetwork` (replaced by `WiFiNetworkObservation`)
- Remove `RegulatoryPipeline` class (replaced by `RegulatoryDomainResolver` + `ChannelRecommendationEngine`)
- Remove old adapter code
- Update MCP server to read from store
- **Keep `NetworkInfoService.fetchAll()`** — still needed by `InterfacesView` for non-Wi-Fi interface information (ethernet, virtual adapters, DNS, subnet). Only remove direct Wi-Fi status usage from menu bar/scanner/diagnostics.

---

## 16. Key Prohibitions

- Do NOT create two separate stores (MenuBarStore + ScannerStore)
- Do NOT let menu bar call CoreWLAN or NetworkInfoService directly
- Do NOT let scanner page call CoreWLAN directly
- Do NOT let View compute channel recommendations
- Do NOT let ViewModel duplicate quality judgment logic
- Do NOT put full environment scan in a background 30s timer
- Do NOT create a monolithic AnyDataStore without semantic properties
- Do NOT rewrite all UI in Phase 1
- Do NOT break existing OSS real-time analysis capability
- Do NOT remove `WiFiNetwork` until Phase 10 (all consumers migrated)
- Do NOT re-parse raw IE data in consumers — use `WiFiNetworkObservation.capabilities`
- Do NOT use RSSI in `WiFiNetworkObservation.id` (unstable across scans)
- Do NOT absorb all regulatory logic into `ChannelRecommendationEngine` — keep `RegulatoryDomainResolver` separate
- Do NOT make `WiFiObservationStore` orchestrate refreshes — use `WiFiObservationController`
- Do NOT remove `NetworkInfoService.fetchAll()` globally — keep for `InterfacesView`

---

## 17. Testing Strategy

### Golden Fixture Tests (before deleting old paths)

Before any old code path is removed, golden fixture tests must compare old vs new behavior:

| Fixture | Old path | New path | Assertion |
|---------|----------|----------|-----------|
| Channel quality scoring | `ChannelQualityCalculator.compute()` with known `[APInfo]` | `ChannelOccupancyAnalyzer.analyze()` with equivalent `WiFiNetworkObservation` | Identical `[ChannelQuality]` output |
| Channel recommendation | `RegulatoryPipeline.computeRecommendations()` | `ChannelRecommendationEngine.recommend()` + `RegulatoryDomainResolver.resolve()` | Identical `[ChannelRecommendation]` output |
| Chart series data | `ChannelSpanCalculator.toSeriesData()` with `WiFiNetwork` | `ChannelSpanCalculator.toSeriesData()` with `WiFiNetworkObservation` | Identical `[ChartSeriesData]` output |
| Diagnostics | `OverviewView.diagnose()` with `NetworkInterfaceInfo` | `DiagnosticEvaluator.evaluate()` with `WiFiCurrentStatus` | Identical `Diagnosis` output |
| IE parsing | `IEParser.parse(data:)` directly | `WiFiNetworkCapabilities` from provider | Identical `IEData` fields |

### Per-Phase Verification

- **Phase 1:** New model types compile. Adapter tests verify round-trip conversion.
- **Phase 2:** IE parsing produces identical results. Golden fixture tests pass.
- **Phase 3:** Provider tests mock system APIs, verify normalized output.
- **Phase 4:** Analyzer tests verify same input → same output as old paths. Golden fixture tests pass.
- **Phase 5:** Pipeline integration tests verify refresh modes produce correct `WiFiObservation` subsets.
- **Phase 6-9:** UI behavioral equivalence — existing UI tests (if any) pass. Manual verification of menu bar, scanner, roaming.
- **Phase 10:** Compilation check — no references to removed types (except `NetworkInfoService.fetchAll()` which remains for Interfaces view).
