# Pro Timeline Consistency Controller Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Pro timeline clear a linearization boundary so stale loads and pre-clear observations cannot reappear, while post-clear events and retained custom dates remain intact.

**Architecture:** Add a Pro-only `WiFiObservationEventTimelineController` as the sole consistency boundary around the SQLite event log and shared recent buffer. It owns the data generation and clear barrier; coordinator and timeline view model use its narrow APIs instead of accessing storage directly. Timeline date state flows from app-root bindings through one normalization helper into the view model, with no initial `@Published` reverse subscription.

**Tech Stack:** Swift 6, SwiftUI, Combine, Swift Testing, SQLite3, Xcode 27 beta.

## Global Constraints

- macOS 14+ and Swift 6 strict concurrency.
- All event, timeline, and consistency-controller code remains in the Pro target.
- OSS receives no event model, event database, or paid timeline implementation.
- Use `xcodebuild`; do not run UI test bundles.
- Do not commit or push without explicit user instruction.

---

## File Map

| File | Responsibility |
|---|---|
| `Pro/Events/WiFiObservationEventTimelineController.swift` | Own generation, load validation, clear barrier, recent buffer, and queued post-clear persistence. |
| `Pro/Events/WiFiObservationEventCoordinator.swift` | Detect events and submit them with the captured controller generation. |
| `Pro/Events/ProObservationEventBootstrap.swift` | Construct and expose one shared controller to all Pro consumers. |
| `Pro/Timeline/TimelineViewModel.swift` | Load timeline snapshots through the controller. |
| `Pro/Timeline/TimelineView.swift` | Synchronize parent-owned date bindings explicitly without `onReceive`. |
| `Pro/Tests/WiFiLensProTests/TimelinePresentationTests.swift` | Deterministic concurrency and date-state regression tests. |
| `WiFiLens/WiFiLens.xcodeproj/project.pbxproj` | Add the controller only to the Pro Sources phase. |

### Task 1: Define and prove the consistency boundary

**Files:**
- Create: `Pro/Events/WiFiObservationEventTimelineController.swift`
- Modify: `Pro/Tests/WiFiLensProTests/TimelinePresentationTests.swift`
- Modify: `WiFiLens/WiFiLens.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces: `@MainActor final class WiFiObservationEventTimelineController`
- Produces: `var currentGeneration: UInt { get }`
- Produces: `func loadRecent(limit: Int) async -> [WiFiObservationEvent]?`
- Produces: `func accept(_ events: [WiFiObservationEvent], generation: UInt) async throws`
- Produces: `func hydrateRecent(limit: Int) async`
- Produces: `func clearTimelineData() async throws`
- Produces: `let recentStore: WiFiObservationEventRecentStore`

- [ ] **Step 1: Add a deterministic failing stale-load test**

Use `DelayedTimelineEventLogStore` to pause `loadRecent`, start
`controller.loadRecent(limit:)`, call `controller.clearTimelineData()`, resume
the old load, and assert its result is `nil`. The failure before implementation
must be a compile failure because the controller type does not exist.

- [ ] **Step 2: Verify RED**

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens Pro" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensProTests/TimelinePresentationTests/staleTimelineLoadIsRejectedAfterClear
```

Expected: FAIL because `WiFiObservationEventTimelineController` is undefined.

- [ ] **Step 3: Add a failing post-clear-event barrier test**

Use a controllable event-log store whose `deleteAll()` pauses after starting.
Begin clear, capture the new generation, accept a new event, release deletion,
then assert the event exists in both `recentStore` and persisted storage.

- [ ] **Step 4: Implement the controller minimally**

The controller must:

```swift
@MainActor
final class WiFiObservationEventTimelineController {
    let recentStore: WiFiObservationEventRecentStore
    private let eventLogStore: WiFiObservationEventLogStoring
    private(set) var currentGeneration: UInt = 0
    private var isClearing = false
    private var queuedEvents: [WiFiObservationEvent] = []
}
```

`loadRecent` captures `currentGeneration`, awaits storage, and returns `nil`
when the generation changed. `clearTimelineData` increments the generation,
clears `recentStore` immediately, marks the barrier active, awaits deletion,
then ends the barrier and persists queued current-generation events. `accept`
rejects mismatched generations, updates `recentStore`, queues while clearing,
and otherwise appends to storage. Deduplicate queued events by UUID before
flushing.

- [ ] **Step 5: Add the file to the Pro target only**

Add one PBXFileReference under the Pro Events group, one PBXBuildFile, and one
entry in the `WiFiLensPro` Sources phase. Do not add it to the OSS Sources phase.

- [ ] **Step 6: Verify GREEN**

