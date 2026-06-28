# Unified Wi-Fi Observation Pipeline — Implementation Plan (Phases 1–5)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add normalized observation models, providers, analyzers, pipeline, controller, and store — all additive, no existing code removed or changed.

**Architecture:** Introduce a parallel data layer alongside existing code. New types (`WiFiCurrentStatus`, `WiFiNetworkObservation`, etc.) coexist with old types (`NetworkInterfaceInfo`, `WiFiNetwork`). Adapters bridge old → new. Existing UI continues unchanged until Phase 6+.

**Tech Stack:** Swift 6.0, SwiftUI, @Observable, CoreWLAN, Swift Testing (`@Test`, `#expect()`)

## Global Constraints

- macOS 14+, Swift 6.0
- Tests: `xcodebuild ... -only-testing:WiFiLensTests`
- New `.swift` files must be added to both `WiFiLens` and `WiFiLensPro` PBXSourcesBuildPhase
- All new types must be `Sendable` (data crosses actor boundaries)
- No comments in code unless user requests them
- Existing code must compile and pass tests after every task

## File Structure

### New Files (Phase 1 — Models)

| File | Responsibility |
|------|---------------|
| `WiFiLens/Sources/WiFiLens/Observation/Models/WiFiCurrentStatus.swift` | Current Wi-Fi connection state |
| `WiFiLens/Sources/WiFiLens/Observation/Models/WiFiNetworkCapabilities.swift` | Parsed IE data container |
| `WiFiLens/Sources/WiFiLens/Observation/Models/WiFiNetworkObservation.swift` | Single scanned network observation |
| `WiFiLens/Sources/WiFiLens/Observation/Models/WiFiEnvironmentSnapshot.swift` | Complete scan result |
| `WiFiLens/Sources/WiFiLens/Observation/Models/GatewayLatencyResult.swift` | Ping latency result |
| `WiFiLens/Sources/WiFiLens/Observation/Models/WiFiObservation.swift` | Aggregated refresh result |
| `WiFiLens/Sources/WiFiLens/Observation/Models/WiFiQualityResult.swift` | Quality evaluation result |
| `WiFiLens/Sources/WiFiLens/Observation/Models/DiagnosticResult.swift` | Diagnostic evaluation result |
| `WiFiLens/Sources/WiFiLens/Observation/Models/WiFiObservationEvent.swift` | Roaming/connection events |
| `WiFiLens/Sources/WiFiLens/Observation/Models/WiFiObservationError.swift` | Error types |
| `WiFiLens/Sources/WiFiLens/Observation/Models/ObservationModels.swift` | Re-exports all models (convenience) |

### New Files (Phase 2 — IE Adapter)

| File | Responsibility |
|------|---------------|
| `WiFiLens/Sources/WiFiLens/Observation/Adapters/NetworkObservationAdapter.swift` | `WiFiNetwork` → `WiFiNetworkObservation` conversion |

### New Files (Phase 3 — Providers)

| File | Responsibility |
|------|---------------|
| `WiFiLens/Sources/WiFiLens/Observation/Providers/WiFiCurrentConnectionProvider.swift` | Wraps `NetworkInfoService` → `WiFiCurrentStatus` |
| `WiFiLens/Sources/WiFiLens/Observation/Providers/WiFiEnvironmentScanProvider.swift` | Wraps `WiFiScanner` + IE parsing → `WiFiEnvironmentSnapshot` |
| `WiFiLens/Sources/WiFiLens/Observation/Providers/GatewayLatencyProvider.swift` | Wraps `GatewayPinger` → `GatewayLatencyResult` |
| `WiFiLens/Sources/WiFiLens/Observation/Providers/RoamingProbeProvider.swift` | Wraps `CWWiFiClient` direct access → `WiFiCurrentStatus` |

### New Files (Phase 4 — Analyzers)

| File | Responsibility |
|------|---------------|
| `WiFiLens/Sources/WiFiLens/Observation/Analyzers/WiFiQualityEvaluator.swift` | `WiFiCurrentStatus` + `GatewayLatencyResult` → `WiFiQualityResult` |
| `WiFiLens/Sources/WiFiLens/Observation/Analyzers/ChannelOccupancyAnalyzer.swift` | `WiFiEnvironmentSnapshot` → `[ChannelQuality]` |
| `WiFiLens/Sources/WiFiLens/Observation/Analyzers/RegulatoryDomainResolver.swift` | Region inference (replaces `RegulatoryPipeline` ownership) |
| `WiFiLens/Sources/WiFiLens/Observation/Analyzers/ChannelRecommendationEngine.swift` | `[ChannelQuality]` + regulatory → `[ChannelRecommendation]` |
| `WiFiLens/Sources/WiFiLens/Observation/Analyzers/DiagnosticEvaluator.swift` | `WiFiCurrentStatus` + quality + channels → `DiagnosticResult` |
| `WiFiLens/Sources/WiFiLens/Observation/Analyzers/RoamingEventDetector.swift` | `WiFiCurrentStatus` diff → `[WiFiObservationEvent]` |

### New Files (Phase 5 — Pipeline + Store + Controller)

| File | Responsibility |
|------|---------------|
| `WiFiLens/Sources/WiFiLens/Observation/Pipeline/WiFiObservationPipeline.swift` | Three refresh modes orchestrating providers + analyzers |
| `WiFiLens/Sources/WiFiLens/Observation/Store/WiFiObservationStore.swift` | `@Published` state container |
| `WiFiLens/Sources/WiFiLens/Observation/Controller/WiFiObservationController.swift` | Pipeline → Store orchestration |

### New Files (Tests)

| File | Responsibility |
|------|---------------|
| `WiFiLens/WiFiLensTests/Observation/ModelsTests.swift` | Model equality, ID strategy, adapter round-trip |
| `WiFiLens/WiFiLensTests/Observation/ProviderTests.swift` | Provider output structure (mocked) |
| `WiFiLens/WiFiLensTests/Observation/AnalyzerTests.swift` | Analyzer correctness (golden fixtures) |
| `WiFiLens/WiFiLensTests/Observation/PipelineTests.swift` | Pipeline refresh mode verification |
| `WiFiLens/WiFiLensTests/Observation/ControllerTests.swift` | Controller → Store flow |

---

## Task 1: Add observation model types

**Files:**
- Create: `WiFiLens/Sources/WiFiLens/Observation/Models/WiFiObservationError.swift`
- Create: `WiFiLens/Sources/WiFiLens/Observation/Models/WiFiCurrentStatus.swift`
- Create: `WiFiLens/Sources/WiFiLens/Observation/Models/WiFiNetworkCapabilities.swift`
- Create: `WiFiLens/Sources/WiFiLens/Observation/Models/WiFiNetworkObservation.swift`
- Create: `WiFiLens/Sources/WiFiLens/Observation/Models/WiFiEnvironmentSnapshot.swift`
- Create: `WiFiLens/Sources/WiFiLens/Observation/Models/GatewayLatencyResult.swift`
- Create: `WiFiLens/Sources/WiFiLens/Observation/Models/WiFiQualityResult.swift`
- Create: `WiFiLens/Sources/WiFiLens/Observation/Models/DiagnosticResult.swift`
- Create: `WiFiLens/Sources/WiFiLens/Observation/Models/WiFiObservationEvent.swift`
- Create: `WiFiLens/Sources/WiFiLens/Observation/Models/WiFiObservation.swift`
- Create: `WiFiLens/WiFiLensTests/Observation/ModelsTests.swift`

