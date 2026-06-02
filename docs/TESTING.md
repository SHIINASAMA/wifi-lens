# Testing

## Frameworks

| Target | Framework | Purpose |
|--------|-----------|---------|
| WiFiLensTests | Swift Testing (`@Test`, `#expect()`) | Pure-logic unit tests with `@testable import WiFiLens` |
| WiFiLensUITests | XCTest (`XCTestCase`) | End-to-end UI tests via XCUI accessibility tree |

## Running Tests

```sh
# All tests (unit + UI)
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test
```

## Unit Tests (WiFiLensTests)

Swift Testing target injected into the app process via `TEST_HOST` for `@testable import` symbol resolution. All test `.swift` files must be registered in `project.pbxproj` under the WiFiLensTests target's Sources build phase and listed in the WiFiLensTests scheme's `<Testables>` / `<MacroExpansion>`.

Covered modules: `ChannelSpanCalculator`, `IEParser`, `SSIDColorHasher`, `ChannelQualityCalculator`, `NetworkTableRow`, `BandChartViewModel`, `BandChartLayout`, `SnapshotToChartAdapter`.

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
