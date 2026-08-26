# ISSUES

## Active issues

- [x] `MCPServer.swift` — The MCP tool surface needs a documented raw-data boundary. Only `scan_networks`, `get_network_detail`, and `get_channel_occupancy` are exposed, and the provider supplies only the latest `[WiFiNetwork]` snapshot. Treat MCP as a small read-only integration surface, not a diagnostic engine: AI clients should interpret the raw facts, rank options, and produce recommendations.
  - 2026-08-26 decision: keep MCP as an add-on and do not add analytical methods such as channel recommendations, interference candidates, or security posture summaries. Preserve the three existing tools as the compatibility baseline. The only candidate addition is `get_scan_metadata`; implement it only if it can return authoritative runtime context (such as scanner availability or interface state) that cannot be derived by the AI from the network array. Do not invent timestamps, history, or capabilities.
  - Implementation plan:
    1. Audit the existing three tools and lock their request/response contracts with focused tests, including empty scans, missing networks, invalid filters, and unknown tools.
    2. Decide whether `get_scan_metadata` has enough non-derived value after checking what `ScannerViewModel` already exposes. If every useful field can be computed from `scan_networks`, close this issue without a new method.
    3. If metadata proceeds, widen the MCP provider explicitly behind a small snapshot/value type rather than passing scattered mutable app state into `MCPServer`.
    4. Update `.agents/references/project/MCP.md` to state the raw-data-only positioning and the explicit non-goals below.
    5. Verify shared-source changes with OSS + Pro Debug builds and `WiFiLensTests`.
  - Non-goals: rescan/control actions, Network Self-Check exposure, signal history or persistence, BLE data, automation, recommendations/scores/diagnoses, LAN/public/tunneled access, and any new permission or external network dependency.
  - 2026-08-26 resolution: implemented the four-tool raw-data surface and removed the old array-only provider. `get_scan_metadata` exposes only authoritative scanner/runtime facts; analytical and control surfaces remain non-goals.

- [ ] `SignalHistoryStore.swift` — Signal history limited to 20 points in memory (≈60s window at the default 3s scan interval). Deferred: blocked on Product Direction "session model" (persistence layer needed).
  - 2026-08-16 (DD-5): re-audit — `allSnapshots` is consumed by the Pro recording feature (not dead code), and `allHistory` has test-only references in the OSS tree. The earlier "no production consumers" assessment covered only OSS sources and was wrong. No cleanup performed; keep both accessors as-is. Open product question: does a session model (persistent / longer history) belong on the roadmap?

## Deferred

- `SecondaryToolbarCapsule.swift` — `NSSegmentedControl.role = .valueSelection` (macOS 27 API) is commented out until CI Xcode ships the macOS 27+ SDK. Re-enable when `Xcode_27.app` or later is available on the runner.

## Notes

- This issue list focuses on behaviour-vs-expectations gaps, state-refresh defects, and structural patterns that make completeness hard to assess.
