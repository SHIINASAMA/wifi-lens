# Observation Runtime Migration Design

**Date:** 2026-07-11
**Status:** Approved
**Scope:** Immutable observation publication followed by production migration to a single observation runtime

## Goal

Make one shared observation runtime the authoritative production path for Wi-Fi observations, while first removing the correctness risk caused by the Pro event pipeline reconstructing observations from mutable store state.

The migration is intentionally split into two independently reversible milestones:

1. **Immutable Observation Publication** fixes event input identity and ordering without changing the existing scan and analysis algorithms.
2. **Production Observation Runtime Migration** moves production orchestration out of `ScannerViewModel` and into the runtime, eliminating the duplicate pipeline path.

The design preserves the OSS/Pro product boundary. Shared code publishes observations without knowing any paid event type. The Pro target supplies the only event consumer implementation.

## Problem Statement

The repository currently has two observation implementations:

- `WiFiObservationPipeline` and `WiFiObservationController` model the intended provider-to-analyzer-to-store flow and have focused unit tests.
- `ScannerViewModel.startScanLoop()` remains the production path and independently performs current-connection discovery, latency measurement, environment adaptation, channel analysis, regulatory inference, recommendation, quality evaluation, diagnosis, and `store.apply`.

These paths have already diverged. The standalone pipeline uses fixed supported bands, no target AP, and no user region override in places where the production scanner uses live device capabilities, a target AP, and user/default region settings. Tests for the standalone pipeline therefore do not prove that production follows the same semantics.

The Pro event coordinator adds a separate correctness problem. It observes `WiFiObservationStore.$lastUpdated`, receives only a timestamp, creates an asynchronous task, and later reads mutable `currentStatus` and `gatewayLatency` fields from the store. If observations are applied faster than those tasks execute, multiple tasks can read the final store state. Intermediate roaming or network-switch transitions are then unrecoverable. Store fields can also represent values from different partial observations.

The event recorder's apparent input is an immutable `WiFiObservation`, but its effective production input is a mutable-store notification. The current interface is therefore not the real test surface.

## Design Principles

1. A `WiFiObservation` is an immutable value representing one refresh cycle.
2. The exact value accepted by the runtime is the value observed by downstream consumers.
3. Acceptance order is authoritative; consumers must not infer order from task scheduling, store timestamps, or database row IDs.
4. The runtime is a narrow Wi-Fi observation module, not a general-purpose event bus.
5. There is exactly one production observation producer.
6. UI projection, paid event semantics, persistence, and presentation remain downstream concerns.
7. A currently unused implementation is not automatically dead. Providers, analyzers, filters, normalized models, and planned migration components are retained when they have an independent responsibility.
8. A duplicate orchestration layer is removed only after the runtime has replaced its production behavior and deletion-test evidence shows no lost capability.

## Target Architecture

```text
System APIs
    |
    v
Providers / scan source
    |
    v
Observation Runtime
    |-- provider orchestration
    |-- analyzers
    |-- immutable WiFiObservation construction
    |-- ordered publication
    |
    +--> WiFiObservationStore projection --> existing UI consumers
    |
    +--> ordered observation consumers
            |
            +--> Pro observation-to-event adapter
                    |
                    +--> classifier / recorder
                    +--> Event Journal
                    +--> Timeline and Menu Bar
```

The shared runtime owns production observation creation and ordered publication. `WiFiObservationStore` becomes a UI projection of accepted observations rather than the event pipeline's input bus.

`ScannerViewModel` ultimately owns only scanner-related interaction and presentation state:

- authorization and lifecycle commands exposed to views;
- filter queries and visibility selections;
- chart, table, history, and other presentation projections;
- forwarding runtime lifecycle operations.

It no longer owns a second implementation of current-status, latency, quality, diagnosis, regulatory recommendation, or store publication orchestration.

## Component Boundaries

### Observation Runtime

The runtime is the only production producer of accepted observations after Milestone 2. During Milestone 1 it acts as the publication boundary while the existing scanner remains the temporary producer.

Responsibilities:

- accept or construct one immutable observation per production refresh cycle;
- preserve observation and nested model timestamps;
- publish observations in acceptance order;
- update the shared store projection;
- enqueue eligible observations for fixed, composition-time consumers;
- isolate consumer failures from store publication and other consumers;
- expose lifecycle and diagnostics needed by the app shell.

Non-responsibilities:

- generic application event delivery;
- Pro event classification or persistence;
- UI filtering, localization, or presentation mapping;
- recording-session persistence;
- MCP transport behavior.