**Interfaces:**
- Consumes: `ChannelBand` (existing), `WiFiChannel` (existing)
- Produces: All observation model types used by every subsequent task

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p WiFiLens/Sources/WiFiLens/Observation/Models
mkdir -p WiFiLens/Sources/WiFiLens/Observation/Adapters
mkdir -p WiFiLens/Sources/WiFiLens/Observation/Providers
mkdir -p WiFiLens/Sources/WiFiLens/Observation/Analyzers
mkdir -p WiFiLens/Sources/WiFiLens/Observation/Pipeline
mkdir -p WiFiLens/Sources/WiFiLens/Observation/Store
mkdir -p WiFiLens/Sources/WiFiLens/Observation/Controller
mkdir -p WiFiLens/WiFiLensTests/Observation
```

- [ ] **Step 2: Write WiFiObservationError**

Create `WiFiLens/Sources/WiFiLens/Observation/Models/WiFiObservationError.swift`:

```swift
import Foundation

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

- [ ] **Step 3: Write WiFiCurrentStatus**

Create `WiFiLens/Sources/WiFiLens/Observation/Models/WiFiCurrentStatus.swift`:

```swift
import Foundation

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

- [ ] **Step 4: Write WiFiNetworkCapabilities**

Create `WiFiLens/Sources/WiFiLens/Observation/Models/WiFiNetworkCapabilities.swift`:

```swift
import Foundation

struct WiFiNetworkCapabilities: Equatable, Sendable {
    var phyMode: String
    var channelWidth: Int
    var supports80211k: Bool
    var supports80211r: Bool
    var supports80211v: Bool
    var supportsWPA3: Bool
    var countryCode: String?
    var isHiddenSSID: Bool
    var mcs: String?
    var nss: String?
    var security: String?

    static let empty = WiFiNetworkCapabilities(
        phyMode: "",
        channelWidth: 20,
        supports80211k: false,
        supports80211r: false,
        supports80211v: false,
        supportsWPA3: false,
        countryCode: nil,
        isHiddenSSID: false,
        mcs: nil,
        nss: nil,
        security: nil
    )
}
```

- [ ] **Step 5: Write WiFiNetworkObservation**

Create `WiFiLens/Sources/WiFiLens/Observation/Models/WiFiNetworkObservation.swift`:

```swift
import Foundation

struct WiFiNetworkObservation: Identifiable, Equatable, Sendable {
    var id: String
    var ssid: String?
    var bssid: String
    var rssi: Int
    var channel: WiFiChannel
    var isIBSS: Bool
    var capabilities: WiFiNetworkCapabilities
    var rawIEData: Data?
    var isCurrentNetwork: Bool

    init(
        ssid: String?,
        bssid: String,
        rssi: Int,
        channel: WiFiChannel,
        isIBSS: Bool = false,
        capabilities: WiFiNetworkCapabilities = .empty,
        rawIEData: Data? = nil,
        isCurrentNetwork: Bool = false
    ) {
        self.ssid = ssid
        self.bssid = bssid
        self.rssi = rssi
        self.channel = channel
        self.isIBSS = isIBSS
        self.capabilities = capabilities
        self.rawIEData = rawIEData
        self.isCurrentNetwork = isCurrentNetwork
        self.id = WiFiNetworkObservation.makeID(
            bssid: bssid, ssid: ssid, channel: channel,
            security: capabilities.security, phyMode: capabilities.phyMode
        )
    }

    static func makeID(
        bssid: String,
        ssid: String?,
        channel: WiFiChannel,
        security: String?,
        phyMode: String?
    ) -> String {
        if !bssid.isEmpty && bssid != "unknown" {
            return "\(bssid)-\(channel.channelNumber)-\(channel.band.rawValue)"
        }
        let parts = [
            ssid ?? "",
            "\(channel.channelNumber)",
            channel.band.id,
            security ?? "",
            phyMode ?? ""
        ]
        return "local-\(parts.joined(separator: "-"))"
    }
}
```

- [ ] **Step 6: Write WiFiEnvironmentSnapshot**

Create `WiFiLens/Sources/WiFiLens/Observation/Models/WiFiEnvironmentSnapshot.swift`:

```swift
import Foundation

struct WiFiEnvironmentSnapshot: Equatable, Sendable {
    var timestamp: Date
    var interfaceName: String?
    var networks: [WiFiNetworkObservation]
    var scanDurationMs: Double?
    var error: WiFiObservationError?
}
```

- [ ] **Step 7: Write GatewayLatencyResult**

Create `WiFiLens/Sources/WiFiLens/Observation/Models/GatewayLatencyResult.swift`:

```swift
import Foundation

struct GatewayLatencyResult: Equatable, Sendable {
    var timestamp: Date
    var routerIP: String?
    var latencyMs: Double?
    var packetLoss: Double?
    var error: WiFiObservationError?
}
```

- [ ] **Step 8: Write WiFiQualityResult**

Create `WiFiLens/Sources/WiFiLens/Observation/Models/WiFiQualityResult.swift`:

```swift
import Foundation

struct WiFiQualityResult: Equatable, Sendable {
    var level: WiFiQualityLevel
    var signalLabel: String
    var latencyLabel: String
    var summary: String
}

enum WiFiQualityLevel: String, Sendable, CaseIterable {
    case good, fair, poor, unknown

    var displayName: String {
        switch self {
        case .good:    String(localized: "observation.quality.good", comment: "Good quality level")
        case .fair:    String(localized: "observation.quality.fair", comment: "Fair quality level")
        case .poor:    String(localized: "observation.quality.poor", comment: "Poor quality level")
        case .unknown: String(localized: "observation.quality.unknown", comment: "Unknown quality level")
        }
    }
}
```

- [ ] **Step 9: Write DiagnosticResult**

Create `WiFiLens/Sources/WiFiLens/Observation/Models/DiagnosticResult.swift`:

```swift
import SwiftUI

struct DiagnosticResult: Equatable, Sendable {
    var icon: String
    var title: String
    var message: String
    var severity: DiagnosticSeverity

    static let unknown = DiagnosticResult(
        icon: "questionmark.circle",
        title: String(localized: "observation.diagnosis.unknown.title", comment: "Unknown diagnosis title"),
        message: String(localized: "observation.diagnosis.unknown.message", comment: "Unknown diagnosis message"),
        severity: .ok
    )
}

enum DiagnosticSeverity: String, Sendable, CaseIterable {
    case excellent, warning, critical, ok
}
```

- [ ] **Step 10: Write WiFiObservationEvent**

Create `WiFiLens/Sources/WiFiLens/Observation/Models/WiFiObservationEvent.swift`:

```swift
import Foundation

