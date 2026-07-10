# Timeline Context Snapshot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Attach a context snapshot (SSID, BSSID, channel, band, RSSI, interface, security, phy mode) to each timeline event so the inline detail panel can display meaningful network context.

**Architecture:** Add an `EventContextSnapshot` struct to `WiFiObservationEvent`, capture it from `WiFiCurrentStatus` at event creation time, persist as JSON in the `event_index` table, and surface it through the presentation layer to the inline detail panel.

**Tech Stack:** Swift 6.0, SQLite3, SwiftUI, Swift Testing

## Global Constraints

- macOS 14+, Swift 6.0 strict concurrency
- Events are created in `WiFiEventRecorder` (actor) which has access to `WiFiObservation.currentStatus`
- SQLite schema lives in `WiFiObservationEventSQLiteStore` — must handle migration for existing databases
- All new strings must be added to `Localizable.xcstrings` with `"extractionState": "manual"`
- Tests use Swift Testing (`@Test`, `#expect()`) with `@testable import`

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `Pro/Events/WiFiObservationEvent.swift` | Modify | Add `EventContextSnapshot` struct and `contextSnapshot` field |
| `Pro/Events/WiFiObservationEventSQLiteStore.swift` | Modify | Add `context_snapshot TEXT` column, persist/load JSON |
| `Pro/Events/WiFiObservationEvent.swift` (WiFiEventRecorder) | Modify | Capture snapshot from observation when creating events |
| `Pro/Timeline/TimelineViewModel.swift` | Modify | Pass snapshot through to presentation model |
| `Pro/Timeline/TimelineView.swift` | Modify | Display snapshot data in inline detail panel |
| `Pro/Tests/WiFiLensProTests/TimelinePresentationTests.swift` | Modify | Add tests for snapshot in presentation |

---

### Task 1: Add EventContextSnapshot to the event model

**Files:**
- Modify: `Pro/Events/WiFiObservationEvent.swift:26-51`

**Interfaces:**
- Produces: `EventContextSnapshot` struct, `WiFiObservationEvent.contextSnapshot` field

- [ ] **Step 1: Add the snapshot struct and field**

Add after the `WiFiObservationEvent` struct (after line 51):

```swift
struct EventContextSnapshot: Codable, Equatable, Sendable {
    var ssid: String?
    var bssid: String?
    var channel: Int?
    var band: String?
    var rssi: Int?
    var interfaceName: String?
    var security: String?
    var phyMode: String?
}
```

Add to `WiFiObservationEvent` struct (after `details` field, line 30):

```swift
var contextSnapshot: EventContextSnapshot?
```

Update the `init` to accept the new parameter:

```swift
init(
    id: UUID = UUID(),
    timestamp: Date = Date(),
    type: EventType,
    details: String = "",
    contextSnapshot: EventContextSnapshot? = nil
) {
    self.id = id
    self.timestamp = timestamp
    self.type = type
    self.details = details
    self.contextSnapshot = contextSnapshot
}
```

- [ ] **Step 2: Add a convenience init on WiFiCurrentStatus**

Add a static method to create a snapshot from `WiFiCurrentStatus`. This keeps the mapping close to the source type. Add after the `EventContextSnapshot` struct:

```swift
extension WiFiCurrentStatus {
    var eventContextSnapshot: EventContextSnapshot {
        EventContextSnapshot(
            ssid: ssid,
            bssid: bssid,
            channel: channel,
            band: band?.rawValue,
            rssi: rssi,
            interfaceName: interfaceName,
            security: security,
            phyMode: phyMode
        )
    }
}
```

Note: This extension is in the Pro module which imports WiFiLens, so `WiFiCurrentStatus` and `ChannelBand` are accessible.

