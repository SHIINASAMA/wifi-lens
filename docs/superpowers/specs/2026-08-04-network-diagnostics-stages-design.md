# Network Diagnostics Stage Model

## Status

Approved for implementation on 2026-08-04. Final revision incorporates the
developer review: the overall-conclusion description is corrected, the stage
type is a pure domain model, stage status is derived state, the UI is a
presentation projection, the LAN probe is named `gatewayReachability`, and the
preserved behaviors are enumerated.

## Problem

The network self-check presents five flat checks (path, dns, internet, ipv6,
proxy) without any explicit stage concept. The three measurable hops — local
environment, LAN connectivity to the router, and internet connectivity — are
not defined in the model and not visible in the UI:

- Router/gateway reachability is buried as evidence inside the path check, and
  a failed gateway ping does not produce its own status or failure state.
- The workbench table has no grouping, so it is not obvious which checks belong
  to which hop.
- There is no visual representation of the `This Mac → Router → Internet`
  chain, so a failure cannot be localized to a specific hop at a glance.

## Goals

- Introduce three first-class stages — `This Mac`, `LAN`, `Internet` — as a
  pure domain model with no UI metadata.
- Derive stage status on demand from check results via a dedicated resolver;
  the runner never stores or publishes stage state.
- Extract router reachability from the path check into a dedicated
  `GatewayReachabilityCheck` with its own status.
- Present a pipeline diagram at the top of the workbench: stations
  `This Mac / Router / Internet` and connecting rail segments `LAN / Internet`.
  Connectivity status is emphasized on the connecting lines, not only on
  stations. Group the workbench table by stage with collapsible headers and
  no per-group status badges. Both
  are presentation projections of check results and derived stage status.
- Treat the proxy check as part of the This Mac stage: it is local
  configuration and continues to participate in the overall conclusion.
- Keep the forced IPv6 probe as an optional probe listed under Additional
  Checks; it never downgrades the Internet stage and never affects the overall
  conclusion.

## Overall Conclusion

- The aggregation algorithm of `NetworkDiagnosticConclusion.evaluate` stays
  unchanged.
- The new `gatewayReachability` check participates in the existing computation:
  the required-ID set is `Set(NetworkDiagnosticCheckID.allCases)` (the view
  model passes its own `checkIDs`), and the "any non-normal result" rule
  includes it.
- A gateway-reachability `.abnormal` therefore makes the overall conclusion
  `needsAttention`. It never triggers `networkUnavailable`, which requires a
  hard path failure or an internet HTTPS connectivity error.
- `.ipv6` results are excluded from the "any non-normal result" rule: a
  skipped, failed, or indeterminate IPv6 probe never changes the overall
  conclusion and surfaces only as an attention row under Additional Checks.
- `NetworkDiagnosticConclusion.primaryIssue` gains `.gatewayReachability` in
  its priority list so a LAN failure surfaces a remediation in the conclusion
  strip. This is a presentation-correctness change, not a change to the
  aggregation algorithm.

## Non-Goals

- No new measurements beyond router reachability: no LAN DNS server probing, no
  DHCP or IP-validity validation.
- No changes to control endpoints, proxy candidate resolution, timeout
  budgets, or the network-change rerun behavior.
- No change to the overall conclusion aggregation algorithm.
- No stage state in the runner, and no UI-driven mutation of stage or runner
  state.
- No new source files: `project.pbxproj` (objectVersion 77) has no
  file-system-synchronized groups, so new types live in existing files to avoid
  build-phase churn.
- No Pro edition changes; the shared `NetworkDiagnostics/` sources compile into
  both OSS and Pro unchanged.

## Design

### Stage Domain Model

```swift
enum NetworkDiagnosticStage: CaseIterable, Equatable, Sendable {
    case thisMac
    case lan
    case internet
}
```

The stage type expresses only the three diagnostic stages. It may define its
contributing check IDs:

- `thisMac` → `[.path, .dns, .proxy]`
- `lan` → `[.gatewayReachability]`
- `internet` → `[.internet]`

The domain type carries no title, SF Symbol, color, diagram style, or table
style. All UI metadata lives in the presentation layer.

### Derived Stage Status

The runner owns only: check execution order, dependency and blocked rules,
per-check execution phases, and per-check results. It does not save, update,
or publish a separate mutable stage state.

Stage status is always computed from the current check results:

```swift
struct NetworkDiagnosticStageResolver {
    func status(
        for stage: NetworkDiagnosticStage,
        results: [NetworkDiagnosticCheckID: NetworkDiagnosticResult]
    ) -> NetworkDiagnosticStatus?
}
```

Derivation rules (multi-check stages aggregate; `lan` has a single check):

