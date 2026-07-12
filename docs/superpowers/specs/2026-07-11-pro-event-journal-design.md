# Pro Event Journal Design

**Date:** 2026-07-11
**Status:** Approved
**Scope:** Consolidate the Pro-only Wi-Fi event lifecycle behind one deep journal module without changing event semantics, persistence format, or OSS behavior.

## Goal

Replace the current chain of shallow event-lifecycle modules with one Pro-only `WiFiObservationEventJournal` that owns exact-observation ingestion, event derivation, optimistic recent publication, persistence, hydration, querying, clear generations, clear-time queuing, and stale-work rejection.

The journal must make the event lifecycle understandable from one implementation while retaining `WiFiObservationEventLogStoring` as the persistence seam and `WiFiObservationEventSQLiteStore` as the production adapter.

## Current Problem

One accepted observation currently crosses all of these lifecycle owners:

```text
Runtime consumer worker
  -> WiFiObservationEventCoordinator
  -> WiFiEventRecorder
  -> WiFiObservationEventTimelineController
  -> WiFiObservationEventRecentStore
  -> WiFiObservationEventLogStoring
  -> TimelineViewModel / MenuBarStatusViewModel
```

The clear generation, clear queue, hydration validation, recent publication, persistence ordering, and UI invalidation rules are distributed across the coordinator, timeline controller, recent store, Bootstrap notification, and view model. Callers must understand internal generation timing and compensate for clear through a process-wide notification.

This arrangement is locally simple but globally shallow: the important invariant is the lifecycle of the journal, yet no single module owns that lifecycle.

## Constraints

- The entire journal implementation remains Pro-only. OSS may expose `WiFiObservation`, `WiFiObservationConsuming`, and the shared runtime, but no Pro event model, journal, recorder, or persistence type may enter the OSS Sources phase.
- `WiFiObservationEventLogStoring` remains the only persistence protocol. SQLite and controllable in-memory, delayed, and failing test adapters must continue to conform to it.
- `WiFiObservationEventSQLiteStore` remains the production persistence adapter and its schema is unchanged.
- The journal consumes the exact immutable `WiFiObservation` delivered by `WiFiObservationRuntime`; it must never reconstruct event input from `WiFiObservationStore`.
- Existing connection semantics remain unchanged: different known SSIDs produce disconnect plus connect; a BSSID change within the same known SSID produces roam; missing SSID identity falls back to disconnect plus connect.
- Recent publication remains optimistic: derived events become visible before persistence completes.
- UI tests are outside the default verification scope. Verification uses Pro unit tests, OSS unit tests, and both Debug builds.
- No new third-party dependency is introduced.

## Considered Approaches

### 1. Journal consumes exact observations — selected

The journal implements `WiFiObservationConsuming` and owns derivation, lifecycle consistency, recent publication, query, and persistence. Bootstrap constructs and registers the journal.

This is the only approach that hides the generation captured before asynchronous derivation. It removes the need for callers to understand `accept(events:generation:)`.

### 2. Journal consumes classified events

The coordinator and recorder would remain outside the journal. Migration would be smaller, but the coordinator would still capture generation before derivation and pass it into the journal. Clear linearization would therefore remain a cross-module responsibility.

This does not meet the depth and locality goal.

### 3. Actor core plus observable facade

A separate actor would own consistency state while a MainActor facade published UI state. This provides strong mechanical isolation but creates another cross-module synchronization boundary and duplicates state transfer for a lifecycle that is already serialized on MainActor.

The current workload does not justify the additional facade.

## Chosen Architecture

```text
WiFiObservationRuntime
  -> WiFiObservationEventJournal
       |- exact-observation derivation and cooldown
       |- current generation and stale-work rejection
       |- optimistic recent publication (limit 50)
       |- hydration and generation-safe query
       |- clear coalescing and clear-time queue
       `- WiFiObservationEventLogStoring
            `- WiFiObservationEventSQLiteStore

TimelineViewModel -> journal query + recent publication
MenuBarStatusViewModel -> journal recent publication
Settings -> ProObservationEventBootstrap.clearTimelineData() -> journal.clear()
```

`ProObservationEventBootstrap` remains the composition adapter. It owns the shared journal instance, registers it with the runtime once, and injects it into Pro UI view models. It does not own event lifecycle state.

## Journal Surface

The journal is a concrete type. There is no journal protocol because there is one production implementation and no second adapter boundary.

```swift
@MainActor
final class WiFiObservationEventJournal: ObservableObject, WiFiObservationConsuming {
    @Published private(set) var recentEvents: [WiFiObservationEvent] = []

    func start()
    func consume(_ observation: WiFiObservation) async throws
    func queryRecent(limit: Int) async -> [WiFiObservationEvent]
    func clear() async throws
}
```

The journal does not expose generation, hydration, queueing, merge, replacement, classified-event acceptance, or persistence ordering.