Run the two focused controller tests. Expected: both pass.

### Task 2: Route every producer and loader through the controller

**Files:**
- Modify: `Pro/Events/WiFiObservationEventCoordinator.swift`
- Modify: `Pro/Events/ProObservationEventBootstrap.swift`
- Modify: `Pro/Timeline/TimelineViewModel.swift`
- Modify: `Pro/Tests/WiFiLensProTests/TimelinePresentationTests.swift`

**Interfaces:**
- Consumes: `WiFiObservationEventTimelineController`
- Coordinator initializer: `init(observationStore:eventRecorder:timelineController:)`
- Timeline view-model initializer: `init(timelineController:calendar:now:)`

- [ ] **Step 1: Write a failing ViewModel stale-reload regression test**

Start `viewModel.reload()` against a paused pre-clear snapshot, clear through
the same controller, resume the old reload, and assert `viewModel.events` is
empty. This specifically exercises `TimelineViewModel.reload`, not coordinator
hydration.

- [ ] **Step 2: Verify RED**

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens Pro" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensProTests/TimelinePresentationTests/timelineReloadCannotRestorePreClearSnapshot
```

Expected: FAIL because the old reload restores the delayed snapshot.

- [ ] **Step 3: Migrate coordinator**

Remove coordinator-owned `dataGeneration`, `eventLogStore`, and direct recent
store writes. Capture `timelineController.currentGeneration` before recording,
then call `try await timelineController.accept(events, generation:)`.
`start()` calls `timelineController.hydrateRecent(limit: 50)`.

- [ ] **Step 4: Migrate ViewModel and bootstrap**

Replace `recentStore` and `eventLogStore` initializer arguments with one
controller. Subscribe to `timelineController.recentStore`; implement `reload`
with `guard let persistedEvents = await timelineController.loadRecent(limit:)
else { return }`. Bootstrap creates one shared controller and delegates clear,
view-model creation, and recent-store exposure to it.

- [ ] **Step 5: Update all test construction sites**

Each test creates a controller from its test event-log store and recent store,
then injects that controller into the coordinator or ViewModel. Preserve the
existing live-event hydration and clear tests as regression coverage.

- [ ] **Step 6: Verify GREEN**

Run the full `TimelinePresentationTests` suite. Expected: all timeline tests pass.

### Task 3: Make date synchronization lifecycle-independent

**Files:**
- Modify: `Pro/Timeline/TimelineView.swift`
- Modify: `Pro/Timeline/TimelineViewModel.swift`
- Modify: `Pro/Tests/WiFiLensProTests/TimelinePresentationTests.swift`

**Interfaces:**
- Consumes: `TimelineViewModel.normalizeCustomRange(_:_:)`
- Produces: one `synchronizeCustomRangeFromBindings()` view helper.

- [ ] **Step 1: Add a retained-date regression test at the logic boundary**

Prepare a fresh ViewModel with a non-default ordered range and assert the range
remains exactly equal to the supplied parent values. Retain the inverted-range
tests to prove normalization still writes the corrected endpoint.

- [ ] **Step 2: Remove reverse subscriptions**

Delete both `onReceive(viewModel.$customStartDate/customEndDate)` modifiers.
On appearance and either binding endpoint change, call one helper that:

```swift
let normalized = TimelineViewModel.normalizeCustomRange(customStartDate, customEndDate)
if customStartDate != normalized.start { customStartDate = normalized.start }
if customEndDate != normalized.end { customEndDate = normalized.end }
viewModel.setCustomRange(start: normalized.start, end: normalized.end)
```

Add `setCustomRange(start:end:)` to the ViewModel so both endpoints are applied
through one named mutation boundary. `prepare` uses the same method.

- [ ] **Step 3: Run focused date tests**

Run `TimelinePresentationTests` and confirm retained, inverted, and ordered
range tests pass.

### Task 4: Verify product boundaries and the complete fix

**Files:**
- Verify only; do not modify unless a failure identifies a regression.

- [ ] **Step 1: Run all Pro unit tests**

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens Pro" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensProTests
```

Expected: zero failures, including all concurrency tests.

- [ ] **Step 2: Build OSS**

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates build
```

Expected: build succeeds without compiling the controller into the OSS target.

- [ ] **Step 3: Run OSS unit tests**

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests
```

Expected: zero failures; no UI tests run.

- [ ] **Step 4: Inspect final scope**

Run `git diff --check`, `git status --short`, and inspect both the main-repo diff
and `git -C Pro diff`. Expected: only the approved specs, plan, Pro submodule
implementation/tests, project membership, and AGENTS documentation entry differ.
