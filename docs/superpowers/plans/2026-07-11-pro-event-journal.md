# Pro Event Journal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the distributed Pro event lifecycle with one `WiFiObservationEventJournal` that consumes exact observations and owns derivation, optimistic recent publication, persistence, hydration, query consistency, and clear linearization.

**Architecture:** Introduce a concrete MainActor Journal behind the existing runtime consumer seam while retaining `WiFiObservationEventLogStoring` and SQLite as the persistence boundary. Freeze current failure and clear semantics first, migrate Bootstrap and UI consumers second, then delete the coordinator, timeline controller, recent store, JSONL store, recorder protocol, and clear notification.

**Tech Stack:** Swift 6.0, SwiftUI, Combine, Swift Testing, macOS 14+, Xcode project targets `WiFiLensPro` and `WiFiLensProTests`.

## Global Constraints

- All Journal implementation, event models, and persistence code remain Pro-only and absent from the OSS Sources phase.
- `WiFiObservationEventLogStoring` and `WiFiObservationEventSQLiteStore` remain unchanged as the true persistence seam and production adapter.
- Journal input is the exact immutable `WiFiObservation` delivered by `WiFiObservationRuntime`; Store reconstruction is forbidden.
- Different known SSIDs remain disconnect plus connect; same known SSID with a new BSSID remains roam; missing SSID identity remains disconnect plus connect.
- Recent publication happens before persistence and is not rolled back when append fails.
- Clear generation, stale derivation rejection, clear-time queuing, hydration validation, and clear coalescing become private Journal responsibilities.
- Recording, MCP, menu live metrics, SQLite schema, event types, and classifier thresholds do not change.
- Use `xcodebuild`; never use `swift build` or `swift test` for the app.
- Do not run `WiFiLensUITests` or `WiFiLensProUITests`.
- Do not use a worktree.
- Do not stage, commit, or push without a separate explicit user instruction.

---

### Task 1: Freeze Failure and Clear-Barrier Semantics

**Files:**
- Create: `Pro/Tests/WiFiLensProTests/EventJournalTests.swift`
- Modify: `WiFiLens/WiFiLens.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: existing `WiFiObservationEventCoordinator`, `WiFiObservationEventTimelineController`, `WiFiObservationEventRecentStore`, `WiFiObservationEventRecording`, and `WiFiObservationEventLogStoring`.
- Produces: deterministic characterization tests and reusable controllable persistence/derivation adapters that Task 2 migrates to the Journal.

- [ ] **Step 1: Add `EventJournalTests.swift` to the Pro test target**

Add a PBX file reference, PBX build file, Pro test group entry, and `WiFiLensProTests` Sources-phase entry. Do not add the file to OSS tests or either app target.

- [ ] **Step 2: Add deterministic failure adapters**

Create these test-only types in `EventJournalTests.swift`:

```swift
private enum JournalTestError: Error, Equatable {
    case appendFailed
    case deleteFailed
}

private actor FailingJournalLogStore: WiFiObservationEventLogStoring {
    enum Mode: Equatable {
        case failAppend
        case failDelete
        case failAppendAfterDelete
    }

    private var persisted: [WiFiObservationEvent]
    private let mode: Mode
    private let deleteEntered = JournalTestGate()
    private let deleteRelease = JournalTestGate()
    private var hasDeleted = false
    private(set) var appendAttempts: [[WiFiObservationEvent]] = []
    private(set) var deleteCount = 0

    init(mode: Mode, persisted: [WiFiObservationEvent] = []) {
        self.mode = mode
        self.persisted = persisted
    }

    func append(_ events: [WiFiObservationEvent]) async throws {
        appendAttempts.append(events)
        if mode == .failAppend || (mode == .failAppendAfterDelete && hasDeleted) {
            throw JournalTestError.appendFailed
        }
        persisted.append(contentsOf: events)
    }

    func loadRecent(limit: Int) async -> [WiFiObservationEvent] {
        Array(persisted.suffix(limit).reversed())
    }

    func deleteAll() async throws {
        deleteCount += 1
        await deleteEntered.open()
        await deleteRelease.wait()
        if mode == .failDelete {
            throw JournalTestError.deleteFailed
        }
        hasDeleted = true
        persisted.removeAll()
    }

    func waitUntilDeleteEntered() async { await deleteEntered.wait() }
    func resumeDelete() async { await deleteRelease.open() }
}

