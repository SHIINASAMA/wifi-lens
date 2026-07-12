# Structured Network Identity for Pro Events

**Date:** 2026-07-12
**Status:** Implemented
**Scope:** Replace connection-event display strings with structured SSID/BSSID payloads, move all label generation to Pro presentation code, and reset the development SQLite event schema instead of retaining legacy decoding.

## Goal

Make structured network identity the only source of truth for Pro connection and disconnection events.

The event domain must carry SSID and BSSID as separate fields. The detector must not create display text, SQLite must not store a combined label in an SSID column, and presentation code must not recover identity from `EventContextSnapshot`.

## Current Problem

`WiFiObservationEvent` stores connection type, generic `details`, and an optional context snapshot. `RoamingEventDetector` writes labels such as `SSID (BSSID)` into `details`. SQLite then writes that entire label into `from_ssid` or `to_ssid`, while the context snapshot stores SSID and BSSID again as separate fields.

One connection therefore has three competing representations:

```text
Event.details              -> "Office (aa:bb:cc:dd:ee:ff)"
SQLite from_ssid/to_ssid   -> "Office (aa:bb:cc:dd:ee:ff)"
EventContextSnapshot       -> ssid: "Office", bssid: "aa:bb:cc:dd:ee:ff"
```

Presentation, persistence, search, and cooldown behavior depend on an undocumented string convention. A label-format change can corrupt storage semantics or change event deduplication.

## Product Decision

The affected build remains under development. Schema v1 history does not need migration or display preservation.

The v2 store will reset the event tables when it encounters an older schema. It will not parse strings shaped like `SSID (BSSID)`, retain a legacy identity case, or reconstruct identity from context snapshots. Users of the development build lose existing Timeline history once when the schema upgrades.

## Constraints

- All connection identity and persistence implementation remains Pro-only.
- OSS continues to expose the immutable observation and runtime consumer seam, without paid event models or persistence code.
- Connection classification semantics do not change: different known SSIDs produce disconnect plus connect; a BSSID change within one known SSID produces roam; missing SSID identity falls back to disconnect plus connect when visible identity changes.
- The four existing typed events remain unchanged: BSSID change, channel change, signal drop, and latency spike.
- `EventContextSnapshot` remains an environment snapshot. It may describe the same observed network, but no connection identity code may use it as a fallback or primary key.
- Timeline and menu must render the same identity label from the same adapter.
- No new third-party dependency is introduced.
- Default verification excludes UI test bundles.

## Considered Approaches

### 1. Versioned structured schema with explicit legacy identity

The domain would support both structured identity and an opaque legacy label. SQLite would mark each row with an identity encoding.

This preserves old labels without guessing, but it makes a development-only encoding mistake part of the permanent event domain.

### 2. Add BSSID columns without an encoding boundary

Old combined labels would continue to occupy SSID columns, while new rows would write separate values.

This produces a schema that cannot distinguish a real SSID from an old display label. It renames the ambiguity instead of removing it.

### 3. Reset schema v1 and admit only structured identity (selected)

The store drops v1 event tables, creates a v2 schema, and starts with empty history. The domain exposes one structured identity type and no compatibility case.

This option removes the string contract, keeps the model honest, and matches the development-stage data-retention decision.

## Domain Model

Add one immutable Pro domain value:

```swift
struct WiFiNetworkIdentity: Codable, Equatable, Hashable, Sendable {
    let ssid: String?
    let bssid: String?
}
```

The value represents the identity observed at the transition boundary. SSID remains case-sensitive. Code that compares or keys BSSID values must compare them case-insensitively while retaining the observed value for display.

Both fields may be nil. That state represents a transition whose network identity was unavailable. Interface name does not become an identity field.

Change the connection cases to carry identity directly:

```swift
enum EventType: Codable, Equatable, Sendable {
    case bssidChange(from: String, to: String)
    case disconnection(identity: WiFiNetworkIdentity)
    case connected(identity: WiFiNetworkIdentity)
    case signalDrop(from: Int, to: Int)
    case latencySpike(from: Double, to: Double)
    case channelChange(from: Int, to: Int)
}
```

