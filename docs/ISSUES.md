# ISSUES

## High Priority

- [x] `WiFiLens/Sources/WiFiLens/WiFiLensApp.swift`, `WiFiLens/Sources/WiFiLens/Spectrum/ContentView.swift`, `WiFiLens/Sources/WiFiLens/Channels/ChannelQualityView.swift` — P0 main-window regression: scene-level `.windowResizability(.contentSize)` plus autosaved window restoration and mounted hidden pages allowed the main window to reopen larger than the current screen `visibleFrame`, causing the window to sit behind the Dock and making full-screen transitions unstable. Fix: revert to standard macOS window sizing, normalize restored frames in `WindowFramePolicy`, add regression tests, and document the guardrails in `.agents/references/project/WINDOWING.md`.
- [x] `WiFiLens/Sources/WiFiLens/BLE/BLEScanner.swift:50-57,86-99` — `BLEScannerDelegate` closures (`onDiscover`, `onReady`) strongly capture `del`, creating retain cycles. `stopScanning()` never sets `delegate = nil` or clears closure properties. On each 30s `restartScan()`, a new delegate is assigned but the old one remains leaked with its closures and the `AsyncStream.Continuation`'s `onTermination` handler. Fix: use `[weak del]` in closures, clear closures in `onTermination` before `del.stop()`, and set `delegate = nil` in `stopScanning()`.
- [x] `WiFiLens/Sources/WiFiLens/Regulatory/RegionInferenceEngine.swift:172` — JP channel 14 bonus weighting is a no-op. The `if domain == .JP && hardwareChannels.contains("1-14")` body is empty (`/* weighted */`), meaning Japanese devices with channel 14 get no extra matching confidence. JP can tie EU when channel 14 is present, and only wins because it happens to be iterated before EU in the `[.US, .JP, .CN, .EU]` array — the decision depends on array literal ordering rather than signal strength.

## Medium Priority

- [ ] `SignalHistoryStore.swift` — Signal history limited to 20 points in memory. Deferred: blocked on Product Direction "session model" (persistence layer needed).

## Notes

- This issue list focuses on behaviour-vs-expectations gaps, state-refresh defects, and structural patterns that make completeness hard to assess.
- `SecondaryToolbarCapsule.swift` — `NSSegmentedControl.role = .valueSelection` (macOS 27 API) is commented out until CI Xcode ships the macOS 27+ SDK. Re-enable when `Xcode_27.app` or later is available on the runner.
