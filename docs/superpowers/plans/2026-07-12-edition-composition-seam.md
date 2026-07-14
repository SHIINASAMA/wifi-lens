# OSS / Pro Edition Composition Seam Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Centralize OSS and Pro feature composition behind target-selected adapters without changing any user-visible behavior.

**Architecture:** The shared shell retains product routes, common pages, locked upsell metadata, and window behavior. A same-name `EditionComposition` type is supplied by exactly one target-specific source file per edition. The OSS implementation supplies the existing locked/preview surfaces and no-op lifecycle contribution; the Pro implementation owns Timeline, recording/session, journal lifecycle, menu-bar routing, settings additions, and commands.

**Tech Stack:** Swift 6, SwiftUI/AppKit, Xcode project target membership, Swift Testing, macOS 14+.

## Global Constraints

- Phase 1 is behavior-preserving: no route, copy, control, lock state, persistence, event, window, menu-bar, settings, toolbar, or command behavior may change.
- Shared shell code must not name `EventFilterType`, `TimelineNavigationRequest`, `TimelineViewModel`, `WiFiObservationEventJournal`, `ProObservationEventBootstrap`, `RecordingViewModel`, or Pro SQLite types.
- `SidebarPage.timeline` and all shared upsell descriptors remain in shared Sources.
- `EditionComposition` is compile-time target-selected; no runtime registry or dependency-injection container.
- Keep type erasure out of domain APIs. Target-specific SwiftUI wrapper views are the composition boundary.
- The OSS adapter must not import or reference a Pro type.
- No Pro implementation source may be a WiFiLens/OSS Sources member.
- Add every new OSS test file to the WiFiLensTests PBX Sources phase and every new Pro test file to WiFiLensProTests.
- Use `xcodebuild`; do not run UI test bundles unless explicitly requested.
- Do not commit, merge, or push without a new explicit user instruction.
- Execute with fresh sequential implementer/reviewer Subagents and no worktree.

---

## File Structure

| File | Responsibility |
| --- | --- |
| `WiFiLens/Sources/WiFiLens/App/EditionCompositionContext.swift` | Shared, Pro-free bindings and callbacks that an edition contribution needs from the app shell. |
| `WiFiLens/Sources/WiFiLens/App/OSSEditionComposition.swift` | OSS-only same-name adapter; renders existing locked Timeline/recording surfaces and no-op lifecycle. |
| `Pro/App/ProEditionComposition.swift` | Pro-only same-name adapter; owns target-specific state and delegates to focused Pro surface views. |
| `Pro/App/ProTimelineCompositionView.swift` | Owns Timeline range/search/filter/inspector/navigation state and renders the existing Timeline UI. |
| `Pro/App/ProSettingsComposition.swift` | Owns existing Pro Settings rows and Timeline clear action. |
| `Pro/App/ProMenuBarComposition.swift` | Owns Menu Bar scene and event-ID-to-Timeline navigation state. |
| `WiFiLens/Sources/WiFiLens/WiFiLensApp.swift` | Keeps common product shell only; calls edition façade rather than Pro symbols. |
| `WiFiLens/Sources/WiFiLens/App/SettingsView.swift` | Hosts a target-selected settings contribution instead of `#if PRO` implementation bodies. |
| `WiFiLens/Sources/WiFiLens/App/SecondaryToolbar.swift` | Delegates edition-owned Timeline/recording descriptor policy to the façade while preserving common descriptors. |
| `WiFiLens/Tests/WiFiLensTests/EditionCompositionTests.swift` | Verifies OSS locked contributions and shared-shell isolation. |
| `Pro/Tests/WiFiLensProTests/EditionCompositionTests.swift` | Verifies Pro Timeline defaults, lifecycle idempotence, and event-route handoff. |

## Task 1: Establish the Pro-free façade and OSS adapter

**Files:**
- Create: `WiFiLens/Sources/WiFiLens/App/EditionCompositionContext.swift`
- Create: `WiFiLens/Sources/WiFiLens/App/OSSEditionComposition.swift`
- Create: `WiFiLens/Tests/WiFiLensTests/EditionCompositionTests.swift`
- Modify: `WiFiLens/Sources/WiFiLens/App/SecondaryToolbar.swift`
- Modify: `WiFiLens/WiFiLens.xcodeproj/project.pbxproj`

**Consumes:** Shared `SidebarPage`, `SecondaryToolbarItemID`, `SecondaryToolbarDescriptor`, `ScannerViewModel`, and existing `ProFeaturePlaceholderView`/`TimelineSkeletonView`.

