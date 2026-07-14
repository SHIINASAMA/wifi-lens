# PR Review Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep Pro journal termination within one two-second budget and make SQLite event replay idempotent.

**Architecture:** `ProObservationEventBootstrap` will derive both drain and shutdown waits from one monotonic deadline, preserving distinct diagnostics while bounding their combined duration. `WiFiObservationEventSQLiteStore` will enforce replay idempotency at the database boundary with SQLite conflict-ignore inserts, preserving the first committed payload and allowing new events in a mixed replay batch to commit.

**Tech Stack:** Swift 6.0, Swift Concurrency, Swift Testing, SQLite3, Xcode 26 macOS unit-test targets.

## Global Constraints

- macOS 14+ and Swift 6.0 remain unchanged.
- No event-model, schema-version, scan-cadence, or user-visible behavior changes.
- No retry queue, upsert semantics, historical-row mutation, or third-party dependency.
- UI tests remain out of scope.
- Use `xcodebuild`; never use `swift build` or `swift test` for the app targets.
- Do not stage, commit, or push without a separate explicit user instruction.
- Preserve the existing user modification in `WiFiLens/Configs/Base.xcconfig`.

---

### Task 1: Share One Pro Termination Budget

**Files:**
- Modify: `Pro/Events/ProObservationEventBootstrap.swift:32-125`
- Test: `Pro/Tests/WiFiLensProTests/EventJournalTests.swift:31-176`

**Interfaces:**
- Consumes: `ContinuousClock`, `WiFiObservationEventJournal.drainPersistence()`, `beginShutdown()`, and existing termination diagnostics.
- Produces: `ProObservationEventBootstrap.prepareForTermination(timeout: Duration = terminationTimeout)` and `remainingDuration(until:clock:)`.

- [ ] **Step 1: Write the failing shared-budget test and update existing call labels**

Add this test to `EventJournalBootstrapTests` and change the five existing `drainTimeout:` call labels in the same suite to `timeout:`:

```swift
@MainActor
@Test("Pro termination shares one timeout across drain and shutdown")
func proTerminationUsesOneSharedTimeout() async throws {
    let event = makeEvent(id: 116, timestamp: 11_600, type: .connected(identity: unknownIdentity))
    let logStore = NonCooperativeJournalLogStore()
    let journal = WiFiObservationEventJournal(
        eventLogStore: logStore,
        deriveEvents: { _ in [event] }
    )

    try await ProObservationEventBootstrap.withEventJournalForTesting(journal) {
        try await journal.consume(makeObservation(timestamp: 11_600))
        await logStore.waitUntilAppendEntered()
        let clock = ContinuousClock()
        let startedAt = clock.now

        let diagnostics = await ProObservationEventBootstrap.prepareForTermination(
            timeout: .milliseconds(100)
        )
        let elapsed = startedAt.duration(to: clock.now)

        #expect(diagnostics.outcome == .timedOut)
        #expect(diagnostics.shutdownOutcome == .timedOut)
        #expect(elapsed < .milliseconds(150))
        #expect(diagnostics.unpersistedEventCount == 1)

        await logStore.releaseAppend()
        await journal.shutdown()
    }
}
```

- [ ] **Step 2: Run the focused suite and verify RED**

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens Pro" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensProTests/EventJournalBootstrapTests
```

Expected: compilation fails because `prepareForTermination` does not accept the `timeout:` label. This proves the test requires the new single-budget API rather than exercising the existing two-budget behavior.

- [ ] **Step 3: Implement the monotonic shared deadline**

Replace the current timeout constants and `prepareForTermination` implementation with:

```swift
static let terminationTimeout: Duration = .seconds(2)

static func prepareForTermination(
    timeout: Duration = terminationTimeout
) async -> ProEventJournalTerminationDiagnostics {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    let outcome = await boundedDrain(
        timeout: remainingDuration(until: deadline, clock: clock)
    )
    let shutdownTask = await journal.beginShutdown()
    let shutdownOutcome = await boundedShutdown(
        shutdownTask,
        timeout: remainingDuration(until: deadline, clock: clock)
    )
    let persistence = await journal.persistenceDiagnostics()
    let diagnostics = ProEventJournalTerminationDiagnostics(
        outcome: outcome,
        shutdownOutcome: shutdownOutcome,
        unpersistedEventCount: persistence.shutdownUnpersistedEventCount
    )
    lastTerminationDiagnostics = diagnostics
    logTerminationDiagnostics(diagnostics)
    return diagnostics
}

