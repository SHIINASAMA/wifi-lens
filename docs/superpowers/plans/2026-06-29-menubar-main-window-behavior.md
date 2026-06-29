# MenuBar Main Window Behavior Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a unified main-window reopen path for the Pro MenuBar, add dedicated open/settings/quit actions, and switch the app between regular and accessory activation modes when the main window closes or reopens.

**Architecture:** Keep the change app-owned and narrowly scoped. `WiFiLensApp` becomes the single coordinator for main-window capture, reopen, focus, optional route changes, and activation-policy transitions. The MenuBar UI delegates to that coordinator instead of owning navigation or window behavior.

**Tech Stack:** SwiftUI, AppKit (`NSWindow`, `NSApp`, activation policy), Swift Testing, Xcode project build/test flow

## Global Constraints

- Do not refactor unrelated app structure or navigation architecture.
- Do not change Pro gating logic or the Menu Bar feature toggle behavior itself.
- Do not redesign MenuBar visual styling beyond the required new actions and divider.
- Do not introduce a new routing model separate from the existing `SidebarPage` state.
- Do not perform broader localization cleanup. Any new copy uses temporary keys or the existing localization placeholder pattern.
- App build/test must use `xcodebuild`, never `swift build` / `swift test`.
- Do not run UI test bundles unless the user explicitly asks for them.
- Never commit without explicit user instruction.

## File Structure

| File | Responsibility |
|------|----------------|
| `WiFiLens/Sources/WiFiLens/WiFiLensApp.swift` | Own main-window reference capture, close observation, unified `showMainWindow(route:)`, app-level Settings command routing, and activation-policy transitions |
| `Pro/MenuBar/MenuBarScene.swift` | Pass MenuBar action callbacks into MenuBar content |
| `Pro/MenuBar/MenuBarStatusView.swift` | Render the new MenuBar actions and delegate them through callbacks |
| `WiFiLens/Tests/WiFiLensTests/App/MenuBarWindowBehaviorTests.swift` | Cover extracted pure helper behavior for route preservation and activation-policy decisions |
| `WiFiLens/WiFiLens.xcodeproj/project.pbxproj` | Register the new test file in the test target |

### Task 1: Add focused regression tests for MenuBar window behavior helpers

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/WiFiLensApp.swift`
- Create: `WiFiLens/Tests/WiFiLensTests/App/MenuBarWindowBehaviorTests.swift`
- Modify: `WiFiLens/WiFiLens.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: existing `SidebarPage`
- Produces:
  - `enum MainWindowRouteIntent: Equatable { case preserveCurrentPage; case navigate(SidebarPage) }`
  - `enum MainWindowActivationAction: Equatable { case keepCurrentPolicy; case switchToRegular; case switchToAccessory }`
  - `func routeIntent(for route: SidebarPage?) -> MainWindowRouteIntent`
  - `func closeAction(menuBarEnabled: Bool) -> MainWindowActivationAction`
  - `func reopenAction(menuBarEnabled: Bool, currentPolicy: NSApplication.ActivationPolicy) -> MainWindowActivationAction`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import WiFiLens

@Suite("MenuBar Main Window Behavior")
struct MenuBarWindowBehaviorTests {
    @Test("route intent preserves current page when route is nil")
    func routeIntentPreservesCurrentPage() {
        #expect(routeIntent(for: nil) == .preserveCurrentPage)
    }

    @Test("route intent navigates when route is provided")
    func routeIntentNavigatesToSettings() {
        #expect(routeIntent(for: .settings) == .navigate(.settings))
    }

    @Test("close action switches to accessory only when menu bar is enabled")
    func closeActionDependsOnMenuBarFlag() {
        #expect(closeAction(menuBarEnabled: true) == .switchToAccessory)
        #expect(closeAction(menuBarEnabled: false) == .keepCurrentPolicy)
    }

