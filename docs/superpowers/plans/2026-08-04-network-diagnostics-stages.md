# Network Diagnostics Stage Model Implementation Plan

> **Execution note:** Work through the checked steps in order, using the repository's plan-execution workflow and test-driven gates.

**Goal:** Define `This Mac` / `LAN` / `Internet` stages in the network self-check: a derived-stage domain model, a dedicated gateway reachability check, a pipeline diagram with connectivity status on the connecting lines, and a stage-grouped workbench table.

**Architecture:** The runner keeps owning check execution only. A new `GatewayReachabilityCheck` replaces the gateway latency embedded in the path check. `NetworkDiagnosticStage` (pure domain) plus `NetworkDiagnosticStageResolver` compute stage status on demand from check results. The pipeline diagram and grouped table are presentation projections (`NetworkDiagnosticsPipelinePresentation` + `NetworkDiagnosticsWorkbenchItem`) built from results and execution phases. All new types live in existing files because `project.pbxproj` (objectVersion 77) has no file-system-synchronized groups.

**Tech Stack:** Swift 6, SwiftUI + AppKit, NWPathMonitor, ICMP gateway ping (existing `GatewayLatencyProvider`), CFNetwork, Swift Testing, Xcode project (OSS + Pro schemes).

## Global Constraints

- Do not create new source or test files: add all new types to existing files to avoid `project.pbxproj` build-phase edits.
- Check-ID order is fixed: `path → gatewayReachability → dns → internet → ipv6 → proxy`.
- Gateway ping failure returns `.abnormal`; `gatewayReachability` `.abnormal` never blocks `dns`, `internet`, or `ipv6`.
- IPv6 displays under Additional Checks and never affects the Internet stage
  status or the overall conclusion (`NetworkDiagnosticConclusion.evaluate`
  excludes `.ipv6` from its non-normal rule).
- Proxy and DNS resolution are part of the This Mac stage (local
  configuration) and continue to participate in the overall conclusion.
- `NetworkDiagnosticConclusion.primaryIssue` gains `.gatewayReachability` (after `.path`) so LAN failures surface remediation.
- `NetworkDiagnosticStage` carries no title, icon, color, or style metadata; all UI metadata lives in the presentation layer.
- The runner never stores or publishes stage state; stage status is derived via `NetworkDiagnosticStageResolver`.
- No new measurements beyond router reachability.
- No new localization, accessibility, Reduce Motion, or historical-evidence compatibility work beyond what the new UI requires.
- Repository-facing artifacts (code, docs, messages) are written in English.
- Verification uses `xcodebuild` only — never `swift build` / `swift test`. Do not run UI test bundles.
- Do not commit without explicit user instruction. If the user requests commits, ask exactly `Run the checks relevant to this commit before committing?` before each one and follow the consent protocol in `.agents/references/collaboration-rules.md`.

---