- [ ] **Step 3: Run existing tests to verify no breakage**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests -only-testing:WiFiLensProTests 2>&1 | tail -5`

Expected: All tests pass (the new field has a default value of `nil`).

- [ ] **Step 4: Commit**

```bash
cd Pro && git add Events/WiFiObservationEvent.swift && git commit -m "feat: add EventContextSnapshot to WiFiObservationEvent"
cd .. && git add Pro && git commit -m "feat: add EventContextSnapshot to WiFiObservationEvent"
```

---

### Task 2: Persist context snapshot in SQLite

**Files:**
- Modify: `Pro/Events/WiFiObservationEventSQLiteStore.swift`

**Interfaces:**
- Consumes: `EventContextSnapshot` (from Task 1)
- Produces: `context_snapshot` column in `event_index`, snapshot hydrated on load

- [ ] **Step 1: Add migration to add the column**

In `ensureInitialized()` (the method that creates tables), add an `ALTER TABLE` migration after the existing `CREATE TABLE` statements. Use a try/catch since `ALTER TABLE ADD COLUMN` fails silently if the column already exists:

```swift
// Migration: add context_snapshot column
do {
    try db.exec("""
        ALTER TABLE event_index ADD COLUMN context_snapshot TEXT
    """)
} catch {
    // Column already exists, ignore
}
```

- [ ] **Step 2: Update insert statement to include snapshot**

In `insertEventsInTransaction`, the `insertEventIndex` SQL needs to include the new column. Find the INSERT statement for `event_index` and add `context_snapshot`:

Change the INSERT to include the snapshot column, and bind the JSON-encoded snapshot:

```swift
let snapshotJSON = event.contextSnapshot.map { snapshot in
    let encoder = JSONEncoder()
    return try? encoder.encode(snapshot).flatMap { String(data: $0, encoding: .utf8) }
} ?? nil
```

Bind it to the INSERT parameter.

- [ ] **Step 3: Update load to decode snapshot**

In `loadRecentSpine` (or wherever `event_index` rows are read), add `context_snapshot` to the SELECT columns and decode it:

```swift
let contextSnapshot: EventContextSnapshot? = row.column(named: "context_snapshot").flatMap { jsonText in
    guard let data = jsonText.dataValue else { return nil }
    return try? JSONDecoder().decode(EventContextSnapshot.self, from: data)
}
```

Pass this into the `SpineRow` or equivalent intermediate struct, then into the final `WiFiObservationEvent`.

- [ ] **Step 4: Run tests**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests -only-testing:WiFiLensProTests 2>&1 | tail -5`

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
cd Pro && git add Events/WiFiObservationEventSQLiteStore.swift && git commit -m "feat: persist EventContextSnapshot in SQLite"
cd .. && git add Pro && git commit -m "feat: persist EventContextSnapshot in SQLite"
```

---

### Task 3: Capture context snapshot at event creation

**Files:**
- Modify: `Pro/Events/WiFiObservationEvent.swift` (WiFiEventRecorder, lines 104-185)
- Modify: `Pro/Events/RoamingEventDetector.swift`

**Interfaces:**
- Consumes: `WiFiObservation.currentStatus` (available in recorder)
- Produces: `WiFiObservationEvent` instances with `contextSnapshot` populated

- [ ] **Step 1: Update RoamingEventDetector to accept and pass context**

Change the `detect` method signature to accept an optional snapshot parameter:

```swift
static func detect(
    previous: WiFiCurrentStatus?,
    current: WiFiCurrentStatus,
    contextSnapshot: EventContextSnapshot? = nil
) -> [WiFiObservationEvent]
```

In each `WiFiObservationEvent(...)` initializer call inside `detect()`, add `contextSnapshot: contextSnapshot`.

- [ ] **Step 2: Update WiFiEventRecorder to create and pass snapshot**

In `WiFiEventRecorder.record()`, create the snapshot from `currentStatus` before calling the detector:

```swift
if let currentStatus = observation.currentStatus {
    let snapshot = currentStatus.eventContextSnapshot
    events.append(contentsOf: RoamingEventDetector.detect(
        previous: previousStatus,
        current: currentStatus,
        contextSnapshot: snapshot
    ))
    previousStatus = currentStatus
}
```

For latency spikes (which are created directly in the recorder, not via the detector), also attach the snapshot:

```swift
if let currentLatency = observation.gatewayLatency {
    if let event = detectLatencySpike(previous: previousLatency, current: currentLatency) {
        var eventWithSnapshot = event
        eventWithSnapshot.contextSnapshot = observation.currentStatus?.eventContextSnapshot
        events.append(eventWithSnapshot)
    }
    previousLatency = currentLatency
}
```

- [ ] **Step 3: Run tests**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests -only-testing:WiFiLensProTests 2>&1 | tail -5`

Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
cd Pro && git add Events/WiFiObservationEvent.swift Events/RoamingEventDetector.swift && git commit -m "feat: capture EventContextSnapshot from WiFiCurrentStatus at event creation"
cd .. && git add Pro && git commit -m "feat: capture EventContextSnapshot at event creation"
```

---

### Task 4: Surface snapshot in presentation model

**Files:**
- Modify: `Pro/Timeline/TimelineViewModel.swift`

**Interfaces:**
- Consumes: `WiFiObservationEvent.contextSnapshot` (from Task 1-3)
- Produces: `TimelineEventPresentation.contextSnapshot` field

- [ ] **Step 1: Add contextSnapshot to TimelineEventPresentation**

In `TimelineEventPresentation` struct, add:

```swift
let contextSnapshot: EventContextSnapshot?
```

- [ ] **Step 2: Pass snapshot through in the presentation mapping**

In the `WiFiObservationEvent.presentation` computed property, add `contextSnapshot: contextSnapshot` to every `TimelineEventPresentation(...)` initializer call. There are 6 event type cases — add it to all of them.

- [ ] **Step 3: Run tests**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests -only-testing:WiFiLensProTests 2>&1 | tail -5`