An internal initializer may accept an asynchronous event-derivation closure so tests can suspend derivation and prove the clear-generation barrier. Production composition supplies `WiFiEventRecorder.record`. This replaces the production-facing `WiFiObservationEventRecording` protocol without losing a deterministic concurrency test seam.

## State Ownership

The journal owns:

- `recentEvents`, capped at 50 and deduplicated by event ID;
- the current clear generation;
- whether a clear is active;
- events accepted after clear starts and before deletion completes;
- the active coalesced clear task;
- whether the persisted snapshot is currently valid for UI queries;
- idempotent hydration startup;
- the concrete recorder used to derive events and apply cooldown;
- the persistence adapter reference.

The journal does not own Timeline filters, Timeline selection, menu presentation formatting, live connection metrics, SQLite schema logic, or observation production.

## Ingest Semantics

`consume(_:)` preserves the current coordinator behavior:

1. Reject an observation without `currentStatus`. A latency-only observation does not create an event.
2. Capture the current generation before awaiting event derivation.
3. Derive connection, roaming, signal, channel, and latency events from the exact observation.
4. Reject the result if the generation changed while derivation was suspended.
5. Ignore an empty result.
6. Append new event IDs to `recentEvents` before persistence.
7. If clear is active, add the events to the internal clear queue and return without writing to the log immediately.
8. Otherwise append the batch through `WiFiObservationEventLogStoring` and propagate any error.

The recent-first order is deliberate. A persistence failure must not retract an event already visible in the menu or Timeline.

## Query and Hydration Semantics

`start()` is idempotent and begins an internal hydration of the 50-event recent buffer by calling the same generation-safe query path used by Timeline. The returned snapshot already includes live recent events that arrived during the load, so hydration replaces the recent buffer with that result without overwriting live work.

`queryRecent(limit:)` returns a valid linearized array, not an optional stale marker:

1. If the persisted snapshot is invalid because a clear is active or its deletion failed, return the current optimistic recent snapshot without reading persistence.
2. Otherwise capture the current generation and load persisted events.
3. If the generation changed or persistence became invalid during the load, retry against the current state.
4. Merge persisted events with optimistic `recentEvents` by ID.
5. Sort deterministically by timestamp and UUID tie-break and return the requested suffix.

This hides generation handling from `TimelineViewModel` and keeps optimistic events visible even when persistence append failed.

## Clear Semantics

`clear()` preserves the existing linearization contract:

1. Concurrent callers await the same active clear task.
2. The first caller increments generation exactly once.
3. The journal enters clearing state, marks the persisted snapshot invalid for queries, discards any stale queue, and publishes an empty recent array immediately.
4. The journal awaits `deleteAll()`.
5. Observations derived after the generation increment publish immediately to recent and enter the clear queue.
6. After successful deletion, the journal marks persistence valid and repeatedly drains and appends queued batches while remaining in clearing state.
7. When no queued event remains, the journal leaves clearing state without another suspension and completes the shared clear task.

Events whose derivation began before clear are rejected by their captured generation. Events whose derivation began after clear survive the deletion barrier.

No global clear notification is posted. Publishing `recentEvents = []` directly clears the menu and instructs `TimelineViewModel` to replace its local event set with empty state. Later clear-time events arrive through the same publisher.

## Failure Semantics

The refactor preserves these existing behaviors and adds characterization tests before structural deletion:

### Normal append failure

- Recent publication remains visible.
- The append error propagates from `consume` to the runtime consumer worker.
- The failed batch is absent from persistence.

### `deleteAll` failure

- The already-published empty recent state remains authoritative for pre-clear events.
- Events accepted during clear remain visible in recent.
- The journal drains the clear queue and attempts a best-effort append.
- Persistence remains invalid for queries during the current process, so a later reload cannot resurrect the old rows that failed deletion.
- The original delete error propagates.

### Post-delete queued append failure

- Clear-time events remain visible in recent.
- The failing batch is drained exactly once, and events that arrive while that append is suspended remain visible even if their best-effort persistence also fails.
- The append error propagates from `clear`.
- The journal does not claim persistence success or silently swallow the error.

These behaviors are intentionally not converted into rollback semantics during this architecture change.

## UI Integration

### Timeline

`TimelineViewModel` receives the journal directly. It:

- subscribes to `journal.$recentEvents`;
- replaces its local event set with empty state when the journal publishes an empty array;
- merges non-empty live recent events by ID;
- calls `queryRecent(limit: 500)` for reload, replaces local state with that snapshot, and immediately merges the Journal's then-current recent publication to close the query-return/continuation-resume window;
- retains date range, type, search, navigation, and presentation responsibilities.

It no longer observes a clear notification, reads a recent store, handles a nullable stale query, or compensates for controller internals.

### Menu Bar

`MenuBarStatusViewModel` receives the journal directly for event presentation. It continues to read live connection metrics from `WiFiObservationStore`, maps journal events to menu presentation, sorts newest first, retains five presentations, and displays the first three.