- `thisMac`: aggregated from `path`, `dns`, and `proxy` (all local configuration).
- `lan`: the status of its single contributing check.
- `internet`: the status of the `internet` check only; `dns` no longer contributes.
- Aggregation for every stage:
  - any contributing result `.abnormal` → `.abnormal`;
  - otherwise any contributing result `.indeterminate` → `.indeterminate`;
  - otherwise all contributing results `.blocked` → `.blocked`;
  - otherwise `.normal`;
  - `nil` if any contributing result is missing.

The `ipv6` result (including `.skipped`) never affects the Internet stage
status or the overall conclusion: `NetworkDiagnosticConclusion.evaluate`
excludes `.ipv6` from its non-normal rule. Running/waiting presentation is
derived by the presentation layer from the per-check execution phases; no
separate stage lifecycle state exists.

### Gateway Reachability Check

New check ID `NetworkDiagnosticCheckID.gatewayReachability` (between `.path`
and `.dns` in `allCases`) and check type `GatewayReachabilityCheck`. The ID and
type names are deliberately distinct from the `NetworkDiagnosticStage.lan`
stage: the stage is the logical diagnostic phase; the check is the concrete
probe currently executed for it.

`GatewayReachabilityCheck` reuses the existing interface source and gateway
latency provider:

- Router IP available and ping succeeds → `.normal`, evidence
  `gateway.latency-ms`.
- Router IP available and ping fails → `.abnormal`, evidence
  `gateway.unreachable` (value: router IP).
- No router IP available → `.indeterminate`, evidence `gateway.unavailable`.

The path check keeps interface, IP, subnet, router, and DNS-server evidence but
loses gateway latency. Evidence codes move from the `path.*` namespace to
`gateway.*`:

- `path.gateway-latency-ms` → `gateway.latency-ms`
- `path.gateway-unreachable` → `gateway.unreachable`
- `path.gateway-unavailable` → `gateway.unavailable`

`path.router` remains on the path check as interface detail. The check takes no
timeout parameter; the latency provider owns its own timing.

### Runner Dependencies

Execution order: `path → gatewayReachability → dns → internet → ipv6 → proxy`.

| Check | Blocked by |
|---|---|
| `gatewayReachability` | `path` hard failure (`.abnormal` / `.blocked`) |
| `dns` | `path` hard failure |
| `internet`, `ipv6` | `path`, `dns` hard failures |
| `proxy` | `path` hard failure |

A gateway-reachability `.abnormal` does **not** block downstream checks:
internet probes retain independent evidence value (for example under a VPN
where internet works without router reachability).

### Additional Checks

The forced IPv6 probe is presented under an "Additional Checks" group. Its
status feeds no stage conclusion and is excluded from the overall conclusion
entirely; it surfaces only as an attention row.

### Data Flow

```text
Check definitions
→ Runner execution and results
→ Stage status derivation
→ Pipeline and table presentation
```

The UI never mutates stage or runner state.

### UI: Pipeline Diagram

A subway-style diagram is added at the top of the workbench workspace and is
visible in idle, running, and completed states. It is a presentation
projection (`NetworkDiagnosticsPipelinePresentation` +
`NetworkDiagnosticsPipelineView`) computed from check results, execution
phases, and the stage resolver.

- Stations (nodes): `This Mac` (SF Symbol `macbook`), `Router`
  (`wifi.router`), `Internet` (`globe`).
- Rail segments (edges): `LAN` and `Internet` labels above the segments, with
  directional arrowheads toward the next station.

Connectivity status is emphasized on the edges:

| Edge state | Presentation |
|---|---|
| idle / waiting | neutral gray line and label |
| running | active edge accent-colored pulsing line; downstream waiting |
| `.normal` | solid green line, green label |
| `.abnormal` | red dashed line with a break and `xmark.circle.fill` at the gap |
| `.indeterminate` | orange dashed line with `questionmark.circle.fill` at the gap |
| `.blocked` | gray dashed line with `lock.fill` at the gap |

Only an edge with `isActive` pulses, and only when Reduce Motion is off; idle
and waiting edges are fully static. The pulse is a `SwiftUI.TimelineView`
opacity cycle driven by elapsed time, not a view-appearance toggle, so an edge
never animates before its stage starts. The SwiftUI qualifier is required
because the Pro module defines its own `TimelineView` type.

Station rings reflect endpoint status:

- `This Mac` ring shows the `thisMac` stage status.
- `Router` is the LAN endpoint: dashed and dimmed when the LAN edge is
  `.abnormal` or `.blocked`.
- `Internet` is the WAN endpoint: dashed and dimmed when the Internet edge is
  `.abnormal` or `.blocked`.

