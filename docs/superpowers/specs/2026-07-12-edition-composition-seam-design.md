# OSS / Pro Edition Composition Seam Design

## Status

Approved for planning. Phase 1 is strictly behavior-preserving.

## Goal

Centralize OSS and Pro edition composition behind target-selected adapters so the shared application shell owns only product routes and upsell descriptors, while Pro implementation knowledge and lifecycle ownership remain in the Pro target.

## Non-Goals

- Change no user-visible route, label, menu item, settings row, toolbar item, lock state, persistence behavior, or event behavior.
- Change no event-journal, recording, session, Timeline, Menu Bar, or SQLite domain semantics.
- Introduce no runtime plug-in registry, dependency-injection container, or cross-edition dynamic dispatch.
- Move the shared `SidebarPage.timeline` route or its locked upsell presentation out of OSS.

## Current Problem

The commercial boundary is already correct: Pro event, Timeline, menu bar, recording, session, and SQLite implementation files are not members of OSS Sources. However, the shared application root has compile-time knowledge of Pro types and state, including `TimelineNavigationRequest`, `EventFilterType`, `ProObservationEventBootstrap`, Timeline range/search/inspector state, recording state, menu-bar event handling, and Timeline-specific toolbar construction. `SettingsView` also invokes the Pro bootstrap directly.

This leaves edition selection distributed between `WiFiLensApp.swift`, `SettingsView.swift`, `SecondaryToolbar.swift`, `SidebarView.swift`, and feature views. Adding a new paid feature requires editing several shared surfaces and manually preserving target membership boundaries.

## Chosen Architecture

Use a compile-time `EditionComposition` façade.

The shared app shell calls only façade operations expressed in shared product concepts. The OSS and Pro targets compile different source files that define the same façade API. Each target therefore receives exactly one concrete edition implementation without runtime registration.

```text
Shared app shell
  owns: SidebarPage routes, common pages, locked/upsell descriptors,
        window restoration, common toolbar selections
  calls: EditionComposition

OSS EditionComposition
  owns: locked/preview contribution and no-op lifecycle contribution

Pro EditionComposition
  owns: Timeline composition state, Timeline toolbar contribution,
        recording/session composition, event-journal lifecycle,
        menu-bar event routing, settings contribution, commands
```

### Why Not a Runtime Protocol

A protocol that returns arbitrary SwiftUI views would require pervasive `AnyView` or associated-type plumbing. That would weaken static target-boundary auditing and spread type erasure through the common shell. The façade uses type erasure, if required, only at the narrow Scene/View boundary where target-specific SwiftUI view types enter the shared shell.

### Façade Contract

The shared contract must use only shared types:

- `SidebarPage` for product-level routing.
- `SecondaryToolbarItemID` and `SecondaryToolbarDescriptor` for shared toolbar mechanics.
- Shared callbacks for opening a main window, Settings, or a product route.
- Shared scanner, BLE, and window dependencies already owned by the shell.

The contract must not name `EventFilterType`, `TimelineNavigationRequest`, `TimelineViewModel`, `WiFiObservationEventJournal`, `ProObservationEventBootstrap`, `RecordingViewModel`, SQLite stores, or any other Pro-only domain type.

## Ownership by Surface

### Shared Shell

The shared shell retains:

- `WiFiLensApp` scene routing and main-window restoration.
- `SidebarPage`, including `.timeline`, and the OSS Timeline upsell/locked route.
- Shared common-page rendering, permission gates, Wi-Fi availability gates, Sidebar, and common settings content.
- Shared toolbar primitives and common channel/interface selections.
- Product-level callbacks for open-main-window, open-settings, and navigate-to-page.

It must no longer retain Pro Timeline filters, Timeline navigation requests, Timeline search/inspector state, recording state, or direct bootstrap calls.

### Pro Composition

The Pro implementation owns:

- Timeline content assembly and its range, search, filter, inspector, and selected-event navigation state.
- Timeline toolbar descriptors and bindings.
- Spectrum recording/session assembly.
- `ProObservationEventBootstrap.start(observationRuntime:)` lifecycle registration.
- Menu-bar scene construction and event-ID-to-Timeline navigation handling.
- Pro-only settings rows, including menu-bar enablement and clear Timeline data.
- Pro command contributions that require Timeline/event knowledge.

