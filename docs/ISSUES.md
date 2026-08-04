# ISSUES

## Active issues

- [ ] `SignalHistoryStore.swift` — Signal history limited to 20 points in memory. Deferred: blocked on Product Direction "session model" (persistence layer needed).

## Deferred

- `SecondaryToolbarCapsule.swift` — `NSSegmentedControl.role = .valueSelection` (macOS 27 API) is commented out until CI Xcode ships the macOS 27+ SDK. Re-enable when `Xcode_27.app` or later is available on the runner.

## Notes

- This issue list focuses on behaviour-vs-expectations gaps, state-refresh defects, and structural patterns that make completeness hard to assess.
