# Testing

## Frameworks

| Target | Framework | Purpose |
|--------|-----------|---------|
| WiFiLensTests | Swift Testing (`@Test`, `#expect()`) | Pure-logic unit tests with `@testable import WiFiLens` |
| WiFiLensUITests | XCTest (`XCTestCase`) | End-to-end UI tests for the OSS app |
| WiFiLensProUITests | XCTest (`XCTestCase`) | End-to-end UI tests for the Pro app (Recording, StoreKit) |

## Running Tests

Default verification should use `xcodebuild build` plus unit-test-only runs. Do not run UI test bundles unless the user explicitly asks for UI tests.

```sh
# Build verification — OSS target
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build

# Unit tests only — OSS target
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests

# Build verification — Pro target
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens Pro" -configuration Debug -destination 'platform=macOS' build

# UI tests — run only when explicitly requested by the user
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensUITests
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens Pro" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensProUITests
```

## Unit Tests (WiFiLensTests)

Swift Testing target injected into the app process via `TEST_HOST` for `@testable import` symbol resolution. All test `.swift` files must be registered in `project.pbxproj` under the WiFiLensTests target's Sources build phase and listed in the WiFiLensTests scheme's `<Testables>` / `<MacroExpansion>`.

Covered modules: `ChannelSpanCalculator`, `IEParser`, `SSIDColorHasher`, `ChannelQualityCalculator`, `NetworkTableRow`, `BandChartViewModel`, `BandChartLayout`, `SnapshotToChartAdapter`.

### Edition Composition Registration

Edition-composition tests verify the shared-shell contract while each target compiles exactly one edition adapter. Register shared test files in `WiFiLensTests`; register Pro-only composition tests in `WiFiLensProTests`. Keep `OSSEditionComposition.swift` out of the Pro Sources phase and `ProEditionComposition.swift` out of the OSS Sources phase. This preserves OSS Timeline and recording upsell surfaces without importing Pro domain code.

The OSS suite asserts the adapter contributes the locked Markdown preview. The Pro suite invokes the contributed action against a real `MarkdownExportService` test probe and verifies the same `ScannerViewModel` reaches it. Keep the shared `WiFiLensApp` export menu as a structured switch over this contribution; do not move Pro service names into shared root code or replace the seam with broad `AnyView` command injection.

### Runtime Backpressure and Snapshot Coverage

`RuntimeTests` deterministically blocks raw cycle A, admits B, then replaces B with C. It must observe A then C, `replacementCount == 1`, and no occupied raw slots after stop. Snapshot tests use a counting interface source and assert one capture per admitted cycle plus identical cycle ID/timestamp provenance in current status and runtime output. A suspended fake source proves capture does not occupy the main actor; provider unit tests must use hand-built connected/disconnected snapshots and must never construct `SystemNetworkInterfaceSnapshotSource`, which is reserved for production integration. `ScannerRuntimeMigrationTests` verifies the Interfaces projection comes from that output snapshot, detects a mutation back to a live `NetworkInfoService.fetchAll()` call, and proves the permanent termination gate rejects powered-on reconcile/restart/start work, supersedes an already-suspended runtime start, stops CoreWLAN monitoring, and is idempotent.

### Pro State and Journal Coverage