### OSS Composition

The OSS implementation owns:

- Locked Timeline and recording preview contributions already presented to OSS users.
- No-op implementations for Pro lifecycle and command extensions.

The OSS adapter must not import or reference Pro symbols. It may use shared upsell descriptors and shared route callbacks only.

## Data and Lifecycle Flow

1. The shared root restores or selects a `SidebarPage`.
2. For an edition-owned page or surface, it asks `EditionComposition` for the matching contribution.
3. The OSS adapter supplies the existing locked/preview behavior.
4. The Pro adapter supplies the real Timeline, recording/session, settings, command, and menu-bar contributions.
5. On app activation, the shared root invokes one edition lifecycle entry point. Only the Pro adapter starts the observation-event journal; OSS performs no event lifecycle work.
6. A menu-bar event selection remains internal to the Pro adapter until it resolves to the shared `.timeline` route. Event ID state never crosses into the shared root.

## Target Membership Rules

- The shared façade declaration and shared shell are members of both app targets.
- `OSSEditionComposition.swift` is a WiFiLens/OSS source only.
- `ProEditionComposition.swift` and any Pro composition helpers are WiFiLensPro sources only.
- Pro composition helpers may import and construct Pro Timeline, event-journal, Menu Bar, recording/session, and SQLite-facing types.
- No Pro source file is added to the OSS Sources build phase.
- The project file must make the two edition implementation memberships mechanically auditable.

## Behavior-Preservation Contract

The following must remain identical before and after Phase 1:

- Sidebar page availability, labels, icons, ordering, and locked Timeline presentation in OSS.
- Pro Timeline route behavior, range defaults, search, inspector, filters, and navigation from menu-bar events.
- Spectrum recording selection and session behavior in Pro; recording lock behavior in OSS.
- Settings sections, controls, clear-data action, menu-bar enablement, and command behavior.
- Event journal startup timing and idempotence.
- Window routing, restoration, keyboard commands, and Menu Bar actions.

## Error Handling

The refactor adds no new user-facing error paths. Existing errors remain owned by the same domain modules:

- Timeline and journal errors stay within Pro event infrastructure.
- Clear-data errors remain surfaced by the existing Pro settings behavior.
- OSS lifecycle remains a no-op and must not synthesize journal or persistence state.

## Tests and Acceptance Evidence

Add focused tests that prove:

- The shared shell can compile and exercise its route/upsell contract without importing Pro types.
- The OSS adapter preserves the locked Timeline and recording-preview behavior.
- The Pro adapter preserves Timeline toolbar defaults and menu-bar event navigation behavior.
- The Pro lifecycle adapter starts the shared journal exactly once for a runtime.
- The settings contribution still exposes Pro menu-bar and clear-Timeline controls, while OSS retains previews.
- `project.pbxproj` contains one OSS adapter membership in OSS Sources and one Pro adapter membership in Pro Sources, with neither adapter present in the wrong target.

Run the OSS and Pro unit targets separately, both Debug builds, PBX lint, production-symbol deletion searches from the shared root, and root/Pro diff checks. Do not run UI test bundles unless explicitly requested.

## Deletion Test

After the refactor, deleting direct uses of `EventFilterType`, `TimelineNavigationRequest`, `ProObservationEventBootstrap`, and other Pro implementation symbols from the shared app root must leave both editions fully composed through their adapters. `SidebarPage.timeline` remains because OSS needs a legal upsell route.

## Risks and Mitigations

| Risk | Mitigation |
| --- | --- |
| SwiftUI opaque view types make the façade leak implementation types | Limit type erasure to a single façade boundary; keep domain-specific state in target-only wrapper views. |
| A large façade becomes a new god object | Split Pro internals by surface: main content, settings, commands, lifecycle, and menu bar; expose only the minimal façade. |
| Target membership accidentally exposes Pro code to OSS | Add PBX membership assertions and run both target builds on every acceptance pass. |
| Refactoring changes lifecycle ordering | Characterize and retain existing journal start/idempotence tests before moving ownership. |

## Rollout

Phase 1 is one behavior-preserving composition refactor. New paid features must use the established façade after this phase; they should not add direct Pro domain references to the shared root.