    @Test("reopen action switches to regular only from accessory mode with menu bar enabled")
    func reopenActionDependsOnCurrentPolicy() {
        #expect(reopenAction(menuBarEnabled: true, currentPolicy: .accessory) == .switchToRegular)
        #expect(reopenAction(menuBarEnabled: true, currentPolicy: .regular) == .keepCurrentPolicy)
        #expect(reopenAction(menuBarEnabled: false, currentPolicy: .accessory) == .keepCurrentPolicy)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests/MenuBarWindowBehaviorTests
```

Expected: test target fails because the helper types/functions do not exist yet, or the new test file is not yet wired into the project.

- [ ] **Step 3: Add the minimal helper types and functions**

Add small pure helpers near the app-level window coordination code:

```swift
enum MainWindowRouteIntent: Equatable {
    case preserveCurrentPage
    case navigate(SidebarPage)
}

enum MainWindowActivationAction: Equatable {
    case keepCurrentPolicy
    case switchToRegular
    case switchToAccessory
}

func routeIntent(for route: SidebarPage?) -> MainWindowRouteIntent {
    guard let route else { return .preserveCurrentPage }
    return .navigate(route)
}

func closeAction(menuBarEnabled: Bool) -> MainWindowActivationAction {
    menuBarEnabled ? .switchToAccessory : .keepCurrentPolicy
}

func reopenAction(menuBarEnabled: Bool, currentPolicy: NSApplication.ActivationPolicy) -> MainWindowActivationAction {
    guard menuBarEnabled, currentPolicy == .accessory else { return .keepCurrentPolicy }
    return .switchToRegular
}
```

- [ ] **Step 4: Register the new test file in the Xcode project**

Update `project.pbxproj` so `MenuBarWindowBehaviorTests.swift` is added as:

- `PBXFileReference`
- member of the `WiFiLensTests` group
- `PBXBuildFile`
- entry in the `WiFiLensTests` Sources build phase

- [ ] **Step 5: Run test to verify it passes**

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests/MenuBarWindowBehaviorTests
```

Expected: `MenuBarWindowBehaviorTests` passes cleanly.

### Task 2: Implement unified main-window coordination in `WiFiLensApp`

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/WiFiLensApp.swift`

**Interfaces:**
- Consumes:
  - `routeIntent(for route: SidebarPage?) -> MainWindowRouteIntent`
  - `closeAction(menuBarEnabled: Bool) -> MainWindowActivationAction`
  - `reopenAction(menuBarEnabled: Bool, currentPolicy: NSApplication.ActivationPolicy) -> MainWindowActivationAction`
- Produces:
  - `@MainActor func showMainWindow(route: SidebarPage? = nil)`
  - `@MainActor func registerMainWindow(_ window: NSWindow?)`
  - a weakly-retained main-window reference
  - close-notification handling filtered to the main window

- [ ] **Step 1: Write the failing test or failing verification command**

Use the focused helper tests from Task 1 plus a build check that will currently fail once the call sites are updated but the coordinator is not yet complete.

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build
```

Expected: build fails after temporary call-site updates reference `showMainWindow(route:)` before it is fully implemented.

- [ ] **Step 2: Capture the main window through `WindowAccessor`**

Replace the current fire-and-forget accessor with a callback-based form:

```swift
private struct WindowAccessor: NSViewRepresentable {
    let defaultSize: CGSize
    let minSize: CGSize
    let onResolveWindow: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(view.window)
            onResolveWindow(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(nsView.window)
            onResolveWindow(nsView.window)
        }
    }
}
```

- [ ] **Step 3: Add app-owned main-window state and close observation**

Introduce small app-owned state for:

```swift
@State private var mainWindow: NSWindow?
@State private var pendingMainWindowRoute: SidebarPage?
@AppStorage("menuBarEnabled") private var menuBarEnabled = true
```

And add registration logic:

```swift
@MainActor
private func registerMainWindow(_ window: NSWindow?) {
    guard let window else { return }
    mainWindow = window

    NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: nil)
    NotificationCenter.default.addObserver(
        forName: NSWindow.willCloseNotification,
        object: window,
        queue: .main
    ) { _ in
        handleMainWindowWillClose()
    }

    if let pendingRoute = pendingMainWindowRoute {
        selectedPage = pendingRoute
        pendingMainWindowRoute = nil
    }
}
```

If `self` cannot be used safely in that shape inside `App`, convert the observer token into explicit `@State private var mainWindowCloseObserver: NSObjectProtocol?` and manage the token directly.

- [ ] **Step 4: Implement the unified coordinator**

Add the app-owned coordinator methods:

```swift
@MainActor
private func showMainWindow(route: SidebarPage? = nil) {
    switch reopenAction(menuBarEnabled: menuBarEnabled, currentPolicy: NSApp.activationPolicy()) {
    case .switchToRegular:
        NSApp.setActivationPolicy(.regular)
    case .keepCurrentPolicy, .switchToAccessory:
        break
    }

    switch routeIntent(for: route) {
    case .navigate(let page):
        selectedPage = page
        pendingMainWindowRoute = page
    case .preserveCurrentPage:
        pendingMainWindowRoute = nil
    }

    if let mainWindow, mainWindow.isVisible {
        NSApp.activate(ignoringOtherApps: true)
        mainWindow.makeKeyAndOrderFront(nil)
        return
    }

    NSApp.activate(ignoringOtherApps: true)
    NSApp.sendAction(#selector(NSWindow.makeKeyAndOrderFront(_:)), to: nil, from: nil)
}

@MainActor
private func handleMainWindowWillClose() {
    mainWindow = nil
    switch closeAction(menuBarEnabled: menuBarEnabled) {
    case .switchToAccessory:
        NSApp.setActivationPolicy(.accessory)
    case .keepCurrentPolicy, .switchToRegular:
        break
    }
}
```

If the project already exposes a more reliable `openWindow` environment path from a nested helper view, use that only for the "no window exists" branch and keep the `NSWindow`-based focusing steps intact.

- [ ] **Step 5: Wire the accessor callback into the root view**

Update the existing background attachment:

```swift
.background(
    WindowAccessor(
        defaultSize: mainWindowDefaultSize,
        minSize: mainWindowMinSize,
        onResolveWindow: registerMainWindow
    )
)
```

- [ ] **Step 6: Route the app Settings command through the new coordinator**

Replace:

```swift
selectedPage = .settings
```

with:

```swift
showMainWindow(route: .settings)
```

- [ ] **Step 7: Run build verification**

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build
```

Expected: build succeeds with the coordinator and window capture integrated.

### Task 3: Update MenuBar actions to use the unified coordinator

**Files:**
- Modify: `Pro/MenuBar/MenuBarScene.swift`
- Modify: `Pro/MenuBar/MenuBarStatusView.swift`

**Interfaces:**
- Consumes:
  - `showMainWindow(route: SidebarPage? = nil)`
- Produces:
  - `MenuBarStatusView` callbacks for open-main-window, settings, and quit

- [ ] **Step 1: Write the failing build change**

Temporarily update `MenuBarStatusView` to require action closures before the scene passes them.

Example target shape:

```swift
struct MenuBarStatusView: View {
    let onOpenMainWindow: () -> Void
    let onOpenSettings: () -> Void
    let onQuit: () -> Void
    @ObservedObject var viewModel: MenuBarStatusViewModel
}
```

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build
```

Expected: build fails because `MenuBarScene` does not yet pass the new closures.

- [ ] **Step 2: Add the new MenuBar actions UI**

Add the requested actions to the popover content:

```swift
private var actionSection: some View {
    VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 10) {
            Button(String(localized: "menubar.action.open_main_window", comment: "Temporary key for opening the main window from the menu bar")) {
                onOpenMainWindow()
            }
            .buttonStyle(.bordered)

            Button(String(localized: "common.action.settings", comment: "Settings button or menu item")) {
                onOpenSettings()
            }
            .buttonStyle(.bordered)
        }

        Divider()

        Button(String(localized: "menubar.action.quit_app", comment: "Temporary key for quitting the app from the menu bar")) {
            onQuit()
        }
        .buttonStyle(.plain)
    }
    .padding(.horizontal, 12)
    .padding(.bottom, 12)
}
```

Then include `actionSection` at the bottom of the existing layout so Quit is separated from the upper functional area.

- [ ] **Step 3: Pass action closures from `MenuBarScene`**

Update the scene to build the MenuBar content with closures:

```swift
MenuBarStatusView(
    viewModel: statusViewModel,
    onOpenMainWindow: { showMainWindow(route: nil) },
    onOpenSettings: { showMainWindow(route: .settings) },
    onQuit: { NSApp.terminate(nil) }
)
```

If `MenuBarScene` cannot call the app method directly, thread the callbacks in from `WiFiLensApp` through a small wrapper view created inside the `MenuBarScene` call site.

- [ ] **Step 4: Route the existing gear button through the same Settings callback**

Replace the current inert gear button action:

```swift
Button(action: onOpenSettings) {
    Image(systemName: "gearshape")
}
```

- [ ] **Step 5: Run focused tests and full default verification**

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests/MenuBarWindowBehaviorTests
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests
```

Expected:

- `MenuBarWindowBehaviorTests` passes
- app build succeeds
- default unit test suite succeeds without running UI tests

## Self-Review Mapping

- Unified `showMainWindow(route:)`: Task 2
- Preserve current page when route is nil: Task 1 + Task 2
- Navigate to Settings through shared state: Task 1 + Task 2 + Task 3
- Add MenuBar "Open Main Window": Task 3
- Add MenuBar "Quit": Task 3
- Switch to accessory on main-window close only when MenuBar is enabled: Task 1 + Task 2
- Restore regular activation before reopen from MenuBar: Task 1 + Task 2
- Keep non-MenuBar close behavior unchanged: Task 1 + Task 2
- Keep scope limited to MenuBar/main-window code: enforced by file structure and constraints
