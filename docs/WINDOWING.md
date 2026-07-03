# Windowing

This document records the main-window sizing and restoration policy for the shipping macOS app.

## P0 Incident: Main Window Off-Screen and Broken Full Screen

- Severity: `P0`
- Report source: App Store Review for `WiFi Lens` `1.4.2 (149)`
- Review date: June 26, 2026
- Review device: `MacBook Pro (14-inch, Nov 2024)` on `macOS 26.5.1`

### User-visible symptoms

- The main window opened behind the Dock and was visibly cut off.
- Clicking the green title-bar button did not enter full screen correctly and the content disappeared.

### Core buggy code

The original scene-level configuration allowed page content to drive the main `NSWindow` size:

```swift
WindowGroup {
    AppRootView(...)
}
.windowResizability(.contentSize)
.defaultSize(width: 900, height: 700)
```

At the same time, the app restored its previous frame through window autosave:

```swift
window?.setFrameAutosaveName("WiFiLensMainWindow")
```

Several mounted pages also advertised large ideal sizes:

```swift
.frame(minWidth: 700, idealWidth: 1000, minHeight: 600)
.frame(minWidth: 700, idealWidth: 1000, minHeight: 600, idealHeight: 700)
```

### Root cause

The bug was not a single bad height constant. It was the interaction of three behaviors:

1. Scene-level `.windowResizability(.contentSize)` made the main app window content-driven instead of behaving like a standard resizable macOS window.
2. The detail area kept multiple pages alive in a `ZStack` to preserve page-local state. Hidden pages could still contribute ideal-size pressure.
3. Autosaved frames were restored without normalizing them against the current screen's `visibleFrame`.

On a smaller review device with the Dock visible, that combination allowed the restored main window to exceed the visible screen area and produced unstable full-screen transitions.

## Pro Incident: Menu Bar Reopen Left Main Window Inactive

- Severity: `P1`
- Report source: manual Pro build testing
- Report date: July 3, 2026
- Affected build: `WiFi Lens Pro` debug build with the Pro menu bar window enabled

### User-visible symptoms

- After closing the Pro main window, reopening it from the menu bar showed the main window but did not reliably bring it to the foreground.
- In one broken state, the title-bar traffic-light controls only showed their colored state on hover, making the main window look inactive even though it was visible.
- Earlier focus-only attempts could make the traffic-light state look correct but still left the window behind other apps.

### Root cause

The menu bar entry point was opening or focusing the main `WindowGroup` while the transient `MenuBarExtra` window was still the active key window. The main window and the menu bar window competed for key/main status in the same event turn.

Strengthening the main-window focus call by itself was not sufficient. Calls such as `makeKeyAndOrderFront`, `makeMain`, `makeKey`, or delayed focus retries addressed symptoms but did not remove the transient menu bar window that was stealing or retaining activation state.

### Fix

Menu bar initiated main-window opens now use a source-aware path:

1. Menu bar actions call `showMainWindow(route:source:)` with `source == .menuBar`.
2. The app first closes the current non-main `NSApp.keyWindow` when it is a transient menu bar window.
3. The main window open/focus work is deferred to the next main-actor turn.
4. The resolved main window is then explicitly activated and brought forward with app/window-level activation calls.

The key behavior is that the transient menu bar window is dismissed before the main window is reopened or focused. This is the part that prevents the stale key-window state from leaking into the restored main window.

### Implementation notes

- Keep menu bar initiated opens distinct from normal app menu opens. App-level commands should not close arbitrary key windows.
- Do not solve this by only adding more `makeKeyAndOrderFront` calls. Those calls can be necessary after the transient window is dismissed, but they are not the root fix.
- Avoid deprecated `NSRunningApplication.ActivationOptions.activateIgnoringOtherApps`; the project treats warnings as errors.
- If the Pro menu bar implementation changes from `MenuBarExtra` to another AppKit window type, retest the close-main-window and reopen-from-menu-bar flow before removing the source-aware path.

## Shipping Policy

The shipping app now follows these rules:

1. The main window is a standard macOS resizable window.
2. The app may provide a default launch size and minimum size, but page content does not control the real `NSWindow` size.
3. Every restored frame is normalized against the current screen's `visibleFrame` before being shown.
4. If a restored frame is obviously invalid, the app falls back to a centered default size.
5. Page-level `idealWidth` / `idealHeight` values are allowed only as local layout hints.

## Current Implementation

- Scene-level sizing guardrails live in `WiFiLens/Sources/WiFiLens/WiFiLensApp.swift`.
- Frame normalization logic lives in `WiFiLens/Sources/WiFiLens/Utilities/WindowFramePolicy.swift`.
- Regression tests live in `WiFiLens/Tests/WiFiLensTests/WindowFramePolicyTests.swift`.

## Audit Results

Audit date: June 27, 2026

### Shipping app

- `WiFiLensApp.swift`
  - `WindowGroup` is the only shipping scene entry point for the main app window.
  - No remaining `.windowResizability(.contentSize)` usage exists in the shipping app.
  - `NSWindow` autosave remains in use, but all restored frames are now normalized.
- `Spectrum/ContentView.swift`
  - Still contains `idealWidth` / `minWidth` page hints.
  - Safe under the current standard-window policy.
- `Channels/ChannelQualityView.swift`
  - Still contains `idealWidth` / `idealHeight` page hints.
  - Safe under the current standard-window policy.

### Non-shipping/demo code

- `ChartLens` demo targets have their own window/layout code.
- No shipping-risk scene-level content-size windowing was found in the main app during this audit.

## Rules for Future Changes

- Do not add `.windowResizability(.contentSize)` to the shipping app window.
- Do not trust autosaved frames without checking the current screen's `visibleFrame`.
- If a page needs a large layout, keep that requirement local to the page. Do not let it resize the top-level `NSWindow`.
- If another state-preservation `ZStack` is introduced, explicitly constrain its container so hidden pages do not become a sizing policy.
- For Pro menu bar actions that reopen the main window, dismiss transient menu bar windows before attempting to activate the main `NSWindow`.