struct WiFiObservationEvent: Identifiable, Equatable, Sendable {
    let id: UUID
    var timestamp: Date
    var type: EventType
    var details: String

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        type: EventType,
        details: String = ""
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.details = details
    }

    enum EventType: Equatable, Sendable {
        case bssidChange(from: String, to: String)
        case disconnection
        case reconnection
        case signalDrop(from: Int, to: Int)
        case latencySpike(from: Double, to: Double)
        case channelChange(from: Int, to: Int)
    }
}
```

- [ ] **Step 11: Write WiFiObservation**

Create `WiFiLens/Sources/WiFiLens/Observation/Models/WiFiObservation.swift`:

```swift
import Foundation

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

    init(
        timestamp: Date = Date(),
        currentStatus: WiFiCurrentStatus? = nil,
        environmentSnapshot: WiFiEnvironmentSnapshot? = nil,
        gatewayLatency: GatewayLatencyResult? = nil,
        quality: WiFiQualityResult? = nil,
        channelAnalysis: [ChannelQuality]? = nil,
        channelRecommendation: [ChannelRecommendation]? = nil,
        diagnosis: DiagnosticResult? = nil,
        events: [WiFiObservationEvent] = [],
        errors: [WiFiObservationError] = []
    ) {
        self.timestamp = timestamp
        self.currentStatus = currentStatus
        self.environmentSnapshot = environmentSnapshot
        self.gatewayLatency = gatewayLatency
        self.quality = quality
        self.channelAnalysis = channelAnalysis
        self.channelRecommendation = channelRecommendation
        self.diagnosis = diagnosis
        self.events = events
        self.errors = errors
    }
}
```

- [ ] **Step 12: Write model tests**

Create `WiFiLens/WiFiLensTests/Observation/ModelsTests.swift`:

```swift
import Testing
@testable import WiFiLens

@Suite("Observation Models")
struct ModelsTests {
    @Test("WiFiNetworkObservation uses BSSID-based ID when available")
    func bssidBasedID() {
        let ch = WiFiChannel(band: .band5GHz, channelNumber: 36, channelWidthMHz: 20)
        let obs = WiFiNetworkObservation(ssid: "TestNet", bssid: "AA:BB:CC:DD:EE:FF", rssi: -50, channel: ch)
        #expect(obs.id == "AA:BB:CC:DD:EE:FF-36-2")
    }

    @Test("WiFiNetworkObservation uses local fallback ID when BSSID is unknown")
    func localFallbackID() {
        let ch = WiFiChannel(band: .band24GHz, channelNumber: 6, channelWidthMHz: 20)
        let caps = WiFiNetworkCapabilities(phyMode: "ac", channelWidth: 80, supports80211k: false, supports80211r: false, supports80211v: false, supportsWPA3: true, countryCode: nil, isHiddenSSID: false, mcs: nil, nss: nil, security: "WPA2")
        let obs = WiFiNetworkObservation(ssid: "TestNet", bssid: "unknown", rssi: -60, channel: ch, capabilities: caps)
        #expect(obs.id.hasPrefix("local-"))
        #expect(!obs.id.contains("-60")) // RSSI must not be in ID
    }

    @Test("WiFiNetworkCapabilities empty static")
    func emptyCapabilities() {
        let empty = WiFiNetworkCapabilities.empty
        #expect(empty.phyMode == "")
        #expect(empty.channelWidth == 20)
        #expect(empty.supports80211k == false)
    }

    @Test("WiFiObservation defaults")
    func observationDefaults() {
        let obs = WiFiObservation()
        #expect(obs.currentStatus == nil)
        #expect(obs.events.isEmpty)
        #expect(obs.errors.isEmpty)
    }

    @Test("DiagnosticResult unknown static")
    func unknownDiagnostic() {
        let diag = DiagnosticResult.unknown
        #expect(diag.severity == .ok)
    }

    @Test("WiFiQualityLevel display names")
    func qualityLevelDisplay() {
        #expect(WiFiQualityLevel.good.displayName == String(localized: "observation.quality.good"))
        #expect(WiFiQualityLevel.poor.displayName == String(localized: "observation.quality.poor"))
    }
}
```

- [ ] **Step 13: Add new files to Xcode project**

Run `xed WiFiLens/WiFiLens.xcodeproj` and add all new model `.swift` files to both `WiFiLens` and `WiFiLensPro` targets' Sources build phase. Add test file to `WiFiLensTests` target.

- [ ] **Step 14: Build and test**

```bash
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests
```

Expected: Build succeeds. All tests pass.

- [ ] **Step 15: Commit**

```bash
git add WiFiLens/Sources/WiFiLens/Observation/ WiFiLens/WiFiLensTests/Observation/
git commit -m "feat(observation): add normalized model types for unified pipeline"
```

---

## Task 2: Add NetworkObservationAdapter (WiFiNetwork → WiFiNetworkObservation)

**Files:**
- Create: `WiFiLens/Sources/WiFiLens/Observation/Adapters/NetworkObservationAdapter.swift`
- Modify: `WiFiLens/WiFiLensTests/Observation/ModelsTests.swift` (add adapter tests)

**Interfaces:**
- Consumes: `WiFiNetwork` (existing), `IEParser` (existing), `WiFiNetworkObservation` (Task 1)
- Produces: `NetworkObservationAdapter` used by providers in Task 3 and analyzers in Task 4

- [ ] **Step 1: Write NetworkObservationAdapter**

Create `WiFiLens/Sources/WiFiLens/Observation/Adapters/NetworkObservationAdapter.swift`:

```swift
import Foundation

enum NetworkObservationAdapter {
    static func adapt(
        _ network: WiFiNetwork,
        isCurrentNetwork: Bool = false,
        currentBSSID: String? = nil
    ) -> WiFiNetworkObservation {
        let ieData = network.ieData
        let capabilities = ieData.map { IEParser.parse(data: $0) }
            .map { parseCapabilities($0) }
            ?? .empty

        let isCurrent = isCurrentNetwork || network.bssid == currentBSSID

        return WiFiNetworkObservation(
            ssid: network.ssid,
            bssid: network.bssid,
            rssi: network.rssi,
            channel: network.channel,
            isIBSS: network.isIBSS,
            capabilities: capabilities,
            rawIEData: ieData,
            isCurrentNetwork: isCurrent
        )
    }

    static func adaptAll(
        _ networks: [WiFiNetwork],
        currentBSSID: String? = nil
    ) -> [WiFiNetworkObservation] {
        networks.map { adapt($0, currentBSSID: currentBSSID) }
    }

    static func parseCapabilities(_ ie: IEData) -> WiFiNetworkCapabilities {
        let phyMode: String = {
            if ie.heSupported { return "ax" }
            if ie.vhtSupported { return "ac" }
            if ie.htSupported { return "n" }
            return ""
        }()

        let channelWidth: Int = {
            if ie.supports160MHz { return 160 }
            if ie.supports80MHz { return 80 }
            if ie.supports40MHz { return 40 }
            return 20
        }()

        return WiFiNetworkCapabilities(
            phyMode: phyMode,
            channelWidth: channelWidth,
            supports80211k: ie.supports80211k,
            supports80211r: ie.supports80211r,
            supports80211v: ie.supports80211v,
            supportsWPA3: ie.wpa3,
            countryCode: ie.countryCode,
            isHiddenSSID: ie.isHiddenSSID,
            mcs: ie.mcs,
            nss: ie.nss,
            security: ie.security
        )
    }
}
```

- [ ] **Step 2: Add adapter tests to ModelsTests.swift**

Append to `WiFiLens/WiFiLensTests/Observation/ModelsTests.swift`:

```swift
@Suite("NetworkObservationAdapter")
struct AdapterTests {
    @Test("Adapt WiFiNetwork to WiFiNetworkObservation preserves fields")
    func adaptPreservesFields() {
        let ch = WiFiChannel(band: .band5GHz, channelNumber: 36, channelWidthMHz: 80)
        let nw = WiFiNetwork(ssid: "TestNet", bssid: "AA:BB:CC:DD:EE:FF", rssi: -55, channel: ch)
        let obs = NetworkObservationAdapter.adapt(nw)
        #expect(obs.ssid == "TestNet")
        #expect(obs.bssid == "AA:BB:CC:DD:EE:FF")
        #expect(obs.rssi == -55)
        #expect(obs.channel.channelNumber == 36)
        #expect(obs.rawIEData == nil)
    }