Expected: Tests that construct `TimelineEventPresentation` directly will fail because they don't pass the new required field. Fix them by adding `contextSnapshot: nil`.

- [ ] **Step 4: Fix failing tests**

In `Pro/Tests/WiFiLensProTests/TimelinePresentationTests.swift`, add `contextSnapshot: nil` to both `TimelineEventPresentation(...)` initializer calls.

- [ ] **Step 5: Run tests again**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests -only-testing:WiFiLensProTests 2>&1 | tail -5`

Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
cd Pro && git add Timeline/TimelineViewModel.swift Tests/WiFiLensProTests/TimelinePresentationTests.swift && git commit -m "feat: surface EventContextSnapshot in TimelineEventPresentation"
cd .. && git add Pro && git commit -m "feat: surface EventContextSnapshot in TimelineEventPresentation"
```

---

### Task 5: Display snapshot in inline detail panel

**Files:**
- Modify: `Pro/Timeline/TimelineView.swift` (TimelineEventInlineDetail)

**Interfaces:**
- Consumes: `TimelineEventPresentation.contextSnapshot` (from Task 4)
- Produces: Richer inline detail panel with network context

- [ ] **Step 1: Add context snapshot section to inline detail**

In `TimelineEventInlineDetail.body`, after the existing from/to and badge sections, add a context snapshot section:

```swift
if let snapshot = event.contextSnapshot {
    Divider()

    VStack(alignment: .leading, spacing: 6) {
        if let ssid = snapshot.ssid {
            contextRow(label: "Network", value: ssid)
        }
        if let bssid = snapshot.bssid {
            contextRow(label: "BSSID", value: bssid)
        }
        HStack(spacing: 16) {
            if let channel = snapshot.channel, let band = snapshot.band {
                contextRow(label: "Channel", value: "Ch \(channel) (\(band))")
            }
            if let rssi = snapshot.rssi {
                contextRow(label: "RSSI", value: "\(rssi) dBm")
            }
        }
        HStack(spacing: 16) {
            if let security = snapshot.security {
                contextRow(label: "Security", value: security)
            }
            if let phyMode = snapshot.phyMode {
                contextRow(label: "PHY", value: phyMode)
            }
        }
        if let iface = snapshot.interfaceName {
            contextRow(label: "Interface", value: iface)
        }
    }
}
```

Add the helper method:

```swift
private func contextRow(label: String, value: String) -> some View {
    HStack(spacing: 4) {
        Text(label)
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .frame(width: 52, alignment: .trailing)
        Text(value)
            .font(.caption)
            .fontWeight(.medium)
    }
}
```

- [ ] **Step 2: Adjust detail panel height**

The detail panel currently has a fixed height of 120pt (`TimelineLayout.detailPanelHeight`). With the context snapshot, it needs more space. Change to a dynamic height based on content, or increase the fixed height.

Simplest approach: change `detailPanelHeight` from 120 to 180 in `TimelineLayout`.

- [ ] **Step 3: Run tests**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests -only-testing:WiFiLensProTests 2>&1 | tail -5`

Expected: All tests pass.

- [ ] **Step 4: Build and verify visually**

Run: `xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build`

Then launch the app, navigate to Timeline, click an event row, and verify the context snapshot data appears in the inline detail panel.

- [ ] **Step 5: Commit**

```bash
cd Pro && git add Timeline/TimelineView.swift && git commit -m "feat: display EventContextSnapshot in timeline inline detail panel"
cd .. && git add Pro && git commit -m "feat: display EventContextSnapshot in timeline inline detail panel"
```
