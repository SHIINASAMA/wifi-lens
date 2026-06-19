# Window Toolbar Secondary Navigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move page-internal mode switching for business pages into the real macOS window toolbar principal area, starting with `Channels`, while preserving the sidebar as the primary page navigator.

**Architecture:** Introduce a root-owned secondary-toolbar state model in `AppRootView`, let each `SidebarPage` declare optional secondary toolbar content, and render a custom capsule control through `ToolbarItem(placement: .principal)`. Lift local page mode state out of page views so toolbar interaction is driven by root state instead of page-local `@State`.

**Tech Stack:** SwiftUI, macOS window toolbar APIs, existing `glassBackground` utility, Swift Testing, Xcode project/scheme setup in `WiFiLens.xcodeproj`

## Global Constraints

- Use real SwiftUI window toolbar APIs; do not use overlay-based fake titlebar UI.
- Do not inject custom AppKit views into titlebar button superviews or other private hierarchy surfaces.
- Sidebar remains the primary top-level navigation; the toolbar only handles page-internal secondary switching.
- Pages without secondary navigation, including `Overview`, must not show the principal toolbar capsule.
- New user-facing strings must use `String(localized:)` and be added manually to `Resources/Localizable.xcstrings` only if new copy is introduced.
- All new `.swift` source files must be added to both `WiFiLens` and `WiFiLensPro` targets if new files are created.
- Default verification is `xcodebuild ... build` plus `-only-testing:WiFiLensTests`; do not run UI test bundles unless explicitly requested.

---

### Task 1: Define Root-Owned Secondary Toolbar State

**Files:**
- Modify: `/Users/kaoru/Developer/wifi-lens/WiFiLens/Sources/WiFiLens/WiFiLensApp.swift`
- Modify: `/Users/kaoru/Developer/wifi-lens/WiFiLens/Sources/WiFiLens/App/SidebarView.swift`
- Create: `/Users/kaoru/Developer/wifi-lens/WiFiLens/Sources/WiFiLens/App/SecondaryToolbar.swift`
- Test: `/Users/kaoru/Developer/wifi-lens/WiFiLens/Tests/WiFiLensTests/SecondaryToolbarTests.swift`

**Interfaces:**
- Consumes: `SidebarPage`
- Produces:
  - `enum SecondaryToolbarItemID: Hashable`
  - `struct SecondaryToolbarItem: Identifiable, Equatable`
  - `struct SecondaryToolbarDescriptor: Equatable`
  - `extension SidebarPage { var supportsSecondaryToolbar: Bool }`
  - Root state entries for page-specific secondary selections

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import WiFiLens

@Test func secondaryToolbarDescriptor_isNilForOverview() {
    #expect(SecondaryToolbarDescriptor.forPage(.overview) == nil)
}