### Store Projection

`WiFiObservationStore` remains shared and continues to expose the fields used by existing UI consumers. Applying an observation may remain a synchronous main-actor operation.

`lastUpdated` may continue to trigger UI refresh behavior, but it is no longer an event identity, ordering token, or reconstruction signal. No event consumer may read store fields in response to `lastUpdated` to recreate an observation.

Partial observations may continue to update only the fields they contain. This projection behavior must not be used to synthesize a complete event input.

### Ordered Observation Consumers

Consumers are registered through application composition rather than discovered through a global registry. The shared consumer boundary deals only in `WiFiObservation`; it has no reference to `WiFiObservationEvent`, Timeline, SQLite, or other paid types.

Each consumer has an independent serial queue:

- values are processed in acceptance order;
- values are not coalesced or overwritten;
- consumer work does not block the store projection;
- a consumer failure does not stop later observations or other consumers;
- accepted observations are drained when scanning stops normally.

The initial production configurations are:

| Edition | Store projection | Additional consumer |
|---|---|---|
| OSS | Yes | None |
| Pro | Yes | Pro observation-to-event adapter |

This is a real composition seam: OSS and Pro are distinct shipping configurations. The OSS build does not need a fake Pro consumer.

### Pro Observation-to-Event Adapter

The adapter remains entirely in the Pro target. It replaces the coordinator's `$lastUpdated` subscription and receives exact observations from the runtime.

Eligibility and event rules:

- only observations containing `currentStatus` enter connection, roaming, signal, or channel event processing;
- latency events are evaluated only when the same observation also contains `gatewayLatency`;
- the adapter never borrows a previous latency value from the store to complete a partial observation;
- the recorder may retain its own explicit previous-observation state because transition detection inherently compares ordered observations;
- existing connection-classification, cooldown, clear-generation, recent-event, and persistence semantics remain unchanged in Milestone 1.

The Pro adapter feeds the existing event consistency boundary. Event Journal consolidation is a separate architecture initiative and is not required to complete this design.

## Ordering and Backpressure Semantics

Runtime acceptance order is the canonical in-process observation order. An internal monotonically increasing sequence may be used for diagnostics and queue coordination, but it is not persisted and is not part of the domain model.

The runtime follows these rules:

1. An accepted observation is applied to the store without waiting for slow consumers.
2. The same immutable value is appended to each eligible consumer's serial queue.
3. A consumer processes every accepted value in order.
4. There is no latest-value replacement, bounded drop-oldest policy, or silent coalescing.
5. A normal scan shutdown drains values already accepted by the runtime. A scan result that was never accepted may be discarded when its producing task is cancelled.
6. If a queue accumulates unexpectedly, diagnostics record its depth and the age of its oldest value. The runtime does not silently trade event correctness for memory.

The minimum normal scan interval is approximately one second, and Pro event processing is small relative to that interval. Lossless serial delivery is therefore the appropriate default. A future capacity policy requires a separate design based on measured pressure rather than speculative dropping.

## Milestone 1: Immutable Observation Publication

### Objective

Remove mutable-store reconstruction from the Pro event path while preserving the current production scan and analysis algorithms.

### Data Flow

```text
ScannerViewModel temporary producer
    |
    | constructs WiFiObservation using current production logic
    v
Observation Runtime publication boundary
    |--> Store projection
    +--> Pro ordered consumer --> existing event recorder/controller
```

### Changes

- Introduce the shared runtime publication boundary and ordered consumer mechanism.
- Compose the runtime with the shared store in both editions.
- Compose the Pro observation-to-event adapter only in the Pro target.
- Replace `ScannerViewModel`'s direct `store.apply(observation)` call with runtime acceptance.
- Remove the Pro coordinator's `$lastUpdated` subscription and mutable store reads.
- Preserve the existing recorder, classifier, Timeline controller, recent store, SQLite store, and clear-generation behavior.
- Preserve all current UI store fields and notifications required by unrelated consumers.

### Milestone 1 Acceptance Criteria

- Two observations accepted back-to-back reach the Pro adapter as two distinct values in the same order.
- A network A-to-B switch cannot collapse into two reads of network B.
- A same-SSID BSSID transition preserves both old and new statuses.
- The Store and Pro adapter receive the same observation value.
- A delayed or failing Pro consumer does not delay Store updates.
- An observation without `currentStatus` cannot create a Pro Wi-Fi event.
- A current-status observation without same-cycle latency cannot reuse an older Store latency for a latency event.
- The OSS build accepts and projects observations without compiling any Pro event implementation.
- Existing Timeline clear, hydration, cooldown, and persistence tests remain green.