Remove `WiFiObservationEvent.details` and its initializer argument. No replacement generic payload field will be added.

## Identity Construction

`RoamingEventDetector` constructs identity from the status that participates in the transition:

- `.connected` uses the current connected status;
- `.disconnection` uses the previous connected status;
- a network switch emits a disconnection with the previous identity followed by a connection with the current identity;
- missing SSID or BSSID remains nil in the payload;
- neither the detector nor the recorder formats a label.

The detector continues attaching the matching status snapshot for environment detail. A disconnected event therefore carries the previous identity and previous environment snapshot. A connected event carries the current identity and current environment snapshot.

The equal values do not create an ownership relationship. The payload owns transition identity. The snapshot owns diagnostic context.

## Typed Cooldown Keys

Replace `WiFiEventRecorder`'s string semantic key with a private `Hashable` key enum. Connection keys carry structured identity. BSSID components use a lowercased comparison form so case-only differences do not bypass cooldown.

The key keeps the existing event-specific behavior:

```text
bssidChange(from, to)
disconnection(identity)
connected(identity)
signalDrop
latencySpike
channelChange(from, to)
```

No cooldown key may depend on a presentation label.

## Presentation Boundary

Add one Pro-internal presentation adapter shared by Timeline and menu. It maps `WiFiNetworkIdentity` to a label using these rules:

| SSID | BSSID | Label |
|------|-------|-------|
| present | present | `SSID (BSSID)` |
| present | absent | `SSID` |
| absent | present | `BSSID` |
| absent | absent | `Wi-Fi` |

The adapter also exposes the non-empty raw SSID and BSSID search terms. It does not read `EventContextSnapshot`.

`TimelineEventPresentation` uses the adapter label for subtitle and from/to values. Its search index adds raw identity terms explicitly instead of relying on the formatted subtitle. Menu presentation uses the same adapter label as its detail.

The existing context-detail card continues to render `EventContextSnapshot`. A snapshot may show environment fields that are absent from identity, but it cannot change the connection label.

## SQLite Schema v2

Keep the typed event-table design and replace the connection transition table definition with structured columns:

```sql
CREATE TABLE wifi_connection_transition_events (
    event_id TEXT PRIMARY KEY NOT NULL,
    from_state TEXT NOT NULL,
    to_state TEXT NOT NULL,
    from_ssid TEXT,
    from_bssid TEXT,
    to_ssid TEXT,
    to_bssid TEXT,
    FOREIGN KEY (event_id) REFERENCES event_index(id) ON DELETE CASCADE,
    CHECK (from_state IN ('connected', 'disconnected')),
    CHECK (to_state IN ('connected', 'disconnected')),
    CHECK (from_state <> to_state),
    CHECK (
        (from_state = 'connected' AND to_ssid IS NULL AND to_bssid IS NULL)
        OR
        (to_state = 'connected' AND from_ssid IS NULL AND from_bssid IS NULL)
    )
);
```

Only the connected side stores identity. Both identity columns on that side may remain null for an unknown identity.

Connection insert logic binds SSID and BSSID from the event payload. Hydration reads those columns into the matching associated value. It never consults context JSON for identity.

The other four typed tables and `event_index.context_snapshot` retain their current formats.

## Destructive Version Upgrade

Stop assigning `PRAGMA user_version = 1` during connection configuration. Initialization will use this order:

1. Open the database and enable WAL and foreign keys.
2. Read `PRAGMA user_version`.
3. If event tables exist with a version below 2, drop every event child table and `event_index` inside one transaction.
4. Create the complete v2 schema.
5. Validate the required v2 columns.
6. Set `PRAGMA user_version = 2` after schema creation succeeds.

A fresh empty database starts at version 0 and creates v2 without a reset. A database with a version greater than 2 causes initialization to fail with an unsupported-schema error; older application code must not destroy a newer store.