**Produces:** A shared-only `EditionCompositionContext` and target-selected `EditionComposition` API that later Pro sources must implement exactly.

- [x] **Step 1: Write failing OSS characterization tests**

Create `EditionCompositionTests.swift` with Swift Testing coverage that calls the façade’s descriptor and page contribution APIs. Assert the existing OSS contract:

```swift
@Test("OSS timeline contribution remains a locked preview")
func ossTimelineContributionIsLockedPreview() {
    #expect(EditionComposition.timelineToolbarDescriptor == nil)
    #expect(EditionComposition.isTimelineLockedPreview)
}

@Test("OSS recording segment remains locked")
func ossRecordingSegmentRemainsLocked() {
    let descriptor = EditionComposition.spectrumToolbarDescriptor
    #expect(descriptor.items.first { $0.id == .spectrumRecording }?.isLocked == true)
}
```

Add the test file to the WiFiLensTests PBX group, build phase, and scheme testables.

- [x] **Step 2: Run the focused test to verify it fails**

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests/EditionCompositionTests
```

Expected: compilation failure because `EditionComposition` does not exist.

- [x] **Step 3: Define only shared façade inputs and OSS behavior**

Create a context that carries shared bindings/callbacks only. It must not mention a Pro type:

```swift
struct EditionCompositionContext {
    let scannerViewModel: ScannerViewModel
    let selectedPage: Binding<SidebarPage>
    let secondaryToolbarSelections: Binding<SecondaryToolbarSelections>
    let bleEnabled: Binding<Bool>
    let openMainWindow: (SidebarPage?) -> Void
}
```

In `OSSEditionComposition.swift`, define the target-local same-name façade:

```swift
enum EditionComposition {
    static let isTimelineLockedPreview = true
    static var timelineToolbarDescriptor: SecondaryToolbarDescriptor? { nil }
    static var spectrumToolbarDescriptor: SecondaryToolbarDescriptor {
        SecondaryToolbarDescriptor.spectrum(recordingLocked: true)
    }

    @ViewBuilder
    static func detailContribution(context: EditionCompositionContext) -> some View {
        if context.selectedPage.wrappedValue == .timeline {
            ProFeaturePlaceholderView(/* preserve existing title, description, icon, skeleton */)
                .accessibilityIdentifier("page-timeline")
        }
    }

    static func startLifecycle(observationRuntime: WiFiObservationRuntime) {}
}
```

Refactor `SecondaryToolbarDescriptor` so its common spectrum structure accepts `recordingLocked: Bool`; retain its existing public `forPage(_:)` behavior by delegating the edition choice to `EditionComposition`.

- [x] **Step 4: Run the focused OSS test to verify it passes**

Run the Step 2 command. Expected: `EditionCompositionTests` passes with the existing lock states.

- [x] **Step 5: Verify target ownership and keep work uncommitted**

Run:

```sh
plutil -lint WiFiLens/WiFiLens.xcodeproj/project.pbxproj
rg -n 'OSSEditionComposition.swift|EditionCompositionTests.swift' WiFiLens/WiFiLens.xcodeproj/project.pbxproj
git diff --check
git diff --cached --name-status
```

Expected: the OSS adapter and its test have only OSS/WiFiLens target memberships; no staged changes. Do not commit.

## Task 2: Move Pro state and lifecycle into focused Pro composition surfaces

**Files:**
- Create: `Pro/App/ProEditionComposition.swift`
- Create: `Pro/App/ProTimelineCompositionView.swift`
- Create: `Pro/App/ProSettingsComposition.swift`
- Create: `Pro/App/ProMenuBarComposition.swift`
- Create: `Pro/Tests/WiFiLensProTests/EditionCompositionTests.swift`
- Modify: `WiFiLens/WiFiLens.xcodeproj/project.pbxproj`

**Consumes:** The Task 1 façade shape and `EditionCompositionContext`; existing `TimelineView`, `TimelineFilterPanel`, `ContentView`, `MenuBarScene`, and `ProObservationEventBootstrap`.

**Produces:** Pro-only wrappers that own all Pro composition state and satisfy the same façade API.

- [x] **Step 1: Write failing Pro characterization tests**

Add a Pro test file that covers the preserved Pro composition contract:

```swift
@Test("Pro Timeline toolbar keeps today as its default")
func proTimelineToolbarDefaultsToToday() {
    #expect(EditionComposition.timelineToolbarDescriptor?.defaultSelection == .timelineToday)
}

