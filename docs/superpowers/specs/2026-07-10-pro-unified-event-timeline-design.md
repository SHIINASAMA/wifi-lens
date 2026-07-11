# Pro Unified Event Timeline Design

> **Status: Superseded as an architecture input.** The historical design is
> retained below, but its `WiFiObservationStore`-as-input architecture is
> superseded by
> `2026-07-11-observation-runtime-migration-design.md` and
> `2026-07-11-production-observation-runtime-migration.md`. Pro event delivery
> now consumes exact immutable observations from `WiFiObservationRuntime`.

## Goal

Make the Pro menu bar and Pro timeline present, navigate to, and clear one
authoritative stream of Wi-Fi events, while keeping all paid event features out
of the OSS target.

## Scope

This design replaces the menu bar's independent `ConnectionRecorder`,
`ConnectionEvent`, `EventDetector`, and JSON `EventStore` event pipeline. It
does not change Wi-Fi scanning, the observation pipeline, recording sessions,
or any OSS user-facing feature.

## Product Requirements

1. The menu bar and timeline must show events produced by the same event ID,
   event type, timestamp, and persistence store.
2. Selecting an event in the menu bar must open the main window's timeline,
   make the event visible, and expand its inline detail if it remains in the
   current result set.
3. Selecting "View All" must open the timeline without inventing an event
   selection.
4. Clearing timeline data must clear every event shown by the Pro menu bar and
   timeline immediately.
5. Timeline range, search, and type filters must retain their effective values
   after navigating away from the timeline and back.
6. A custom date range must always be valid: its end date cannot precede its
   start date.
7. The OSS target must not compile, persist, or display any paid event timeline
   or menu-bar-event behavior.

## Architecture

### Ownership boundary

`WiFiObservationStore` remains in the main application module and is the only
cross-boundary input. It already contains current Wi-Fi status and latency.

All event-specific code remains in the `WiFiLensPro` target under `Pro/Events`,
`Pro/Timeline`, and `Pro/MenuBar`, guarded by the existing Pro target build
configuration. OSS must not receive a new event model, event database, or
event UI dependency.

### Single source of truth

`WiFiObservationEventCoordinator` remains the only event producer. It observes
`WiFiObservationStore`, sends observations to `WiFiEventRecorder`, persists
the resulting `WiFiObservationEvent` values through a Pro-only
`WiFiObservationEventTimelineController`.

The controller is the consistency boundary around
`WiFiObservationEventSQLiteStore` and `WiFiObservationEventRecentStore`. It
owns a monotonically increasing data generation. The coordinator and timeline
view model no longer read or mutate the event log directly:

- every asynchronous load captures the current generation and may publish its
  result only while that generation is still current;
- every observation captures a generation before event detection and may be
  accepted only while that generation is still current;
- clearing advances the generation and clears the recent buffer before waiting
  for persistence, invalidating all older loads and observations immediately;
- events arriving after clearing begins belong to the new generation and are
  kept in memory, queued while deletion is in progress, and persisted after the
  deletion barrier completes.

This makes clearing a linearization boundary: events from before the clear
cannot reappear, while events produced after the clear begins remain visible.
The controller does not expose its raw event-log store to UI consumers.

`ProObservationEventBootstrap` owns that coordinator and controller. It
exposes narrowly scoped Pro APIs for:

- creating a timeline view model;
- observing recent events for menu-bar presentation;
- clearing all event data; and
- requesting timeline navigation to an optional event ID.

The menu bar no longer samples the network, detects events, or maintains a
second event file. It maps `WiFiObservationEvent` to display-only menu rows.
The timeline continues to map the same event to its richer presentation.

### Navigation contract

Add a Pro-only `TimelineNavigationRequest` value containing an optional event
UUID. The app scene owns the pending request and passes it into the root view,
so it survives replacement of the conditional `TimelineView`.