private static func remainingDuration(
    until deadline: ContinuousClock.Instant,
    clock: ContinuousClock
) -> Duration {
    max(.zero, clock.now.duration(to: deadline))
}
```

Delete `terminationDrainTimeout` and the `shutdownTimeout` parameter. Do not change `boundedDrain`, `boundedShutdown`, `firstResult`, or diagnostic cases.

- [ ] **Step 4: Run the focused suite and verify GREEN**

Run the command from Step 2.

Expected: `EventJournalBootstrapTests` passes; the non-cooperative test completes near the supplied 100 ms total rather than consuming two 100 ms phase budgets.

- [ ] **Step 5: Review the task diff without staging**

Run:

```sh
git -C Pro diff --check
git -C Pro diff -- Events/ProObservationEventBootstrap.swift Tests/WiFiLensProTests/EventJournalTests.swift
```

Expected: only the shared timeout API, its remaining-budget helper, call-label updates, and the new regression test appear.

---

### Task 2: Make SQLite Event Replay Idempotent

**Files:**
- Modify: `Pro/Events/WiFiObservationEventSQLiteStore.swift:305-420`
- Test: `Pro/Tests/WiFiLensProTests/WiFiObservationEventSQLiteStoreTests.swift:20-115`

**Interfaces:**
- Consumes: existing v2 primary keys on `event_index.id` and typed-table `event_id` columns.
- Produces: idempotent `WiFiObservationEventSQLiteStore.append(_:)` semantics in which the first committed row for an event ID remains authoritative.

- [ ] **Step 1: Write the failing mixed-replay test**

Add this test to `WiFiObservationEventSQLiteStoreTests`:

```swift
@Test func duplicateReplayDoesNotRollbackNewEventsInTheSameBatch() async throws {
    let databaseURL = temporaryDatabaseURL()
    defer { removeDatabase(at: databaseURL) }
    let store = WiFiObservationEventSQLiteStore(databaseURL: databaseURL)
    let existing = makeEvent(
        index: 90,
        type: .connected(identity: WiFiNetworkIdentity(ssid: "Existing", bssid: "00:11:22:33:44:55"))
    )
    let newEvent = makeEvent(
        index: 91,
        type: .channelChange(from: 36, to: 44)
    )

    try await store.append([existing])
    try await store.append([existing, newEvent])

    #expect(await store.loadRecent(limit: 10) == [existing, newEvent])
    #expect(try rowCount(in: "event_index", at: databaseURL) == 2)
}
```

- [ ] **Step 2: Run the SQLite suite and verify RED**

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens Pro" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensProTests/WiFiObservationEventSQLiteStoreTests
```

Expected: the new test throws a SQLite primary-key constraint error on the replayed `event_index.id`, and the mixed batch does not commit `newEvent`.

- [ ] **Step 3: Make every event insert ignore primary-key replay conflicts**

In `insertEventIndex` and every branch of `insertTypedEvent`, change only the insertion verb while preserving columns, bindings, and transaction boundaries:

```sql
INSERT OR IGNORE INTO event_index (id, occurred_at, kind, severity, source, context_snapshot)
VALUES (?, ?, ?, ?, ?, ?);

INSERT OR IGNORE INTO wifi_bssid_change_events (event_id, from_bssid, to_bssid)
VALUES (?, ?, ?);

INSERT OR IGNORE INTO wifi_channel_change_events (event_id, from_channel, to_channel)
VALUES (?, ?, ?);

INSERT OR IGNORE INTO wifi_signal_change_events (event_id, from_rssi, to_rssi)
VALUES (?, ?, ?);

INSERT OR IGNORE INTO wifi_latency_change_events (event_id, from_latency_ms, to_latency_ms)
VALUES (?, ?, ?);

INSERT OR IGNORE INTO wifi_connection_transition_events (
    event_id,
    from_state,
    to_state,
    from_ssid,
    from_bssid,
    to_ssid,
    to_bssid
) VALUES (?, ?, ?, ?, ?, ?, ?);
```

Do not use `INSERT OR REPLACE`: replay must not overwrite the first committed payload or trigger foreign-key replacement behavior.

- [ ] **Step 4: Run the SQLite suite and verify GREEN**

Run the command from Step 2.

Expected: the duplicate replay succeeds, exactly two index rows remain, and both the existing and new event load correctly.

- [ ] **Step 5: Run all Pro unit tests**

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens Pro" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensProTests
```

Expected: all Pro unit tests pass without UI test execution.

- [ ] **Step 6: Review the task diff without staging**

Run:

```sh
git -C Pro diff --check
git -C Pro diff -- Events/WiFiObservationEventSQLiteStore.swift Tests/WiFiLensProTests/WiFiObservationEventSQLiteStoreTests.swift
```

Expected: only the six conflict-policy changes and the replay regression test appear.

---

### Task 3: Cross-Target Verification and Documentation Consistency

**Files:**
- Modify: `docs/TESTING.md:46-48`
- Verify: `docs/superpowers/specs/2026-07-14-pr-review-hardening-design.md`
- Verify: `docs/superpowers/plans/2026-07-14-pr-review-hardening.md`

**Interfaces:**
- Consumes: the two completed Pro behavior changes.
- Produces: repository testing guidance that records the shared termination budget and idempotent persistence coverage.

- [ ] **Step 1: Update the Pro journal coverage paragraph**

Append these sentences to the Pro State and Journal Coverage paragraph in `docs/TESTING.md`:

```markdown
The bootstrap termination tests also enforce one shared two-second Pro budget across drain and shutdown, leaving the outer three-second application deadline authoritative. SQLite store tests replay an existing event ID alongside a new event and prove conflict-ignore persistence keeps the first payload without rolling back the new row.
```

- [ ] **Step 2: Run the full OSS unit suite**

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests
```

Expected: all OSS unit tests pass; no UI tests run.

- [ ] **Step 3: Build both app targets**

Run sequentially:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens Pro" -configuration Debug -destination 'platform=macOS' build
```

Expected: both commands end with `BUILD SUCCEEDED`.

- [ ] **Step 4: Perform final scope and whitespace checks**

Run:

```sh
git diff --check
git status --short
git -C Pro status --short
```

Expected: `WiFiLens/Configs/Base.xcconfig` remains modified but untouched; only the approved root documentation and intended Pro source/test files are newly changed. Do not stage, commit, or push.
