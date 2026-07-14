# Runtime Backpressure and Pro State Preservation Design

## Status

Approved for specification review.

## Goal

Fix the edition-composition lifecycle regression and bound scan-cycle work so active Pro state survives route changes, interface data is fetched once per cycle, and slow processing cannot accumulate stale scans or consumer work.

## Decisions

- Normal scanning and recording use newest-observation semantics under overload. A newer cycle replaces pending stale work; dropped cycles are counted diagnostically.
- Pro Spectrum recording/session and Timeline state are owned by a long-lived Pro-only coordinator for the main-window lifetime.
- Each scan cycle reads `NetworkInfoService.fetchAll()` once. Both `WiFiCurrentStatus` and the Interfaces projection derive from that immutable snapshot.
- Pro-only Markdown export commands move behind `EditionComposition`.

## Pro State Ownership

`ProEditionComposition` creates one coordinator per main-window scene. It is not process-wide or static. Route changes preserve that coordinator; destroying the owning main-window scene tears it down.

The coordinator is internally split into two focused owners behind the single `EditionComposition` façade:

- `ProSpectrumSessionState` owns `RecordingViewModel?`, readiness, and recording/session lifecycle.
- `ProTimelinePresentationState` owns search text, custom dates, enabled event types, inspector presentation, and navigation state.

Route changes must not destroy either owner. Spectrum and Timeline views may be conditionally rendered, but re-entering either route receives the same coordinator-backed state. On main-window teardown, spectrum session teardown must stop any active recording/session and restore scan-interval overrides before releasing its state.

Persistent presentation/session state is separate from route-visible task ownership. Timeline query, filter, and navigation state survives route changes, but Timeline loading and observation tasks stop while Timeline is inactive unless a documented operation explicitly requires them. `ProEditionWindowState.tearDown()` is idempotent, is invoked by the actual owning scene lifecycle, and restores scan overrides exactly once across repeated calls.

## Single Interface Snapshot

The runtime creates a value-semantic `Sendable` interface snapshot with a cycle identifier and capture timestamp. The current-connection provider derives `WiFiCurrentStatus` from that snapshot instead of calling `NetworkInfoService.fetchAll()` itself. `ScannerViewModel` assigns its Interfaces projection from the same snapshot. Tests prove matching cycle identifier and timestamp, not merely one service invocation.

## Bounded Latest-Only Processing

There is exactly one raw-cycle admission buffer in the complete pipeline: one in-flight cycle plus one latest pending cycle. No `AsyncStream` may add another backlog. If a newer cycle arrives while that pending slot is occupied, it replaces the pending older cycle. Every replacement increments a dropped-cycle diagnostic counter exposed for tests and debug visibility. The deterministic overload sequence is A in-flight, B pending, C replacing B; consumer delivery is exactly A then C and the replacement counter is one.

Raw scan observations and live presentation projections are coalescible. Already-derived domain events are not: connection, disconnection, roaming, IP-change, and equivalent Journal events must never be silently replaced once derived.

Journal persistence uses a bounded ordered queue with an explicit capacity constant. When it reaches capacity, derived-event admission waits for capacity; it does not replace an event or make SQLite completion part of the critical path for non-critical live UI projections. Saturation count, current depth, and time spent backpressured are emitted as diagnostics. Cancellation removes blocked admission without leaking tasks; shutdown deterministically resumes queued and blocked waiters. Normal shutdown callers join the worker, while process termination separately bounds that join because a persistence adapter may ignore cancellation. A persistence failure remains governed by the Journal's existing documented live-recent behavior.

Route-scoped Timeline cancellation may also remove a queued, not-yet-running query/drain barrier so inactive presentation work does not remain behind a suspended append. This cancellation never removes an admitted append or delete operation.

Normal application termination is coordinated through AppKit's `applicationShouldTerminate`. Repeated requests share one operation. A three-second process deadline covers both scanner/runtime stop and the target-selected edition hook; when it expires, the coordinator requests cancellation and sends the single delayed AppKit reply without awaiting a non-cooperative loser. The scanner synchronously enters a persistent terminating gate before its first suspension, stops CoreWLAN monitoring, cancels its monitoring/startup tasks, and submits a runtime stop that supersedes an already-suspended start. Subsequent reconcile, start, restart, and lifecycle-enqueue requests cannot revive scanning. OSS has a no-op edition hook.

Pro separately bounds both the shared Journal drain and the wait for its already-linearized shutdown. The default local drain limit is two seconds. Drain outcome and shutdown-completion outcome are distinct diagnostics. These bounds guarantee an AppKit reply; they do not guarantee that a synchronous SQLite call or another non-cooperative dependency has returned. After the deadline, the operation has been asked to cancel and the process may exit while that work is still suspended. No second persistence queue or detached long-lived task chain is created. Live unpersisted accounting has explicit permanent and pending-at-shutdown states. Persistence failure, cancelled blocked append admission, and queued or blocked append disposal at shutdown add to one O(1) permanent scalar; they do not retain request identities. Only an in-flight append becomes request-keyed pending work when shutdown linearizes. The single persistence worker bounds this dictionary to at most one entry. Later success removes it, while failure or cancellation moves its count into the permanent scalar without changing the total. Actor serialization plus exclusive request ownership ensures each request takes one terminal path. Every aggregate addition saturates at `UInt64.max` rather than wrapping. A termination diagnostic is an immutable cutoff snapshot, so it does not change if live accounting later converges after a non-cooperative append succeeds.

This policy intentionally favors fresh Wi-Fi state and bounded resource use over processing stale historical scan cycles.

## Command Composition

The shared app root retains the common export menu shell. `EditionComposition` supplies the edition-specific Markdown export action in Pro and the existing locked preview in OSS. Shared root code must not name `MarkdownExportService`.

## Tests

- Navigate away/back during active recording and prove the same recording session survives.
- Destroy a main-window scene with an active recording and prove teardown stops the session and restores the scan interval.
- Navigate away/back with Timeline search, date range, event filters, inspector, and menu-bar event selection; prove state survives.
- Prove two main-window scenes do not share Spectrum or Timeline coordinator state, and lifecycle/bootstrap registration remains duplicate-safe per scene/runtime contract.
- Assert one `NetworkInfoService` snapshot per runtime cycle feeds both status and Interfaces projection.
- Simulate slow runtime processing and assert one in-flight plus one pending slot, newest-cycle delivery, and replacement diagnostics.
- Simulate persistence overload and assert ordered Journal event delivery, backpressure diagnostics, and no silent replacement of derived events.
- Cancel pending raw cycles, saturated Journal admission, runtime shutdown, and coordinator teardown; assert no retained task, waiter, or scan-interval override remains.
- Audit shared root for `RecordingViewModel`, Timeline types, journal bootstrap, Menu Bar, and Markdown export implementation symbols.

## Non-Goals

- No user-visible route, copy, edition entitlement, or normal-cadence scan behavior changes.
- No lossless backlog replay.
- No UI test bundle unless explicitly requested.
