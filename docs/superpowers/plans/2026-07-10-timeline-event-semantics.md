# Timeline Event Semantics and Detail Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Correct Pro Wi-Fi roaming semantics and repair the timeline rail and inline-detail hierarchy.

**Architecture:** A Pro-only connection transition classifier determines connection meaning before event construction. The existing detector maps classifications into persisted events with per-event snapshots, while the timeline view fixes compositing and removes redundant detail content without changing storage schema.

**Tech Stack:** Swift 6.0, SwiftUI, Swift Testing, SQLite persistence, Xcode project targets

## Global Constraints

- macOS 14+, Swift 6.0.
- All event classification and timeline behavior remains Pro-only.
- OSS must not import or compile the Pro classifier or event types.
- No database schema migration or new persisted event kind.
- Tests use Swift Testing (`@Test`, `#expect()`).
- Do not run UI test bundles unless explicitly requested.
- English is used for code, comments, commit messages, and documentation.
- Never commit without explicit user instruction.

---

## File Structure

```text
Pro/Events/
  WiFiConnectionTransitionClassifier.swift  # Pure connection-state classification
  RoamingEventDetector.swift                 # Classification-to-event orchestration
  WiFiObservationEvent.swift                 # Recorder cooldown identity

Pro/Timeline/
  TimelineView.swift                         # Rail compositing and detail hierarchy

Pro/Tests/WiFiLensProTests/
  RoamingEventDetectorTests.swift            # Classifier and event mapping regressions
  WiFiEventRecorderTests.swift               # Recorder cooldown regressions
```

---

### Task 1: Connection Transition Classification

**Files:**
- Create: `Pro/Events/WiFiConnectionTransitionClassifier.swift`
- Modify: `Pro/Tests/WiFiLensProTests/RoamingEventDetectorTests.swift`
- Modify: `WiFiLens/WiFiLens.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `WiFiCurrentStatus`
- Produces: `WiFiConnectionTransition` and `WiFiConnectionTransitionClassifier.classify(previous:current:)`

- [ ] **Step 1: Add failing classifier tests**

```swift
@Test func classifiesSameSSIDBSSIDChangeAsRoam() {
    let result = WiFiConnectionTransitionClassifier.classify(
        previous: connectedStatus(ssid: "Office", bssid: "AA:01"),
        current: connectedStatus(ssid: "Office", bssid: "AA:02")
    )
    #expect(result == .roamed(fromBSSID: "AA:01", toBSSID: "AA:02"))
}

@Test func classifiesDifferentSSIDAsNetworkSwitch() {
    let result = WiFiConnectionTransitionClassifier.classify(
        previous: connectedStatus(ssid: "A", bssid: "AA:01"),
        current: connectedStatus(ssid: "B", bssid: "BB:01")
    )
    #expect(result == .switchedNetworks)
}

@Test func classifiesMissingSSIDIdentityChangeAsNetworkSwitch() {
    let result = WiFiConnectionTransitionClassifier.classify(
        previous: connectedStatus(ssid: nil, bssid: "AA:01"),
        current: connectedStatus(ssid: nil, bssid: "AA:02")
    )
    #expect(result == .switchedNetworks)
}
```

- [ ] **Step 2: Run the focused Pro tests and confirm RED**

```bash
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens Pro" -configuration Debug -destination 'platform=macOS' test -only-testing:WiFiLensProTests/RoamingEventDetectorTests
```

Expected: compilation failure because `WiFiConnectionTransitionClassifier` does not exist.

- [ ] **Step 3: Implement the pure classifier**

```swift
enum WiFiConnectionTransition: Equatable, Sendable {
    case unchanged
    case connected
    case disconnected
    case roamed(fromBSSID: String, toBSSID: String)
    case switchedNetworks
}