When a menu-bar row is activated, `MenuBarStatusViewModel` forwards the event
UUID to its scene callback. The app root sets the selected page to Timeline and
stores that UUID. `TimelineView` receives the pending request and, after its
event log/recent store load completes, selects and scrolls to the matching
event. It then consumes the request. If an event has been pruned or cleared,
the page opens normally with no selection.

"View All" uses the same callback with `nil`, so it never changes the current
filters or claims to select an event.

### Filter state and validation

The app root remains the owner of timeline filter state because the timeline
view is conditionally created. On every TimelineView appearance it copies the
selected range, custom start/end dates, search text, and enabled types into its
view model before starting it. All subsequent binding changes update that same
view model.

The filter panel clamps an edited start date to no later than the end date and
an edited end date to no earlier than the start date. `TimelineView` performs
one explicit binding-to-view-model synchronization on appearance: it
normalizes the parent-owned range, writes a corrected endpoint back only when
needed, and then prepares the view model from those normalized values.

Subsequent binding changes follow the same binding -> normalization -> view
model direction. The view no longer subscribes to the view model's initial
`@Published` date values, so a newly created timeline cannot overwrite dates
retained by the app root before preparation. The view model retains defensive
normalization for programmatic callers.

### Data deletion and legacy data

`clearTimelineData()` delegates to the timeline controller. The controller
advances its generation, immediately empties the shared recent buffer, deletes
the unified SQLite event log, and then flushes any new-generation events that
arrived during deletion. Since menu rows use that buffer, both views become
empty through their normal subscriptions while post-clear events remain live.

The legacy `connection_events.json` is not migrated: it has one-hour retention
and incompatible event semantics. The legacy recorder and store are removed
from the Pro target, so existing files become unreachable application-support
data. No user-visible migration or data-loss prompt is required because those
events were never part of the authoritative timeline.

## Failure Handling

An event-log write failure is logged by the coordinator. The recent store still
updates, so the current session's menu bar and timeline remain consistent. On a
later reload only persisted events can be recovered, which is the existing
durability behavior.

If deletion fails, the controller ends the deletion barrier, attempts to
persist any queued new-generation events, and propagates the deletion error to
the settings UI. It never accepts an old-generation load after a clear attempt.

When a navigation request references a missing event, the timeline clears the
request and presents its normal filtered list or empty state. It does not show
an error because pruning and clearing are legitimate causes.

## Test Strategy

Use Swift Testing in `WiFiLensProTests` for all new Pro behavior:

1. Menu-bar presentation receives events from the shared recent store, not a
   `ConnectionEvent` recorder.
2. A menu event navigation request preserves its UUID until TimelineViewModel
   has loaded and selects that UUID.
3. `View All` sends no UUID.
4. Clearing the bootstrap store empties both timeline and menu-bar observers.
5. TimelineViewModel applies custom ranges and event-type filters.
6. Recreated TimelineView state receives preserved custom dates, search text,
   and enabled types.
7. Date normalization maintains `start <= end`.
8. A timeline reload started before clear cannot restore its captured events
   after a post-clear empty reload.
9. An observation started before clear is rejected, while an observation that
   starts after clear begins is retained and persisted after deletion.
10. Recreating `TimelineView` cannot publish its view-model defaults back over
    the parent-owned custom dates before preparation.

Run the Pro unit target and the OSS unit target separately. Do not run UI test
bundles unless explicitly requested.

## Acceptance Criteria

- There is exactly one persisted Pro Wi-Fi event store and one event detector.
- Searching for `ConnectionRecorder`, `ConnectionEvent`, `EventStore`, and
  `Pro/MenuBar/EventDetector.swift` returns no production references.
- Menu rows and timeline entries derive from `WiFiObservationEvent.id`.
- A menu-row action carries the exact event UUID into the timeline selection.
- Clearing data empties both consumer surfaces without restarting the app.
- A pre-clear asynchronous load cannot publish after the clear boundary.
- Events produced after clearing begins survive the deletion barrier.
- Timeline date synchronization does not depend on SwiftUI lifecycle ordering.
- OSS tests and Pro tests pass; no UI tests are required for this change.
