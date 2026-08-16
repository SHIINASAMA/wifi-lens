# ISSUES

## Active issues

- [ ] `SignalHistoryStore.swift` — Signal history limited to 20 points in memory (≈60s window at the default 3s scan interval). Deferred: blocked on Product Direction "session model" (persistence layer needed).
  - 2026-08-16 (DD-5): re-audit — `allSnapshots` is consumed by the Pro recording feature (not dead code), and `allHistory` has test-only references in the OSS tree. The earlier "no production consumers" assessment covered only OSS sources and was wrong. No cleanup performed; keep both accessors as-is. Open product question: does a session model (persistent / longer history) belong on the roadmap?

## Deferred

- `SecondaryToolbarCapsule.swift` — `NSSegmentedControl.role = .valueSelection` (macOS 27 API) is commented out until CI Xcode ships the macOS 27+ SDK. Re-enable when `Xcode_27.app` or later is available on the runner.

## Notes

- This issue list focuses on behaviour-vs-expectations gaps, state-refresh defects, and structural patterns that make completeness hard to assess.
