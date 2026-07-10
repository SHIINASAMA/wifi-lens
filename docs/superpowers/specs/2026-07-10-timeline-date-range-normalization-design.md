# Timeline Custom Date-Range Inversion Normalization

- **Date:** 2026-07-10
- **Status:** Superseded in part by the unified timeline consistency design
- **Issue:** P2 #1
- **Target:** `Pro` submodule (`Pro/Timeline/TimelineViewModel.swift`, `Pro/Timeline/TimelineView.swift`)
- **Approach:** A — Minimal targeted fix (ViewModel silent normalization + write-back to binding)

## Problem

The timeline filter supports a custom date range. When the end date is earlier than the
start date (an inverted range), the behavior is inconsistent and can break filtering.

### Verification findings

1. **Filter panel shows dates inconsistent with actual filtering.**
   `TimelineViewModel.prepare()` normalizes the inverted range internally:

   ```swift
   // TimelineViewModel.swift:151
   self.customEndDate = max(customStartDate, customEndDate)
   ```

   `TimelineView` passes the root-view `@Binding` values into `prepare()` on `.onAppear`
   (`TimelineView.swift:59-65`). The ViewModel stores the corrected value in its own
   `@Published` properties, but the ViewModel does **not** hold the bindings and cannot
   write back. `TimelineFilterPanel` (wired in `WiFiLensApp.swift:268-273`) binds to the
   *same* `$customStartDate`/`$customEndDate` as `TimelineView`, so the panel keeps showing
   the inverted (uncorrected) dates while `applyFilters()` filters using the normalized
   values.

2. **Manually inverting the range via the panel empties the timeline.**
   `TimelineView`'s `.onChange(of: customStartDate/customEndDate)` handlers
   (`TimelineView.swift:73-81`) only assign `viewModel.customStartDate/customEndDate = newValue`
   without normalizing. If the user picks an end date earlier than the start date, the
   ViewModel receives an inverted range and `matchesDateFilter` (`.custom` case,
   `TimelineViewModel.swift:236-241`) evaluates `timestamp >= start && timestamp < end` with
   `start > end`, which is never true — the timeline shows nothing.

### Root cause

`TimelineView`'s `@Binding` and `TimelineViewModel`'s `@Published` each hold an independent
copy of the date range. Normalization exists only on the `prepare()` path, so:
- the corrected value never propagates back to the bindings (panel inconsistency), and
- the `.onChange` path never normalizes (manual inversion breaks filtering).

## Design

### §1 Normalization point — `TimelineViewModel.swift`

Promote normalization from the single `prepare()` path to the `customStartDate` /
`customEndDate` setters, so every mutation entry (prepare / panel `.onChange` / deep-link)
is normalized.

- Extract a pure helper:

  ```swift
  static func normalizeCustomRange(_ start: Date, _ end: Date) -> (start: Date, end: Date) {
      // end is clamped up to start; invariant: end >= start
      (start, max(start, end))
  }
  ```

- `customEndDate` `didSet`:

  ```swift
  self.customEndDate = Self.normalizeCustomRange(customStartDate, customEndDate).end
  ```

- `customStartDate` `didSet`: if `customStartDate > customEndDate`, clamp
  `customEndDate = customStartDate` (maintains `end >= start`).

- Both setters still call `applyFilters()` so filtering always runs on normalized values.

- `prepare()` assigns the two properties directly; normalization is delegated to the
  setters (logic converges to one place).

> Swift's `didSet` does not recursively fire for an assignment to the *same* property made
> inside its own `didSet`. When `customStartDate`'s `didSet` mutates `customEndDate`, that
> triggers `customEndDate`'s `didSet`, but at that point `end == start`, so normalization is
> a no-op and no infinite loop occurs.

### §2 Write-back and loop guard — `TimelineView.swift` (superseded)

> This section described the first implementation. The lifecycle-dependent
> `onReceive` reverse synchronization is superseded by the explicit
> binding-to-normalization-to-view-model flow in
> `2026-07-10-pro-unified-event-timeline-design.md`.

`TimelineView` now treats the app-root bindings as the source of truth. On
appearance and on every later endpoint change, it normalizes the binding pair,
writes back only a corrected endpoint, and then prepares the view model from
that normalized pair. There is no reverse subscription to the view model's
initial `@Published` values.

### §3 Data flow

```
panel edits binding ──▶ normalize binding pair ──▶ write corrected endpoint
                                                  │
                                                  └──▶ prepare ViewModel

TimelineView appears ──▶ read retained bindings ──▶ normalize ──▶ prepare ViewModel
```

The deep-link path (`resolveNavigationRequest` → `prepare`) flows through the same path, so
normalization applies automatically.

### §4 Testing

- **New pure-function unit test** `normalizeCustomRange`:
  - inverted range → `end` clamped to `start`;
  - already-ordered range → unchanged;
  - equal range → equal.
- **New ViewModel setter unit test**: assign `viewModel.customEndDate` to a value earlier than
  `customStartDate`; assert `customEndDate == customStartDate` (covers the "manual inversion
  empties the timeline" bug at the logic layer). Reverse case: assign `customStartDate` later
  than `customEndDate`; assert `customEndDate` is clamped up.
- The binding synchronization is exposed through a deterministic helper so its
  retained-date and inverted-range behavior can be unit tested without a UI
  test bundle.

### §5 Boundaries / error handling

- Equality guards on binding writes prevent feedback loops; normalization never
  produces a `nil` or empty range.
- `TimelineFilterPanel` interaction is unchanged (per the chosen "ViewModel silent
  normalization" behavior).

## Out of scope

- P2 #2: missing interaction and race tests for menu-bar UUID → timeline scroll/expand.
- Architectural unification of bindings as the single source of truth (Approach C) — explicitly
  deferred; this fix is targeted at the two reported symptoms.
- P1 items (already committed; P1 #3 verified closed).
