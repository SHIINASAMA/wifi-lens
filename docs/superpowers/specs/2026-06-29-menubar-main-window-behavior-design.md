# MenuBar Main Window Behavior Design

## Goal

Adjust the existing Pro menu bar behavior so it can:

- open or re-activate the main window without changing the current page
- open or re-activate the main window and navigate to Settings when requested
- fully terminate the app from the menu bar
- hide the Dock presence after the main window closes when MenuBar mode is enabled
- restore normal Dock and app activation behavior when the user reopens the main window from the menu bar

The implementation must stay narrowly scoped to MenuBar, main-window activation, and the existing app-level navigation state.

## Non-Goals

- Do not refactor unrelated app structure or navigation architecture.
- Do not change Pro gating logic or the Menu Bar feature toggle behavior itself.
- Do not redesign MenuBar visual styling beyond the required new actions and divider.
- Do not introduce a new routing model separate from the existing `SidebarPage` state.
- Do not perform broader localization cleanup. Any new copy uses temporary keys or the existing localization placeholder pattern.

## Existing Context

The current app already has the pieces needed for this behavior, but they are not coordinated:

- `WiFiLensApp` owns the current app-level route via `selectedPage: SidebarPage`
- `WindowGroup` owns the main app window
- `WindowAccessor` already gets access to the backing `NSWindow`
- the Pro MenuBar feature is controlled by `@AppStorage("menuBarEnabled")`
- the app-level Settings command currently changes `selectedPage = .settings`
- the current menu bar popover has a gear button, but no dedicated open-main-window or quit actions

The missing piece is a single main-window coordination path that handles activation policy, window creation, focus, and optional page navigation together.

## Design Summary

Add a single app-level coordinator method:

```swift
showMainWindow(route: SidebarPage? = nil)
```

Behavior:

- `route == nil`
  - open or re-activate the main window
  - keep the current page unchanged
- `route == .settings`
  - open or re-activate the main window
  - navigate to Settings through the existing `selectedPage` state

The coordinator becomes the only path used by:

- MenuBar "Open Main Window"
- MenuBar "Settings"
- app-level Settings menu command

## Main Window Identification

The main window is identified through the existing `WindowAccessor` path.

`WindowAccessor` already configures the main `NSWindow` and sets:

```swift
window.setFrameAutosaveName("WiFiLensMainWindow")
```

That window will be treated as the single main window for MenuBar reopen/focus behavior.

The implementation should capture and retain a weak reference to that window in app-owned state, instead of scanning or managing unrelated windows.

## Unified Main Window Coordinator

### API

```swift
@MainActor
func showMainWindow(route: SidebarPage? = nil)
```

### Responsibilities

1. If MenuBar mode is enabled and the app is currently in accessory mode, switch back to `.regular`
2. If a main window already exists:
   - optionally update `selectedPage` when `route != nil`
   - call `NSApp.activate(ignoringOtherApps: true)`
   - call `window.makeKeyAndOrderFront(nil)`
3. If the main window does not exist:
   - optionally set `selectedPage` before window creation when `route != nil`
   - request creation/showing of the main window through the existing `WindowGroup` path
   - after the window becomes available, activate the app and bring that window to front
4. If `route == nil`, do not modify `selectedPage`

### Rationale

- focus and route change must be coordinated from one place
- Settings navigation must not depend on whether the window has already fully rendered
- existing `selectedPage` is already the global route state, so no new route channel is needed
- `NSWindow` access is preferred over relying only on `openWindow(id:)` because the requested behavior requires deterministic frontmost activation

## Window Reopen Strategy

The implementation should reuse existing window infrastructure and keep the reopen path minimal.

Preferred behavior:

- if the captured main window exists, reuse it directly
- if it does not exist, request a new main window from the app scene
- once the new window is attached through `WindowAccessor`, bring it to front

`openWindow` may still be used as the creation mechanism when no window exists, but it must not be treated as sufficient by itself for focus and route behavior. A follow-up frontmost activation step is still required.

## Dock and Activation Policy Behavior

### On Main Window Close

When the main window closes:

- if `menuBarEnabled == true`
  - switch the app activation policy to `.accessory`
  - this removes the normal Dock-presence behavior and leaves the app resident as a menu bar app
- if `menuBarEnabled == false`
  - do nothing
  - keep the existing standard macOS app behavior unchanged

