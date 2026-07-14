# Immutable Observation Publication Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish each production `WiFiObservation` once through an ordered runtime so the Store and Pro event pipeline receive the exact same immutable value.

**Architecture:** Add a shared main-actor `WiFiObservationRuntime` that applies observations to `WiFiObservationStore` immediately and feeds fixed consumers through independent serial queues. Keep `ScannerViewModel` as the temporary observation producer in this milestone, and replace the Pro coordinator's mutable Store subscription with a Pro-only runtime consumer.

**Tech Stack:** Swift 6.0, Swift Concurrency, Combine, Swift Testing, SwiftUI, Xcode project target membership

## Global Constraints

- macOS 14+ and Swift 6.0.
- App verification uses `xcodebuild`; never use `swift build` or `swift test` for the app.
- Do not run UI test bundles.
- Shared runtime code belongs to both `WiFiLens` and `WiFiLensPro` targets.
- Pro event adapter code belongs only to `WiFiLensPro`.
- Event delivery is ordered, lossless for accepted in-process observations, and failure-isolated.
- Only observations containing `currentStatus` are eligible for the Pro event consumer.
- Latency events use only `gatewayLatency` from the same observation.
- Do not move Pro event models, classification, persistence, Timeline, or Menu Bar behavior into shared code.
- Do not remove filters, providers, analyzers, normalized models, chart/table projections, or persistence adapters.
- Do not commit without explicit user authorization.

---

## File Map

| File | Responsibility |
|---|---|
| `WiFiLens/Sources/WiFiLens/Observation/Runtime/WiFiObservationRuntime.swift` | Shared runtime, consumer interface, serial delivery queue, diagnostics, Store projection |
| `WiFiLens/Tests/WiFiLensTests/Observation/RuntimeTests.swift` | Ordering, Store immediacy, failure isolation, draining, no-consumer composition |
| `WiFiLens/Sources/WiFiLens/Scanner/ScannerViewModel.swift` | Temporary producer submits completed observations to runtime |
| `Pro/Events/WiFiObservationEventCoordinator.swift` | Pro runtime consumer; processes exact observations without Store reconstruction |
| `Pro/Events/ProObservationEventBootstrap.swift` | Pro composition and consumer registration |
| `Pro/Tests/WiFiLensProTests/TimelinePresentationTests.swift` | Consecutive observation and eligibility regression coverage |
| `WiFiLens/Sources/WiFiLens/WiFiLensApp.swift` | Register Pro consumer before scanning starts |
| `WiFiLens/WiFiLens.xcodeproj/project.pbxproj` | Runtime and test target membership |

---

### Task 1: Add the Ordered Observation Runtime

**Files:**
- Create: `WiFiLens/Sources/WiFiLens/Observation/Runtime/WiFiObservationRuntime.swift`
- Create: `WiFiLens/Tests/WiFiLensTests/Observation/RuntimeTests.swift`
- Modify: `WiFiLens/WiFiLens.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `WiFiObservation`, `WiFiObservationStore`
- Produces: `WiFiObservationConsuming.consume(_:)`, `WiFiObservationRuntime.accept(_:)`, `addConsumer(_:)`, `drainConsumers()`

- [ ] **Step 1: Add failing runtime tests**

Create `RuntimeTests.swift` with controlled main-actor consumers:

```swift
import Foundation
import Testing
@testable import WiFi_Lens

@Suite("WiFiObservationRuntime")
@MainActor
struct RuntimeTests {
    @Test("accepted observations update the store and preserve consumer order")
    func orderedDelivery() async {
        let store = WiFiObservationStore()
        let consumer = CapturingObservationConsumer()
        let runtime = WiFiObservationRuntime(store: store)
        runtime.addConsumer(consumer)

        let first = WiFiObservation(timestamp: Date(timeIntervalSince1970: 1))
        let second = WiFiObservation(timestamp: Date(timeIntervalSince1970: 2))
        runtime.accept(first)
        runtime.accept(second)

        #expect(store.lastUpdated != nil)
        await runtime.drainConsumers()
        #expect(consumer.observations == [first, second])
    }