@Test("Pro lifecycle registers its event journal once")
@MainActor
func proLifecycleStartsJournalOnce() async throws {
    // Use ProObservationEventBootstrap.withEventJournalForTesting and a recording runtime.
    // Call EditionComposition.startLifecycle twice and assert one consumer registration.
}
```

Add the file to WiFiLensProTests only.

- [x] **Step 2: Run the focused Pro test to verify it fails**

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens Pro" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensProTests/EditionCompositionTests
```

Expected: compilation failure because the Pro façade is not present.

- [x] **Step 3: Implement focused Pro wrappers without changing feature behavior**

Implement `ProEditionComposition` as the same façade API with Pro-only internals:

```swift
enum EditionComposition {
    static let isTimelineLockedPreview = false
    static var timelineToolbarDescriptor: SecondaryToolbarDescriptor? {
        .timeline(defaultSelection: .timelineToday)
    }
    static var spectrumToolbarDescriptor: SecondaryToolbarDescriptor {
        .spectrum(recordingLocked: false)
    }

    static func startLifecycle(observationRuntime: WiFiObservationRuntime) {
        ProObservationEventBootstrap.start(observationRuntime: observationRuntime)
    }
}
```

`ProTimelineCompositionView` owns `@State` for search text, range dates, event filters, inspector presentation, and `TimelineNavigationRequest`. It renders the existing `TimelineView` and `TimelineFilterPanel` bindings unchanged. `ProSettingsComposition` owns the existing menu-bar toggle and clear-data row behavior. `ProMenuBarComposition` owns event-ID navigation then calls the shared route callback with `.timeline`.

- [x] **Step 4: Run focused Pro tests to verify they pass**

Run the Step 2 command plus:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens Pro" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensProTests/EventJournalTests -only-testing:WiFiLensProTests/TimelinePresentationTests -only-testing:WiFiLensProTests/MenuBarMigrationTests
```

Expected: all selected Pro tests pass.

- [x] **Step 5: Verify Pro-only membership and keep work uncommitted**

Run:

```sh
plutil -lint WiFiLens/WiFiLens.xcodeproj/project.pbxproj
rg -n 'ProEditionComposition.swift|ProTimelineCompositionView.swift|ProSettingsComposition.swift|ProMenuBarComposition.swift|EditionCompositionTests.swift' WiFiLens/WiFiLens.xcodeproj/project.pbxproj
git -C Pro diff --check
git -C Pro diff --cached --name-status
```

Expected: all four Pro composition sources and the Pro test appear only in Pro/ProTests build phases; no staged changes. Do not commit.

## Task 3: Reduce the shared root to product-shell knowledge

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/WiFiLensApp.swift`
- Modify: `WiFiLens/Sources/WiFiLens/App/SettingsView.swift`
- Modify: `WiFiLens/Sources/WiFiLens/App/SecondaryToolbar.swift`
- Modify: `WiFiLens/Tests/WiFiLensTests/EditionCompositionTests.swift`
- Modify: `Pro/Tests/WiFiLensProTests/EditionCompositionTests.swift`

**Consumes:** Task 1 and Task 2 façade APIs.

**Produces:** A shared root with no direct Pro type/lifecycle knowledge.

- [x] **Step 1: Extend tests with shared-root deletion assertions**

Add source-level regression assertions only if existing test infrastructure supports fixture-source inspection; otherwise make the acceptance search a mandatory gate. Preserve behavioral tests for:

```swift
@Test("shared Timeline route remains available to OSS")
func sharedTimelineRouteRemainsAvailable() {
    #expect(SidebarPage.allCases.contains(.timeline))
}

@Test("Pro menu-bar route resolves to Timeline")
func proMenuBarEventRouteResolvesToTimeline() {
    #expect(EditionComposition.routeForMenuBarEvent() == .timeline)
}
```

- [x] **Step 2: Run the focused tests to verify the new API fails**

Run the focused OSS and Pro commands from Tasks 1 and 2. Expected: compile failure for the new route handoff API.

- [x] **Step 3: Replace shared-root Pro branches with edition contributions**

Apply these constraints while editing `WiFiLensApp.swift`:

```swift
// Shared root calls only this shape; it never stores TimelineNavigationRequest.
EditionComposition.detailContribution(context: editionContext)
EditionComposition.toolbarContribution(context: editionContext)
EditionComposition.startLifecycle(observationRuntime: viewModel.observationRuntime)
EditionComposition.menuBarScene(openMainWindow: showMainWindow, terminate: { NSApp.terminate(nil) })
```

