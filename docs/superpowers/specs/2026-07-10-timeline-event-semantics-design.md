# Timeline Event Semantics and Detail Layout Design

## Goal

Make the Pro event timeline visually coherent and ensure Wi-Fi connection events distinguish roaming from an explicit network switch.

## Scope

- Pro-only Wi-Fi event classification and timeline presentation.
- Timeline rail compositing, inline detail hierarchy, and duplicated badge removal.
- Regression coverage for connection transitions, event snapshots, and cooldown identity.
- OSS compatibility verification without moving paid behavior into the OSS target.

## Non-Goals

- No new persisted event kind or database schema migration.
- No changes to the menu entitlement boundary.
- No UI-test bundle execution unless explicitly requested.
- No attempt to infer a roam when either SSID is unavailable.

## Architecture

Connection semantics are classified before events are constructed. A dedicated `WiFiConnectionTransitionClassifier` consumes the previous and current `WiFiCurrentStatus` values and returns one of five explicit outcomes: unchanged, connected, disconnected, roamed, or switched networks. `RoamingEventDetector` remains the event orchestration layer for compatibility, but delegates connection meaning to the classifier and separately detects signal and channel changes.

```text
previous/current WiFiCurrentStatus
        |
        v
WiFiConnectionTransitionClassifier
        |
        +-- connected -----------------> one connected event
        +-- disconnected --------------> one disconnection event
        +-- roamed --------------------> one BSSID-change event
        +-- switched networks ---------> disconnection + connected events
        +-- unchanged -----------------> no connection event
        |
        v
independent signal/channel detection when network identity is stable
```

All new classification code stays under `Pro/Events`. The OSS target continues to own only the shared observation model and does not import or compile Pro event semantics.

## Connection Classification Rules

| Previous state | Current state | Identity comparison | Classification |
|---|---|---|---|
| Disconnected | Disconnected | Any | Unchanged |
| Disconnected | Connected | Any | Connected |
| Connected | Disconnected | Any | Disconnected |
| Connected | Connected | Same non-empty SSID and different non-empty BSSID | Roamed |
| Connected | Connected | Different SSIDs | Switched networks |
| Connected | Connected | Either SSID unavailable and identity changed | Switched networks |
| Connected | Connected | Same identity | Unchanged |

SSID comparison is exact because SSIDs are case-sensitive identifiers. Whitespace is not normalized. Empty SSID and BSSID strings are treated as unavailable, while non-empty BSSID comparison is case-insensitive. A missing SSID cannot establish that two APs belong to the same ESS, so a BSSID or other visible identity change falls back to disconnected plus connected events.

## Event Construction

- A roaming event uses the current status snapshot and carries the old and new BSSID.
- A normal disconnection uses the previous status label and previous status snapshot.
- A normal connection uses the current status label and current status snapshot.
- A switched-network classification emits two ordered events at the current observation timestamp: disconnection using the previous status, then connection using the current status.
- Signal-drop and channel-change events are not emitted during a switched-network classification. Those values belong to different networks and are not meaningful continuous changes.
- Signal-drop and channel-change events remain eligible during a confirmed roam because the old and new APs share the same SSID.

## Cooldown Identity

Connection cooldown keys include the event's network label rather than sharing one global `connected` or `disconnection` key. This prevents an earlier transition involving network A from suppressing a later transition involving network B. Existing BSSID and channel transition keys remain value-specific.

## Timeline Presentation

### Rail

The vertical rail is rendered as the list background rather than an overlay. Row markers and their opaque backing circles therefore composite above the rail naturally. Marker colors stay fully opaque.

### Inline Detail

- Remove the leading divider because the rounded detail card already defines the boundary.
- Remove the badge/value row because it duplicates the collapsed row badge and, for metric events, duplicates the target value.
- Keep the divider before the context snapshot because it separates event fields from captured network metadata.
- Preserve the existing compact from/to layout and context rows.

## Testing

Unit tests cover same-SSID roaming, different-SSID switching, missing-SSID fallback, old/new event snapshots, suppression of unrelated metric deltas during a switch, metric deltas during a confirmed roam, and network-specific cooldown behavior. Existing persistence mappings must round-trip both switch events without a schema change.

UI changes are verified through compilation and focused structural inspection; the default verification remains Pro unit tests, OSS unit tests, and a Debug build.
