# Runtime Backpressure and Pro State Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve per-window Pro Spectrum/Timeline state, remove duplicate interface snapshots, and bound runtime work without dropping derived Journal events.

**Architecture:** A per-window Pro coordinator owns separate Spectrum session and Timeline presentation states. Runtime input carries one immutable interface snapshot. Scanning uses one in-flight cycle plus one replaceable latest pending cycle; Journal persistence is bounded and ordered with backpressure rather than event replacement.

**Tech Stack:** Swift 6, SwiftUI Observation, AsyncStream/actors, Swift Testing, macOS 14+.

## Global Constraints

- Coordinator is per main-window scene; idempotent scene-lifecycle teardown stops recording and restores scan interval overrides exactly once.
- Raw scan cycles are newest-only; derived Journal events are ordered and non-coalescible.
- Scan buffer is exactly one in-flight plus one latest pending cycle; each replacement increments diagnostics.
- Snapshot is value-semantic/Sendable with cycle ID and capture timestamp; status and Interfaces must prove identical provenance.
- Shared root must not name Pro recording, Timeline, Journal, menu-bar, or Markdown implementation symbols.
- No UI tests, commits, merges, or pushes without explicit authorization.
- Execute sequentially with fresh Subagents and no worktree.

---

### Task 1: Per-window Pro state coordinator

**Files:**
- Modify: `Pro/App/ProEditionComposition.swift`, `Pro/App/ProSpectrumCompositionView.swift`, `Pro/App/ProTimelineCompositionView.swift`, `Pro/Tests/WiFiLensProTests/EditionCompositionTests.swift`

**Produces:** `ProEditionWindowState` containing `ProSpectrumSessionState` and `ProTimelinePresentationState`, constructed by the main-window composition rather than a static façade.

- [x] Write failing tests proving route changes retain state while inactive Timeline tasks stop, repeated scene teardown stops recording/restores interval once, and distinct windows do not share state.
- [x] Run `xcodebuild ... -scheme "WiFi Lens Pro" ... -only-testing:WiFiLensProTests/EditionCompositionTests`; expect RED because state is still route-local/static.
- [x] Implement `@MainActor @Observable` state owners. Pass one `ProEditionWindowState` through the Pro detail composition. Add deterministic `tearDown()` that stops recording before releasing its view model.
- [x] Run the focused suite; expect all state/teardown tests green. Do not commit.

### Task 2: Single interface snapshot per cycle

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/Observation/Providers/WiFiCurrentConnectionProvider.swift`, runtime cycle/output models, `WiFiLens/Sources/WiFiLens/Scanner/ScannerViewModel.swift`, relevant Runtime/Provider tests.

**Produces:** an immutable interface snapshot on the cycle/output, used for both current status and `networkInfo`.

- [x] Add a fake interface source with a call counter; write a failing runtime-cycle test asserting one fetch plus matching snapshot cycle ID/timestamp in status and Interfaces data.
- [x] Run the focused Runtime/Provider test; expect two-fetch behavior to fail.
- [x] Fetch interfaces once through the `SystemNetworkInterfaceSnapshotSource` actor off the main actor, pass the immutable snapshot to status derivation, and assign `networkInfo` from output rather than calling `fetchAll()` in `handleRuntimeOutput`.
- [x] Run focused tests and OSS unit target; expect green. Do not commit.

### Task 3: Bounded raw-cycle and Journal persistence delivery

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/Scanner/WiFiScanner.swift`, `WiFiLens/Sources/WiFiLens/Observation/Runtime/WiFiObservationRuntime.swift`, Pro Journal delivery code, Runtime/EventJournal tests.

**Produces:** diagnostics for raw-cycle replacement and persistence saturation, latest-only raw-cycle buffer, and ordered bounded Journal backpressure.

- [x] Add failing deterministic tests: A blocked, B pending, C replaces B yields exactly A then C and one replacement; saturated bounded Journal admission preserves ordered events, exposes capacity/depth/saturation diagnostics, and cancellation/shutdown releases waiters without task leaks.
- [x] Run focused Runtime and Pro EventJournal tests; expect RED with current unbounded queues.
- [x] Implement the sole raw-cycle one-in-flight/one-pending gate without AsyncStream backlog. Implement bounded ordered Journal admission off the non-critical UI projection path, with cancellation and shutdown cleanup.

### Task 4: Process termination deadline and persistent scanner stop gate

**Files:** shared AppKit termination coordinator, `ScannerViewModel`, `WiFiPowerMonitor`, Pro Journal/bootstrap, focused OSS and Pro tests.

**Produces:** one bounded AppKit reply path across runtime plus edition cleanup, a permanent scanner terminating gate, bounded Pro drain/shutdown waiting, immutable termination-cutoff diagnostics, and live unpersisted accounting that converges after late persistence completion.

- [x] Add RED tests using checked-continuation gates that ignore cancellation; prove the previous structured task-group timeout waited for its loser and the AppKit coordinator had no hard deadline.
- [x] Replace structured timeout races with one-shot, non-joining first-result signals. Keep one three-second outer AppKit deadline and separate Pro drain/shutdown outcome diagnostics.
- [x] Add Scanner race tests for post-termination powered-on reconcile/restart/start, a capability lookup already suspended at termination, repeated stop, and CoreWLAN monitoring teardown.
- [x] Model unpersisted append state explicitly: an O(1) permanent aggregate with saturating arithmetic, at most one request-keyed pending in-flight append, late-success convergence, and immutable termination-cutoff snapshots without double counting or retained permanent identities.
- [x] Run final OSS EditionComposition/ScannerRuntimeMigration and Pro EventJournal/Bootstrap suites and diff hygiene checks.
- [x] Run focused suites; expect green. Do not commit.

### Task 5: Command seam, documentation, and complete gates

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/WiFiLensApp.swift`, edition adapters, command tests, `docs/ARCHITECTURE.md`, `Pro/docs/ARCHITECTURE.md`, `docs/TESTING.md`

- [x] Add failing command tests showing Pro Markdown export and OSS locked preview are supplied by edition composition.
- [x] Move `MarkdownExportService` references from shared root into Pro composition; keep common export shell in root.
- [x] Run full OSS/Pro unit targets and both Debug builds.
- [x] Audit `plutil -lint`, PBX membership, full shared-root symbol deletion searches, diff/staging checks, and record exact evidence. Do not commit.

## Completion Criteria

All lifecycle, snapshot, overload, ordering, command, target-boundary, full-unit, and build tests pass; final independent review reports no P0/P1; and all changes remain unstaged/uncommitted unless explicitly authorized.