    @Test("Adapt marks current network by BSSID match")
    func adaptMarksCurrent() {
        let ch = WiFiChannel(band: .band5GHz, channelNumber: 36, channelWidthMHz: 20)
        let nw = WiFiNetwork(ssid: "Net", bssid: "AA:BB:CC:DD:EE:FF", rssi: -50, channel: ch)
        let obs = NetworkObservationAdapter.adapt(nw, currentBSSID: "AA:BB:CC:DD:EE:FF")
        #expect(obs.isCurrentNetwork == true)
    }

    @Test("AdaptAll converts array")
    func adaptAllArray() {
        let ch = WiFiChannel(band: .band24GHz, channelNumber: 6, channelWidthMHz: 20)
        let networks = [
            WiFiNetwork(ssid: "A", bssid: "11:22:33:44:55:66", rssi: -60, channel: ch),
            WiFiNetwork(ssid: "B", bssid: "AA:BB:CC:DD:EE:FF", rssi: -70, channel: ch)
        ]
        let observations = NetworkObservationAdapter.adaptAll(networks)
        #expect(observations.count == 2)
        #expect(observations[0].ssid == "A")
        #expect(observations[1].ssid == "B")
    }
}
```

- [ ] **Step 3: Add file to Xcode project**

Add `NetworkObservationAdapter.swift` to both `WiFiLens` and `WiFiLensPro` targets.

- [ ] **Step 4: Build and test**

```bash
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests
```

Expected: Build succeeds. All tests pass.

- [ ] **Step 5: Commit**

```bash
git add WiFiLens/Sources/WiFiLens/Observation/Adapters/ WiFiLens/WiFiLensTests/Observation/ModelsTests.swift
git commit -m "feat(observation): add NetworkObservationAdapter for WiFiNetwork conversion"
```

---

## Task 3: Add providers

**Files:**
- Create: `WiFiLens/Sources/WiFiLens/Observation/Providers/WiFiCurrentConnectionProvider.swift`
- Create: `WiFiLens/Sources/WiFiLens/Observation/Providers/WiFiEnvironmentScanProvider.swift`
- Create: `WiFiLens/Sources/WiFiLens/Observation/Providers/GatewayLatencyProvider.swift`
- Create: `WiFiLens/Sources/WiFiLens/Observation/Providers/RoamingProbeProvider.swift`
- Create: `WiFiLens/WiFiLensTests/Observation/ProviderTests.swift`

**Interfaces:**
- Consumes: `NetworkInfoService` (existing), `WiFiScanner` (existing), `GatewayPinger` (existing), `CWWiFiClient` (existing), models from Task 1, adapter from Task 2
- Produces: Provider protocols + concrete implementations used by pipeline in Task 5

- [ ] **Step 1: Write WiFiCurrentConnectionProvider**

Create `WiFiLens/Sources/WiFiLens/Observation/Providers/WiFiCurrentConnectionProvider.swift`:

```swift
import Foundation

protocol WiFiCurrentConnectionProviding: Sendable {
    func fetchCurrentStatus() async -> WiFiCurrentStatus
}

struct WiFiCurrentConnectionProvider: WiFiCurrentConnectionProviding {
    func fetchCurrentStatus() async -> WiFiCurrentStatus {
        await MainActor.run {
            let interfaces = NetworkInfoService.fetchAll()
            guard let wifi = interfaces.first(where: { $0.ssid != nil }) else {
                return WiFiCurrentStatus(
                    timestamp: Date(),
                    isConnected: false,
                    isWiFiPowerOn: true,
                    error: .noWiFiConnection
                )
            }
            return WiFiCurrentStatus(
                timestamp: Date(),
                interfaceName: wifi.interfaceName,
                ssid: wifi.ssid,
                bssid: wifi.bssid,
                channel: wifi.channel,
                band: wifi.channel.flatMap { ChannelBand.from(channelNumber: $0) },
                rssi: wifi.rssi,
                txRate: wifi.txRate,
                phyMode: wifi.phyMode,
                security: wifi.security,
                routerIP: wifi.router,
                isConnected: true,
                isWiFiPowerOn: true
            )
        }
    }
}
```

- [ ] **Step 2: Write WiFiEnvironmentScanProvider**

Create `WiFiLens/Sources/WiFiLens/Observation/Providers/WiFiEnvironmentScanProvider.swift`:

```swift
import Foundation

protocol WiFiEnvironmentScanProviding: Sendable {
    func scanEnvironment() async -> WiFiEnvironmentSnapshot
}

struct WiFiEnvironmentScanProvider: WiFiEnvironmentScanProviding {
    private let scanner = WiFiScanner()

    func scanEnvironment() async -> WiFiEnvironmentSnapshot {
        let startTime = Date()
        var networks: [WiFiNetwork] = []

        for await event in scanner.startScanning(interval: 0) {
            if case .networks(let nw) = event {
                networks = nw
                break
            }
        }

        await scanner.stopScanning()

        let currentBSSID: String? = await MainActor.run {
            NetworkInfoService.fetchAll().first(where: { $0.ssid != nil })?.bssid
        }

        let observations = NetworkObservationAdapter.adaptAll(networks, currentBSSID: currentBSSID)
        let interfaceName = await scanner.interfaceName()
        let duration = Date().timeIntervalSince(startTime) * 1000

        return WiFiEnvironmentSnapshot(
            timestamp: Date(),
            interfaceName: interfaceName,
            networks: observations,
            scanDurationMs: duration
        )
    }
}
```

- [ ] **Step 3: Write GatewayLatencyProvider**

Create `WiFiLens/Sources/WiFiLens/Observation/Providers/GatewayLatencyProvider.swift`:

```swift
import Foundation

protocol GatewayLatencyProviding: Sendable {
    func measure(routerIP: String?) async -> GatewayLatencyResult
}

struct GatewayLatencyProvider: GatewayLatencyProviding {
    private let pinger = GatewayPinger()

    func measure(routerIP: String?) async -> GatewayLatencyResult {
        guard let routerIP else {
            return GatewayLatencyResult(
                timestamp: Date(),
                error: .missingRouterIP
            )
        }
        let latency = await pinger.ping(host: routerIP)
        return GatewayLatencyResult(
            timestamp: Date(),
            routerIP: routerIP,
            latencyMs: latency
        )
    }
}
```

- [ ] **Step 4: Write RoamingProbeProvider**

Create `WiFiLens/Sources/WiFiLens/Observation/Providers/RoamingProbeProvider.swift`:

```swift
import Foundation
import CoreWLAN

protocol RoamingProbeProviding: Sendable {
    func fetchCurrentProbe() async -> WiFiCurrentStatus
}

struct RoamingProbeProvider: RoamingProbeProviding {
    func fetchCurrentProbe() async -> WiFiCurrentStatus {
        await MainActor.run {
            guard let iface = CWWiFiClient.shared().interface() else {
                return WiFiCurrentStatus(
                    timestamp: Date(),
                    isConnected: false,
                    isWiFiPowerOn: false,
                    error: .noWiFiInterface
                )
            }
            let ssid = iface.ssid()
            let bssid = iface.bssid()
            let channelNum = iface.wlanChannel()?.channelNumber
            let band = channelNum.flatMap { ChannelBand.from(channelNumber: $0) }
            return WiFiCurrentStatus(
                timestamp: Date(),
                interfaceName: iface.interfaceName,
                ssid: ssid,
                bssid: bssid,
                channel: channelNum,
                band: band,
                rssi: iface.rssiValue(),
                txRate: iface.transmitRate(),
                isConnected: ssid != nil,
                isWiFiPowerOn: true
            )
        }
    }
}
```

- [ ] **Step 5: Write provider tests**

Create `WiFiLens/WiFiLensTests/Observation/ProviderTests.swift`:

```swift
import Testing
@testable import WiFiLens

