# Pro Unified Event Timeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Pro menu bar and timeline consume one Wi-Fi event stream, navigate to the exact selected event, and retain valid filters.

**Architecture:** `WiFiObservationEventCoordinator` remains the sole producer and the existing SQLite/recent stores remain the sole persistence and live sources. The Pro menu bar subscribes to the shared recent store and maps its events for display; the app root passes menu selections as UUID navigation requests to Timeline. OSS continues to supply only `WiFiObservationStore`.

**Tech Stack:** Swift 6, SwiftUI, Combine, Swift Testing, SQLite3.

## Global Constraints

- macOS 14+, Swift 6 strict concurrency.
- Event, timeline, and menu-event code is Pro-only; OSS receives no paid event types or database dependency.
- Tests use Swift Testing and `@testable import WiFi_Lens_Pro`.
- Do not run UI test bundles unless explicitly requested.
- Do not commit without explicit user instruction.

---

## File Map

| File | Change |
|---|---|
| `Pro/Events/ProObservationEventBootstrap.swift` | Expose the shared recent store inside Pro. |
| `Pro/MenuBar/MenuBarStatusViewModel.swift` | Map shared observation events into menu presentation rows. |
| `Pro/MenuBar/MenuBarStatusView.swift` | Send optional selected UUIDs to the scene callback. |
| `Pro/MenuBar/MenuBarScene.swift` | Forward menu UUIDs to the root. |
| `Pro/Timeline/TimelineViewModel.swift` | Defines the Pro-only pending selection model and restores filters/resolves selected events. |
| `Pro/Timeline/TimelineView.swift` | Synchronize bindings and expand/scroll selected rows. |
| `Pro/Timeline/TimelineFilterPanel.swift` | Clamp custom date bounds. |
| `WiFiLens/Sources/WiFiLens/WiFiLensApp.swift` | Own Pro filter/navigation state. |
| `WiFiLens/WiFiLens.xcodeproj/project.pbxproj` | Add navigation file; remove obsolete sources. |

### Task 1: Make the menu bar consume the shared Pro event store

**Files:**
- Modify: `Pro/Events/ProObservationEventBootstrap.swift`
- Modify: `Pro/MenuBar/MenuBarStatusViewModel.swift`
- Modify: `Pro/Tests/WiFiLensProTests/MenuBarMigrationTests.swift`

**Interfaces:** Produces `MenuBarEventPresentation: Identifiable, Equatable` with `id`, `timestamp`, `title`, `detail`, `icon`, and `tone`; changes the view-model initializer to accept `recentStore: WiFiObservationEventRecentStore`.

- [ ] **Step 1: Write the failing test**

```swift
@Test("menu events mirror the shared recent store")
func menuEventsUseSharedRecentStore() async {
    let recentStore = WiFiObservationEventRecentStore()
    let vm = MenuBarStatusViewModel(store: WiFiObservationStore(), recentStore: recentStore)
    let event = WiFiObservationEvent(type: .disconnection)
    recentStore.append([event])
    #expect(await waitUntil { vm.recentEvents.map(\.id) == [event.id] })
}
```

- [ ] **Step 2: Verify RED**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens Pro" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensProTests/MenuBarMigrationTests/menuEventsUseSharedRecentStore`

Expected: compilation fails because the initializer and shared presentation type do not exist.

- [ ] **Step 3: Implement the minimal shared mapping**

Add:

```swift
struct MenuBarEventPresentation: Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let title: String
    let detail: String
    let icon: String
    let tone: TimelineEventPresentation.Tone
}
```

Expose `static var recentEventStore: WiFiObservationEventRecentStore` from the bootstrap. Replace `ConnectionEvent` publishing with a subscription to the injected store's `$recentEvents`; map each event from its existing timeline presentation, sort newest first, and keep five rows. Remove `ConnectionRecorder` ownership and start/stop APIs from the view model.

- [ ] **Step 4: Verify GREEN**

Run the Step 2 command. Expected: the new test passes.

### Task 2: Carry a menu event UUID into Timeline

**Files:**
- Modify: `Pro/MenuBar/MenuBarStatusView.swift`
- Modify: `Pro/MenuBar/MenuBarScene.swift`
- Modify: `WiFiLens/Sources/WiFiLens/WiFiLensApp.swift`
- Modify: `WiFiLens/WiFiLens.xcodeproj/project.pbxproj`
- Test: `Pro/Tests/WiFiLensProTests/MenuBarMigrationTests.swift`

**Interfaces:** Produces `struct TimelineNavigationRequest: Equatable { let eventID: UUID? }`; changes `onOpenTimeline` to `(UUID?) -> Void`; adds `Binding<TimelineNavigationRequest?>` to `TimelineView`.

- [ ] **Step 1: Write failing request tests**

```swift
@Test func menuEventRequestPreservesID() {
    let id = UUID()
    #expect(TimelineNavigationRequest(eventID: id).eventID == id)
}

@Test func viewAllRequestHasNoSelection() {
    #expect(TimelineNavigationRequest(eventID: nil).eventID == nil)
}
```

- [ ] **Step 2: Verify RED**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens Pro" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensProTests/MenuBarMigrationTests/menuEventRequestPreservesID -only-testing:WiFiLensProTests/MenuBarMigrationTests/viewAllRequestHasNoSelection`

