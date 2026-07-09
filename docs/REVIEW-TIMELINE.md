# Timeline Feature — PM Review

> Review date: 2026-07-08
> Reviewer perspective: Product Manager
> Feature scope: Event Timeline (Pro-only)

---

## Current State

### Implemented Features

| Category | Feature |
|----------|---------|
| **Data** | 6 event types: roaming, channel change, signal drop, latency spike, disconnection, reconnection |
| **Display** | Hourly-grouped event list with timestamp, icon, badge, color coding |
| **Filtering** | Date range (All/Today/Yesterday/This Week) + text search |
| **Persistence** | SQLite storage (max 500 events) + in-memory cache (recent 50) |
| **Menu Bar** | Real-time event display + "View All" navigation |
| **Pro Gating** | Full feature Pro-only; OSS shows skeleton preview |
| **Localization** | UI frame translated (en/ja/zh-Hans/de/es) |

---

## Gap Analysis

### P0 — Core Experience Gaps

| # | Issue | Description |
|---|-------|-------------|
| 1 | **Event titles not localized** | `TimelineViewModel` hardcodes all 6 event title/subtitle strings in English (e.g. "Roamed between access points"). Localization keys exist but are unused. |
| 2 | **No event detail view** | Tapping an event row does not expand to show full context — preceding/following signal changes, associated BSSID, duration, etc. |
| 3 | **No custom date range picker** | Only preset ranges (Today/Yesterday/This Week). Users cannot select a specific date interval for investigation. |

### P1 — Feature Completeness

| # | Issue | Description |
|---|-------|-------------|
| 4 | **No export capability** | Cannot export event list as CSV/JSON/PDF. Critical for troubleshooting workflows. |
| 5 | **No event statistics summary** | Missing aggregate view — e.g. "12 roams this week / 3 disconnections". |
| 6 | **No context menu** | Cannot right-click an event to copy, export, or annotate. |
| 7 | **Weak empty state** | Empty list only shows "No Events" text. No action guidance (e.g. "Start scanning to record events"). |
| 8 | **No loading state** | No skeleton/indicator during initial SQLite data load. |

### P2 — Experience Polish

| # | Issue | Description |
|---|-------|-------------|
| 9 | **No hover state** | Event rows have no hover highlight — weak interactive feedback. |
| 10 | **No event notifications** | Important events (disconnection, roaming) have no system notification push. |
| 11 | **No favorites/bookmarks** | Cannot mark important events for later review. |
| 12 | **No event correlation** | Disconnect → Reconnect should be visually linked; currently displayed as independent rows. |
| 13 | **Filter state not persisted** | Filter resets to "Today" on every page open; no memory of last selection. |
| 14 | **No history cleanup** | No manual purge of old events; SQLite has no auto-expiration. |
| 15 | **No share functionality** | Cannot share a single event or event summary with others. |

---

## Recommended Roadmap

```
Current status: MVP usable, but lacks key interactions and data utilization.

Suggested sprints:
  Sprint 1: P0-1 Event localization + P0-2 Event detail view
  Sprint 2: P1-4 Export + P1-5 Statistics summary
  Sprint 3: P1-6 Context menu + P2-9 Hover states + P2-12 Event correlation
  Later:    Notifications, favorites, custom date range
```

---

## File Inventory

| Path | Role |
|------|------|
| `Pro/Timeline/TimelineView.swift` | Main view, list, row, section layout |
| `Pro/Timeline/TimelineViewModel.swift` | ViewModel, filter/search, event presentation mapping |
| `Pro/Events/WiFiObservationEvent.swift` | Event model, recorder, protocols |
| `Pro/Events/WiFiObservationEventCoordinator.swift` | Orchestration: observation → detection → persistence |
| `Pro/Events/WiFiObservationEventSQLiteStore.swift` | SQLite persistence |
| `Pro/Events/WiFiObservationEventRecentStore.swift` | In-memory recent events |
| `Pro/Events/RoamingEventDetector.swift` | Event detection logic |
| `WiFiLens/Sources/WiFiLens/App/SidebarView.swift` | Sidebar integration |
| `WiFiLens/Sources/WiFiLens/App/SecondaryToolbar.swift` | Filter toolbar |
