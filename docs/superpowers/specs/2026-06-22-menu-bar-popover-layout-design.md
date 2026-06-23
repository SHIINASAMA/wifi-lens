# Menu Bar Popover Layout Refinement Design

**Date:** 2026-06-22
**Status:** Approved
**Scope:** Pro/MenuBar/MenuBarStatusView.swift, Pro/MenuBar/SparklineView.swift

## Problem

The current menu bar popover has the right information but low layout efficiency. The UI feels too spacious, heavy, and visually inflated — more like an iOS widget than a compact macOS menu bar panel.

## Design Goal

Keep all existing information, but make the layout more compact, sharper, and more menu-bar-like. Higher information density, less visual fat.

## Target Layout

```
WiFi Lens                                      ⚙
┌────────────────────────────────────────────┐
│ Quality           Network                  │
│ Good              MyHome                   │
│                                            │
│ Channel           Signal                   │
│ 40                -55 dBm · Stable         │
│                                            │
│ Gateway           Updated                  │
│ 5 ms · Normal     18:17:21                 │
└────────────────────────────────────────────┘
┌────────────────────────────────────────────┐
│ Trends                                     │
│ Signal    [compact sparkline]     -55 dBm  │
│ Latency   [compact sparkline]     5 ms     │
└────────────────────────────────────────────┘
┌────────────────────────────────────────────┐
│ Recent Events                    View All  │
│ No events in the last hour                 │
└────────────────────────────────────────────┘
Refresh                              Open WiFi Lens
```

## Changes

### 1. Status Card → 2-Column Grid

**Current:** Single-column list with icons, dividers, 32px row height.

**New:** 2-column × 3-row grid, no icons, no dividers, ~28px row height.

| Label (11pt, secondary) | Value (13pt, primary) |
|---|---|
| Quality | Good |
| Network | MyHome |
| Channel | 40 |
| Signal | -55 dBm · Stable |
| Gateway | 5 ms · Normal |
| Updated | 18:17:21 |

- Remove all icons from status panel
- Remove all divider lines
- Use spacing and typography for separation
- Labels: 11–12pt Regular, secondary color
- Values: 13–14pt Medium, primary color (semantic color for status)
- Row height: ~28px
- Card padding: 12–14px

### 2. Merge Trend Cards

**Current:** Two separate full-width cards with large vertical sparklines and y-axis labels.

**New:** One shared "Trends" card with compact inline sparklines.

```
Trends
Signal    [sparkline]    -55 dBm
Latency   [sparkline]    5 ms
```

- Remove y-axis labels entirely
- Keep sparkline height: 28–32px
- Each trend row: 40–48px
- Current value displayed on right side
- Compact section title (12pt Semibold)

### 3. Compact Events Section

**Current:** Large card with generous padding, empty state centered in big blank area.

**New:** Compact section with minimal empty state.

```
Recent Events                    View All
No events in the last hour
```

- Empty state: single line, no large card
- Section height when empty: ~40–48px
- When events exist: expand naturally
- Remove divider after "Recent Events" header

### 4. Footer Actions

**Current:** Two full-width buttons, 34px height, large spacing.

**New:** Two balanced buttons, reduced height.

```
Refresh Now              Open WiFi Lens
```

- Button height: ~30px
- Keep Open WiFi Lens as primary (blue), Refresh as secondary
- Reduce visual dominance of primary button

### 5. Typography

| Element | Current | New |
|---|---|---|
| Header title | 15pt Semibold | 15pt Semibold |
| Status labels | 12pt Medium | 11pt Regular, secondary |
| Status values | 12pt Semibold | 13pt Medium |
| Trend title | 12pt Semibold | 12pt Semibold |
| Trend value | 12pt Semibold | 13pt Medium |
| Events title | 12pt Semibold | 12pt Semibold |
| Event text | 10pt | 10pt |
| Button text | 11pt Semibold | 11pt Medium |

### 6. Spacing & Dimensions

| Metric | Current | New |
|---|---|---|
| Popover width | 386 | 386 |
| Card corner radius | 10 | 8 |
| Card padding | 16 | 12 |
| Section gap | 10 | 8 |
| Status row height | 32 | 28 |
| Trend row height | ~48 | ~40 |
| Event row height | 24 | 22 |
| Footer button height | 34 | 30 |
| Outer horizontal padding | 18 | 14 |
| Bottom padding | 18 | 14 |
| Shadow radius | 30 | 20 |

### 7. Visual Weight

- Remove most internal dividers
- Reduce shadow from `radius: 30, y: 12` to `radius: 20, y: 8`
- Keep card background (`Color.white.opacity(0.72)`) and border subtle
- Remove icons from status panel entirely
- Use semantic colors only for status values, not categories

## Files to Modify

1. `Pro/MenuBar/MenuBarStatusView.swift` — main layout changes
2. `Pro/MenuBar/SparklineView.swift` — no changes needed (already compact)

## Out of Scope

- No changes to `MenuBarStatusViewModel.swift` (data layer unchanged)
- No changes to `ConnectionEvent`, `ConnectionRecord`, `EventDetector`
- No new files needed