private actor JournalTestGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        let pending = waiters
        waiters.removeAll()
        pending.forEach { $0.resume() }
    }
}
```

`failAppendAfterDelete` permits setup appends until `deleteAll()` succeeds, then fails the queued append. The adapter exposes exact append attempts, delete count, and deterministic delete entry/release handshakes; tests must not use sleeps.

- [ ] **Step 3: Characterize optimistic append failure**

Add a test that constructs the existing TimelineController with a failing-append log and a RecentStore, calls `accept([event], generation: currentGeneration)`, catches `.appendFailed`, and proves:

```swift
#expect(recentStore.recentEvents == [event])
#expect(await logStore.appendAttempts == [[event]])
```

This test must pass before the refactor and demonstrates that persistence failure does not retract recent state.

- [ ] **Step 4: Characterize delete failure with a clear-time event**

Start `clearTimelineData()` against a delete-failing store, wait for `deleteAll` to enter, accept a new event using the post-clear generation, release deletion, and prove:

```swift
#expect(recentStore.recentEvents == [liveEvent])
#expect(await logStore.appendAttempts.last == [liveEvent])
```

The clear call must throw `.deleteFailed`, and the best-effort queued append must not replace that original error.

- [ ] **Step 5: Characterize queued append failure after successful deletion**

Start clear against a store that succeeds deletion but fails the queued append, accept a live event after clear starts, release deletion, and prove that clear throws `.appendFailed` while `recentStore.recentEvents` still contains the live event exactly once.

- [ ] **Step 6: Characterize stale asynchronous derivation**

Add a suspended `WiFiObservationEventRecording` test double with `entered` and `release` gates. Begin `coordinator.consume(observation)`, wait until derivation enters, complete `clearTimelineData()`, release derivation, and prove the pre-clear derived event is absent from both recent and persistence.

- [ ] **Step 7: Run the new characterization suite**

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens Pro" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensProTests/EventJournalTests
```

Expected: all new tests pass against the existing implementation. Record the exact test count in `.superpowers/sdd/pro-event-journal-task-1-report.md`; do not commit.

---

### Task 2: Implement the Deep Journal Core

**Files:**
- Create: `Pro/Events/WiFiObservationEventJournal.swift`
- Modify: `Pro/Tests/WiFiLensProTests/EventJournalTests.swift`
- Modify: `WiFiLens/WiFiLens.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `WiFiObservation`, `WiFiObservationConsuming`, `WiFiEventRecorder.record`, `WiFiObservationEvent`, and `WiFiObservationEventLogStoring`.
- Produces: concrete `WiFiObservationEventJournal` with `start()`, `consume(_:)`, `queryRecent(limit:)`, `clear()`, and `@Published private(set) recentEvents`.

- [ ] **Step 1: Write Journal surface tests before production code**

Change the Task 1 tests to construct `WiFiObservationEventJournal` through an internal test initializer:

```swift
let journal = WiFiObservationEventJournal(
    eventLogStore: logStore,
    deriveEvents: { _ in [event] }
)
```

Add compile-failing tests for:

- `consume` publishing recent before an append failure;
- delete failure retaining clear-time recent and preventing old persisted rows from reappearing through `queryRecent`;
- queued append failure after successful delete;
- derivation begun before clear being rejected;
- derivation begun after clear surviving deletion;
- an event accepted while the first post-delete queued append is suspended remaining queued and persisting after the older batch;
- concurrent clear calls causing one delete;
- recent deduplication and 50-event limit;
- hydration merging a live event that arrives while load is suspended;
- query retrying after a generation change rather than returning stale data.

Expected RED: compilation fails because `WiFiObservationEventJournal` does not exist.

- [ ] **Step 2: Add the Journal to Pro Sources only**

Create `Pro/Events/WiFiObservationEventJournal.swift` and add one PBX build file to the `WiFiLensPro` Sources phase. Do not add it to OSS Sources.

- [ ] **Step 3: Define the exact concrete surface and test seam**

Implement this type shape:

```swift
import Combine
import Foundation

@MainActor
final class WiFiObservationEventJournal: ObservableObject, WiFiObservationConsuming {
    typealias EventDeriver = @Sendable (WiFiObservation) async -> [WiFiObservationEvent]

    @Published private(set) var recentEvents: [WiFiObservationEvent] = []

    private let eventLogStore: WiFiObservationEventLogStoring
    private let deriveEvents: EventDeriver
    private let recentLimit: Int
    private var currentGeneration: UInt = 0
    private var isClearing = false
    private var persistenceSnapshotIsValid = true
    private var queuedEvents: [WiFiObservationEvent] = []
    private var activeClearTask: Task<Void, Error>?
    private var hasStarted = false