enum WiFiConnectionTransitionClassifier {
    static func classify(
        previous: WiFiCurrentStatus,
        current: WiFiCurrentStatus
    ) -> WiFiConnectionTransition
}
```

The implementation follows the approved classification table and requires equal non-nil SSIDs before emitting `.roamed`.

- [ ] **Step 4: Add the source file to the Pro target and confirm GREEN**

Add the file reference and build-file entry to the Pro Sources phase in `project.pbxproj`, rerun the focused command, and expect all classifier tests to pass.

---

### Task 2: Event Mapping and Per-Event Snapshots

**Files:**
- Modify: `Pro/Events/RoamingEventDetector.swift`
- Modify: `Pro/Tests/WiFiLensProTests/RoamingEventDetectorTests.swift`

**Interfaces:**
- Consumes: `WiFiConnectionTransitionClassifier.classify(previous:current:)`
- Produces: ordered `[WiFiObservationEvent]` with old/new snapshots

- [ ] **Step 1: Add failing switch-event tests**

```swift
@Test func networkSwitchEmitsDisconnectThenConnectWithMatchingSnapshots() {
    let previous = connectedStatus(ssid: "A", bssid: "AA:01", channel: 1, rssi: -45)
    let current = connectedStatus(ssid: "B", bssid: "BB:01", channel: 36, rssi: -70)

    let events = RoamingEventDetector.detect(previous: previous, current: current)

    #expect(events.count == 2)
    #expect(events[0].type == .disconnection)
    #expect(events[0].contextSnapshot == previous.eventContextSnapshot)
    #expect(events[1].type == .connected)
    #expect(events[1].contextSnapshot == current.eventContextSnapshot)
}
```

Also assert no `.signalDrop` or `.channelChange` is emitted for the switch, while a confirmed same-SSID roam may still emit them.

- [ ] **Step 2: Run the focused tests and confirm RED**

Use the Task 1 focused test command. Expected: the existing detector emits a BSSID change and uses the current snapshot for every event.

- [ ] **Step 3: Map classifications to events**

Refactor `detect` to classify first, then construct transition events with `previous.eventContextSnapshot` for disconnection and `current.eventContextSnapshot` for connection and roaming. Retain the optional caller snapshot only as a compatibility fallback for independent metric events.

- [ ] **Step 4: Gate continuous metrics by network continuity**

Only detect signal and channel deltas when the classification is `.unchanged` or `.roamed`. Rerun focused tests and expect GREEN.

---

### Task 3: Recorder Cooldown Identity

**Files:**
- Modify: `Pro/Events/WiFiObservationEvent.swift`
- Modify: `Pro/Tests/WiFiLensProTests/WiFiEventRecorderTests.swift`

**Interfaces:**
- Consumes: `WiFiObservationEvent.details`
- Produces: network-specific semantic cooldown keys

- [ ] **Step 1: Add a failing network-switch cooldown test**

Record A, switch A to B, then switch B to C within 60 seconds. Assert both switches emit one disconnection and one connection event.

- [ ] **Step 2: Run the recorder tests and confirm RED**

```bash
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens Pro" -configuration Debug -destination 'platform=macOS' test -only-testing:WiFiLensProTests/WiFiEventRecorderTests
```

Expected: B-to-C connection transition events are suppressed by the global transition keys.

- [ ] **Step 3: Include the event label in transition keys**

Change the key API to consume the complete event:

```swift
private func semanticKey(for event: WiFiObservationEvent) -> String
```

Use `disconnection:\(event.details)` and `connected:\(event.details)` while preserving value-specific keys for all other cases.

- [ ] **Step 4: Rerun recorder tests and expect GREEN**

Confirm the new regression and existing cooldown tests pass.

---

### Task 4: Timeline Visual Hierarchy

**Files:**
- Modify: `Pro/Timeline/TimelineView.swift`

**Interfaces:**
- Consumes: `TimelineEventPresentation`
- Produces: corrected SwiftUI compositing and non-duplicated detail layout

- [ ] **Step 1: Move the rail behind rows**

Replace the list-level `.overlay(alignment: .topLeading)` with `.background(alignment: .topLeading)` while retaining the same inset and hit-testing behavior.

- [ ] **Step 2: Remove redundant detail elements**

Delete the leading `Divider` and the complete `if let badge = event.badge` value row. Keep the divider before `contextSnapshot`.

- [ ] **Step 3: Compile the Pro target**

```bash
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens Pro" -configuration Debug -destination 'platform=macOS' build
```

Expected: `BUILD SUCCEEDED`.

---

### Task 5: Full Verification and Boundary Audit

**Files:**
- Verify: `Pro/Events/*.swift`
- Verify: `Pro/Timeline/TimelineView.swift`
- Verify: `WiFiLens/WiFiLens.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces: evidence that Pro behavior works and OSS remains isolated

- [ ] **Step 1: Run all Pro unit tests**

```bash
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens Pro" -configuration Debug -destination 'platform=macOS' test -only-testing:WiFiLensProTests
```

Expected: zero failures.

- [ ] **Step 2: Run OSS unit tests**

```bash
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests
```

Expected: zero failures.

- [ ] **Step 3: Build the Pro app**

```bash
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens Pro" -configuration Debug -destination 'platform=macOS' build
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Audit the paid boundary and final diff**

Run `git diff --check`, inspect both the main repository and Pro submodule diffs, and verify the new classifier is referenced only by the Pro target.