@Suite("Observation Providers")
struct ProviderTests {
    @Test("WiFiCurrentConnectionProvider returns status or error")
    func currentConnectionProvider() async {
        let provider = WiFiCurrentConnectionProvider()
        let status = await provider.fetchCurrentStatus()
        // On a machine with Wi-Fi, isConnected should be true
        // On CI without Wi-Fi, error should be set
        if status.isConnected {
            #expect(status.ssid != nil)
            #expect(status.bssid != nil)
        } else {
            #expect(status.error != nil)
        }
    }

    @Test("GatewayLatencyProvider returns result with routerIP")
    func gatewayLatencyProvider() async {
        let provider = GatewayLatencyProvider()
        let result = await provider.measure(routerIP: nil)
        #expect(result.error == .missingRouterIP)

        let result2 = await provider.measure(routerIP: "127.0.0.1")
        #expect(result2.latencyMs != nil || result2.error != nil)
    }
}
```

- [ ] **Step 6: Add files to Xcode project**

Add all 4 provider files to both `WiFiLens` and `WiFiLensPro` targets. Add test file to `WiFiLensTests`.

- [ ] **Step 7: Build and test**

```bash
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests
```

Expected: Build succeeds. All tests pass.

- [ ] **Step 8: Commit**

```bash
git add WiFiLens/Sources/WiFiLens/Observation/Providers/ WiFiLens/WiFiLensTests/Observation/ProviderTests.swift
git commit -m "feat(observation): add providers for current connection, environment scan, gateway latency, and roaming probe"
```

---

## Task 4: Add analyzers

**Files:**
- Create: `WiFiLens/Sources/WiFiLens/Observation/Analyzers/WiFiQualityEvaluator.swift`
- Create: `WiFiLens/Sources/WiFiLens/Observation/Analyzers/ChannelOccupancyAnalyzer.swift`
- Create: `WiFiLens/Sources/WiFiLens/Observation/Analyzers/RegulatoryDomainResolver.swift`
- Create: `WiFiLens/Sources/WiFiLens/Observation/Analyzers/ChannelRecommendationEngine.swift`
- Create: `WiFiLens/Sources/WiFiLens/Observation/Analyzers/DiagnosticEvaluator.swift`
- Create: `WiFiLens/Sources/WiFiLens/Observation/Analyzers/RoamingEventDetector.swift`
- Create: `WiFiLens/WiFiLensTests/Observation/AnalyzerTests.swift`

**Interfaces:**
- Consumes: Models from Task 1, `ChannelQualityCalculator` (existing), `RegulatoryFilter` (existing), `RegionInferenceEngine` (existing), `RecommendationReasonCalculator` (existing)
- Produces: Analyzer functions used by pipeline in Task 5

- [ ] **Step 1: Write WiFiQualityEvaluator**

Create `WiFiLens/Sources/WiFiLens/Observation/Analyzers/WiFiQualityEvaluator.swift`:

```swift
import Foundation

enum WiFiQualityEvaluator {
    static func evaluate(
        currentStatus: WiFiCurrentStatus,
        gatewayLatency: GatewayLatencyResult? = nil
    ) -> WiFiQualityResult {
        let rssi = currentStatus.rssi ?? -100
        let level = evaluateLevel(rssi: rssi, latencyMs: gatewayLatency?.latencyMs)
        let signalLabel = Self.signalLabel(rssi: rssi)
        let latencyLabel = Self.latencyLabel(ms: gatewayLatency?.latencyMs)
        let summary = Self.summary(level: level, signalLabel: signalLabel, latencyLabel: latencyLabel)
        return WiFiQualityResult(level: level, signalLabel: signalLabel, latencyLabel: latencyLabel, summary: summary)
    }

    private static func evaluateLevel(rssi: Int, latencyMs: Double?) -> WiFiQualityLevel {
        if rssi >= -55 {
            if let ms = latencyMs, ms < 50 { return .good }
            if latencyMs == nil { return .good }
            return .fair
        }
        if rssi >= -70 {
            if let ms = latencyMs, ms < 100 { return .fair }
            return .poor
        }
        return .poor
    }

    private static func signalLabel(rssi: Int) -> String {
        if rssi >= -55 { return String(localized: "observation.signal.strong", comment: "Strong signal") }
        if rssi >= -70 { return String(localized: "observation.signal.good", comment: "Good signal") }
        if rssi >= -85 { return String(localized: "observation.signal.moderate", comment: "Moderate signal") }
        return String(localized: "observation.signal.weak", comment: "Weak signal")
    }

    private static func latencyLabel(ms: Double?) -> String {
        guard let ms else { return String(localized: "observation.latency.unavailable", comment: "Latency unavailable") }
        if ms < 50 { return String(localized: "observation.latency.normal", comment: "Normal latency") }
        if ms < 100 { return String(localized: "observation.latency.elevated", comment: "Elevated latency") }
        return String(localized: "observation.latency.high", comment: "High latency")
    }

    private static func summary(level: WiFiQualityLevel, signalLabel: String, latencyLabel: String) -> String {
        switch level {
        case .good:    return String(localized: "observation.summary.good", comment: "Good connection summary")
        case .fair:    return String(localized: "observation.summary.fair", comment: "Fair connection summary")
        case .poor:    return String(localized: "observation.summary.poor", comment: "Poor connection summary")
        case .unknown: return String(localized: "observation.summary.unknown", comment: "Unknown connection summary")
        }
    }
}
```

- [ ] **Step 2: Write ChannelOccupancyAnalyzer**

Create `WiFiLens/Sources/WiFiLens/Observation/Analyzers/ChannelOccupancyAnalyzer.swift`:

```swift
import Foundation

enum ChannelOccupancyAnalyzer {
    static func analyze(
        snapshot: WiFiEnvironmentSnapshot,
        currentChannel: Int?,
        supportedBands: Set<String>,
        targetAP: ChannelQualityCalculator.TargetAP?
    ) -> [ChannelQuality] {
        var seen = [String: ChannelQualityCalculator.APInfo]()
        for obs in snapshot.networks {
            let key = "\(obs.bssid)-\(obs.channel.band.rawValue)"
            let widthLabel = channelWidthLabel(obs.capabilities.channelWidth)
            let span = ChannelSpanCalculator.channelBlock(
                primaryChannel: obs.channel.channelNumber,
                widthMHz: obs.channel.channelWidthMHz,
                band: obs.channel.band,
                spanDirection: obs.channel.spanDirection
            )
            let info = ChannelQualityCalculator.APInfo(
                channel: obs.channel.channelNumber,
                rssi: obs.rssi,
                channelWidth: widthLabel,
                band: obs.channel.band.id,
                apex: Double(span.left + span.right) / 2.0,
                bssid: obs.bssid,
                ssid: obs.ssid
            )
            if let existing = seen[key] {
                if info.rssi > existing.rssi { seen[key] = info }
            } else {
                seen[key] = info
            }
        }
        return ChannelQualityCalculator.compute(
            aps: Array(seen.values),
            currentChannel: currentChannel,
            supportedBands: supportedBands,
            targetAP: targetAP
        )
    }