`WiFiLensProTests/EditionCompositionTests` verifies route changes preserve Spectrum and Timeline presentation state, inactive Timeline work is cancelled, distinct windows remain isolated, menu-bar selection targets the active window, repeated close teardown stops recording/restores the interval once, a second recording clears the first session's projection, and no-delta ticks advance an outer observable duration without materializing the running buffer. Shared edition-composition tests exercise two-window Spectrum/BLE route leases and use a pausable fake BLE scanner to prove a released or replaced start cannot revive work, stop is idempotent, and the paired stream finishes without Bluetooth hardware or permission. Timeline presentation tests enforce the 500-event default retention bound. `EventJournalTests` uses small injected capacities and suspended persistence stores to verify admission completion is independent of SQLite completion, FIFO delivery, no derived-event replacement, saturation diagnostics, permanently counted blocked-append cancellation, Runtime stop without Journal shutdown, cancellable queued read barriers, barrier failure propagation, query fallback without an inconsistent SQLite read, shared shutdown completion, shutdown linearization, and explicit permanent/pending unpersisted transitions without double counting. Its DEBUG retention assertion repeatedly creates permanent failures and proves the scalar total increases while no request identity remains; only the single shutdown-time in-flight request may be retained as pending. The serialized `EventJournalBootstrapTests` additionally uses a checked-continuation store that ignores cancellation to verify that drain and shutdown deadlines do not join the loser, distinguishes drain outcome from shutdown completion, retains an immutable termination-cutoff snapshot, and lets live accounting converge when a late append eventually succeeds. The bootstrap termination tests also enforce one shared two-second Pro budget across drain and shutdown, leaving the outer three-second application deadline authoritative. SQLite store tests replay an existing event ID alongside a new event and prove conflict-ignore persistence keeps the first payload without rolling back the new row. Shared `EditionCompositionTests` uses the same kind of non-cooperative gate to prove the three-second production deadline (shortened by injection in tests) produces exactly one prompt AppKit reply. These are unit suites; do not substitute UI tests for the deterministic lifecycle, termination, and overload gates.

## UI Tests (WiFiLensUITests)

### Launch Arguments

| Argument | Purpose |
|----------|---------|
| `-ApplePersistenceIgnoreState YES` | Suppress macOS window state restoration so WindowGroup always creates a fresh window |
| `-UITest` | Custom flag; app init skips BLEViewModel creation and logs "UI test mode" |

### macOS Window State Restoration

macOS persists window existence across launches via `NSWindowRestoration`. If a prior run ended with all windows closed, the system restores "0 windows" on the next launch, suppressing SwiftUI `WindowGroup`'s default window creation. This produces an accessibility tree with only `MenuBar` and `TouchBar` — no `Window` element.

The UI test `setUp` addresses this with two measures:

1. **Delete saved state** before launch: `~/Library/Saved Application State/io.github.kaoru.wifi-lens.savedState`
2. **Launch argument** `-ApplePersistenceIgnoreState YES` — standard Cocoa mechanism read by `NSApplication` at startup

### Debugging Missing Windows

If `app.windows.firstMatch.waitForExistence(timeout:)` fails, dump the accessibility tree:

```swift
print(app.debugDescription)
```

If the tree shows `Application → MenuBar / TouchBar` without a `Window`, window restoration is the likely cause. Also check:
- System console for SwiftUI errors: `log stream --predicate 'process == "WiFi Lens"' --level debug`
- Window menu items — if Close/Minimize/Zoom are all disabled, no window instance exists

### Accessibility Identifiers

All key UI elements carry `.accessibilityIdentifier()` for stable querying (see `docs/ARCHITECTURE.md` for the full convention). Examples: `sidebar-overview`, `page-settings`, `location-permission-view`, `wifi-off-view`, `settings-theme-picker`.

## Pro UI Tests (WiFiLensProUITests)

Pro tests live under `Pro/Tests/` (root-level submodule) and test the `WiFiLensPro` target (bundle ID: `com.kaoru.wifi-lens-pro`). They require the Pro scheme (`WiFi Lens Pro`) with `TEST_TARGET_NAME = WiFiLensPro`.

### Pro Accessibility Identifiers

SwiftUI `.accessibilityIdentifier()` does not reliably propagate to AppKit views on macOS (known issue). Pro elements inherit the nearest ancestor identifier that does propagate (`page-spectrum`). Tests use element type / count / position rather than custom identifiers.

| Element | Detection method |
|---------|-----------------|
| Mode picker (Live/Recording) | `container.radioButtons.count == 2` — the only RadioGroup on the spectrum page |
| Recording view active | Button count changes vs Live dashboard |

### Xcode Target Setup

A `WiFiLensProUITests` target must be created manually in Xcode:

1. **Add target**: File → New → Target → macOS → UI Testing Bundle, name `WiFiLensProUITests`
2. **Set TEST_TARGET_NAME** = `WiFiLensPro` in the target's build settings
3. **Add test files** from `Pro/Tests/` to the target
4. **Add to scheme**: Open `WiFi Lens Pro` scheme → Test → add `WiFiLensProUITests` to testables
5. **Delete the template** `WiFiLensProUITests.swift` / `WiFiLensProUITestsLaunchTests.swift` that Xcode generates
