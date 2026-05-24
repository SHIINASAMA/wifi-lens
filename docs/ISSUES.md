# ISSUES

## High Priority

- [x] `WiFiLens/Sources/WiFiLens/Views/ContentView.swift:293-300` — The AP count in the table section header uses `viewModel.combinedTableRows.count`, which ignores band toggles and the hidden-SSID filter, so the header subtitle drifts out of sync with the rows actually shown.
- [x] `WiFiLens/Sources/WiFiLens/Views/NativeTableView.swift:86-95` — The table reloads only when row IDs or `isVisible` changes. When scan data updates SSID, RSSI, security, or quality score without changing the ID set, rows are not refreshed and stale values remain on screen.
- [x] `WiFiLens/Sources/WiFiLens/Services/MCPServer.swift:169-175` — The HTTP response header line separator uses bare `\r` instead of `\r\n`, making the server non-conformant. ~~Not a bug: Swift multiline string appends implicit `\n` after each `\r`, producing valid `\r\n`.~~

## Medium Priority

- [x] `OverviewView.swift` — Overview is still a placeholder. The sidebar entry is commented out so it is unreachable. Fixed: Overview is now the default landing page with a full dashboard (connection card, diagnostics, channel advice, environment summary).
- [x] `ContentView.swift` empty-state — The switch included unreachable `.scanning` and `.grantedButSSIDUnavailable` cases. Fixed: replaced with `default: EmptyView()`.
- [x] `BandChartView.swift` zoom — The TODO item said "scroll-to-zoom" but the implementation is drag-to-marquee. Fixed: renamed TODO item to "Drag-to-zoom on charts".
- [ ] `SignalHistoryStore.swift` — Signal history limited to 20 points in memory. Deferred: blocked on Product Direction "session model" (persistence layer needed).
- [x] `WiFiLensApp.swift` CSV export — Added timestamp, band, phy_mode, channel_width, k, r, v, hidden_ssid. Removed dead ExportMenuView.swift.

## Low Priority

- [x] `ContentView.swift` band filter — The table filter derived a band ID from the localized `bandLabel` string, which would silently break on locale changes. Fixed: added raw `bandID` field to `NetworkTableRow`.
- [x] `NativeTableView.swift` — `.uniformColumnAutoresizingStyle` distributes column widths evenly. Fixed: changed to `.noColumnAutoresizing` alongside auto-width implementation.
- [x] `CrashReporter.swift` — Crash log writes used `.atomic` overwrite on a single `crash.log` file, losing earlier traces in back-to-back crashes. Fixed: each crash now writes to a timestamped file (`crash-2026-05-21T12-34-56Z.log`); `consumeCrashLog()` enumerates all.

## Notes

- The following TODO items were confirmed as having real implementations and have been checked off: drag-to-zoom on charts, dark-mode colour verification, and the signal-history trend line.
- This issue list focuses on behaviour-vs-expectations gaps, state-refresh defects, and structural patterns that make completeness hard to assess.