    private static func channelWidthLabel(_ width: Int) -> String {
        switch width {
        case 160: return "160"
        case 80:  return "80"
        case 40:  return "40"
        default:  return "20"
        }
    }
}
```

- [ ] **Step 3: Write RegulatoryDomainResolver**

Create `WiFiLens/Sources/WiFiLens/Observation/Analyzers/RegulatoryDomainResolver.swift`:

```swift
import Foundation

enum RegulatoryDomainResolver {
    static func resolve(
        userOverride: RegulatoryDomain?,
        userDefaultsOverride: RegulatoryDomain?,
        systemLocale: Locale = .current,
        supportedChannelsRaw: [(Int, Int)],
        apCountryCodes: [String]
    ) -> RegionInferenceResult {
        RegionInferenceEngine.infer(
            systemLocale: systemLocale,
            supportedChannels: supportedChannelsRaw,
            apCountryCodes: apCountryCodes,
            userOverride: userOverride ?? userDefaultsOverride
        )
    }
}
```

- [ ] **Step 4: Write ChannelRecommendationEngine**

Create `WiFiLens/Sources/WiFiLens/Observation/Analyzers/ChannelRecommendationEngine.swift`:

```swift
import Foundation

enum ChannelRecommendationEngine {
    static func recommend(
        channelAnalysis: [ChannelQuality],
        snapshot: WiFiEnvironmentSnapshot,
        inferredRegion: RegionInferenceResult,
        deviceSupportedChannels: Set<String>,
        deviceCapabilities: DevicePHYCapabilities
    ) -> [ChannelRecommendation] {
        let input = RegulatoryFilter.FilterInput(
            rfResults: channelAnalysis,
            inferredRegion: inferredRegion,
            deviceSupportedChannels: deviceSupportedChannels,
            deviceCapabilities: deviceCapabilities,
            userClassificationOverrides: nil
        )
        let filtered = RegulatoryFilter.apply(to: input)
        return RecommendationReasonCalculator.compute(for: filtered)
    }
}
```

- [ ] **Step 5: Write DiagnosticEvaluator**

Create `WiFiLens/Sources/WiFiLens/Observation/Analyzers/DiagnosticEvaluator.swift`:

```swift
import SwiftUI

enum DiagnosticEvaluator {
    static func evaluate(
        currentStatus: WiFiCurrentStatus,
        quality: WiFiQualityResult? = nil,
        channelAnalysis: [ChannelQuality]? = nil,
        channelRecommendations: [ChannelRecommendation]? = nil
    ) -> DiagnosticResult {
        let rssi = currentStatus.rssi ?? -100
        let chScore = channelAnalysis?
            .first(where: { $0.isCurrentChannel })?
            .qualityScore ?? 50
        let apCount = channelAnalysis?
            .first(where: { $0.isCurrentChannel })?
            .apCount ?? 0
        let sec = currentStatus.security ?? ""
        let phy = currentStatus.phyMode ?? ""

        if rssi >= -55 && chScore >= 70 && sec.contains("WPA3") {
            return DiagnosticResult(
                icon: "star.fill",
                title: String(localized: "observation.diagnosis.excellent.title", comment: "Excellent connection"),
                message: String(localized: "observation.diagnosis.excellent.message", comment: "Excellent connection message"),
                severity: .excellent
            )
        }

        if rssi < -75 {
            return DiagnosticResult(
                icon: "wifi.slash",
                title: String(localized: "observation.diagnosis.weak_signal.title", comment: "Weak signal"),
                message: String(localized: "observation.diagnosis.weak_signal.message", comment: "Weak signal advice"),
                severity: .critical
            )
        }

        if chScore < 50 {
            let channelNum = currentStatus.channel ?? 0
            let recList = channelRecommendations?.prefix(2).map { "\($0.channel)" }.joined(separator: " / ") ?? ""
            return DiagnosticResult(
                icon: "antenna.radiowaves.left.and.right",
                title: String(localized: "observation.diagnosis.congested.title", comment: "Congested channel"),
                message: String(format: String(localized: "observation.diagnosis.congested.message_fmt", comment: "Congested channel with details"), channelNum, apCount, recList),
                severity: .warning
            )
        }

        if chScore < 70 {
            return DiagnosticResult(
                icon: "antenna.radiowaves.left.and.right",
                title: String(localized: "observation.diagnosis.mediocre.title", comment: "Mediocre channel"),
                message: String(localized: "observation.diagnosis.mediocre.message", comment: "Mediocre channel advice"),
                severity: .warning
            )
        }

        if !sec.contains("WPA3") && sec != "—" && !sec.isEmpty {
            return DiagnosticResult(
                icon: "lock.open.fill",
                title: String(localized: "observation.diagnosis.security.title", comment: "Weak security"),
                message: String(format: String(localized: "observation.diagnosis.security.message_fmt", comment: "Security advice with type"), sec),
                severity: .warning
            )
        }

        if phy == "n" || phy == "ac" {
            let version = phy == "n" ? "4" : "5"
            return DiagnosticResult(
                icon: "speedometer",
                title: String(localized: "observation.diagnosis.old_phy.title", comment: "Older Wi-Fi generation"),
                message: String(format: String(localized: "observation.diagnosis.old_phy.message_fmt", comment: "PHY upgrade advice"), version),
                severity: .warning
            )
        }

        return DiagnosticResult(
            icon: "checkmark.circle.fill",
            title: String(localized: "observation.diagnosis.ok.title", comment: "Acceptable connection"),
            message: String(localized: "observation.diagnosis.ok.message", comment: "General advice"),
            severity: .ok
        )
    }
}
```

- [ ] **Step 6: Write RoamingEventDetector**

Create `WiFiLens/Sources/WiFiLens/Observation/Analyzers/RoamingEventDetector.swift`:

```swift
import Foundation

enum RoamingEventDetector {
    static func detect(
        previous: WiFiCurrentStatus?,
        current: WiFiCurrentStatus
    ) -> [WiFiObservationEvent] {
        guard let previous else { return [] }
        var events: [WiFiObservationEvent] = []

        if let prevBSSID = previous.bssid, let curBSSID = current.bssid,
           prevBSSID != curBSSID {
            events.append(WiFiObservationEvent(
                type: .bssidChange(from: prevBSSID, to: curBSSID)
            ))
        }

        if previous.isConnected && !current.isConnected {
            events.append(WiFiObservationEvent(type: .disconnection))
        }

        if !previous.isConnected && current.isConnected {
            events.append(WiFiObservationEvent(type: .reconnection))
        }

        if let prevRSSI = previous.rssi, let curRSSI = current.rssi,
           prevRSSI - curRSSI > 20 {
            events.append(WiFiObservationEvent(
                type: .signalDrop(from: prevRSSI, to: curRSSI)
            ))
        }

        if let prevCh = previous.channel, let curCh = current.channel,
           prevCh != curCh {
            events.append(WiFiObservationEvent(
                type: .channelChange(from: prevCh, to: curCh)
            ))
        }

        return events
    }
}
```

- [ ] **Step 7: Write analyzer tests**

Create `WiFiLens/WiFiLensTests/Observation/AnalyzerTests.swift`:

```swift
import Testing
@testable import WiFiLens