    @Test("a suspended consumer does not delay store publication")
    func storeIsImmediate() async {
        let store = WiFiObservationStore()
        let consumer = SuspendedObservationConsumer()
        let runtime = WiFiObservationRuntime(store: store)
        runtime.addConsumer(consumer)

        let status = WiFiCurrentStatus(
            timestamp: Date(), ssid: "Office", bssid: "AA:BB",
            isConnected: true, isWiFiPowerOn: true
        )
        runtime.accept(WiFiObservation(currentStatus: status))

        #expect(store.currentStatus == status)
        consumer.resume()
        await runtime.drainConsumers()
    }

    @Test("a failing consumer does not stop later observations")
    func failureIsolation() async {
        let consumer = FailOnceObservationConsumer()
        let runtime = WiFiObservationRuntime(store: WiFiObservationStore())
        runtime.addConsumer(consumer)
        runtime.accept(WiFiObservation(timestamp: Date(timeIntervalSince1970: 1)))
        runtime.accept(WiFiObservation(timestamp: Date(timeIntervalSince1970: 2)))

        await runtime.drainConsumers()
        #expect(consumer.attemptedTimestamps == [
            Date(timeIntervalSince1970: 1), Date(timeIntervalSince1970: 2),
        ])
    }

    @Test("OSS composition needs no consumer")
    func noConsumerComposition() async {
        let store = WiFiObservationStore()
        let runtime = WiFiObservationRuntime(store: store)
        let status = WiFiCurrentStatus(timestamp: Date(), isConnected: false, isWiFiPowerOn: true)
        runtime.accept(WiFiObservation(currentStatus: status))
        await runtime.drainConsumers()
        #expect(store.currentStatus == status)
    }
}
```

Define the three test consumers in the same file. `CapturingObservationConsumer` appends every value, `SuspendedObservationConsumer` waits on a checked continuation until `resume()`, and `FailOnceObservationConsumer` throws only for its first call while recording both attempts.

- [ ] **Step 2: Add test membership and verify RED**

Add `RuntimeTests.swift` as a PBX file reference, a `WiFiLensTests` build file, a member of the Observation test group, and a member of the test target Sources phase.

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests/RuntimeTests
```

Expected: compilation fails because `WiFiObservationRuntime` and `WiFiObservationConsuming` do not exist.

- [ ] **Step 3: Implement the runtime and serial worker**

Create `WiFiObservationRuntime.swift` with this public shape:

```swift
import Foundation

@MainActor
protocol WiFiObservationConsuming: AnyObject {
    func consume(_ observation: WiFiObservation) async throws
}

struct ObservationConsumerDiagnostics: Equatable, Sendable {
    let pendingCount: Int
    let oldestObservationTimestamp: Date?
    let failureCount: Int
}

@MainActor
final class WiFiObservationRuntime {
    let store: WiFiObservationStore

    init(store: WiFiObservationStore = .shared) {
        self.store = store
    }

    func addConsumer(_ consumer: any WiFiObservationConsuming)
    func accept(_ observation: WiFiObservation)
    func drainConsumers() async
    func diagnostics() -> [ObjectIdentifier: ObservationConsumerDiagnostics]
}
```

Implementation requirements:

- identify class-bound consumers with `ObjectIdentifier` and ignore duplicate registration;
- call `store.apply(observation)` synchronously inside `accept`;
- enqueue the exact observation into every worker after applying the Store;
- implement each worker as a main-actor task chain whose new task awaits the previous tail before invoking its consumer;
- catch and log each consumer error inside the worker, increment `failureCount`, and continue the chain;
- track pending count and oldest queued timestamp without using a drop policy;
- make `drainConsumers()` snapshot worker tail tasks and await them without cancelling work.

- [ ] **Step 4: Add runtime source membership**

Add `WiFiObservationRuntime.swift` to the Observation group and to both `WiFiLens` and `WiFiLensPro` Sources phases.

- [ ] **Step 5: Run runtime tests GREEN**