### Rollback Boundary

Milestone 1 is independently revertible before Milestone 2. Reverting it restores the old publication path but must not be used as a fallback after the mutable-store race has been accepted as a correctness defect. Milestone 2 can be rolled back without restoring the old Pro Store-reconstruction path.

## Milestone 2: Production Observation Runtime Migration

### Objective

Make the existing normalized observation architecture the real production path and remove duplicate production orchestration from `ScannerViewModel`.

### Production Responsibilities to Migrate

The runtime must take ownership of the behavior currently embedded in the scan loop:

- environment scanning and normalized network adaptation;
- current connection acquisition;
- gateway latency measurement;
- device capabilities and supported bands;
- current target AP selection;
- channel occupancy analysis;
- user and defaults-based regulatory override resolution;
- channel recommendation;
- Wi-Fi quality evaluation;
- diagnosis construction;
- final immutable observation construction and publication.

Migration must use the existing providers, analyzers, normalized models, and filter-related implementations where they match production requirements. It must correct the standalone pipeline's current semantic gaps instead of replacing production behavior with fixed values such as all supported bands, a nil target AP, or a nil user override.

### ScannerViewModel After Migration

`ScannerViewModel` remains a presentation-facing model. It consumes accepted observations or derived normalized data to maintain:

- `SignalHistoryStore` and network snapshots;
- AP filter query state;
- per-panel visibility and lock state;
- band chart view models;
- table rows and display-state projections;
- selected network and other view interaction state;
- MCP's existing data-provider surface until a later MCP migration;
- Recording's existing inputs until a later Recording migration.

These capabilities are not deletion candidates merely because they are downstream of the runtime.

### Explicitly Deferred Consumers

Recording and MCP public structures are not redesigned in this initiative.

- Recording may continue to use existing scanner history and scan-interval controls.
- MCP may continue to expose its current transport and data-provider interface.
- The runtime migration must ensure their data ultimately originates from the single production observation path where applicable.
- Direct migration of Recording and MCP to observation streams requires separate designs.

### Deletion Policy

A type or code path may be deleted only when all of the following are true:

1. The runtime production path has replaced its behavior.
2. It has no independent domain or presentation responsibility.
3. Removing it concentrates complexity in the deeper runtime rather than moving code sideways.
4. Repository references and active design documents show no remaining planned use.
5. Focused tests, both app builds, and target-membership inspection confirm the removal.

Expected deletion or absorption candidates include:

- duplicated current-status, latency, analysis, recommendation, diagnosis, and store-publication orchestration inside the scanner loop;
- the shallow pipeline-to-store controller after the runtime owns that behavior;
- temporary Milestone 1 bridge wiring that has no final responsibility.

Protected categories include:

- AP filter parser and filter services;
- providers and analyzers with independent behavior;
- normalized observation models;
- chart, table, history, and visibility projections;
- the persistence seam with real SQLite and test adapters;
- compatibility adapters that still serve a shipping or tested boundary.

### Milestone 2 Acceptance Criteria

- Production scanning constructs and publishes observations through the runtime rather than a duplicate Scanner implementation.
- There is one production implementation for observation analysis and Store publication.
- User region overrides, target AP selection, device-supported bands, and capabilities preserve current production semantics.
- Scan interval changes, Wi-Fi power changes, authorization changes, scene activation, and cancellation preserve current lifecycle behavior.
- Filters, charts, tables, signal history, and AP visibility behavior remain unchanged.
- Pro events continue to receive exact, ordered observations through the Milestone 1 seam.
- Recording and MCP continue to work through their existing public structures.
- The old shallow controller and replaced scanner orchestration have no production references.
- OSS unit tests, Pro unit tests, the OSS Debug build, and the Pro Debug build pass.

## Error Handling

### Provider and Analyzer Errors

Provider failures are represented in the observation's existing error model whenever a meaningful partial observation can still be published.

- Environment-scan failure must not erase a valid current connection.
- Latency failure affects latency and dependent quality evaluation but must not manufacture a disconnection.
- Current-status failure must not be filled from stale Store fields for event processing.
- Analyzer failure must not corrupt the last valid projection with fabricated default values.

### Consumer Errors

Consumer errors are isolated from the Store and other consumers.