@Suite("Observation Analyzers")
struct AnalyzerTests {
    @Test("WiFiQualityEvaluator: strong signal + low latency = good")
    func strongGood() {
        let status = WiFiCurrentStatus(
            timestamp: Date(), ssid: "Test", bssid: "AA:BB", channel: 36,
            rssi: -45, isConnected: true, isWiFiPowerOn: true
        )
        let latency = GatewayLatencyResult(timestamp: Date(), latencyMs: 20)
        let result = WiFiQualityEvaluator.evaluate(currentStatus: status, gatewayLatency: latency)
        #expect(result.level == .good)
    }

    @Test("WiFiQualityEvaluator: weak signal = poor")
    func weakPoor() {
        let status = WiFiCurrentStatus(
            timestamp: Date(), ssid: "Test", bssid: "AA:BB", channel: 6,
            rssi: -80, isConnected: true, isWiFiPowerOn: true
        )
        let result = WiFiQualityEvaluator.evaluate(currentStatus: status)
        #expect(result.level == .poor)
    }

    @Test("RoamingEventDetector: BSSID change produces event")
    func bssidChangeEvent() {
        let prev = WiFiCurrentStatus(
            timestamp: Date(), ssid: "Net", bssid: "AA:BB:CC:DD:EE:01",
            channel: 36, rssi: -50, isConnected: true, isWiFiPowerOn: true
        )
        let cur = WiFiCurrentStatus(
            timestamp: Date(), ssid: "Net", bssid: "AA:BB:CC:DD:EE:02",
            channel: 36, rssi: -55, isConnected: true, isWiFiPowerOn: true
        )
        let events = RoamingEventDetector.detect(previous: prev, current: cur)
        #expect(events.count == 1)
        if case .bssidChange(let from, let to) = events[0].type {
            #expect(from == "AA:BB:CC:DD:EE:01")
            #expect(to == "AA:BB:CC:DD:EE:02")
        } else {
            Issue.record("Expected bssidChange event")
        }
    }

    @Test("RoamingEventDetector: signal drop > 20dBm produces event")
    func signalDropEvent() {
        let prev = WiFiCurrentStatus(
            timestamp: Date(), ssid: "Net", bssid: "AA:BB",
            channel: 6, rssi: -50, isConnected: true, isWiFiPowerOn: true
        )
        let cur = WiFiCurrentStatus(
            timestamp: Date(), ssid: "Net", bssid: "AA:BB",
            channel: 6, rssi: -75, isConnected: true, isWiFiPowerOn: true
        )
        let events = RoamingEventDetector.detect(previous: prev, current: cur)
        #expect(events.contains { $0.type == .signalDrop(from: -50, to: -75) })
    }

    @Test("DiagnosticEvaluator: excellent when strong + WPA3 + good channel")
    func excellentDiagnostic() {
        let status = WiFiCurrentStatus(
            timestamp: Date(), ssid: "Net", bssid: "AA:BB", channel: 36,
            rssi: -45, security: "WPA3", isConnected: true, isWiFiPowerOn: true
        )
        let ch = ChannelQuality(
            channel: 36, band: "5", bandDisplay: "5 GHz",
            qualityScore: 85, qualityLevel: .good,
            apCount: 1, coChannelCount: 0, adjacentCount: 1,
            interferenceScore: 15, overlapLevel: .low,
            strongestNeighborRSSI: -70, isCurrentChannel: true
        )
        let result = DiagnosticEvaluator.evaluate(
            currentStatus: status, channelAnalysis: [ch]
        )
        #expect(result.severity == .excellent)
    }
}
```

- [ ] **Step 8: Add files to Xcode project**

Add all 6 analyzer files to both `WiFiLens` and `WiFiLensPro` targets. Add test file to `WiFiLensTests`.

- [ ] **Step 9: Build and test**

```bash
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests
```

Expected: Build succeeds. All tests pass.

- [ ] **Step 10: Commit**

```bash
git add WiFiLens/Sources/WiFiLens/Observation/Analyzers/ WiFiLens/WiFiLensTests/Observation/AnalyzerTests.swift
git commit -m "feat(observation): add analyzers for quality, channel occupancy, regulatory, recommendations, diagnostics, and roaming events"
```

---

## Task 5: Add pipeline, store, and controller

**Files:**
- Create: `WiFiLens/Sources/WiFiLens/Observation/Pipeline/WiFiObservationPipeline.swift`
- Create: `WiFiLens/Sources/WiFiLens/Observation/Store/WiFiObservationStore.swift`
- Create: `WiFiLens/Sources/WiFiLens/Observation/Controller/WiFiObservationController.swift`
- Create: `WiFiLens/WiFiLensTests/Observation/PipelineTests.swift`
- Create: `WiFiLens/WiFiLensTests/Observation/ControllerTests.swift`

**Interfaces:**
- Consumes: All providers from Task 3, all analyzers from Task 4, models from Task 1
- Produces: `WiFiObservationPipeline`, `WiFiObservationStore`, `WiFiObservationController` — the public API for Phase 6+ UI migration

- [ ] **Step 1: Write WiFiObservationPipeline**

Create `WiFiLens/Sources/WiFiLens/Observation/Pipeline/WiFiObservationPipeline.swift`:

```swift
import Foundation

protocol WiFiObservationPipelining: Sendable {
    func refreshCurrentConnection() async -> WiFiObservation
    func refreshEnvironmentScan() async -> WiFiObservation
    func refreshFullObservation() async -> WiFiObservation
}

struct WiFiObservationPipeline: WiFiObservationPipelining {
    let currentConnectionProvider: WiFiCurrentConnectionProviding
    let environmentScanProvider: WiFiEnvironmentScanProviding
    let gatewayLatencyProvider: GatewayLatencyProviding

    init(
        currentConnectionProvider: WiFiCurrentConnectionProviding = WiFiCurrentConnectionProvider(),
        environmentScanProvider: WiFiEnvironmentScanProviding = WiFiEnvironmentScanProvider(),
        gatewayLatencyProvider: GatewayLatencyProviding = GatewayLatencyProvider()
    ) {
        self.currentConnectionProvider = currentConnectionProvider
        self.environmentScanProvider = environmentScanProvider
        self.gatewayLatencyProvider = gatewayLatencyProvider
    }

    func refreshCurrentConnection() async -> WiFiObservation {
        let status = await currentConnectionProvider.fetchCurrentStatus()
        let latency = await gatewayLatencyProvider.measure(routerIP: status.routerIP)
        let quality = WiFiQualityEvaluator.evaluate(currentStatus: status, gatewayLatency: latency)
        return WiFiObservation(
            currentStatus: status,
            gatewayLatency: latency,
            quality: quality
        )
    }

    func refreshEnvironmentScan() async -> WiFiObservation {
        let snapshot = await environmentScanProvider.scanEnvironment()
        let currentChannel = await MainActor.run {
            NetworkInfoService.fetchAll().first(where: { $0.ssid != nil })?.channel
        }
        let channelAnalysis = ChannelOccupancyAnalyzer.analyze(
            snapshot: snapshot,
            currentChannel: currentChannel,
            supportedBands: ["24", "5", "6"],
            targetAP: nil
        )
        return WiFiObservation(
            environmentSnapshot: snapshot,
            channelAnalysis: channelAnalysis
        )
    }

    func refreshFullObservation() async -> WiFiObservation {
        let current = await refreshCurrentConnection()
        let scan = await refreshEnvironmentScan()

        var observation = current
        observation.environmentSnapshot = scan.environmentSnapshot
        observation.channelAnalysis = scan.channelAnalysis
        observation.diagnosis = DiagnosticEvaluator.evaluate(
            currentStatus: current.currentStatus ?? WiFiCurrentStatus(
                timestamp: Date(), isConnected: false, isWiFiPowerOn: true
            ),
            quality: current.quality,
            channelAnalysis: scan.channelAnalysis
        )
        return observation
    }
}
```

- [ ] **Step 2: Write WiFiObservationStore**

Create `WiFiLens/Sources/WiFiLens/Observation/Store/WiFiObservationStore.swift`:

```swift
import Foundation