If the transactional reset or schema creation fails, initialization propagates the error and does not mark the store initialized. A later call retries initialization. `loadRecent` retains its existing error logging and empty-result behavior.

The canonical/legacy application-support path selection remains unchanged. It addresses file location, not event encoding. Any selected v1 file follows the same v2 reset rule.

## Data Flow

```text
WiFiCurrentStatus
  -> WiFiConnectionTransitionClassifier
  -> RoamingEventDetector
       -> WiFiNetworkIdentity(ssid, bssid)
       -> connected(identity) / disconnection(identity)
  -> WiFiObservationEventJournal
       -> optimistic recent publication
       -> SQLite v2 structured columns

WiFiObservationEvent
  -> shared identity presentation adapter
       -> Timeline label + explicit SSID/BSSID search terms
       -> menu detail label

EventContextSnapshot
  -> Timeline diagnostic detail only
```

## Failure Semantics

The identity change does not alter Journal ordering or failure rules. Recent publication remains optimistic, accepted pre-clear appends remain part of the clear barrier, and persistence errors retain their current precedence.

Schema reset failure is an initialization failure. The store must not continue against a partially upgraded schema. A successful v2 reset returns empty history and accepts subsequent structured events.

Damaged v2 rows continue through the existing skip-and-log recovery path. Hydration skips a row when its state transition is invalid. Null identity fields remain valid and produce an unknown identity.

## Testing Strategy

Implementation follows TDD in these groups.

### Domain and detector

- connection and disconnection events carry exact SSID/BSSID fields;
- network switching preserves the old and new identities in event order;
- SSID-only, BSSID-only, and unknown identities remain structured;
- context snapshots match the correct transition status but do not define identity;
- the four non-connection event payloads and classification thresholds remain unchanged;
- typed cooldown keys retain event-specific cooldown and normalize BSSID case.

### Presentation and search

- all four label combinations follow the table above;
- Timeline and menu produce the same label for the same identity;
- Timeline search matches raw SSID and BSSID;
- an unknown event identity stays `Wi-Fi` even when its context snapshot contains SSID or BSSID;
- connection from/to values use the structured payload.

### SQLite

- a fresh store creates user version 2 and all structured columns;
- connection events round-trip SSID and BSSID independently;
- null identity combinations round-trip;
- a seeded v1 store containing `SSID (BSSID)` resets to empty v2 history without parsing the string;
- a version greater than 2 fails without deleting its tables;
- the four other typed events still round-trip;
- delete-all and Journal clear behavior remain valid after schema creation or reset.

### Deletion and edition boundaries

- production code contains no `WiFiObservationEvent.details`, `connectionLabel`, or combined-label persistence path;
- the v1 fixture may use a `details` column only to prove destructive reset;
- no concrete identity or Pro event implementation enters the OSS Sources phase;
- the Pro test file remains in the Pro test target.

### Completion verification

Run the focused Pro suites during implementation, then run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens Pro" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensProTests
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens Pro" -configuration Debug -destination 'platform=macOS' build
git diff --check
git -C Pro diff --check
```

Do not run UI test bundles unless requested.

## Acceptance Criteria

- Connection event identity exists once, as the associated `WiFiNetworkIdentity` payload.
- Production code has no generic event `details` field.
- Detector, recorder cooldown, SQLite, Timeline, menu, and search consume structured identity.
- SQLite v2 stores SSID and BSSID separately and resets v1 history without parsing it.
- `EventContextSnapshot` remains diagnostic context and cannot influence the connection label.
- The four non-connection typed events retain their behavior and persisted payloads.
- OSS contains no paid identity or event implementation.
- Focused and full unit tests pass, both Debug builds succeed, and independent review reports no open Critical or Important findings.

## Out of Scope

- Preserving v1 Timeline history.
- Parsing combined legacy labels.
- Changing connection, roaming, signal, channel, or latency detection thresholds.
- Replacing SQLite or changing the Journal interface.
- Adding identity to non-connection event payloads.
- Redesigning Timeline or menu layout.