This rule applies only to the main window close path. It must not change behavior for users who have not enabled the MenuBar feature.

### On Reopen From MenuBar

When the user reopens the main window from the menu bar, `showMainWindow(route:)` must:

- switch activation policy back to `.regular` before reopening or foregrounding the window
- activate the app
- bring the main window forward

This applies to both:

- open-main-window action
- settings action

## MenuBar Actions

The menu bar popover should expose three actions relevant to this change:

1. Open Main Window
   - calls `showMainWindow(route: nil)`
   - does not navigate away from the current page
2. Settings
   - calls `showMainWindow(route: .settings)`
   - always ensures the main window is visible and frontmost
3. Quit
   - separated from the functional area by `Divider()`
   - calls `NSApp.terminate(nil)` or an existing equivalent if one already exists

The existing gear button should also route through the same Settings coordinator path instead of owning separate logic.

## Navigation Behavior

Navigation continues to use the existing app-level route:

```swift
@State private var selectedPage: SidebarPage
```

Rules:

- `showMainWindow(route: nil)` preserves the current `selectedPage`
- `showMainWindow(route: .settings)` updates `selectedPage = .settings`
- no new navigation state type is introduced
- no page-specific rendering dependency is added to the MenuBar layer

This keeps route changes independent from whether the window already exists or whether SwiftUI has completed a fresh render pass.

## Window Lifecycle Hooking

The implementation needs a reliable signal for "main window closed".

Acceptable approaches:

- attach close observation directly to the captured main `NSWindow`
- or observe the main-window close notification at the app layer, provided it is filtered to the known main window

Requirements:

- only the main window should trigger activation-policy changes
- the hook must be cleaned up or replaced safely if a new main window instance is created later
- no unrelated windows should affect Dock/accessory transitions

## File Scope

Expected direct touch points:

- `WiFiLens/Sources/WiFiLens/WiFiLensApp.swift`
  - add unified `showMainWindow(route:)`
  - retain/capture the main `NSWindow`
  - integrate reopen, Settings command, and close handling
- `Pro/MenuBar/MenuBarScene.swift`
  - wire menu actions to the unified coordinator
- `Pro/MenuBar/MenuBarStatusView.swift`
  - add or update the required action buttons if they live here today

The exact split depends on where the current action UI is implemented, but no broader module refactor is in scope.

## Validation

### Manual Scenarios

1. Main window exists, click MenuBar "Open Main Window"
   - app activates
   - main window moves to front
   - current page remains unchanged

2. Main window exists, click MenuBar "Settings"
   - app activates
   - main window moves to front
   - page becomes Settings

3. MenuBar enabled, close main window
   - app remains resident through MenuBar
   - Dock presence is removed via accessory mode

4. Main window closed while MenuBar remains active, click "Open Main Window"
   - activation policy returns to regular
   - app activates
   - main window opens
   - default/current route behavior is preserved

5. Main window closed while MenuBar remains active, click "Settings"
   - activation policy returns to regular
   - app activates
   - main window opens
   - Settings page is shown

6. Click "Quit"
   - app fully terminates

7. MenuBar disabled, close main window
   - behavior remains unchanged from current standard app behavior

### Automated Coverage

Add focused tests only where the current test structure can support them without broad harness changes.

Useful targets:

- unit coverage for any extracted pure helper that decides activation-policy behavior
- regression coverage for route-preservation vs route-change behavior if the logic is factored into testable app-side helpers

Default verification after implementation:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests
```

UI test bundles are out of scope unless explicitly requested.

## Risks and Constraints

- SwiftUI window creation timing is not fully deterministic, so focus logic must tolerate the case where a new window is requested before an `NSWindow` instance is immediately available
- activation policy transitions should be done only when needed to avoid unnecessary Dock churn
- route changes must not unexpectedly reset the current page for the open-main-window action
- the solution must remain compatible with the existing restored-window behavior and not fight the current `WindowAccessor` sizing/restoration setup

## Recommended Implementation Shape

Keep the implementation small and app-owned:

- extend the existing app file rather than introducing a new generalized window manager subsystem
- store a weak main-window reference captured through `WindowAccessor`
- expose a single closure or app-owned callback path that MenuBar views can invoke
- centralize activation policy, focus, and route update logic in one method

This provides the requested behavior with the smallest surface-area change and avoids refactoring unrelated modules.