The diagram is an accessible combined element with per-station accessibility
labels.

### Table Grouping

The workbench table gains four group sections, produced by
`NetworkDiagnosticsPresentation.workbenchItems` as header/check items:

| Group | Rows |
|---|---|
| This Mac | System Path, DNS Resolution, System Proxy |
| LAN | Gateway Reachability |
| Internet | Internet Access |
| Additional Checks | Optional IPv6 |

Stage groups show only the stage title with a collapse chevron; no per-group
status badge. Groups are collapsible: after completion, groups whose rows are
all `.normal` or `.skipped` default to collapsed, while a group with any
non-normal row stays expanded; during a run every group stays expanded so the
reveal of completed and active checks is unaffected. The Additional Checks
group behaves the same. Row content, remediation, the progress strip, and the
conclusion strip stay unchanged.

### Localization

New keys, added through the i18n-completer scripts with manual extraction
state and `en` / `zh-Hans` / `ja` values (`de` / `es` fall back to `en`):

| Key | en | zh-Hans | ja |
|---|---|---|---|
| `network_diagnostics.stage.this_mac.title` | This Mac | 本机环境 | このMac |
| `network_diagnostics.stage.lan.title` | LAN | 局域网连通性 | LAN |
| `network_diagnostics.stage.internet.title` | Internet | 互联网 | インターネット |
| `network_diagnostics.stage.additional.title` | Additional Checks | 附加检测 | 追加チェック |
| `network_diagnostics.check.gateway_reachability.title` | Gateway Reachability | 网关可达性 | ゲートウェイ到達性 |
| `network_diagnostics.diagram.router.title` | Router | 路由器 | ルーター |
| `network_diagnostics.gateway.normal.summary` | Gateway reachable | 网关可达 | ゲートウェイに到達 |
| `network_diagnostics.gateway.abnormal.summary` | Gateway unreachable | 网关不可达 | ゲートウェイに到達できません |
| `network_diagnostics.gateway.indeterminate.summary` | Gateway reachability unknown | 网关状态未知 | ゲートウェイ到達性不明 |

### Documentation

Update `.agents/references/project/ARCHITECTURE.md`:

- The table row for `NetworkDiagnostics/` gains the three-stage model and the
  gateway reachability check.
- The manual diagnostics paragraph describes six checks, three stages, derived
  stage status, the grouped workbench, and the pipeline diagram.

## Error Handling

- Gateway-reachability `.indeterminate` (no router IP) never blocks downstream
  checks.
- Gateway-reachability `.blocked` follows the runner dependency rule for `path`
  hard failures.
- Edge and station presentation maps every status a stage can reach; no status
  renders as an unhandled default.

## Test Strategy

1. Check-ID order: `[.path, .gatewayReachability, .dns, .internet, .ipv6,
   .proxy]`.
2. Gateway check: ping success, ping failure, missing router IP; the path
   check keeps interface evidence and produces no `gateway.*` codes.
3. Runner: path abnormal blocks `gatewayReachability`; `gatewayReachability`
   abnormal does not block `dns`; overall conclusion becomes `needsAttention`
   and `primaryIssue` names `gatewayReachability`.
4. Stage resolver: `thisMac` aggregates `path`, `dns`, and `proxy`; `lan`
   passthrough; `internet` follows the `internet` check and ignores `dns`
   and `ipv6`, including `indeterminate`, all-`blocked`, and missing
   results; overall-conclusion exclusion of `.ipv6`.
5. Presentation: `workbenchItems` grouping; pipeline station/edge mapping for
   `.normal`, `.abnormal`, `.indeterminate`, `.blocked`, unreachable stations,
   and active edges.
6. Verification: canonical OSS Debug build, Pro Debug build, `WiFiLensTests`
   suite, then the public knowledge-boundary scan and integrity check.

## Manual Validation Matrix

- Normal home Wi-Fi: all stages green, diagram fully green.
- Router unreachable: LAN edge red with break, Router station unreachable,
  downstream checks still run.
- No network path: This Mac abnormal, LAN and downstream blocked.
- IPv6 disabled: Additional Checks shows the IPv6 row skipped; stages and
  overall conclusion unaffected.
- Proxy configured: System Proxy row under This Mac shows the route; an
  abnormal proxy marks This Mac and the overall conclusion.
- DNS failure: DNS Resolution row under This Mac shows the failure; This Mac
  and the overall conclusion reflect it.
- Compact window width: diagram and grouped table remain usable.

## Integration

Single root-repository change with no new source files and no
`project.pbxproj` edits. The shared `NetworkDiagnostics/` sources compile into
both OSS and Pro. Verify during implementation that no Pro submodule copy of
these files exists before finalizing the change set.
