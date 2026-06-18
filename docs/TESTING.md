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

Pro tests live under `WiFiLens/Sources/WiFiLens/Pro/Tests/` and test the `WiFiLensPro` target (bundle ID: `com.kaoru.wifi-lens-pro`). They require the Pro scheme (`WiFi Lens Pro`) with `TEST_TARGET_NAME = WiFiLensPro`.

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
3. **Add test files** from `WiFiLens/Sources/WiFiLens/Pro/Tests/` to the target
4. **Add to scheme**: Open `WiFi Lens Pro` scheme → Test → add `WiFiLensProUITests` to testables
5. **Delete the template** `WiFiLensProUITests.swift` / `WiFiLensProUITestsLaunchTests.swift` that Xcode generates
