# BLE Scanner

Bluetooth Low Energy device scanner with RSSI analysis, trend charts, and device tracking. Built on CoreBluetooth, running independently from the Wi-Fi scan path.

## Architecture

```
CoreBluetooth → BLEAdvertisementEvent → BLEDeviceTracker → BLEDeviceSnapshot
                              (raw batch)      │                    │
                                                │                    ▼
                                          per-device EMA       BLEViewModel
                                          ring buffers             │
                                             30 samples        isScanning
                                             staleTimeout=30s   bluetoothState
                                             max 100 devices     devices[]
                                                                  selectedDeviceID
                                                                      │
                                                          ┌───────────┴───────────┐
                                                          ▼                       ▼
                                                    BLEScannerView         BLETrendChartView
                                                  (device table +         (raw + smoothed
                                                   trend chart)           RSSI over time)
```

## Data Flow

1. `BLEScanner` (Swift actor) — wraps `CBCentralManager` via `BLEScannerDelegate`. Batches `didDiscover` events into 2 s windows via `AsyncStream<BLEScanEvent>`. Restarts scan every 30 s to prevent macOS callback decay. Exposes `bluetoothState` as `.poweredOn`/`.poweredOff`/`.unauthorized`/etc.

2. `BLEDeviceTracker` (`@MainActor`) — processes batch events, maintains per-device ring buffers (30 samples max, 30 s stale timeout, 100 device cap). Applies `ExponentialMovingAverage` (alpha 0.25) for RSSI smoothing. Evicts weakest+oldest devices on overflow. Returns `[BLEDeviceSnapshot]` for ALL known devices every batch (not just those in the current batch), so devices persist until they go stale.

3. `BLEViewModel` (`@MainActor`, `@Observable`) — owns `BLEScanner` + `BLEDeviceTracker` + `BluetoothPermissionManager`. Handles scan lifecycle, bluetooth state transitions (power off → pause/resume, unauthorized → stop), and device selection for chart detail.

4. `BLEScannerView` — SwiftUI view with control bar (start/stop, state indicator, device count), `Table` of discovered devices (name, identifier, raw RSSI, smoothed RSSI, ad count, last seen), and selected-device trend chart section.

5. `BLETrendChartView` — wraps universal `Chart<EmptyView>` with two linear series per device: raw RSSI (thin, 30% opacity) and EMA-smoothed RSSI (thick, solid). Uses index-based x-axis for dense sample display.

## Key Files

| File | Type | Purpose |
|------|------|---------|
| `BLEScanner.swift` | `actor` | CoreBluetooth scan loop, `AsyncStream` batch emission, 30 s restart |
| `BLEDeviceTracker.swift` | `final class` | Per-device ring buffers, EMA smoothing, stale/overflow eviction |
| `BLEViewModel.swift` | `final class` | Scan lifecycle, state machine, selection, error handling |
| `BLEScannerView.swift` | `struct` | Device table, trend chart section, error/empty states |
| `BLETrendChartView.swift` | `struct` | Raw + smoothed RSSI chart via `Chart` engine |
| `BLEAdvertisementEvent.swift` | `struct` | Raw `didDiscover` event: timestamp, UUID, RSSI, txPower, manufacturer data, service UUIDs |
| `BLEChannel.swift` | `enum` | BLE advertising channels (37/38/39) with frequency mapping |
| `BLEDeviceSnapshot.swift` | `struct` | Processed device state for UI: RSSI, smoothed RSSI, first/last seen, ad count, history |
| `BLERSSISample.swift` | `struct` | Single timestamped RSSI reading with raw + smoothed values |
| `BluetoothPermissionManager.swift` | `final class` | `CBManagerAuthorization` status, system dialog trigger, preferences shortcut |

## Key Patterns

- **Actor-based scanner**: `BLEScanner` is a Swift `actor`, ensuring thread-safe access to `shouldStop` and `delegate`. The `BLEScannerDelegate` bridge object is `@unchecked Sendable`, using an `NSLock`-protected accumulator.
- **Batch processing**: Accumulates `didDiscover` events for 2 s before yielding `AsyncStream` values, then drains via `drainAccumulator()`.
- **30 s scan restart**: macOS CoreBluetooth callback delivery degrades over time; `BLEScanner` restarts `scanForPeripherals` every 30 s via `restartScan()`.
- **Dual bluetooth monitoring**: `BLEViewModel` monitors bluetooth state from two sources — the scanner's `AsyncStream` (when scanning) and a dedicated `BLEPowerMonitor` (always active). Both converge via `handleBluetoothStateChange(_:fromScanner:)`.
- **Stateful resume**: When bluetooth powers off during a scan, the ViewModel pauses scanning (`preserveResumeIntent: true`) and auto-resumes when power is restored.
- **Eviction policy**: `BLEDeviceTracker` evicts devices by (RSSI ascending, lastSeen ascending) when count > 100 — weakest and least recently seen devices are removed first.
- **RSSI colors**: green ≥ -60 dBm, yellow ≥ -80 dBm, red below.

## Views

`BLEScannerView` handles multiple states:
- **Disabled** — BLE feature disabled in settings (empty state icon)
- **Bluetooth Off** — powered off / unsupported
- **Unauthorized** — permission denied with instructions
- **Permission Required** — `.notDetermined` with prompt to trigger system dialog
- **Scanning (empty)** — `ProgressView` while initial batch arrives
- **Idle** — play button prompt
- **Active** — device table + selected-device trend chart

## Testing

- `BLEScanner` and `BLEDeviceTracker` are testable via mock event injection (pure logic).
- `BLEViewModel` state transitions (power off → pause → resume) can be tested by toggling `bluetoothState` directly.