    init(
        eventLogStore: WiFiObservationEventLogStoring = WiFiObservationEventSQLiteStore(),
        recentLimit: Int = 50,
        recorder: WiFiEventRecorder = WiFiEventRecorder()
    ) {
        self.eventLogStore = eventLogStore
        self.recentLimit = recentLimit
        self.deriveEvents = { observation in
            await recorder.record(observation)
        }
    }

    init(
        eventLogStore: WiFiObservationEventLogStoring,
        recentLimit: Int = 50,
        deriveEvents: @escaping EventDeriver
    ) {
        self.eventLogStore = eventLogStore
        self.recentLimit = recentLimit
        self.deriveEvents = deriveEvents
    }
}
```

No generation or queue state may be exposed outside the type.

- [ ] **Step 4: Implement optimistic ingestion**

Implement `consume(_:)` with this ordering:

```swift
func consume(_ observation: WiFiObservation) async throws {
    guard observation.currentStatus != nil else { return }
    let generation = currentGeneration
    let events = await deriveEvents(observation)
    guard generation == currentGeneration, !events.isEmpty else { return }

    appendRecent(events)
    if isClearing {
        queue(events)
        return
    }
    try await eventLogStore.append(events)
}
```

`appendRecent` must deduplicate by ID, preserve accepted batch order, and retain only the latest `recentLimit` events.

- [ ] **Step 5: Implement generation-safe query and hydration**

Implement `queryRecent(limit:)` as a retry loop. When `persistenceSnapshotIsValid` is false, return the current recent suffix without touching the log. Otherwise load persisted events, retry if generation or validity changed, then merge persisted and optimistic recent by ID with deterministic timestamp/UUID ordering.

Implement idempotent `start()` as a MainActor task that calls `queryRecent(limit: recentLimit)` and replaces recent with the returned combined snapshot.

- [ ] **Step 6: Implement clear coalescing and failure semantics**

Implement `clear()` with an `activeClearTask` and a private `performClear()`:

```swift
private func performClear() async throws {
    currentGeneration &+= 1
    isClearing = true
    persistenceSnapshotIsValid = false
    queuedEvents.removeAll(keepingCapacity: true)
    recentEvents = []

    do {
        try await eventLogStore.deleteAll()
    } catch {
        let pending = drainQueuedEvents()
        isClearing = false
        if !pending.isEmpty {
            try? await eventLogStore.append(pending)
        }
        throw error
    }

    persistenceSnapshotIsValid = true
    do {
        while !queuedEvents.isEmpty {
            let pending = drainQueuedEvents()
            try await eventLogStore.append(pending)
        }
        isClearing = false
    } catch {
        let remaining = drainQueuedEvents()
        isClearing = false
        if !remaining.isEmpty {
            try? await eventLogStore.append(remaining)
        }
        throw error
    }
}
```

`clear()` must reset `activeClearTask` on both success and failure. A failed `deleteAll` leaves `persistenceSnapshotIsValid == false`; a successful delete followed by append failure leaves it true. An event accepted while a queued append is suspended must remain queued and be flushed before clear succeeds; it must never bypass the older batch.

- [ ] **Step 7: Run Journal tests and focused existing event tests**

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens Pro" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensProTests/EventJournalTests -only-testing:WiFiLensProTests/WiFiEventRecorderTests -only-testing:WiFiLensProTests/RoamingEventDetectorTests
```

Expected: all Journal, recorder, and classifier tests pass while the old production chain still compiles. Record evidence in `.superpowers/sdd/pro-event-journal-task-2-report.md`; do not commit.

---

### Task 3: Migrate Pro Composition, Timeline, and Menu

**Files:**
- Modify: `Pro/Events/ProObservationEventBootstrap.swift`
- Modify: `Pro/Timeline/TimelineViewModel.swift`
- Modify: `Pro/MenuBar/MenuBarStatusViewModel.swift`
- Modify: `Pro/Tests/WiFiLensProTests/TimelinePresentationTests.swift`
- Modify: `Pro/Tests/WiFiLensProTests/MenuBarMigrationTests.swift`
- Modify: `Pro/Tests/WiFiLensProTests/EventJournalTests.swift`

**Interfaces:**
- Consumes: `WiFiObservationEventJournal` from Task 2 and the unchanged runtime consumer API.
- Produces: one shared Journal registered by Bootstrap and injected into Timeline and menu presentation.

- [ ] **Step 1: Add failing composition and UI tests**

Before changing production composition, update tests to require:

- Runtime registration followed by exact observation ingestion through the real Journal and recorder;
- Timeline and menu observing the same event IDs from one Journal;
- `journal.clear()` publishing empty state to both without NotificationCenter;
- Timeline `reload()` replacing local events from `queryRecent(limit: 500)`;
- an empty Journal recent publication clearing Timeline local state;
- menu live connection metrics continuing to come from `WiFiObservationStore`.

Expected RED: existing initializers require TimelineController or RecentStore and Bootstrap does not expose a shared Journal.

- [ ] **Step 2: Reduce Bootstrap to composition**

Replace the shared controller/coordinator state with:

```swift
@MainActor
enum ProObservationEventBootstrap {
    private static let journal = WiFiObservationEventJournal()
    private static var hasRegisteredConsumer = false

    static var eventJournal: WiFiObservationEventJournal { journal }

    static func start(observationRuntime: WiFiObservationRuntime) {
        guard !hasRegisteredConsumer else { return }
        hasRegisteredConsumer = true
        observationRuntime.addConsumer(journal)
        journal.start()
    }

    static func makeTimelineViewModel() -> TimelineViewModel {
        TimelineViewModel(journal: journal)
    }

    static func clearTimelineData() async throws {
        try await journal.clear()
    }
}
```

Remove the clear Notification declaration and post.

- [ ] **Step 3: Migrate TimelineViewModel**

Replace the TimelineController dependency with `WiFiObservationEventJournal`. Subscribe to `journal.$recentEvents`:

```swift
journal.$recentEvents
    .receive(on: RunLoop.main)
    .sink { [weak self] recentEvents in
        guard let self else { return }
        if recentEvents.isEmpty {
            self.replaceAll(with: [])
        } else {
            self.merge(recentEvents)
        }
    }
    .store(in: &cancellables)
```

Remove NotificationCenter observation. Implement reload as:

```swift
func reload(limit: Int = 500) async {
    isLoading = true
    let snapshot = await journal.queryRecent(limit: limit)
    replaceAll(with: snapshot)
    merge(journal.recentEvents)
    isLoading = false
}
```

Retain filtering, ordering, navigation, custom range normalization, and presentation mapping unchanged.

- [ ] **Step 4: Migrate MenuBarStatusViewModel**

Replace `WiFiObservationEventRecentStore` injection with:

```swift
private let journal: WiFiObservationEventJournal

init(
    store: WiFiObservationStore = .shared,
    journal: WiFiObservationEventJournal = ProObservationEventBootstrap.eventJournal
)
```

Subscribe to `journal.$recentEvents`. Preserve mapping, newest-first sorting, five-item ViewModel limit, three-item view display, and all live Store metrics.

- [ ] **Step 5: Migrate tests to Journal construction**

Replace test controller/recent-store setup with a Journal using controllable `WiFiObservationEventLogStoring` adapters and, where exact event batches are needed, a deterministic `deriveEvents` closure. Preserve every existing assertion for:

- hydration/live merge;
- stale load after clear;
- Timeline clear replacement;
- menu and Timeline ID identity;
- connection switch and roam ordering;
- navigation and filters.

- [ ] **Step 6: Run focused Pro integration suites**

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens Pro" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensProTests/EventJournalTests -only-testing:WiFiLensProTests/TimelinePresentationTests -only-testing:WiFiLensProTests/MenuBarMigrationTests
```

Expected: the Journal-backed Timeline and menu tests pass, and no test relies on clear Notification behavior. Record evidence in `.superpowers/sdd/pro-event-journal-task-3-report.md`; do not commit.

---

### Task 4: Delete the Shallow Event Lifecycle

**Files:**
- Delete: `Pro/Events/WiFiObservationEventCoordinator.swift`
- Delete: `Pro/Events/WiFiObservationEventTimelineController.swift`
- Delete: `Pro/Events/WiFiObservationEventRecentStore.swift`
- Modify: `Pro/Events/WiFiObservationEvent.swift`
- Modify: `Pro/Events/WiFiObservationEventJournal.swift`
- Modify: `Pro/Tests/WiFiLensProTests/TimelinePresentationTests.swift`
- Modify: `Pro/Tests/WiFiLensProTests/EventJournalTests.swift`
- Modify: `WiFiLens/WiFiLens.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: completed Journal production path from Task 3.
- Produces: one deep lifecycle module, with only the persistence protocol and SQLite adapter remaining as external storage seams.

- [ ] **Step 1: Run the deletion reference audit**

Run:

```sh
rg -n 'WiFiObservationEventCoordinator|WiFiObservationEventTimelineController|WiFiObservationEventRecentStore|WiFiObservationEventLogStore|wifiLensTimelineDataDidClear|WiFiObservationEventRecording' Pro WiFiLens -g '*.swift'
```