Expected: compilation fails because `TimelineNavigationRequest` does not exist.

- [ ] **Step 3: Implement routing**

Define the request type in the existing Timeline module. Make View All send `nil` and event rows send `event.id`. In `WiFiLensApp`, add `@State private var timelineNavigationRequest: TimelineNavigationRequest?`, pass its binding to `AppRootView`, and have the Pro `MenuBarScene` callback assign it before calling `showMainWindow(route: .timeline, source: .menuBar)`.

- [ ] **Step 4: Verify GREEN**

Run the Step 2 command. Expected: both tests pass.

### Task 3: Restore filters and resolve selected timeline events

**Files:**
- Modify: `Pro/Timeline/TimelineViewModel.swift`
- Modify: `Pro/Timeline/TimelineView.swift`
- Modify: `Pro/Timeline/TimelineFilterPanel.swift`
- Test: `Pro/Tests/WiFiLensProTests/TimelinePresentationTests.swift`

**Interfaces:** Produces `prepare(selectedFilter:customStartDate:customEndDate:searchText:enabledEventTypes:)` and `eventIndex(for:) -> Int?` on TimelineViewModel.

- [ ] **Step 1: Write failing tests**

```swift
@MainActor @Test func prepareRestoresCustomFilter() async {
    let disconnection = WiFiObservationEvent(timestamp: Date(timeIntervalSince1970: 100), type: .disconnection)
    let connection = WiFiObservationEvent(timestamp: Date(timeIntervalSince1970: 100), type: .connected)
    let log = MutableTimelineEventLogStore(events: [disconnection, connection])
    let vm = TimelineViewModel(recentStore: WiFiObservationEventRecentStore(), eventLogStore: log)
    vm.prepare(selectedFilter: .custom, customStartDate: Date(timeIntervalSince1970: 0), customEndDate: Date(timeIntervalSince1970: 200), searchText: "", enabledEventTypes: [.disconnection])
    await vm.reload()
    #expect(vm.events.map(\.id) == [disconnection.id])
}
```

- [ ] **Step 2: Verify RED**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens Pro" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensProTests/TimelinePresentationTests/prepareRestoresCustomFilter`

Expected: compilation fails because `prepare` does not exist.

- [ ] **Step 3: Implement synchronization and selection**

Implement `prepare` to assign all five properties before one `applyFilters()` call; implement `eventIndex(for:)` over filtered presentations. In `TimelineView.onAppear`, invoke `prepare` before `start()`. On a pending UUID, reload, select and scroll to its row, then consume the request; if absent, consume it without selecting. Make both DatePicker bindings clamp the other endpoint so `start <= end` remains true.

- [ ] **Step 4: Verify GREEN**

Run the Step 2 command and add focused tests for `eventIndex(for:)` and inverted date normalization. Expected: all pass.

### Task 4: Remove the duplicate menu event pipeline

**Files:**
- Delete: `Pro/MenuBar/ConnectionRecorder.swift`
- Delete: `Pro/MenuBar/ConnectionEvent.swift`
- Delete: `Pro/MenuBar/EventStore.swift`
- Delete: `Pro/MenuBar/EventDetector.swift`
- Modify: `WiFiLens/WiFiLens.xcodeproj/project.pbxproj`
- Test: `Pro/Tests/WiFiLensProTests/MenuBarMigrationTests.swift`

- [ ] **Step 1: Write the failing reactive-clear test**

```swift
@MainActor @Test func clearingRecentStoreEmptiesMenu() async {
    let recentStore = WiFiObservationEventRecentStore()
    let vm = MenuBarStatusViewModel(store: WiFiObservationStore(), recentStore: recentStore)
    recentStore.append([WiFiObservationEvent(type: .disconnection)])
    #expect(await waitUntil { !vm.recentEvents.isEmpty })
    recentStore.replace(with: [])
    #expect(await waitUntil { vm.recentEvents.isEmpty })
}
```

- [ ] **Step 2: Verify RED and implement empty-store replacement**

Run the focused Pro test first; then ensure the recent-store sink assigns `[]` for an empty update so the test passes.

- [ ] **Step 3: Remove files and project references**

Delete the four obsolete files with `apply_patch`. Remove each matching PBXBuildFile, PBXFileReference, MenuBar group child, and WiFiLensPro Sources entry. Preserve `Pro/Events/RoamingEventDetector.swift`: it is the unified pipeline detector.

- [ ] **Step 4: Verify static boundary**

Run: `rg -n "ConnectionRecorder|ConnectionEvent|EventStore|Pro/MenuBar/EventDetector" Pro WiFiLens/Sources/WiFiLens --glob '*.swift'`

Expected: no production references.

### Task 5: Verify both products

- [ ] **Step 1: Run all Pro unit tests**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens Pro" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensProTests`

Expected: all Pro unit tests pass.

- [ ] **Step 2: Run OSS build and unit tests**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build`

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests`

Expected: OSS succeeds without Pro event UI.

- [ ] **Step 3: Check final working tree**

Run: `git diff --check`

Expected: no whitespace errors.
