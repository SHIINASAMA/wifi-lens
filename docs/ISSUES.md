# ISSUES

## High Priority

- [x] `WiFiLens/Sources/WiFiLens/BLE/BLEScanner.swift:50-57,86-99` — `BLEScannerDelegate` closures (`onDiscover`, `onReady`) strongly capture `del`, creating retain cycles. `stopScanning()` never sets `delegate = nil` or clears closure properties. On each 30s `restartScan()`, a new delegate is assigned but the old one remains leaked with its closures and the `AsyncStream.Continuation`'s `onTermination` handler. Fix: use `[weak del]` in closures, clear closures in `onTermination` before `del.stop()`, and set `delegate = nil` in `stopScanning()`.
- [x] `WiFiLens/Sources/WiFiLens/Regulatory/RegionInferenceEngine.swift:172` — JP channel 14 bonus weighting is a no-op. The `if domain == .JP && hardwareChannels.contains("1-14")` body is empty (`/* weighted */`), meaning Japanese devices with channel 14 get no extra matching confidence. JP can tie EU when channel 14 is present, and only wins because it happens to be iterated before EU in the `[.US, .JP, .CN, .EU]` array — the decision depends on array literal ordering rather than signal strength.

## Medium Priority

- [ ] `SignalHistoryStore.swift` — Signal history limited to 20 points in memory. Deferred: blocked on Product Direction "session model" (persistence layer needed).

## Notes

- This issue list focuses on behaviour-vs-expectations gaps, state-refresh defects, and structural patterns that make completeness hard to assess.