### Task 1: Check ID and Gateway Reachability Check

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/NetworkDiagnostics/NetworkDiagnosticModels.swift:3` (add enum case)
- Modify: `WiFiLens/Sources/WiFiLens/NetworkDiagnostics/NetworkConnectivityCheck.swift` (strip gateway latency; add `GatewayReachabilityCheck`)
- Modify: `WiFiLens/Sources/WiFiLens/NetworkDiagnostics/DiagnosticRunner.swift:95-115` (exhaustive switch keeps compiling)
- Modify: `WiFiLens/Sources/WiFiLens/NetworkDiagnostics/NetworkDiagnosticsView.swift:410-435` (`checkTitle` / `checkIcon` exhaustive switches)
- Test: `WiFiLens/Tests/WiFiLensTests/NetworkDiagnostics/NetworkDiagnosticsTests.swift`

**Interfaces:**
- Consumes: `NetworkInterfaceInfoSourcing`, `GatewayLatencyProviding`, `GatewayLatencyResult`, `NetworkInterfaceInfo`, `StubPathSource`, `StubNetworkInterfaceSource`, `StubGatewayLatencyProvider`, `makeNetworkInterface(router:)` (all existing).
- Produces:
  - `NetworkDiagnosticCheckID.gatewayReachability` (raw value `"gatewayReachability"`, declared between `.path` and `.dns` so `allCases` order is `[.path, .gatewayReachability, .dns, .internet, .ipv6, .proxy]`).
  - `GatewayReachabilityCheck: DiagnosticCheck` with `let id = NetworkDiagnosticCheckID.gatewayReachability` and `init(interfaceSource: any NetworkInterfaceInfoSourcing = SystemNetworkInterfaceInfoSource(), gatewayLatency: any GatewayLatencyProviding = GatewayLatencyProvider())`.
  - Evidence codes `gateway.latency-ms`, `gateway.unreachable`, `gateway.unavailable`.

- [ ] **Step 1: Update the identifier-order test (red)**

In `NetworkDiagnosticsTests.swift`, replace `diagnosticIdentifierOrder`:

```swift
@Test("diagnostic identifiers keep path and internet distinct in execution order")
func diagnosticIdentifierOrder() {
    #expect(NetworkDiagnosticCheckID.allCases == [.path, .gatewayReachability, .dns, .internet, .ipv6, .proxy])
    #expect(NetworkDiagnosticCheckID.path != .internet)
    #expect(Set(NetworkDiagnosticCheckID.allCases).count == 6)
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests`

Expected: FAIL — compile error `cannot find 'gatewayReachability' in scope`.

- [ ] **Step 3: Add the check ID (green)**

In `NetworkDiagnosticModels.swift`, change the enum to:

```swift
enum NetworkDiagnosticCheckID: String, CaseIterable, Equatable, Hashable, Sendable {
    case path, gatewayReachability, dns, internet, ipv6, proxy
}
```

- [ ] **Step 4: Keep the exhaustive switches compiling**

In `DiagnosticRunner.swift`, inside `blockingResult`'s `switch id`, add before `case .dns:`:

```swift
        case .gatewayReachability:
            [.init(id: .path, blockingStatuses: hardFailureStatuses)]
```

In `NetworkDiagnosticsView.swift`, in `checkTitle(_:)` add before `case .dns:`:

```swift
        case .gatewayReachability:
            String(localized: "network_diagnostics.check.gateway_reachability.title", comment: "Gateway reachability check title")
```

In `NetworkDiagnosticsView.swift`, in `checkIcon(_:)` add before `case .dns:`:

```swift
        case .gatewayReachability: "point.3.connected.trianglepath.dotted"
```

- [ ] **Step 5: Run the identifier-order test**

Run the command from Step 2. Expected: PASS.

- [ ] **Step 6: Replace the gateway tests (red)**

In `NetworkDiagnosticsTests.swift`, delete `pathCheckRecordsGatewayEvidence` and `gatewayFailureIsAdvisory`, and add:

```swift
@Test("gateway reachability check succeeds with latency evidence")
func gatewayReachabilitySuccess() async {
    let result = await GatewayReachabilityCheck(
        interfaceSource: StubNetworkInterfaceSource(interface: makeNetworkInterface(router: "192.0.2.1")),
        gatewayLatency: StubGatewayLatencyProvider(result: GatewayLatencyResult(
            timestamp: Date(),
            routerIP: "192.0.2.1",
            latencyMs: 2.5
        ))
    ).run()

    #expect(result.id == .gatewayReachability)
    #expect(result.status == .normal)
    #expect(result.evidence.contains(.init(code: "gateway.latency-ms", value: "2.5")))
}

@Test("gateway nonresponse fails the gateway reachability check")
func gatewayNonresponseFailsCheck() async {
    let result = await GatewayReachabilityCheck(
        interfaceSource: StubNetworkInterfaceSource(interface: makeNetworkInterface(router: "192.0.2.1")),
        gatewayLatency: StubGatewayLatencyProvider(result: GatewayLatencyResult(
            timestamp: Date(),
            routerIP: "192.0.2.1",
            error: .gatewayPingFailed("192.0.2.1")
        ))
    ).run()

    #expect(result.status == .abnormal)
    #expect(result.evidence.contains(.init(code: "gateway.unreachable", value: "192.0.2.1")))
}

@Test("gateway reachability is indeterminate without a router IP")
func gatewayReachabilityWithoutRouterIP() async {
    let result = await GatewayReachabilityCheck(
        interfaceSource: StubNetworkInterfaceSource(interface: makeNetworkInterface(router: nil)),
        gatewayLatency: StubGatewayLatencyProvider(result: GatewayLatencyResult(
            timestamp: Date(),
            error: .missingRouterIP
        ))
    ).run()

    #expect(result.status == .indeterminate)
    #expect(result.evidence.contains(.init(code: "gateway.unavailable", value: nil)))
}

@Test("path check keeps interface evidence without gateway latency")
func pathCheckKeepsInterfaceEvidence() async {
    let result = await NetworkConnectivityCheck(
        pathSource: StubPathSource(.satisfied),
        interfaceSource: StubNetworkInterfaceSource(interface: makeNetworkInterface(router: "192.0.2.1"))
    ).run()

    #expect(result.status == .normal)
    #expect(result.evidence.contains(.init(code: "path.interface", value: "en0")))
    #expect(result.evidence.contains(.init(code: "path.local-ip", value: "192.0.2.10")))
    #expect(result.evidence.contains(.init(code: "path.router", value: "192.0.2.1")))
    #expect(!result.evidence.contains { $0.code.hasPrefix("gateway.") })
}
```

- [ ] **Step 7: Run the tests to verify they fail**

Run the command from Step 2. Expected: FAIL — compile error `cannot find 'GatewayReachabilityCheck' in scope`.

- [ ] **Step 8: Implement `GatewayReachabilityCheck` and strip the path check (green)**

In `NetworkConnectivityCheck.swift`:

1. Remove the `gatewayLatency` stored property, its `init` parameter, and the `import`-less `let gateway = await gatewayLatency.measure(...)` call in `run()`. The `init` becomes:

```swift
    init(
        pathSource: any NetworkPathChecking = SystemNetworkPathChecker(),
        interfaceSource: any NetworkInterfaceInfoSourcing = SystemNetworkInterfaceInfoSource(),
        timeout: Duration = .seconds(3)
    ) {
        self.pathSource = pathSource
        self.interfaceSource = interfaceSource
        self.timeout = timeout
    }
```

2. Change `run()` to:

```swift
    func run() async -> NetworkDiagnosticResult {
        let state = await pathSource.currentState(timeout: timeout)
        let pathEvidence = await pathSource.diagnosticEvidence(timeout: timeout)
        let interface = await interfaceSource.currentInterface()
        let evidence = pathEvidence + self.pathEvidence(interface: interface)
        return switch state {
        case .satisfied:
            NetworkDiagnosticResult(
                id: id,
                status: .normal,
                summary: String(
                    localized: "network_diagnostics.path.normal.summary",
                    comment: "Network self-check system path success summary"
                ),
                detail: String(
                    localized: "network_diagnostics.path.normal.summary",
                    comment: "Network self-check system path success detail"
                ),
                evidence: evidence
            )
        case .unsatisfied:
            NetworkDiagnosticResult(
                id: id,
                status: .abnormal,
                summary: String(localized: "network_diagnostics.path.abnormal.summary", comment: "Network self-check system path failure summary"),
                evidence: evidence
            )
        case .requiresConnection, nil:
            NetworkDiagnosticResult(
                id: id,
                status: .indeterminate,
                summary: String(localized: "network_diagnostics.path.indeterminate.summary", comment: "Network self-check system path indeterminate summary"),
                evidence: evidence
            )
        }
    }
```

3. Replace `pathEvidence(interface:gateway:)` with:

```swift
    private func pathEvidence(interface: NetworkInterfaceInfo?) -> [NetworkDiagnosticEvidence] {
        var evidence: [NetworkDiagnosticEvidence] = []
        if let interface {
            evidence.append(.init(code: "path.interface", value: interface.interfaceName))
            if let address = interface.ipv4Addresses.first {
                evidence.append(.init(code: "path.local-ip", value: address))
            }
            if let subnet = interface.subnetMasks.first {
                evidence.append(.init(code: "path.subnet-mask", value: subnet))
            }
            if let router = interface.router {
                evidence.append(.init(code: "path.router", value: router))
            }
            if let dns = interface.dnsServers.first {
                evidence.append(.init(code: "path.dns-server", value: dns))
            }
        }
        return evidence
    }
```

4. Append the new check at the end of the file:

```swift
struct GatewayReachabilityCheck: DiagnosticCheck {
    let id = NetworkDiagnosticCheckID.gatewayReachability
    private let interfaceSource: any NetworkInterfaceInfoSourcing
    private let gatewayLatency: any GatewayLatencyProviding

    init(
        interfaceSource: any NetworkInterfaceInfoSourcing = SystemNetworkInterfaceInfoSource(),
        gatewayLatency: any GatewayLatencyProviding = GatewayLatencyProvider()
    ) {
        self.interfaceSource = interfaceSource
        self.gatewayLatency = gatewayLatency
    }

    func run() async -> NetworkDiagnosticResult {
        let interface = await interfaceSource.currentInterface()
        let gateway = await gatewayLatency.measure(routerIP: interface?.router)

        if let latency = gateway.latencyMs {
            return NetworkDiagnosticResult(
                id: id,
                status: .normal,
                summary: String(
                    localized: "network_diagnostics.gateway.normal.summary",
                    comment: "Network self-check gateway reachability success summary"
                ),
                evidence: [.init(code: "gateway.latency-ms", value: String(latency))]
            )
        }
        if let router = gateway.routerIP {
            return NetworkDiagnosticResult(
                id: id,
                status: .abnormal,
                summary: String(
                    localized: "network_diagnostics.gateway.abnormal.summary",
                    comment: "Network self-check gateway reachability failure summary"
                ),
                evidence: [.init(code: "gateway.unreachable", value: router)]
            )
        }
        return NetworkDiagnosticResult(
            id: id,
            status: .indeterminate,
            summary: String(
                localized: "network_diagnostics.gateway.indeterminate.summary",
                comment: "Network self-check gateway reachability indeterminate summary"
            ),
            evidence: [.init(code: "gateway.unavailable", value: nil)]
        )
    }
}
```

- [ ] **Step 9: Run the tests**

Run the command from Step 2. Expected: PASS (gateway tests, path tests, and identifier order).

- [ ] **Step 10: Commit checkpoint**

Do not commit. If the user requested commits for this plan, ask `Run the checks relevant to this commit before committing?`, then commit with message `feat(network-diagnostics): add gateway reachability check`.

---

### Task 2: Runner Order, Dependencies, and Conclusion Participation

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/NetworkDiagnostics/NetworkDiagnosticsViewModel.swift:85-100` (default checks array)
- Modify: `WiFiLens/Sources/WiFiLens/NetworkDiagnostics/NetworkDiagnosticModels.swift:168-175` (`primaryIssue` priority)
- Test: `WiFiLens/Tests/WiFiLensTests/NetworkDiagnostics/NetworkDiagnosticsTests.swift`

**Interfaces:**
- Consumes: `DiagnosticRunner(checks:minimumStepDuration:sessionBudget:)`, `StubDiagnosticCheck(id:result:)`, `NetworkDiagnosticConclusion.evaluate(_:requiredIDs:)`, `NetworkDiagnosticConclusion.primaryIssue(in:)`, `NetworkDiagnosticResult`.
- Produces: default `NetworkDiagnosticsViewModel` check order `[NetworkConnectivityCheck(), GatewayReachabilityCheck(), DNSResolutionCheck(), HTTPSControlEndpointCheck(), IPv6ControlEndpointCheck(), SystemProxyCheck()]`; `gatewayReachability` blocked by `path` hard failure; `primaryIssue` priority `[.path, .gatewayReachability, .dns, .internet, .proxy]`.

- [ ] **Step 1: Write the runner and conclusion tests (red)**

Add to `NetworkDiagnosticsTests.swift`:

```swift
@Test("runner blocks gateway reachability after a hard path failure")
func runnerBlocksGatewayReachabilityAfterPathFailure() async {
    let checks: [any DiagnosticCheck] = [
        StubDiagnosticCheck(id: .path, result: NetworkDiagnosticResult(id: .path, status: .abnormal, summary: "no path")),
        StubDiagnosticCheck(id: .gatewayReachability, result: NetworkDiagnosticResult(id: .gatewayReachability, status: .normal, summary: "unused")),
        StubDiagnosticCheck(id: .dns, result: NetworkDiagnosticResult(id: .dns, status: .normal, summary: "unused")),
    ]
    let runner = DiagnosticRunner(checks: checks, minimumStepDuration: .zero)

    let results = await runner.run { _ in }

    #expect(results.map(\.id) == [.path, .gatewayReachability, .dns])
    #expect(results[1].status == .blocked)
    #expect(results[1].evidence.contains(.init(code: "blocked.by", value: "path")))
}

@Test("gateway reachability abnormal does not block downstream checks")
func gatewayReachabilityAbnormalDoesNotBlockDownstream() async {
    let checks: [any DiagnosticCheck] = NetworkDiagnosticCheckID.allCases.map { id in
        let status: NetworkDiagnosticStatus = id == .gatewayReachability ? .abnormal : .normal
        return StubDiagnosticCheck(id: id, result: NetworkDiagnosticResult(id: id, status: status, summary: id.rawValue))
    }
    let runner = DiagnosticRunner(checks: checks, minimumStepDuration: .zero)

    let results = await runner.run { _ in }

    #expect(results.map(\.id) == NetworkDiagnosticCheckID.allCases)
    #expect(results[1].status == .abnormal)
    #expect(results[2].status == .normal)
    #expect(results[3].status == .normal)
    #expect(results[4].status == .normal)
}

@Test("gateway reachability abnormal drives the needs attention conclusion")
func gatewayReachabilityDrivesNeedsAttention() {
    let results = [
        NetworkDiagnosticResult(id: .path, status: .normal, summary: ""),
        NetworkDiagnosticResult(id: .gatewayReachability, status: .abnormal, summary: ""),
        NetworkDiagnosticResult(id: .dns, status: .normal, summary: ""),
        NetworkDiagnosticResult(id: .internet, status: .normal, summary: ""),
        NetworkDiagnosticResult(id: .ipv6, status: .skipped, summary: ""),
        NetworkDiagnosticResult(id: .proxy, status: .normal, summary: ""),
    ]

    #expect(NetworkDiagnosticConclusion.evaluate(results) == .needsAttention)
    #expect(NetworkDiagnosticConclusion.primaryIssue(in: results)?.id == .gatewayReachability)
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests`

Expected: FAIL — `primaryIssue` returns `nil` (or `.dns`-independent behavior), so the third test fails on `primaryIssue`; the first two pass because Task 1 already wired the dependency.

- [ ] **Step 3: Implement the conclusion participation (green)**

In `NetworkDiagnosticModels.swift`, change `primaryIssue`'s priority list to:

```swift
        let priority: [NetworkDiagnosticCheckID] = [.path, .gatewayReachability, .dns, .internet, .proxy]
```

In the same file, exclude `.ipv6` from `evaluate`'s non-normal rule so a
skipped or failed IPv6 probe never changes the overall conclusion:

```swift
        if resultsByID.values.contains(where: { result in
            result.status != .normal
                && result.id != .ipv6
                && !isUnverifiedDirectRouteNeutral(
                    result,
                    internet: resultsByID[.internet]
                )
        }) {
            return .needsAttention
        }
```

- [ ] **Step 4: Run the tests**

Run the command from Step 2. Expected: PASS.

- [ ] **Step 5: Update the view model's default checks**

In `NetworkDiagnosticsViewModel.swift`, change the default `init` checks array to:

```swift
    init(checks: [any DiagnosticCheck] = [
        NetworkConnectivityCheck(),
        GatewayReachabilityCheck(),
        DNSResolutionCheck(),
        HTTPSControlEndpointCheck(),
        IPv6ControlEndpointCheck(),
        SystemProxyCheck(),
    ],
```

- [ ] **Step 6: Commit checkpoint**

Do not commit. If the user requested commits, ask `Run the checks relevant to this commit before committing?`, then commit with message `feat(network-diagnostics): run gateway reachability before dns and surface it in the conclusion`.

---

### Task 3: Stage Model and Resolver

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/NetworkDiagnostics/NetworkDiagnosticModels.swift`
- Test: `WiFiLens/Tests/WiFiLensTests/NetworkDiagnostics/NetworkDiagnosticsTests.swift`

**Interfaces:**
- Consumes: `NetworkDiagnosticCheckID`, `NetworkDiagnosticResult`, `NetworkDiagnosticStatus`.
- Produces:
  - `NetworkDiagnosticStage: CaseIterable, Equatable, Sendable` with cases `thisMac`, `lan`, `internet` and `var contributingCheckIDs: [NetworkDiagnosticCheckID]` (`thisMac → [.path, .dns, .proxy]`, `lan → [.gatewayReachability]`, `internet → [.internet]`).
  - `NetworkDiagnosticStageResolver: Sendable` with `func status(for:results:) -> NetworkDiagnosticStatus?`.

- [ ] **Step 1: Write the resolver tests (red)**

Add to `NetworkDiagnosticsTests.swift`:

```swift
@Test("stage resolver aggregates this mac from path dns and proxy and maps lan to its check")
func stageResolverThisMacAndLan() {
    let resolver = NetworkDiagnosticStageResolver()
    let abnormalDNS: [NetworkDiagnosticCheckID: NetworkDiagnosticResult] = [
        .path: .init(id: .path, status: .normal, summary: ""),
        .dns: .init(id: .dns, status: .abnormal, summary: ""),
        .proxy: .init(id: .proxy, status: .normal, summary: ""),
        .gatewayReachability: .init(id: .gatewayReachability, status: .normal, summary: ""),
    ]

    #expect(resolver.status(for: .thisMac, results: abnormalDNS) == .abnormal)
    #expect(resolver.status(for: .lan, results: abnormalDNS) == .normal)
    let proxyOnly: [NetworkDiagnosticCheckID: NetworkDiagnosticResult] = [
        .path: .init(id: .path, status: .normal, summary: ""),
        .dns: .init(id: .dns, status: .normal, summary: ""),
        .proxy: .init(id: .proxy, status: .abnormal, summary: ""),
        .gatewayReachability: .init(id: .gatewayReachability, status: .normal, summary: ""),
    ]
    #expect(resolver.status(for: .thisMac, results: proxyOnly) == .abnormal)
    #expect(resolver.status(for: .thisMac, results: [:]) == nil)
    let missingContributors: [NetworkDiagnosticCheckID: NetworkDiagnosticResult] = [
        .path: .init(id: .path, status: .normal, summary: ""),
    ]
    #expect(resolver.status(for: .thisMac, results: missingContributors) == nil)
}

@Test("internet stage follows the internet check and ignores dns and ipv6")
func stageResolverInternet() {
    let resolver = NetworkDiagnosticStageResolver()

    #expect(resolver.status(for: .internet, results: [.internet: .init(id: .internet, status: .normal, summary: "")]) == .normal)
    #expect(resolver.status(for: .internet, results: [.internet: .init(id: .internet, status: .abnormal, summary: "")]) == .abnormal)
    #expect(resolver.status(for: .internet, results: [.internet: .init(id: .internet, status: .indeterminate, summary: "")]) == .indeterminate)
    #expect(resolver.status(for: .internet, results: [.internet: .init(id: .internet, status: .blocked, summary: "")]) == .blocked)
    let extras: [NetworkDiagnosticCheckID: NetworkDiagnosticResult] = [
        .internet: .init(id: .internet, status: .normal, summary: ""),
        .dns: .init(id: .dns, status: .abnormal, summary: ""),
        .ipv6: .init(id: .ipv6, status: .abnormal, summary: ""),
    ]
    #expect(resolver.status(for: .internet, results: extras) == .normal)
}

@Test("internet stage requires the internet result")
func stageResolverRequiresInternetResult() {
    let resolver = NetworkDiagnosticStageResolver()
    let partial: [NetworkDiagnosticCheckID: NetworkDiagnosticResult] = [
        .dns: .init(id: .dns, status: .normal, summary: ""),
    ]

    #expect(resolver.status(for: .internet, results: partial) == nil)
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests`

Expected: FAIL — compile error `cannot find 'NetworkDiagnosticStage' in scope`.

- [ ] **Step 3: Implement the stage model and resolver (green)**

Append to `NetworkDiagnosticModels.swift`:

```swift
enum NetworkDiagnosticStage: CaseIterable, Equatable, Sendable {
    case thisMac
    case lan
    case internet

    var contributingCheckIDs: [NetworkDiagnosticCheckID] {
        switch self {
        case .thisMac: [.path, .dns, .proxy]
        case .lan: [.gatewayReachability]
        case .internet: [.internet]
        }
    }
}

struct NetworkDiagnosticStageResolver: Sendable {
    func status(
        for stage: NetworkDiagnosticStage,
        results: [NetworkDiagnosticCheckID: NetworkDiagnosticResult]
    ) -> NetworkDiagnosticStatus? {
        let contributingIDs = stage.contributingCheckIDs
        let contributing = contributingIDs.compactMap { results[$0] }
        guard contributing.count == contributingIDs.count else { return nil }

        if contributing.contains(where: { $0.status == .abnormal }) {
            return .abnormal
        }
        if contributing.contains(where: { $0.status == .indeterminate }) {
            return .indeterminate
        }
        if contributing.allSatisfy({ $0.status == .blocked }) {
            return .blocked
        }
        return .normal
    }
}
```

- [ ] **Step 4: Run the tests**

Run the command from Step 2. Expected: PASS.

- [ ] **Step 5: Commit checkpoint**

Do not commit. If the user requested commits, ask `Run the checks relevant to this commit before committing?`, then commit with message `feat(network-diagnostics): add stage model and derived stage status resolver`.

---

### Task 4: Workbench Table Grouping

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/NetworkDiagnostics/NetworkDiagnosticsViewModel.swift:28-55` (`NetworkDiagnosticsPresentation`)
- Modify: `WiFiLens/Sources/WiFiLens/NetworkDiagnostics/NetworkDiagnosticsView.swift` (table cells and helpers)
- Test: `WiFiLens/Tests/WiFiLensTests/NetworkDiagnostics/NetworkDiagnosticsTests.swift`

**Interfaces:**
- Consumes: `NetworkDiagnosticsWorkbenchRow`, `NetworkDiagnosticsPagePhase`, `NetworkDiagnosticsExecutionPhase`, `NetworkDiagnosticStage`, `NetworkDiagnosticStageResolver`, `NetworkDiagnosticResult`, `NetworkDiagnosticCheckID`.
- Produces:
  - `NetworkDiagnosticsWorkbenchItem: Equatable, Identifiable` with cases `.stageHeader(NetworkDiagnosticStage)`, `.additionalHeader`, `.check(NetworkDiagnosticsWorkbenchRow)` and string `id`s `"header.thisMac"` / `"header.lan"` / `"header.internet"` / `"header.additional"` / `"check.<rawValue>"`.
  - `NetworkDiagnosticsPresentation.stage(for: NetworkDiagnosticCheckID) -> NetworkDiagnosticStage?`.
  - `NetworkDiagnosticsPresentation.workbenchItems(pagePhase:executionPhases:results:checkIDs:) -> [NetworkDiagnosticsWorkbenchItem]`.

- [ ] **Step 1: Replace the workbench-rows test (red)**

In `NetworkDiagnosticsTests.swift`, replace the existing `workbenchRows` test (`workbenchRowsReveal...`) with:

```swift
@Test("workbench items interleave stage headers with check rows")
func workbenchItemGrouping() {
    let path = NetworkDiagnosticResult(id: .path, status: .normal, summary: "connected")
    let executionPhases: [NetworkDiagnosticCheckID: NetworkDiagnosticExecutionPhase] = [
        .path: .completed,
        .dns: .checking,
        .proxy: .waiting,
    ]

    #expect(NetworkDiagnosticsPresentation.workbenchItems(
        pagePhase: .idle,
        executionPhases: executionPhases,
        results: [:]
    ).isEmpty)

    let runningItems = NetworkDiagnosticsPresentation.workbenchItems(
        pagePhase: .running,
        executionPhases: executionPhases,
        results: [.path: path],
        checkIDs: [.path, .dns, .proxy]
    )
    #expect(runningItems.map(\.id) == ["header.thisMac", "check.path", "check.dns"])
    #expect(runningItems[0] == .stageHeader(.thisMac))
    #expect(runningItems[1] == .check(.init(id: .path, executionPhase: .completed, result: path)))

    let completedResults = Dictionary(uniqueKeysWithValues: makeResults(
        path: .normal,
        dns: .abnormal,
        internet: .normal,
        ipv6: .skipped,
        proxy: .indeterminate
    ).map { ($0.id, $0) })
    let completedItems = NetworkDiagnosticsPresentation.workbenchItems(
        pagePhase: .completed,
        executionPhases: executionPhases,
        results: completedResults,
        checkIDs: [.path, .dns, .ipv6, .proxy]
    )
    #expect(completedItems.map(\.id) == [
        "header.thisMac", "check.path", "check.dns", "check.proxy",
        "header.additional", "check.ipv6",
    ])
    #expect(completedItems[4] == .additionalHeader)
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests`

Expected: FAIL — compile error `cannot find 'NetworkDiagnosticsWorkbenchItem' in scope`.

- [ ] **Step 3: Implement the grouping presentation (green)**

In `NetworkDiagnosticsViewModel.swift`, add above `NetworkDiagnosticsPresentation`:

```swift
enum NetworkDiagnosticsWorkbenchItem: Equatable, Identifiable {
    case stageHeader(NetworkDiagnosticStage)
    case additionalHeader
    case check(NetworkDiagnosticsWorkbenchRow)

    var id: String {
        switch self {
        case .stageHeader(let stage): "header.\(String(describing: stage))"
        case .additionalHeader: "header.additional"
        case .check(let row): "check.\(row.id.rawValue)"
        }
    }
}
```

Inside `NetworkDiagnosticsPresentation`, add after `workbenchRows`:

```swift
    static func stage(for checkID: NetworkDiagnosticCheckID) -> NetworkDiagnosticStage? {
        switch checkID {
        case .path, .dns, .proxy: .thisMac
        case .gatewayReachability: .lan
        case .internet: .internet
        case .ipv6: nil
        }
    }

    static func workbenchItems(
        pagePhase: NetworkDiagnosticsPagePhase,
        executionPhases: [NetworkDiagnosticCheckID: NetworkDiagnosticExecutionPhase],
        results: [NetworkDiagnosticCheckID: NetworkDiagnosticResult],
        checkIDs: [NetworkDiagnosticCheckID] = NetworkDiagnosticCheckID.allCases
    ) -> [NetworkDiagnosticsWorkbenchItem] {
        let rows = workbenchRows(
            pagePhase: pagePhase,
            executionPhases: executionPhases,
            results: results,
            checkIDs: checkIDs
        )
        guard !rows.isEmpty else { return [] }

        var items: [NetworkDiagnosticsWorkbenchItem] = []
        for currentStage in NetworkDiagnosticStage.allCases {
            let stageRows = rows.filter { stage(for: $0.id) == currentStage }
            if stageRows.isEmpty { continue }
            items.append(.stageHeader(currentStage))
            items.append(contentsOf: stageRows.map { .check($0) })
        }
        let additionalRows = rows.filter { stage(for: $0.id) == nil }
        if !additionalRows.isEmpty {
            items.append(.additionalHeader)
            items.append(contentsOf: additionalRows.map { .check($0) })
        }
        return items
    }
```

- [ ] **Step 4: Render group headers in the table**

In `NetworkDiagnosticsView.swift`:

1. Change the `workbenchRows` computed property to:

```swift
    private var workbenchItems: [NetworkDiagnosticsWorkbenchItem] {
        NetworkDiagnosticsPresentation.workbenchItems(
            pagePhase: viewModel.phase,
            executionPhases: viewModel.executionPhases,
            results: viewModel.results,
            checkIDs: viewModel.checkIDs
        )
    }
```

2. In `resultTable(_:)`, replace every `Table(workbenchRows)` with `Table(workbenchItems)`, and change each column closure parameter from `row` to `item`, calling the new item-based cells:

```swift
            case .regular:
                Table(workbenchItems) {
                    TableColumn(columnCheckTitle) { item in
                        checkCell(item)
                            .padding(.vertical, 7)
                    }
                    .width(min: 150, ideal: 190)

                    TableColumn(columnStatusTitle) { item in
                        statusCell(item)
                            .padding(.vertical, 7)
                    }
                    .width(min: 112, ideal: 132)

                    TableColumn(columnResultTitle) { item in
                        resultCell(item)
                            .padding(.vertical, 7)
                    }
                }
```

The `condensed` and `compact` modes use the same `item` pattern (`checkCell(item)` / `statusCell(item)` / `resultCell(item)`), keeping their existing VStack/HStack structure.

3. Add the item-based cell overloads and header views (place them next to the existing `checkCell` / `statusCell` / `resultCell`):

```swift
    @ViewBuilder
    private func checkCell(_ item: NetworkDiagnosticsWorkbenchItem) -> some View {
        switch item {
        case .stageHeader(let stage): stageHeaderCell(stage)
        case .additionalHeader: additionalHeaderCell
        case .check(let row): checkCell(row)
        }
    }

    @ViewBuilder
    private func statusCell(_ item: NetworkDiagnosticsWorkbenchItem) -> some View {
        switch item {
        case .stageHeader, .additionalHeader: EmptyView()
        case .check(let row): statusCell(row)
        }
    }

    @ViewBuilder
    private func resultCell(_ item: NetworkDiagnosticsWorkbenchItem) -> some View {
        switch item {
        case .stageHeader, .additionalHeader: EmptyView()
        case .check(let row): resultCell(row)
        }
    }

    private func stageHeaderCell(_ stage: NetworkDiagnosticStage) -> some View {
        groupHeaderCell(
            id: "stage.\(String(describing: stage))",
            title: stageTitle(stage),
            icon: stageIcon(stage)
        )
    }

    private var additionalHeaderCell: some View {
        groupHeaderCell(id: "additional", title: additionalTitle, icon: "square.grid.2x2")
    }

    private func groupHeaderCell(id: String, title: String, icon: String) -> some View {
        Button {
            expandedGroupOverride[id] = !isExpanded(id: id, items: rawWorkbenchItems)
        } label: {
            HStack(spacing: 8) {
                Label {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: icon)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: isExpanded(id: id, items: rawWorkbenchItems) ? "chevron.down" : "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isHeader)
    }

    private var additionalTitle: String {
        String(localized: "network_diagnostics.stage.additional.title", comment: "Network self-check additional checks group title")
    }

    private func stageTitle(_ stage: NetworkDiagnosticStage) -> String {
        switch stage {
        case .thisMac:
            String(localized: "network_diagnostics.stage.this_mac.title", comment: "Network self-check local environment stage title")
        case .lan:
            String(localized: "network_diagnostics.stage.lan.title", comment: "Network self-check LAN connectivity stage title")
        case .internet:
            String(localized: "network_diagnostics.stage.internet.title", comment: "Network self-check internet connectivity stage title")
        }
    }

    private func stageIcon(_ stage: NetworkDiagnosticStage) -> String {
        switch stage {
        case .thisMac: "macbook"
        case .lan: "wifi"
        case .internet: "globe"
        }
    }

    private func stageStatusBadge(_ status: NetworkDiagnosticStatus) -> some View {
        Label(statusTitle(status), systemImage: statusIcon(status))
            .font(.caption2.weight(.medium))
            .foregroundStyle(statusColor(status))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor(status).opacity(0.10), in: Capsule())
    }
```

4. Make the groups collapsible. Group headers are plain buttons with a
   chevron and no status badge. Keep an override dictionary and filter
   collapsed groups' check rows out of `workbenchItems`:

```swift
    @State private var expandedGroupOverride: [String: Bool] = [:]
```

   A group is expanded unless the user collapsed it or, after completion, all
   of its rows are `.normal` / `.skipped` (then it defaults to collapsed).
   While running, every group stays expanded so the reveal of completed and
   active checks is unaffected. The view never mutates presentation state
   produced by `NetworkDiagnosticsPresentation`; filtering happens only in the
   view's `workbenchItems` projection.

Note: `statusTitle(_:)`, `statusIcon(_:)`, and `statusColor(_:)` already exist in `NetworkDiagnosticsView`; the new code reuses them.

- [ ] **Step 5: Run the tests**

Run the command from Step 2. Expected: PASS.

- [ ] **Step 6: Build check**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build`

Expected: BUILD SUCCEEDED.

- [ ] **Step 7: Commit checkpoint**

Do not commit. If the user requested commits, ask `Run the checks relevant to this commit before committing?`, then commit with message `feat(network-diagnostics): group workbench table by diagnostic stage`.

---

### Task 5: Pipeline Diagram

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/NetworkDiagnostics/NetworkDiagnosticsView.swift`
- Test: `WiFiLens/Tests/WiFiLensTests/NetworkDiagnostics/NetworkDiagnosticsTests.swift`

**Interfaces:**
- Consumes: `NetworkDiagnosticStageResolver`, `NetworkDiagnosticStage`, `NetworkDiagnosticStatus.presentation`, `NetworkDiagnosticResult`, `NetworkDiagnosticExecutionPhase`, `viewModel.results`, `viewModel.executionPhases`.
- Produces:
  - `NetworkDiagnosticsPipelinePresentation: Equatable, Sendable` with nested `Station` / `Edge` (both `Identifiable`), `static func from(results: [NetworkDiagnosticCheckID: NetworkDiagnosticResult], executionPhases: [NetworkDiagnosticCheckID: NetworkDiagnosticExecutionPhase], resolver: NetworkDiagnosticStageResolver = NetworkDiagnosticStageResolver()) -> Self`.
  - `NetworkDiagnosticsPipelineView: View` with `init(presentation: NetworkDiagnosticsPipelinePresentation)`.

- [ ] **Step 1: Write the presentation tests (red)**

Add to `NetworkDiagnosticsTests.swift`:

```swift
@Test("pipeline presentation maps stages to stations and edges")
func pipelinePresentation() {
    let results: [NetworkDiagnosticCheckID: NetworkDiagnosticResult] = [
        .path: .init(id: .path, status: .normal, summary: ""),
        .gatewayReachability: .init(id: .gatewayReachability, status: .abnormal, summary: ""),
        .dns: .init(id: .dns, status: .normal, summary: ""),
        .internet: .init(id: .internet, status: .normal, summary: ""),
        .ipv6: .init(id: .ipv6, status: .skipped, summary: ""),
        .proxy: .init(id: .proxy, status: .normal, summary: ""),
    ]
    let presentation = NetworkDiagnosticsPipelinePresentation.from(
        results: results,
        executionPhases: [:]
    )

    #expect(presentation.stations.map(\.kind) == [.thisMac, .router, .internet])
    #expect(presentation.edges.map(\.kind) == [.lan, .internet])
    #expect(presentation.stations[0].status == .normal)
    #expect(presentation.stations[1].status == .abnormal)
    #expect(presentation.stations[1].isUnreachable)
    #expect(presentation.stations[2].status == .normal)
    #expect(!presentation.stations[2].isUnreachable)
    #expect(presentation.edges[0].status == .abnormal)
    #expect(presentation.edges[1].status == .normal)
}

@Test("pipeline edge becomes active while its checks are running")
func pipelineEdgeActive() {
    let executionPhases: [NetworkDiagnosticCheckID: NetworkDiagnosticExecutionPhase] = [
        .gatewayReachability: .checking,
    ]
    let presentation = NetworkDiagnosticsPipelinePresentation.from(
        results: [:],
        executionPhases: executionPhases
    )

    #expect(presentation.edges[0].isActive)
    #expect(!presentation.edges[1].isActive)
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests`

Expected: FAIL — compile error `cannot find 'NetworkDiagnosticsPipelinePresentation' in scope`.

- [ ] **Step 3: Implement the projection and the view (green)**

Append to `NetworkDiagnosticsView.swift` (after the `NetworkDiagnosticsView` type):

```swift
struct NetworkDiagnosticsPipelinePresentation: Equatable, Sendable {
    enum StationKind: Hashable, Equatable, Sendable {
        case thisMac
        case router
        case internet
    }

    enum EdgeKind: Hashable, Equatable, Sendable {
        case lan
        case internet
    }

    struct Station: Equatable, Identifiable, Sendable {
        let kind: StationKind
        let status: NetworkDiagnosticStatus?
        let isUnreachable: Bool

        var id: StationKind { kind }
    }

    struct Edge: Equatable, Identifiable, Sendable {
        let kind: EdgeKind
        let status: NetworkDiagnosticStatus?
        let isActive: Bool

        var id: EdgeKind { kind }
    }

    let stations: [Station]
    let edges: [Edge]

    static func from(
        results: [NetworkDiagnosticCheckID: NetworkDiagnosticResult],
        executionPhases: [NetworkDiagnosticCheckID: NetworkDiagnosticExecutionPhase],
        resolver: NetworkDiagnosticStageResolver = NetworkDiagnosticStageResolver()
    ) -> Self {
        let thisMac = resolver.status(for: .thisMac, results: results)
        let lan = resolver.status(for: .lan, results: results)
        let internet = resolver.status(for: .internet, results: results)

        let stations = [
            Station(kind: .thisMac, status: thisMac, isUnreachable: false),
            Station(kind: .router, status: lan, isUnreachable: lan == .abnormal || lan == .blocked),
            Station(kind: .internet, status: internet, isUnreachable: internet == .abnormal || internet == .blocked),
        ]
        let edges = [
            Edge(kind: .lan, status: lan, isActive: isActive(stage: .lan, executionPhases: executionPhases)),
            Edge(kind: .internet, status: internet, isActive: isActive(stage: .internet, executionPhases: executionPhases)),
        ]
        return Self(stations: stations, edges: edges)
    }

    private static func isActive(
        stage: NetworkDiagnosticStage,
        executionPhases: [NetworkDiagnosticCheckID: NetworkDiagnosticExecutionPhase]
    ) -> Bool {
        stage.contributingCheckIDs.contains { executionPhases[$0] == .checking }
    }
}

struct NetworkDiagnosticsPipelineView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let presentation: NetworkDiagnosticsPipelinePresentation

    var body: some View {
        HStack(spacing: 0) {
            station(presentation.stations[0])
            edge(presentation.edges[0])
            station(presentation.stations[1])
            edge(presentation.edges[1])
            station(presentation.stations[2])
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private func station(_ station: NetworkDiagnosticsPipelinePresentation.Station) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .strokeBorder(
                        stationRingColor(station),
                        style: StrokeStyle(lineWidth: 2.5, dash: station.isUnreachable ? [5, 4] : [])
                    )
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(stationRingColor(station).opacity(0.10)))
                Image(systemName: stationIcon(station.kind))
                    .font(.system(size: 19))
                    .foregroundStyle(stationRingColor(station))
            }
            Text(stationTitle(station.kind))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
            if let status = station.status {
                Label(statusTitle(status), systemImage: statusIcon(status))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(statusColor(status))
            }
        }
        .frame(width: 110)
    }

    @ViewBuilder
    private func edge(_ edge: NetworkDiagnosticsPipelinePresentation.Edge) -> some View {
        VStack(spacing: 6) {
            edgeLabel(edge)
            rail(edge)
        }
        .frame(maxWidth: .infinity)
    }

    private func edgeLabel(_ edge: NetworkDiagnosticsPipelinePresentation.Edge) -> some View {
        HStack(spacing: 4) {
            Image(systemName: edgeIcon(edge.kind))
            Text(edgeTitle(edge.kind))
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(edgeColor(edge))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(edgeColor(edge).opacity(0.10), in: Capsule())
    }

    @ViewBuilder
    private func rail(_ edge: NetworkDiagnosticsPipelinePresentation.Edge) -> some View {
        let content = railContent(edge)
        if edge.isActive, !reduceMotion {
            SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let cycle = context.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 1.4) / 1.4
                content.opacity(0.45 + 0.55 * abs(cycle - 0.5) * 2)
            }
        } else {
            content
        }
    }

    private func railContent(_ edge: NetworkDiagnosticsPipelinePresentation.Edge) -> some View {
        let color = edgeColor(edge)
        let breakable = edge.status == .abnormal || edge.status == .indeterminate || edge.status == .blocked
        return ZStack {
            if breakable {
                HStack(spacing: 7) {
                    railLine(color: color, dashed: true)
                    Image(systemName: breakIcon(edge.status))
                        .font(.system(size: 13))
                        .foregroundStyle(color)
                    railLine(color: color, dashed: true)
                }
            } else {
                HStack(spacing: 0) {
                    railLine(color: color, dashed: false)
                    Image(systemName: "arrowtriangle.right.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(color)
                }
            }
        }
        .frame(height: 20)
    }

    private func railLine(color: Color, dashed: Bool) -> some View {
        Rectangle()
            .stroke(color, style: StrokeStyle(lineWidth: 3, dash: dashed ? [7, 5] : []))
            .frame(height: 3)
            .frame(maxWidth: .infinity)
    }

    private func edgeColor(_ edge: NetworkDiagnosticsPipelinePresentation.Edge) -> Color {
        if edge.isActive { return .accentColor }
        guard let status = edge.status else { return .secondary }
        return statusColor(status)
    }

    private func stationRingColor(_ station: NetworkDiagnosticsPipelinePresentation.Station) -> Color {
        if station.isUnreachable { return .secondary }
        guard let status = station.status else { return .secondary }
        return statusColor(status)
    }

    private func breakIcon(_ status: NetworkDiagnosticStatus?) -> String {
        switch status {
        case .abnormal: "xmark.circle.fill"
        case .indeterminate: "questionmark.circle.fill"
        case .blocked: "lock.fill"
        default: "xmark.circle.fill"
        }
    }

    private func stationIcon(_ kind: NetworkDiagnosticsPipelinePresentation.StationKind) -> String {
        switch kind {
        case .thisMac: "macbook"
        case .router: "wifi.router"
        case .internet: "globe"
        }
    }

    private func edgeIcon(_ kind: NetworkDiagnosticsPipelinePresentation.EdgeKind) -> String {
        switch kind {
        case .lan: "wifi"
        case .internet: "globe"
        }
    }

    private func stationTitle(_ kind: NetworkDiagnosticsPipelinePresentation.StationKind) -> String {
        switch kind {
        case .thisMac:
            String(localized: "network_diagnostics.stage.this_mac.title", comment: "Network self-check local environment stage title")
        case .router:
            String(localized: "network_diagnostics.diagram.router.title", comment: "Network self-check pipeline router station title")
        case .internet:
            String(localized: "network_diagnostics.stage.internet.title", comment: "Network self-check internet connectivity stage title")
        }
    }

    private func edgeTitle(_ kind: NetworkDiagnosticsPipelinePresentation.EdgeKind) -> String {
        switch kind {
        case .lan:
            String(localized: "network_diagnostics.stage.lan.title", comment: "Network self-check LAN connectivity stage title")
        case .internet:
            String(localized: "network_diagnostics.stage.internet.title", comment: "Network self-check internet connectivity stage title")
        }
    }

    private var accessibilityLabel: String {
        presentation.stations.map { station in
            let title = stationTitle(station.kind)
            guard let status = station.status else {
                return "\(title): \(String(localized: "network_diagnostics.state.waiting", comment: "Network self-check waiting state"))"
            }
            return "\(title): \(statusTitle(status))"
        }
        .joined(separator: ", ")
    }

    private func statusTitle(_ status: NetworkDiagnosticStatus) -> String {
        String(localized: .init(stringLiteral: status.presentation.labelKey), comment: "Network self-check status label")
    }

    private func statusIcon(_ status: NetworkDiagnosticStatus) -> String {
        status.presentation.icon
    }

    private func statusColor(_ status: NetworkDiagnosticStatus) -> Color {
        switch status.presentation.tone {
        case .success: .green
        case .error: .red
        case .caution: .orange
        case .informational: .blue
        case .muted: .secondary
        }
    }
}
```

- [ ] **Step 4: Wire the diagram into the workspace**

In `NetworkDiagnosticsView.swift`, change `workspace(_:)` to:

```swift
    @ViewBuilder
    private func workspace(_ mode: NetworkDiagnosticsWorkbenchLayoutMode) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            pipelineView
            if viewModel.phase == .idle {
                readyWorkspace
            } else {
                resultTable(mode)
            }
        }
    }

    private var pipelineView: some View {
        NetworkDiagnosticsPipelineView(
            presentation: NetworkDiagnosticsPipelinePresentation.from(
                results: viewModel.results,
                executionPhases: viewModel.executionPhases
            )
        )
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }
```

- [ ] **Step 5: Run the tests**

Run the command from Step 2. Expected: PASS.

- [ ] **Step 6: Build check**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build`

Expected: BUILD SUCCEEDED.

- [ ] **Step 7: Commit checkpoint**

Do not commit. If the user requested commits, ask `Run the checks relevant to this commit before committing?`, then commit with message `feat(network-diagnostics): add pipeline diagram with connectivity status on edges`.

---

### Task 6: Localization

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: `i18n-completer` scripts (`.agents/skills/i18n-completer/scripts/apply_i18n.py`, `scan_i18n.py`), glossary `.agents/skills/i18n-completer/references/LOCALIZATION_TERMS.md`.
- Produces: nine new keys with manual extraction state and `en` / `zh-Hans` / `ja` values; `de` / `es` intentionally fall back to `en`.

- [ ] **Step 1: Add the new keys through the i18n script**

Run:

```bash
cat <<'EOF' | python3 .agents/skills/i18n-completer/scripts/apply_i18n.py WiFiLens/Sources/WiFiLens/Resources/Localizable.xcstrings --from -
{
  "network_diagnostics.stage.this_mac.title": {
    "en": "This Mac",
    "zh-Hans": "本机环境",
    "ja": "このMac"
  },
  "network_diagnostics.stage.lan.title": {
    "en": "LAN",
    "zh-Hans": "局域网连通性",
    "ja": "LAN"
  },
  "network_diagnostics.stage.internet.title": {
    "en": "Internet",
    "zh-Hans": "互联网",
    "ja": "インターネット"
  },
  "network_diagnostics.stage.additional.title": {
    "en": "Additional Checks",
    "zh-Hans": "附加检测",
    "ja": "追加チェック"
  },
  "network_diagnostics.check.gateway_reachability.title": {
    "en": "Gateway Reachability",
    "zh-Hans": "网关可达性",
    "ja": "ゲートウェイ到達性"
  },
  "network_diagnostics.diagram.router.title": {
    "en": "Router",
    "zh-Hans": "路由器",
    "ja": "ルーター"
  },
  "network_diagnostics.gateway.normal.summary": {
    "en": "Gateway reachable",
    "zh-Hans": "网关可达",
    "ja": "ゲートウェイに到達"
  },
  "network_diagnostics.gateway.abnormal.summary": {
    "en": "Gateway unreachable",
    "zh-Hans": "网关不可达",
    "ja": "ゲートウェイに到達できません"
  },
  "network_diagnostics.gateway.indeterminate.summary": {
    "en": "Gateway reachability unknown",
    "zh-Hans": "网关状态未知",
    "ja": "ゲートウェイ到達性不明"
  }
}
EOF
```

Expected output: nine `ADD key [en/zh-Hans/ja]` lines. Confirm the script writes `"extractionState": "manual"` for the new entries.

- [ ] **Step 2: Validate the file and scan for gaps**

Run:

```bash
python3 -m json.tool WiFiLens/Sources/WiFiLens/Resources/Localizable.xcstrings > /dev/null && echo "JSON valid"
python3 .agents/skills/i18n-completer/scripts/scan_i18n.py WiFiLens/Sources/WiFiLens/Resources/Localizable.xcstrings
```

Expected: `JSON valid`; the scan reports no missing `en` / `zh-Hans` / `ja` values for the nine new keys. If the scan lists `de` / `es` for the new keys, accept them as documented fallbacks (the app's documented locales are `en`, `ja`, `zh-Hans`).

- [ ] **Step 3: Commit checkpoint**

Do not commit. If the user requested commits, ask `Run the checks relevant to this commit before committing?`, then commit with message `feat(network-diagnostics): add stage, gateway, and diagram localization`.

---

### Task 7: Test Suite Finalization

**Files:**
- Test: `WiFiLens/Tests/WiFiLensTests/NetworkDiagnostics/NetworkDiagnosticsTests.swift`

**Interfaces:**
- Consumes: all types produced by Tasks 1-6.
- Produces: a passing `WiFiLensTests` suite with no leftover assertions on removed behavior (`path.gateway-*` evidence, 5-check identifier set, flat `workbenchRows`).

- [ ] **Step 1: Audit the suite for stale assertions**

Run `rg -n "path\.gateway|workbenchRows|count == 5" WiFiLens/Tests/WiFiLensTests/NetworkDiagnostics/NetworkDiagnosticsTests.swift`.

Expected: no matches. If any remain, update them to the Task 1/4 equivalents (gateway evidence codes, `workbenchItems`, 6-check set).

- [ ] **Step 2: Run the full unit-test bundle**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests`

Expected: `** TEST SUCCEEDED **` with all tests passing, including the network-change rerun tests (which now run six checks).

- [ ] **Step 3: Commit checkpoint**

Do not commit. If the user requested commits, ask `Run the checks relevant to this commit before committing?`, then commit with message `test(network-diagnostics): finalize stage model test coverage`.

---

### Task 8: Documentation, Build, and Knowledge-Boundary Verification

**Files:**
- Modify: `.agents/references/project/ARCHITECTURE.md`

**Interfaces:**
- Consumes: the finished implementation, `verify-build` skill, `protect-knowledge-boundary` scripts.
- Produces: updated architecture reference and clean OSS + Pro Debug builds, unit tests, and knowledge-boundary scans.

- [ ] **Step 1: Update the architecture reference**

In `.agents/references/project/ARCHITECTURE.md`:

1. Update the `NetworkDiagnostics/` table row to mention the three-stage model, the gateway reachability check, and the derived stage status.
2. In the manual diagnostics paragraph, replace the five-check description with: six checks in order `path → gatewayReachability → dns → internet → ipv6 → proxy`; three stages (`This Mac`, `LAN`, `Internet`) whose status is derived from check results by `NetworkDiagnosticStageResolver`; a pipeline diagram that emphasizes connectivity status on the LAN/Internet connecting lines; and a workbench table grouped by stage with the proxy and DNS checks under This Mac and IPv6 under Additional Checks. Do not describe private Pro types or behavior.

- [ ] **Step 2: Run the canonical verification**

Run: `.agents/skills/verify-build/scripts/verify.sh`

Expected: OSS Debug build, Pro Debug build, and the `WiFiLensTests` unit bundle all succeed. (The script builds both schemes because the shared `NetworkDiagnostics/` sources compile into OSS and Pro.)

- [ ] **Step 3: Run the knowledge-boundary scans**

Run:

```bash
python3 .agents/skills/protect-knowledge-boundary/scripts/check_public_knowledge.py
python3 .agents/skills/protect-knowledge-boundary/scripts/verify_integrity.py
```

Expected: both scripts report no violations (the changes touch only public network-diagnostics code, the architecture reference, docs, and `AGENTS.md`).

- [ ] **Step 4: Verify no Pro submodule copies exist**

Run: `git -C Pro status --short; rg -l "NetworkConnectivityCheck" Pro --glob "*.swift" | head`

Expected: no `NetworkDiagnostics` source files inside `Pro/` (the shared folder lives only in the root repo). If any exist, stop and report before continuing.

- [ ] **Step 5: Report**

Report: which schemes built, the unit-test result, the scan results, and the Pro-copy check.

- [ ] **Step 6: Commit checkpoint**

Do not commit. If the user requested commits, ask `Run the checks relevant to this commit before committing?`, then commit with message `docs(network-diagnostics): describe stage model and gateway reachability check`.

---

## Self-Review Notes

- Spec coverage: stage model (Task 3), resolver (Task 3), gateway check and evidence migration (Task 1), runner order/dependencies (Tasks 1-2), overall conclusion participation (Task 2), proxy under This Mac (Task 4 grouping), diagram (Task 5), table grouping (Task 4), localization (Task 6), documentation (Task 8), preserved behaviors (Global Constraints).
- No placeholders: every code step contains complete code; every command includes expected output.
- No new files: all changes are in existing files, so no `project.pbxproj` edits are needed.
