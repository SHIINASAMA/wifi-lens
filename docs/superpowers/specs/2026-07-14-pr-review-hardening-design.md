# PR Review Hardening Design

**Date:** 2026-07-14
**Status:** Approved for specification review
**Scope:** Address the confirmed termination-budget and duplicate-persistence findings from the PR #14 review without broadening the observation-runtime refactor.

## Goal

Keep Pro journal termination inside the application's three-second termination deadline and make SQLite event replay idempotent without changing live event semantics, schema version, or OSS behavior.

## Decisions

- Pro journal drain and shutdown share one two-second monotonic budget.
- The remaining application deadline stays available for stopping the shared observation runtime and sending the AppKit termination reply.
- Journal shutdown still linearizes after the drain outcome, even when the shared Pro budget has been exhausted.
- SQLite event inserts treat an existing event ID as an already-persisted success.
- Idempotency is enforced at the persistence boundary so it also covers events no longer present in the Journal's bounded recent buffer.
- The existing primary keys and schema version remain unchanged.

## Termination Budget

`ProObservationEventBootstrap.prepareForTermination` establishes one `ContinuousClock` deadline from a default two-second total timeout. The drain phase receives the current remaining duration. After drain completes, fails, is cancelled, or times out, the Journal begins shutdown and the shutdown wait receives only the duration still remaining before the same deadline.

Beginning shutdown is not conditional on remaining time. This preserves queue linearization, blocked-admission cleanup, and unpersisted-event accounting even if the shutdown wait immediately times out. The existing outcome and shutdown-outcome diagnostics remain distinct.

The shared application coordinator retains its three-second hard deadline. The Pro hook therefore cannot intentionally consume four seconds before returning diagnostics.

## Idempotent Persistence

`WiFiObservationEventSQLiteStore` retains `event_index.id` and each typed table's `event_id` primary key. Inserts use SQLite's ignore-on-conflict behavior for those keys. Replaying an already-persisted event becomes a no-op, while other new events in the same transaction are still inserted and committed.

This behavior applies at the SQLite adapter rather than only in `WiFiObservationEventJournal.appendRecent`. The recent buffer is capped, so Journal-only deduplication cannot recognize an old event ID after eviction.

No existing row is overwritten when a replay presents the same ID with different payload data. The first committed event remains authoritative.

## Excluded Review Findings

- The nonisolated asynchronous pipeline is not moved off MainActor because Swift 6 already executes its non-actor-isolated asynchronous work on the generic executor; performance changes require Instruments evidence.
- Rejected publication does not gain an automatic restart. Authorization or Wi-Fi rejection synchronously transitions the scanner to stopped state, and configuration changes must not revive an ineligible scan.
- Timestamp diagnostics bookkeeping, `accept(_:)` documentation, and defensive `deinit` isolation are lower-priority follow-up work outside this hardening change.
- The intentional destructive v2 development-schema reset is unchanged.

## Tests

- Suspend persistence long enough to consume the drain portion of a short shared timeout and prove shutdown receives only the remaining budget.
- Prove the complete Pro termination hook returns within its single supplied timeout while still beginning Journal shutdown and reporting unpersisted events.
- Append the same event ID twice and prove the second append succeeds without adding a duplicate.
- Append a duplicate ID and a new ID in one batch and prove the new event commits rather than the whole transaction rolling back.
- Run Pro unit tests, OSS `WiFiLensTests`, and Debug builds for both app targets. UI tests remain out of scope.

## Non-Goals

- No event-model, schema-version, scan cadence, or user-visible behavior changes.
- No retry queue, upsert semantics, or historical-row mutation.
- No unrelated PR review cleanup.