Classify every hit. Production construction must already point to Journal; remaining hits should be definitions and test fixtures scheduled for deletion or migration.

- [ ] **Step 2: Move recorder ownership into the Journal module**

Move `WiFiEventRecorder` unchanged into `WiFiObservationEventJournal.swift`. Remove `WiFiObservationEventRecording`; Journal uses its asynchronous derivation closure internally, and recorder tests continue to instantiate the concrete actor directly.

- [ ] **Step 3: Remove the unused JSONL store**

Delete the complete `WiFiObservationEventLogStore` actor from `WiFiObservationEvent.swift`. Keep the event model, snapshot mapping, persistence enums, and `WiFiObservationEventLogStoring` protocol.

- [ ] **Step 4: Delete the three shallow modules and PBX entries**

Delete Coordinator, TimelineController, and RecentStore source files. Remove their PBX file references, build files, Event group entries, and Pro Sources-phase entries. Do not alter SQLite membership or add any deleted file to OSS.

- [ ] **Step 5: Remove obsolete test doubles and references**

Delete `FixedTimelineEventRecorder`, `CapturingTimelineEventRecorder`, and any controller/recent-store construction left in tests. Retain controllable persistence adapters because they conform to the real `WiFiObservationEventLogStoring` seam.

- [ ] **Step 6: Prove the deletion test and Pro target integrity**

Run the reference audit again. Expected: zero matches for all six removed symbols. Then run:

```sh
plutil -lint WiFiLens/WiFiLens.xcodeproj/project.pbxproj
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens Pro" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensProTests
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens Pro" -configuration Debug -destination 'platform=macOS' build
```

Expected: PBX lint succeeds, all Pro unit tests pass, and the Pro Debug build succeeds. Record exact counts and the target-membership audit in `.superpowers/sdd/pro-event-journal-task-4-report.md`; do not commit.

---

### Task 5: Document and Verify the Final Architecture

**Files:**
- Modify: `docs/ARCHITECTURE.md`
- Modify: `Pro/docs/ARCHITECTURE.md`
- Modify: `docs/superpowers/specs/2026-07-10-pro-unified-event-timeline-design.md`
- Modify: `docs/superpowers/plans/2026-07-10-pro-unified-event-timeline.md`
- Modify: `docs/superpowers/plans/2026-07-10-pro-timeline-consistency-controller.md`

**Interfaces:**
- Consumes: final Journal implementation and completed deletion audit.
- Produces: authoritative architecture documentation and fresh completion evidence for OSS and Pro.

- [ ] **Step 1: Update shared and Pro architecture docs**

Document this final path:

```text
WiFiObservationRuntime
  -> Pro WiFiObservationEventJournal
       -> optimistic recent publication
       -> generation-safe query / clear
       -> WiFiObservationEventLogStoring
            -> SQLite
```

State that Timeline and menu share Journal event IDs, while menu live metrics continue to read the Store. Remove Coordinator, TimelineController, RecentStore, and Notification descriptions.

- [ ] **Step 2: Mark historical plans as superseded**

Add an English status note to the three 2026-07-10 design/plan files explaining that their distributed Store/controller lifecycle is superseded by the 2026-07-11 Pro Event Journal design and plan. Preserve historical bodies.

- [ ] **Step 3: Run full OSS and Pro verification**

Run, without UI tests:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens Pro" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensProTests
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens Pro" -configuration Debug -destination 'platform=macOS' build
git diff --check
git -C Pro diff --check
```

Expected: both unit targets and both Debug builds succeed, and both diff checks are clean.

- [ ] **Step 4: Run the final acceptance audit**

Prove with source and PBX searches that:

- Journal is the only Pro runtime observation consumer;
- generation, clear queue, hydration validation, and recent publication live only in Journal;
- Timeline and menu inject the same Journal;
- no clear Notification remains;
- SQLite plus controllable test adapters still implement `WiFiObservationEventLogStoring`;
- no Journal or concrete Pro event implementation is present in OSS Sources;
- Recording, MCP, and menu live Store metrics remain unchanged.

Write the exact commands, counts, and findings to `.superpowers/sdd/pro-event-journal-task-5-report.md`; do not commit.

---

## Completion Gate

The phase is complete only after every task has an independent clean review, the final whole-branch review reports no open Critical or Important findings, the deletion audit is zero-hit, OSS and Pro unit tests pass, both Debug builds succeed, and the working tree contains no staged changes or commits created without explicit user authorization.