Move the `#if PRO` Timeline state, recording state, `TimelineToolbarSearchField`, `BorderlessSearchTextField`, direct `MenuBarScene` construction, and direct bootstrap call into the Pro composition files. The OSS adapter supplies the current placeholder and no-op behavior. Retain common Spectrum, channel, interface, Sidebar, Settings, window, and command mechanics in the shared shell.

Refactor `SettingsView` to render a target-selected `EditionComposition.settingsContribution()` instead of containing `#if PRO` implementation bodies. The OSS contribution must render the existing `MenuBarFeaturePreviewRow`; the Pro contribution must render the existing menu-bar control and clear-data section with unchanged accessibility identifiers and clear semantics.

- [x] **Step 4: Run focused behavior tests to verify they pass**

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests/EditionCompositionTests
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens Pro" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensProTests/EditionCompositionTests -only-testing:WiFiLensProTests/EventJournalTests -only-testing:WiFiLensProTests/TimelinePresentationTests -only-testing:WiFiLensProTests/MenuBarMigrationTests
```

Expected: all selected tests pass with unchanged route, lock, lifecycle, Timeline, and menu behavior.

- [x] **Step 5: Run the required shared-root deletion audit**

Run:

```sh
rg -n 'EventFilterType|TimelineNavigationRequest|TimelineViewModel|WiFiObservationEventJournal|ProObservationEventBootstrap|RecordingViewModel|MenuBarScene' WiFiLens/Sources/WiFiLens/WiFiLensApp.swift WiFiLens/Sources/WiFiLens/App/SettingsView.swift
```

Expected: zero production matches. `SidebarPage.timeline`, shared upsell labels, and generic `EditionComposition` calls remain allowed. Do not commit.

## Task 4: Document the seam and run both-edition acceptance gates

**Files:**
- Modify: `docs/ARCHITECTURE.md`
- Modify: `Pro/docs/ARCHITECTURE.md`
- Modify: `docs/TESTING.md` only if the test target registration process needs a new edition-composition note.

**Consumes:** Completed adapters and test coverage from Tasks 1–3.

**Produces:** Auditable documentation and final verification evidence.

- [ ] **Step 1: Write documentation assertions as test checklist entries**

Document these exact architectural facts:

```text
Shared shell owns product routes and upsell descriptors.
Exactly one EditionComposition implementation is compiled per edition.
Pro lifecycle and domain composition are not shared-source responsibilities.
OSS can retain Timeline and recording upsell surfaces without importing Pro domain code.
```

- [ ] **Step 2: Run full unit targets**

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens Pro" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensProTests
```

Expected: both unit targets pass. Do not run UI tests.

- [ ] **Step 3: Build both editions**

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates build
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens Pro" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates build
```

Expected: both builds succeed.

- [ ] **Step 4: Audit PBX membership and production boundaries**

Run:

```sh
plutil -lint WiFiLens/WiFiLens.xcodeproj/project.pbxproj
rg -n 'EditionComposition|ProEditionComposition|OSSEditionComposition' WiFiLens/WiFiLens.xcodeproj/project.pbxproj
rg -n 'EventFilterType|TimelineNavigationRequest|ProObservationEventBootstrap|RecordingViewModel|MenuBarScene' WiFiLens/Sources/WiFiLens/WiFiLensApp.swift WiFiLens/Sources/WiFiLens/App/SettingsView.swift
git diff --check
git -C Pro diff --check
git diff --cached --name-status
git -C Pro diff --cached --name-status
```

Expected: PBX syntax is valid; adapter ownership is edition-correct; shared-root direct Pro references are zero; diff checks are clean; nothing is staged. Do not commit.

- [ ] **Step 5: Record final behavior-preservation evidence**

Record the exact test counts, build results, PBX evidence, deletion-search result, and any reviewer findings in `.superpowers/sdd/edition-composition-seam-task-4-report.md`. Do not commit.

## Completion Criteria

The phase is complete only when all task reviews are clean; OSS and Pro unit targets and Debug builds pass; source deletion searches prove shared root no longer names Pro implementation types; PBX membership proves exactly one adapter per edition; OSS locked routes and Pro Timeline/menu behavior retain their existing tests; documentation describes the seam; and no changes are staged, committed, merged, or pushed without explicit authorization.