@MainActor
final class WiFiObservationStore: ObservableObject {
    @Published var currentStatus: WiFiCurrentStatus?
    @Published var gatewayLatency: GatewayLatencyResult?
    @Published var quality: WiFiQualityResult?

    @Published var latestEnvironmentSnapshot: WiFiEnvironmentSnapshot?
    @Published var channelAnalysis: [ChannelQuality]?
    @Published var channelRecommendation: [ChannelRecommendation]?

    @Published var diagnosis: DiagnosticResult?
    @Published var recentEvents: [WiFiObservationEvent] = []

    @Published var isRefreshingCurrent = false
    @Published var isScanningEnvironment = false
    @Published var lastUpdated: Date?
    @Published var errors: [WiFiObservationError] = []

    func apply(_ observation: WiFiObservation) {
        if let status = observation.currentStatus {
            currentStatus = status
        }
        if let latency = observation.gatewayLatency {
            gatewayLatency = latency
        }
        if let q = observation.quality {
            quality = q
        }
        if let snapshot = observation.environmentSnapshot {
            latestEnvironmentSnapshot = snapshot
        }
        if let analysis = observation.channelAnalysis {
            channelAnalysis = analysis
        }
        if let recs = observation.channelRecommendation {
            channelRecommendation = recs
        }
        if let diag = observation.diagnosis {
            diagnosis = diag
        }
        if !observation.events.isEmpty {
            let existingIDs = Set(recentEvents.map(\.id))
            let newEvents = observation.events.filter { !existingIDs.contains($0.id) }
            recentEvents.append(contentsOf: newEvents)
            if recentEvents.count > 50 {
                recentEvents = Array(recentEvents.suffix(50))
            }
        }
        if !observation.errors.isEmpty {
            errors.append(contentsOf: observation.errors)
            if errors.count > 20 {
                errors = Array(errors.suffix(20))
            }
        }
        lastUpdated = Date()
    }
}
```

- [ ] **Step 3: Write WiFiObservationController**

Create `WiFiLens/Sources/WiFiLens/Observation/Controller/WiFiObservationController.swift`:

```swift
import Foundation

@MainActor
final class WiFiObservationController {
    let pipeline: WiFiObservationPipelining
    let store: WiFiObservationStore

    init(
        pipeline: WiFiObservationPipelining = WiFiObservationPipeline(),
        store: WiFiObservationStore = WiFiObservationStore()
    ) {
        self.pipeline = pipeline
        self.store = store
    }

    func refreshCurrentConnection() async {
        store.isRefreshingCurrent = true
        defer { store.isRefreshingCurrent = false }
        let observation = await pipeline.refreshCurrentConnection()
        store.apply(observation)
    }

    func refreshEnvironmentScan() async {
        store.isScanningEnvironment = true
        defer { store.isScanningEnvironment = false }
        let observation = await pipeline.refreshEnvironmentScan()
        store.apply(observation)
    }

    func refreshFullObservation() async {
        store.isRefreshingCurrent = true
        store.isScanningEnvironment = true
        defer {
            store.isRefreshingCurrent = false
            store.isScanningEnvironment = false
        }
        let observation = await pipeline.refreshFullObservation()
        store.apply(observation)
    }
}
```

- [ ] **Step 4: Write pipeline tests**

Create `WiFiLens/WiFiLensTests/Observation/PipelineTests.swift`:

```swift
import Testing
@testable import WiFiLens

@Suite("WiFiObservationPipeline")
struct PipelineTests {
    @Test("refreshCurrentConnection returns currentStatus + quality, no environment")
    func currentConnectionOnly() async {
        let pipeline = WiFiObservationPipeline()
        let obs = await pipeline.refreshCurrentConnection()
        #expect(obs.currentStatus != nil)
        #expect(obs.quality != nil)
        #expect(obs.environmentSnapshot == nil)
    }

    @Test("refreshEnvironmentScan returns snapshot, no currentStatus")
    func environmentScanOnly() async {
        let pipeline = WiFiObservationPipeline()
        let obs = await pipeline.refreshEnvironmentScan()
        #expect(obs.environmentSnapshot != nil)
        #expect(obs.currentStatus == nil)
    }

    @Test("refreshFullObservation returns all fields")
    func fullObservation() async {
        let pipeline = WiFiObservationPipeline()
        let obs = await pipeline.refreshFullObservation()
        #expect(obs.currentStatus != nil)
        #expect(obs.environmentSnapshot != nil)
        #expect(obs.diagnosis != nil)
    }
}
```

- [ ] **Step 5: Write controller tests**

Create `WiFiLens/WiFiLensTests/Observation/ControllerTests.swift`:

```swift
import Testing
@testable import WiFiLens

@Suite("WiFiObservationController")
struct ControllerTests {
    @Test("refreshCurrentConnection updates store")
    func controllerUpdatesStore() async {
        let store = WiFiObservationStore()
        let controller = WiFiObservationController(store: store)
        await controller.refreshCurrentConnection()
        #expect(store.lastUpdated != nil)
        #expect(store.isRefreshingCurrent == false)
    }

    @Test("refreshEnvironmentScan updates store snapshot")
    func controllerUpdatesSnapshot() async {
        let store = WiFiObservationStore()
        let controller = WiFiObservationController(store: store)
        await controller.refreshEnvironmentScan()
        #expect(store.latestEnvironmentSnapshot != nil)
        #expect(store.isScanningEnvironment == false)
    }
}
```

- [ ] **Step 6: Add files to Xcode project**

Add all 3 source files and 2 test files to appropriate targets.

- [ ] **Step 7: Build and test**

```bash
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests
```

Expected: Build succeeds. All tests pass. Existing behavior unchanged.

- [ ] **Step 8: Commit**

```bash
git add WiFiLens/Sources/WiFiLens/Observation/Pipeline/ WiFiLens/Sources/WiFiLens/Observation/Store/ WiFiLens/Sources/WiFiLens/Observation/Controller/ WiFiLens/WiFiLensTests/Observation/PipelineTests.swift WiFiLens/WiFiLensTests/Observation/ControllerTests.swift
git commit -m "feat(observation): add pipeline, store, and controller for unified observation flow"
```

---

## Summary

After these 5 tasks, the project has:

| Layer | Files | Status |
|-------|-------|--------|
| Models | 11 files in `Observation/Models/` | Additive — old types untouched |
| Adapters | 1 file in `Observation/Adapters/` | Bridges old `WiFiNetwork` → new `WiFiNetworkObservation` |
| Providers | 4 files in `Observation/Providers/` | Wraps existing system APIs |
| Analyzers | 6 files in `Observation/Analyzers/` | Wraps existing calculation logic |
| Pipeline | 1 file in `Observation/Pipeline/` | Three refresh modes |
| Store | 1 file in `Observation/Store/` | `@Published` state container |
| Controller | 1 file in `Observation/Controller/` | Pipeline → Store orchestration |
| Tests | 5 test files | Model, adapter, provider, analyzer, pipeline, controller tests |

**No existing code is modified or removed.** All new code compiles alongside old code. Phase 6+ will migrate UI consumers to use the new pipeline/store/controller.