- Pro classification or recording failures are logged and processing continues with the next observation.
- Event persistence failure retains the existing behavior: the recent event may remain visible for the current process, but restart recovery is not guaranteed.
- The runtime does not automatically replay an observation to a business consumer after an ambiguous failure because replay could duplicate an event.

### Queue Diagnostics

Unexpected consumer backlog should expose diagnostics sufficient to identify pressure:

- current queue depth;
- oldest queued observation age;
- consumer identity suitable for internal logs;
- processing-failure counts.

These diagnostics are implementation details and do not require a user-facing UI in this initiative.

## OSS and Pro Boundary

The existing commercial boundary remains mandatory:

- Shared and OSS targets may contain observation models, providers, analyzers, the runtime, Store projection, and a generic observation-consumer seam.
- Pro event classification, event models, Event Journal behavior, SQLite event persistence, Timeline data flow, and Menu Bar event presentation remain under `Pro/` and in the Pro target only.
- The shared app shell may compose an edition-level observation consumer, but it must not import Pro event implementation details into OSS sources.
- OSS Timeline navigation, lock indicators, and preview skeletons remain allowed product-surface metadata.
- Target membership is part of acceptance testing, not a post-implementation cleanup step.

## Test Strategy

### Milestone 1 Focused Tests

1. Ordered delivery of two immediately accepted observations.
2. No coalescing when a consumer is deliberately suspended.
3. Store publication proceeds while the Pro consumer is suspended.
4. Consumer failure isolation and continuation.
5. Exact observation identity across Store projection and consumer capture.
6. Different-SSID switch preservation under immediate consecutive accepts.
7. Same-SSID BSSID roam preservation under immediate consecutive accepts.
8. No event delivery for an observation without `currentStatus`.
9. No stale latency reuse when same-cycle latency is absent.
10. Normal shutdown drains already accepted observations.
11. OSS composition works with no Pro consumer.
12. Existing Pro clear-generation and persistence tests continue to pass.

### Milestone 2 Focused Tests

1. Runtime provider orchestration produces a complete observation with controlled fixtures.
2. Production target AP selection matches current scanner behavior.
3. Supported bands and device capabilities are passed to analysis and recommendation.
4. User and defaults regulatory overrides preserve priority and semantics.
5. Current status, latency, quality, diagnosis, channel analysis, and recommendations are published in one observation cycle where available.
6. Provider partial failures preserve valid fields and report errors.
7. Scan interval restart behavior remains correct, including Pro recording's one-second override.
8. Wi-Fi power-off and authorization loss stop scanning without accepting fabricated observations.
9. Signal history, filters, chart projections, and table projections receive the migrated data.
10. Scanner inline production orchestration and the shallow controller have no remaining production references.

### Verification Commands

Run focused unit tests and builds without UI test bundles:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build
```

The implementation plan must also identify and run the corresponding Pro unit-test and Pro build commands used by the current project configuration. UI tests remain out of scope unless explicitly requested.

## Documentation Updates During Implementation

Implementation completion must update:

- `docs/ARCHITECTURE.md` with the final runtime data flow and ownership boundaries;
- `Pro/docs/ARCHITECTURE.md` with the Pro observation-to-event adapter and actual Events, Timeline, and Menu Bar modules;
- the older unified observation migration documents where their status or final ownership claims are obsolete.

Documentation updates must describe the final implementation rather than preserving transitional Milestone 1 wiring as the target architecture.

## Non-Goals

- Consolidating the Pro Event Journal internals.
- Changing connection-classification semantics.
- Introducing a new event database schema.
- Migrating Recording directly to an observation stream.
- Migrating MCP directly to an observation stream.
- Redesigning filters, charts, tables, or the Timeline UI.
- Creating a general application event bus.
- Running UI test bundles by default.

## Final Acceptance Criteria

- Pro events consume exact immutable observations rather than reconstructing values from `WiFiObservationStore`.
- Observation delivery to each consumer is ordered, lossless within the accepted in-process stream, and failure-isolated.
- The shared runtime is the only production observation producer after Milestone 2.
- `ScannerViewModel` no longer contains duplicate observation-production orchestration.
- The tested provider and analyzer path is the production path.
- Filters and other independently useful downstream implementations remain intact.
- Recording and MCP remain behaviorally compatible without being redesigned.
- No Pro event implementation is compiled into the OSS target.
- Both milestones have independent verification and rollback boundaries.
- Focused OSS and Pro unit tests and both Debug builds pass without running UI test bundles.