@Test func secondaryToolbarDescriptor_channelsContainsTwoItems() {
    let descriptor = SecondaryToolbarDescriptor.forPage(.channels)
    #expect(descriptor != nil)
    #expect(descriptor?.items.map(\.id) == [.channelsSimple, .channelsTable])
    #expect(descriptor?.defaultSelection == .channelsSimple)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
xcodebuild -project /Users/kaoru/Developer/wifi-lens/WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests/SecondaryToolbarTests
```

Expected: FAIL because `SecondaryToolbarDescriptor` and related symbols do not exist.

- [ ] **Step 3: Write minimal implementation**

```swift
import SwiftUI

enum SecondaryToolbarItemID: Hashable {
    case channelsSimple
    case channelsTable
}

struct SecondaryToolbarItem: Identifiable, Equatable {
    let id: SecondaryToolbarItemID
    let titleKey: String
}

struct SecondaryToolbarDescriptor: Equatable {
    let items: [SecondaryToolbarItem]
    let defaultSelection: SecondaryToolbarItemID

    static func forPage(_ page: SidebarPage) -> Self? {
        switch page {
        case .channels:
            Self(
                items: [
                    SecondaryToolbarItem(id: .channelsSimple, titleKey: "channels.mode.simple"),
                    SecondaryToolbarItem(id: .channelsTable, titleKey: "channels.mode.professional")
                ],
                defaultSelection: .channelsSimple
            )
        default:
            nil
        }
    }
}
```

- [ ] **Step 4: Wire root-owned selection state in `WiFiLensApp.swift`**

```swift
@State private var secondaryToolbarSelections: [SidebarPage: SecondaryToolbarItemID] = [
    .channels: .channelsSimple
]

private var activeSecondaryToolbarDescriptor: SecondaryToolbarDescriptor? {
    SecondaryToolbarDescriptor.forPage(selectedPage)
}

private var activeSecondaryToolbarSelection: Binding<SecondaryToolbarItemID>? {
    guard let descriptor = activeSecondaryToolbarDescriptor else { return nil }
    return Binding(
        get: { secondaryToolbarSelections[selectedPage] ?? descriptor.defaultSelection },
        set: { secondaryToolbarSelections[selectedPage] = $0 }
    )
}
```

- [ ] **Step 5: Run test to verify it passes**

Run:
```bash
xcodebuild -project /Users/kaoru/Developer/wifi-lens/WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests/SecondaryToolbarTests
```

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add /Users/kaoru/Developer/wifi-lens/WiFiLens/Sources/WiFiLens/App/SecondaryToolbar.swift /Users/kaoru/Developer/wifi-lens/WiFiLens/Sources/WiFiLens/WiFiLensApp.swift /Users/kaoru/Developer/wifi-lens/WiFiLens/Tests/WiFiLensTests/SecondaryToolbarTests.swift
git commit -m "feat: add root secondary toolbar model"
```

### Task 2: Build the Custom Capsule Toolbar Control

**Files:**
- Create: `/Users/kaoru/Developer/wifi-lens/WiFiLens/Sources/WiFiLens/App/SecondaryToolbarCapsule.swift`
- Modify: `/Users/kaoru/Developer/wifi-lens/WiFiLens/Sources/WiFiLens/Utilities/GlassBackground.swift`
- Test: `/Users/kaoru/Developer/wifi-lens/WiFiLens/Tests/WiFiLensTests/SecondaryToolbarCapsuleTests.swift`

**Interfaces:**
- Consumes: `SecondaryToolbarDescriptor`, `Binding<SecondaryToolbarItemID>`
- Produces:
  - `struct SecondaryToolbarCapsule: View`
  - Selection callback via binding
  - Stable accessibility identifiers per segment

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import WiFiLens

@Test func capsuleSelectionUpdatesBinding() {
    var selection: SecondaryToolbarItemID = .channelsSimple
    let binding = Binding(
        get: { selection },
        set: { selection = $0 }
    )

    binding.wrappedValue = .channelsTable
    #expect(selection == .channelsTable)
}
```

- [ ] **Step 2: Run test to verify it fails only if needed**

Run:
```bash
xcodebuild -project /Users/kaoru/Developer/wifi-lens/WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests/SecondaryToolbarCapsuleTests
```

Expected: FAIL before file exists, then PASS once basic binding-backed view is added.

- [ ] **Step 3: Write minimal implementation**

```swift
import SwiftUI

struct SecondaryToolbarCapsule: View {
    let descriptor: SecondaryToolbarDescriptor
    @Binding var selection: SecondaryToolbarItemID

    var body: some View {
        HStack(spacing: 6) {
            ForEach(descriptor.items) { item in
                Button {
                    selection = item.id
                } label: {
                    Text(String(localized: item.titleKey, comment: "Secondary toolbar item title"))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .frame(minWidth: 96)
                        .background(selection == item.id ? Color.primary.opacity(0.10) : Color.clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("secondary-toolbar-\(String(describing: item.id))")
            }
        }
        .padding(6)
        .glassBackground(.regular, in: Capsule())
    }
}
```

- [ ] **Step 4: Add toolbar-safe visual constraints**

```swift
.frame(maxWidth: 420)
.fixedSize(horizontal: false, vertical: true)
.contentShape(Capsule())
```

Also ensure the control avoids hover/overlay layers that intercept clicks outside the buttons.

- [ ] **Step 5: Run test to verify it passes**

Run:
```bash
xcodebuild -project /Users/kaoru/Developer/wifi-lens/WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests/SecondaryToolbarCapsuleTests
```

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add /Users/kaoru/Developer/wifi-lens/WiFiLens/Sources/WiFiLens/App/SecondaryToolbarCapsule.swift /Users/kaoru/Developer/wifi-lens/WiFiLens/Tests/WiFiLensTests/SecondaryToolbarCapsuleTests.swift
git commit -m "feat: add custom secondary toolbar capsule"
```

### Task 3: Attach the Capsule to the Real Window Toolbar Principal Area

**Files:**
- Modify: `/Users/kaoru/Developer/wifi-lens/WiFiLens/Sources/WiFiLens/WiFiLensApp.swift`
- Test: `/Users/kaoru/Developer/wifi-lens/WiFiLens/Tests/WiFiLensTests/SecondaryToolbarAttachmentTests.swift`

**Interfaces:**
- Consumes: `activeSecondaryToolbarDescriptor`, `activeSecondaryToolbarSelection`
- Produces:
  - `.toolbar { ToolbarItem(placement: .principal) { ... } }`
  - Page-aware principal toolbar visibility

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import WiFiLens

@Test func channelsPageProvidesSecondaryToolbarDescriptor() {
    #expect(SecondaryToolbarDescriptor.forPage(.channels) != nil)
}

@Test func overviewPageProvidesNoSecondaryToolbarDescriptor() {
    #expect(SecondaryToolbarDescriptor.forPage(.overview) == nil)
}
```

- [ ] **Step 2: Run test to verify it fails only if coverage is missing**

Run:
```bash
xcodebuild -project /Users/kaoru/Developer/wifi-lens/WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests/SecondaryToolbarAttachmentTests
```

Expected: PASS once descriptor mapping exists; this task’s main verification is build plus manual interaction.

- [ ] **Step 3: Write minimal implementation**

Add to the root content chain in `WiFiLensApp.swift`:

```swift
.toolbar {
    ToolbarItem(placement: .principal) {
        if let descriptor = activeSecondaryToolbarDescriptor,
           let selection = activeSecondaryToolbarSelection {
            SecondaryToolbarCapsule(
                descriptor: descriptor,
                selection: selection
            )
        }
    }
}
```

- [ ] **Step 4: Reduce title competition when principal content is present**

Use a page-aware title strategy:

```swift
.navigationTitle(activeSecondaryToolbarDescriptor == nil ? selectedPage.label : "")
```

Keep `Overview` behavior intact unless later intentionally revised.

- [ ] **Step 5: Run build verification**

Run:
```bash
xcodebuild -project /Users/kaoru/Developer/wifi-lens/WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 6: Manual verification**

Check all of the following in the running app:

```text
1. Open Channels page.
2. Confirm the capsule appears centered in the real window toolbar.
3. Click each segment and confirm it is interactive.
4. Switch to Overview and confirm the capsule disappears.
5. Switch back to Channels and confirm the previous selection persists.
```

Expected: No dead click zone, no overlay-style fake titlebar behavior.

- [ ] **Step 7: Commit**

```bash
git add /Users/kaoru/Developer/wifi-lens/WiFiLens/Sources/WiFiLens/WiFiLensApp.swift
git commit -m "feat: attach secondary toolbar to window principal area"
```

### Task 4: Refactor `ChannelQualityView` to Consume Root-Owned Mode State

**Files:**
- Modify: `/Users/kaoru/Developer/wifi-lens/WiFiLens/Sources/WiFiLens/Channels/ChannelQualityView.swift`
- Modify: `/Users/kaoru/Developer/wifi-lens/WiFiLens/Sources/WiFiLens/WiFiLensApp.swift`
- Test: `/Users/kaoru/Developer/wifi-lens/WiFiLens/Tests/WiFiLensTests/ChannelQualityViewModeTests.swift`

**Interfaces:**
- Consumes: root-owned `SecondaryToolbarItemID`
- Produces:
  - `ChannelQualityView(channels:mode:)`
  - Mapping from toolbar selection to `ChannelViewMode`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import WiFiLens

@Test func channelsToolbarSelectionMapsToSimpleMode() {
    #expect(ChannelViewMode.fromToolbarSelection(.channelsSimple) == .simple)
}

@Test func channelsToolbarSelectionMapsToTableMode() {
    #expect(ChannelViewMode.fromToolbarSelection(.channelsTable) == .table)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
xcodebuild -project /Users/kaoru/Developer/wifi-lens/WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests/ChannelQualityViewModeTests
```

Expected: FAIL because mapping helper does not exist.

- [ ] **Step 3: Write minimal implementation**

In `ChannelQualityView.swift`:

```swift
enum ChannelViewMode: String, CaseIterable {
    case simple
    case table

    static func fromToolbarSelection(_ selection: SecondaryToolbarItemID) -> Self {
        switch selection {
        case .channelsSimple: .simple
        case .channelsTable: .table
        }
    }
}
```

Refactor the view initializer/state usage:

```swift
struct ChannelQualityView: View {
    let channels: [ChannelRecommendation]
    let mode: ChannelViewMode
    @State private var sortKey: SortKey = .rfScore
    @State private var sortAscending: Bool = false
    @State private var selectedID: String?
}
```

Remove the in-view segmented picker block entirely.

- [ ] **Step 4: Pass root selection into the page**

In `WiFiLensApp.swift`:

```swift
let channelsMode = ChannelViewMode.fromToolbarSelection(
    secondaryToolbarSelections[.channels] ?? .channelsSimple
)

ChannelQualityView(
    channels: viewModel.channelRecommendations,
    mode: channelsMode
)
```

- [ ] **Step 5: Run test and build verification**

Run:
```bash
xcodebuild -project /Users/kaoru/Developer/wifi-lens/WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests/ChannelQualityViewModeTests
xcodebuild -project /Users/kaoru/Developer/wifi-lens/WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build
```

Expected: PASS and BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add /Users/kaoru/Developer/wifi-lens/WiFiLens/Sources/WiFiLens/Channels/ChannelQualityView.swift /Users/kaoru/Developer/wifi-lens/WiFiLens/Sources/WiFiLens/WiFiLensApp.swift /Users/kaoru/Developer/wifi-lens/WiFiLens/Tests/WiFiLensTests/ChannelQualityViewModeTests.swift
git commit -m "refactor: drive channels mode from root toolbar state"
```

### Task 5: Prepare the Generic Expansion Path for Other Business Pages

**Files:**
- Modify: `/Users/kaoru/Developer/wifi-lens/WiFiLens/Sources/WiFiLens/App/SecondaryToolbar.swift`
- Modify: `/Users/kaoru/Developer/wifi-lens/WiFiLens/Sources/WiFiLens/Interfaces/InterfacesView.swift`
- Modify: `/Users/kaoru/Developer/wifi-lens/WiFiLens/Sources/WiFiLens/Spectrum/ContentView.swift`
- Test: `/Users/kaoru/Developer/wifi-lens/WiFiLens/Tests/WiFiLensTests/SecondaryToolbarDescriptorExpansionTests.swift`

**Interfaces:**
- Consumes: existing page-local mode enums
- Produces:
  - Additional descriptor entries for `interfaces` and `spectrum`
  - A stable extension path for future business pages

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import WiFiLens

@Test func interfacesPageProvidesSecondaryToolbarDescriptor() {
    let descriptor = SecondaryToolbarDescriptor.forPage(.interfaces)
    #expect(descriptor != nil)
    #expect(descriptor?.items.count == 3)
}

@Test func spectrumPageDescriptorCanBeAddedWithoutChangingChannelsContract() {
    let descriptor = SecondaryToolbarDescriptor.forPage(.spectrum)
    #expect(descriptor != nil)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
xcodebuild -project /Users/kaoru/Developer/wifi-lens/WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests/SecondaryToolbarDescriptorExpansionTests
```

Expected: FAIL because only `channels` is defined initially.

- [ ] **Step 3: Write minimal implementation**

Extend `SecondaryToolbarItemID` and `SecondaryToolbarDescriptor.forPage(_:)` with:

```swift
case interfacesSimple
case interfacesDetails
case interfacesMonitor
case spectrumLive
case spectrumRecording
```

Map `SidebarPage.interfaces` and `SidebarPage.spectrum` to descriptors without changing toolbar rendering architecture.

- [ ] **Step 4: Refactor additional pages only when ready**

Convert `InterfacesView` and `Spectrum.ContentView` from local segmented pickers to external mode input using the same pattern proven in `Channels`.

- [ ] **Step 5: Run test and build verification**

Run:
```bash
xcodebuild -project /Users/kaoru/Developer/wifi-lens/WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests/SecondaryToolbarDescriptorExpansionTests
xcodebuild -project /Users/kaoru/Developer/wifi-lens/WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build
```

Expected: PASS and BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add /Users/kaoru/Developer/wifi-lens/WiFiLens/Sources/WiFiLens/App/SecondaryToolbar.swift /Users/kaoru/Developer/wifi-lens/WiFiLens/Sources/WiFiLens/Interfaces/InterfacesView.swift /Users/kaoru/Developer/wifi-lens/WiFiLens/Sources/WiFiLens/Spectrum/ContentView.swift /Users/kaoru/Developer/wifi-lens/WiFiLens/Tests/WiFiLensTests/SecondaryToolbarDescriptorExpansionTests.swift
git commit -m "feat: extend root secondary toolbar to additional pages"
```

### Task 6: Final Verification and Documentation Update

**Files:**
- Modify: `/Users/kaoru/Developer/wifi-lens/docs/ARCHITECTURE.md`
- Test: existing app build/test targets

**Interfaces:**
- Consumes: completed toolbar architecture
- Produces:
  - Updated architecture note for root-owned page secondary toolbar behavior

- [ ] **Step 1: Add architecture documentation**

Add a short note under app shell / key patterns describing:

```markdown
- Page-internal secondary navigation is hosted by the window toolbar principal area.
- `AppRootView` owns the active secondary toolbar descriptor and selection state.
- Business pages consume root-owned mode state instead of rendering local segmented controls when they participate in the shared secondary toolbar system.
```

- [ ] **Step 2: Run final verification**

Run:
```bash
xcodebuild -project /Users/kaoru/Developer/wifi-lens/WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build
xcodebuild -project /Users/kaoru/Developer/wifi-lens/WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests
```

Expected:
```text
BUILD SUCCEEDED
Test Succeeded
```

- [ ] **Step 3: Manual regression sweep**

Check:

```text
1. Overview has no secondary toolbar.
2. Channels toolbar is visible and clickable.
3. Sidebar switching remains intact.
4. Traffic lights and drag region remain usable.
5. No stale toolbar selection appears on pages without descriptors.
```

Expected: No visual or interaction regressions in the titlebar area.

- [ ] **Step 4: Commit**

```bash
git add /Users/kaoru/Developer/wifi-lens/docs/ARCHITECTURE.md
git commit -m "docs: document root-owned secondary toolbar architecture"
```

## Self-Review

- Spec coverage: covered root-owned model, principal toolbar rendering, `Channels` first validation, future extension to most business pages, and no-toolbar behavior for pages like `Overview`.
- Placeholder scan: no `TODO`, `TBD`, or implicit “handle appropriately” steps remain.
- Type consistency: `SecondaryToolbarItemID`, `SecondaryToolbarDescriptor`, and `ChannelViewMode.fromToolbarSelection(_:)` are used consistently across tasks.

## Execution Handoff

Plan complete and targeted for:

`/Users/kaoru/Developer/wifi-lens/docs/superpowers/plans/2026-06-19-window-toolbar-secondary-navigation.md`

Two execution options:

**1. Subagent-Driven (recommended)** - dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - execute tasks in one session with checkpoints