The Store remains a live-metric projection, not an event input bus.

### Settings and Bootstrap

The existing Settings action may continue to call `ProObservationEventBootstrap.clearTimelineData()`. Bootstrap delegates directly to the shared journal. It neither posts a notification nor coordinates a reload.

## Persistence Seam

`WiFiObservationEventLogStoring` remains unchanged:

```swift
protocol WiFiObservationEventLogStoring: Sendable {
    func append(_ events: [WiFiObservationEvent]) async throws
    func loadRecent(limit: Int) async -> [WiFiObservationEvent]
    func deleteAll() async throws
}
```

The protocol is justified by the production SQLite adapter and the in-memory, delayed-load, delayed-delete, and failing adapters needed to prove journal concurrency semantics.

The unused JSONL `WiFiObservationEventLogStore` has no construction site and is deleted.

## File and Module Changes

Create:

- `Pro/Events/WiFiObservationEventJournal.swift` — the complete public event-lifecycle surface and its private/internal state machinery.

Modify:

- `Pro/Events/WiFiObservationEvent.swift` — retain the domain model and persistence protocol; move the concrete recorder into the journal module and remove the JSONL store and recorder protocol.
- `Pro/Events/ProObservationEventBootstrap.swift` — construct, register, inject, and clear the shared journal only.
- `Pro/Timeline/TimelineViewModel.swift` — consume journal query and recent publication.
- `Pro/MenuBar/MenuBarStatusViewModel.swift` — consume journal recent publication.
- Pro tests — migrate construction to the journal and add characterization/concurrency coverage.
- `WiFiLens/WiFiLens.xcodeproj/project.pbxproj` — add the journal to Pro Sources and remove deleted Pro files.
- `Pro/docs/ARCHITECTURE.md` and `docs/ARCHITECTURE.md` — document the deep Journal boundary and Pro-only composition.

Delete:

- `Pro/Events/WiFiObservationEventCoordinator.swift`
- `Pro/Events/WiFiObservationEventTimelineController.swift`
- `Pro/Events/WiFiObservationEventRecentStore.swift`
- the JSONL `WiFiObservationEventLogStore` implementation;
- `Notification.Name.wifiLensTimelineDataDidClear` and all producer/consumer code;
- `WiFiObservationEventRecording` as a production protocol.

## Testing Strategy

### Characterization before deletion

Add deterministic tests for:

- normal append failure retaining recent publication while propagating the error;
- delete failure retaining clear-time recent events and attempting best-effort queue persistence;
- query after delete failure returning only the current recent snapshot rather than resurrecting pre-clear rows;
- successful delete followed by queued append failure retaining recent events while propagating the append error;
- derivation begun before clear and completed afterward being rejected;
- derivation begun after clear surviving the deletion barrier.

### Journal behavior

Migrate and retain coverage for:

- exact Runtime observation ordering;
- different-SSID switch versus same-SSID roam semantics;
- missing-SSID fallback;
- hydration not overwriting live events;
- stale hydration and stale query rejection after clear;
- concurrent clear coalescing;
- recent deduplication, ordering, and 50-event limit;
- Timeline and menu sharing event IDs and clear state;
- persistence round trips through SQLite.

### Deletion audit

The final audit must prove zero references to:

- `WiFiObservationEventCoordinator`;
- `WiFiObservationEventTimelineController`;
- `WiFiObservationEventRecentStore`;
- `WiFiObservationEventLogStore`;
- `wifiLensTimelineDataDidClear`;
- `WiFiObservationEventRecording`.

It must also prove that `WiFiObservationEventLogStoring` still has SQLite plus controllable test adapters and that no Journal implementation enters the OSS Sources phase.

## Acceptance Criteria

1. Runtime registers one Pro Journal consumer and passes exact observations directly to it.
2. Journal is the only owner of event generation capture, recent publication, hydration, query validation, clear queueing, and clear coalescing.
3. Timeline and menu consume the same Journal recent publication and preserve event IDs.
4. Timeline reload obtains a non-optional generation-safe Journal query result.
5. Clear requires no global Notification and cannot restore stale pre-clear data.
6. Optimistic recent visibility survives persistence append failure.
7. Existing clear failure and clear-time event semantics are preserved and directly tested.
8. SQLite remains the production persistence adapter behind `WiFiObservationEventLogStoring`.
9. The unused JSONL store and the three shallow lifecycle modules are deleted with PBX membership cleaned.
10. OSS and Pro unit tests pass, both Debug targets build, and no UI test bundle is run.

## Explicit Non-Goals

- No SQLite schema or migration change.
- No new event types or changes to classification thresholds.
- No change to connection-versus-roaming identity rules.
- No migration of menu live metrics away from `WiFiObservationStore`.
- No migration of Recording or MCP into the Journal.
- No remediation of the separate `RoamingProbeProvider` band-inference issue.
