# ISSUES

## High Priority

- [x] `WiFiLens/Sources/WiFiLens/Views/ContentView.swift:293-300` — The AP count in the table section header uses `viewModel.combinedTableRows.count`, which ignores band toggles and the hidden-SSID filter, so the header subtitle drifts out of sync with the rows actually shown.
- [x] `WiFiLens/Sources/WiFiLens/Views/NativeTableView.swift:86-95` — The table reloads only when row IDs or `isVisible` changes. When scan data updates SSID, RSSI, security, or quality score without changing the ID set, rows are not refreshed and stale values remain on screen.
- [x] `WiFiLens/Sources/WiFiLens/Services/MCPServer.swift:169-175` — The HTTP response header line separator uses bare `\r` instead of `\r\n`, making the server non-conformant. ~~Not a bug: Swift multiline string appends implicit `\n` after each `\r`, producing valid `\r\n`.~~

## Medium Priority

- [ ] `WiFiLens/Sources/WiFiLens/Views/OverviewView.swift:3-13` — Overview is still a placeholder, yet it is the default landing page in the sidebar. The information architecture is already wired up, but the page contributes no value.
- [ ] `WiFiLens/Sources/WiFiLens/Views/ContentView.swift:332-357` — The empty-state `switch` includes a `.scanning` branch that is unreachable because `shouldShowEmptyState` never returns `true` while scanning. It is dead code and a maintenance trap.
- [ ] `WiFiLens/Sources/WiFiLens/Views/BandChartView.swift:252-274` — The current "zoom" is a drag-to-marquee gesture, not scroll-wheel zoom as the TODO describes. The mismatch can cause progress tracking mistakes.
- [ ] `WiFiLens/Sources/WiFiLens/Services/SignalHistoryStore.swift:14-16` — Signal history is limited to the 20 most recent points in memory. TrendChart already consumes it, but the TODO item "Persistent scan history / session recording" remains unchecked for good reason since there is no persistence layer yet.
- [ ] `WiFiLens/Sources/WiFiLens/WiFiLensApp.swift:217-223` and `WiFiLens/Sources/WiFiLens/Views/ExportMenuView.swift:44-50` — CSV export still emits only `channel,rssi,ssid,bssid`. The TODO asks for timestamp, band, PHY mode, channel width, capabilities, and hidden-SSID flag; none of those are present.

## Low Priority

- [ ] `WiFiLens/Sources/WiFiLens/Views/ContentView.swift:198-206` — The table filter derives a band ID from the localized `bandLabel` string. If the label text changes in the future (e.g., a different locale or wording tweak), this mapping silently breaks. The row model should carry a raw band ID instead.
- [x] `WiFiLens/Sources/WiFiLens/Views/NativeTableView.swift:25` — `.uniformColumnAutoresizingStyle` distributes column widths evenly, exacerbating the existing column-width complaints. ~~Fixed: changed to `.noColumnAutoresizing` alongside auto-width implementation.~~
- [ ] `WiFiLens/Sources/WiFiLens/Services/CrashReporter.swift:33` — Crash log writes use `.atomic` and overwrite the single `crash.log` file each time, keeping only the most recent crash. When back-to-back crashes occur during debug, earlier traces are lost and regression investigation becomes harder.

## Notes

- The following TODO items were confirmed as having real implementations and have been checked off: drag-to-zoom on charts, dark-mode colour verification, and the signal-history trend line.
- This issue list focuses on behaviour-vs-expectations gaps, state-refresh defects, and structural patterns that make completeness hard to assess.