Run the Task 1 focused command. Expected: all `RuntimeTests` pass.

- [ ] **Step 6: Commit gate**

If and only if the user explicitly authorizes a commit:

```sh
git add WiFiLens/Sources/WiFiLens/Observation/Runtime/WiFiObservationRuntime.swift WiFiLens/Tests/WiFiLensTests/Observation/RuntimeTests.swift WiFiLens/WiFiLens.xcodeproj/project.pbxproj
git commit -m "feat(observation): add ordered runtime publication"
```

---

### Task 2: Route Production Scanner Observations Through the Runtime

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/Scanner/ScannerViewModel.swift:48-97`
- Modify: `WiFiLens/Sources/WiFiLens/Scanner/ScannerViewModel.swift:420-453`
- Test: `WiFiLens/Tests/WiFiLensTests/Observation/RuntimeTests.swift`

**Interfaces:**
- Consumes: `WiFiObservationRuntime.accept(_:)`
- Produces: `ScannerViewModel.observationRuntime`

- [ ] **Step 1: Add a failing Scanner integration test**

Add a test-only assertion path that constructs a `ScannerViewModel` with a non-shared Store and verifies `scannerViewModel.observationRuntime.store === store`. Keep network scanning out of the unit test.

```swift
@Test("scanner and runtime share the injected store")
func scannerRuntimeUsesInjectedStore() {
    let store = WiFiObservationStore()
    let scanner = ScannerViewModel(store: store)
    #expect(scanner.observationRuntime.store === store)
}
```

Run the focused runtime tests. Expected: compilation fails because `observationRuntime` is absent.

- [ ] **Step 2: Inject and expose the runtime**

Add:

```swift
let observationRuntime: WiFiObservationRuntime
```

Initialize it from the same Store used by `ScannerViewModel`:

```swift
self.store = store
self.observationRuntime = WiFiObservationRuntime(store: store)
```

- [ ] **Step 3: Replace direct Store publication**

Keep the existing observation construction unchanged, assign it to a local value, and replace:

```swift
store.apply(observation)
```

with:

```swift
observationRuntime.accept(observation)
```

There must be no production `store.apply(WiFiObservation(...))` call in `ScannerViewModel` after this step.

- [ ] **Step 4: Run focused tests and build**

Run Runtime tests, then the OSS Debug build. Expected: PASS and `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit gate**

If explicitly authorized:

```sh
git add WiFiLens/Sources/WiFiLens/Scanner/ScannerViewModel.swift WiFiLens/Tests/WiFiLensTests/Observation/RuntimeTests.swift
git commit -m "refactor(observation): publish scanner results through runtime"
```

---

### Task 3: Replace Mutable Store Reconstruction in the Pro Event Pipeline

**Files:**
- Modify: `Pro/Events/WiFiObservationEventCoordinator.swift`
- Modify: `Pro/Events/ProObservationEventBootstrap.swift`
- Modify: `WiFiLens/Sources/WiFiLens/WiFiLensApp.swift:373-380`
- Modify: `Pro/Tests/WiFiLensProTests/TimelinePresentationTests.swift`

**Interfaces:**
- Consumes: `WiFiObservationConsuming`, `WiFiObservationRuntime.addConsumer(_:)`
- Produces: exact observation-to-event processing with no Store subscription

- [ ] **Step 1: Add failing Pro regression tests**

Add tests using a fixed event recorder that records its received observations:

```swift
@MainActor
@Test func coordinatorReceivesConsecutiveExactObservations() async {
    let recorder = CapturingTimelineEventRecorder()
    let controller = WiFiObservationEventTimelineController(
        eventLogStore: EmptyTimelineEventLogStore()
    )
    let coordinator = WiFiObservationEventCoordinator(
        eventRecorder: recorder,
        timelineController: controller
    )
    let first = WiFiObservation(currentStatus: connectedStatus(ssid: "A", bssid: "01"))
    let second = WiFiObservation(currentStatus: connectedStatus(ssid: "B", bssid: "02"))

    try? await coordinator.consume(first)
    try? await coordinator.consume(second)

    #expect(await recorder.observations == [first, second])
}

@MainActor
@Test func coordinatorIgnoresObservationWithoutCurrentStatus() async {
    let recorder = CapturingTimelineEventRecorder()
    let coordinator = WiFiObservationEventCoordinator(
        eventRecorder: recorder,
        timelineController: WiFiObservationEventTimelineController(
            eventLogStore: EmptyTimelineEventLogStore()
        )
    )
    try? await coordinator.consume(WiFiObservation(
        gatewayLatency: GatewayLatencyResult(timestamp: Date(), latencyMs: 400)
    ))
    #expect(await recorder.observations.isEmpty)
}
```

Run the Pro test target. Expected: compilation fails because the coordinator initializer and `consume` interface still require the Store subscription design.

- [ ] **Step 2: Convert the coordinator into the Pro consumer**

Make `WiFiObservationEventCoordinator` conform to `WiFiObservationConsuming`.

- remove `observationStore`, Combine imports, cancellables, and `$lastUpdated` subscription;
- retain idempotent startup hydration in `start()`;
- accept `eventRecorder` and `timelineController` in the initializer;
- implement `consume(_:) async throws`;
- guard `observation.currentStatus != nil` before capturing the controller generation;
- pass the exact observation to `eventRecorder.record`;
- pass emitted events to `timelineController.accept` with the captured generation;
- let the runtime worker isolate thrown persistence errors.

- [ ] **Step 3: Update Pro bootstrap composition**

Replace `start(observationStore:)` with:

```swift
static func start(observationRuntime: WiFiObservationRuntime) {
    guard coordinator == nil else { return }
    let coordinator = WiFiObservationEventCoordinator(
        timelineController: timelineController
    )
    observationRuntime.addConsumer(coordinator)
    coordinator.start()
    self.coordinator = coordinator
}
```

- [ ] **Step 4: Register Pro before scanning starts**

In `AppRootView.task`, change the order to:

```swift
#if PRO
ProObservationEventBootstrap.start(observationRuntime: viewModel.observationRuntime)
#endif
await viewModel.start()
```

This prevents the first accepted observation from preceding consumer registration.

- [ ] **Step 5: Run Pro tests GREEN**

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens Pro" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensProTests
```

Expected: all Pro unit tests pass and no UI test bundle runs.

- [ ] **Step 6: Commit gate**

If explicitly authorized, commit the Pro submodule first, then the parent pointer and shared composition changes in separate commits.

---

### Task 4: Milestone 1 Verification and Documentation

**Files:**
- Modify: `docs/ARCHITECTURE.md`
- Modify: `Pro/docs/ARCHITECTURE.md`

**Interfaces:**
- Consumes: completed Milestone 1 behavior
- Produces: documented transitional architecture and verified target separation

- [ ] **Step 1: Run reference audits**

```sh
rg -n '\$lastUpdated|observationStore\.currentStatus|observationStore\.gatewayLatency' Pro/Events
rg -n 'store\.apply\(WiFiObservation' WiFiLens/Sources/WiFiLens/Scanner/ScannerViewModel.swift
rg -n 'WiFiObservationRuntime.swift in Sources' WiFiLens/WiFiLens.xcodeproj/project.pbxproj
```

Expected: no Pro event Store reconstruction, no direct Scanner Store publication, and two app target memberships for the runtime.

- [ ] **Step 2: Run full non-UI verification**

Run OSS unit tests, Pro unit tests, OSS Debug build, and Pro Debug build. Expected: all tests pass and both builds report `BUILD SUCCEEDED`.

- [ ] **Step 3: Document the transitional boundary**

Update the architecture docs to state that `ScannerViewModel` is still the temporary producer but all publication now passes through the runtime. Document that Pro consumes exact observations and no longer observes Store timestamps.

- [ ] **Step 4: Check target separation and worktree hygiene**

Run `git diff --check`, inspect `git status --short`, and verify no Pro event source was added to the OSS Sources phase.
