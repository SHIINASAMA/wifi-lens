# Network Self-Check Preview Design

**Date:** 2026-07-14
**Status:** Implemented with full-width diagnostic workbench revision

## Goal

Add a user-triggered Network Self-Check page that helps users decide whether the Mac has working network connectivity and whether DNS or system proxy settings need attention.

The feature ships in both the OSS and Pro editions. It must work without Wi-Fi or Location Services because a Mac may reach the network through Ethernet or another interface.

## Scope

The preview runs three checks:

1. Network connectivity through `NWPathMonitor`.
2. DNS resolution of `example.com`.
3. System HTTP, HTTPS, SOCKS, PAC, and automatic proxy discovery configuration.

Each completed check returns one of these statuses:

- Normal
- Abnormal
- Indeterminate

The page produces one overall conclusion:

- Network Normal
- Needs Attention
- Network Unavailable

The preview excludes automatic repair, ping, traceroute, VPN software identification, captive portal detection, network scoring, DoH or DoT identification, and user-defined remote hosts.

## Product Placement

Add Network Self-Check to the shared Tools sidebar section in this order:

1. Spectrum
2. Channels
3. Interfaces
4. Network Self-Check
5. Roaming Test
6. Bluetooth Scanner

The route sets `requiresLocationAuthorization` and `requiresWiFi` to `false`. Both editions expose the same unlocked page. The feature does not use `EditionComposition` and contains no source dependency on the Pro submodule.

## Architecture

Place the implementation in `WiFiLens/Sources/WiFiLens/NetworkDiagnostics/` and add each source file to both the OSS and Pro targets.

Keep this domain separate from the existing observation `DiagnosticResult`. That type describes Wi-Fi signal, security, and channel quality. The new domain uses `NetworkDiagnosticResult` to avoid conflating the two meanings.

### Result Model

`NetworkDiagnosticStatus` has three cases:

```swift
enum NetworkDiagnosticStatus: Sendable {
    case normal
    case abnormal
    case indeterminate
}
```

`NetworkDiagnosticResult` contains:

- The stable check identifier.
- A `NetworkDiagnosticStatus`.
- A localized summary suitable for the check card.
- An optional localized detail.

The result model does not expose raw system proxy dictionaries, resolver implementation details, or platform error codes to the view.

### Check Protocol

Every check implements the shared interface:

```swift
protocol DiagnosticCheck {
    func run() async -> NetworkDiagnosticResult
}
```

Concrete checks own one responsibility each:

- `NetworkConnectivityCheck`
- `DNSResolutionCheck`
- `SystemProxyCheck`

System API access sits behind injected adapters so unit tests can supply deterministic path, resolver, proxy-setting, and TCP-connection behavior.

### Runner

`DiagnosticRunner` accepts an ordered collection of `DiagnosticCheck` values and runs them one at a time. The production order is connectivity, DNS, then proxy. Its run method uses this contract:

```swift
func run(
    onResult: @escaping @Sendable (NetworkDiagnosticResult) async -> Void
) async -> [NetworkDiagnosticResult]
```

The runner calls `onResult` after each check and returns the ordered final results. The page can update one card at a time without coupling the checks to SwiftUI.

The runner prevents one invocation from executing a check more than once. The view model prevents overlapping user-initiated runs.

For the user-facing run, each top-level check remains visibly active for at least 0.8 seconds. The minimum applies per check, not as a single delay after all work finishes. If a real check takes longer than 0.8 seconds, its result appears immediately when the check completes. This pacing belongs to the ordered execution layer so the next item does not appear active before the preceding result is presented. Tests use zero pacing unless they explicitly verify the minimum-duration behavior.

### Page State

`NetworkDiagnosticsViewModel` runs on the main actor and owns:

- The page phase: idle, running, or completed.
- The execution phase for each check: waiting, running, or completed.
- Completed `NetworkDiagnosticResult` values.
- The final overall conclusion.
- The active task so window teardown can cancel it.

Waiting and running are execution phases, not diagnostic statuses. A completed check still uses only Normal, Abnormal, or Indeterminate.

Starting a new run clears the previous conclusion and resets all three execution phases. The model disables the run button until the current run finishes or cancels.

## Check Semantics

### Network Connectivity

Create an `NWPathMonitor`, start it on a private queue, and wait for its first path update.

Map the path status as follows:

| Path outcome | Status |
|---|---|
| `satisfied` | Normal |
| `unsatisfied` | Abnormal |
| `requiresConnection` | Indeterminate |
| No initial update within 3 seconds | Indeterminate |
| Cancellation or unclassified system failure | Indeterminate |

The check cancels its monitor after receiving a result or reaching the timeout.

### DNS Resolution

Resolve `example.com` through the system resolver. The implementation checks DNS resolution only and must not require a successful HTTP response from that host.

| Resolver outcome | Status |
|---|---|
| At least one resolved address | Normal |
| Explicit resolution failure | Abnormal |
| No result within 5 seconds | Indeterminate |
| Cancellation or unclassified system failure | Indeterminate |

The abnormal message states that DNS configuration or service may have a problem. When the Mac has no network path, the page may also show network connectivity as abnormal; the overall conclusion still prioritizes Network Unavailable.

### System Proxy

Read the current system proxy dictionary through the platform CFNetwork or SystemConfiguration API. Parse these settings:

- HTTP enable flag, host, and port
- HTTPS enable flag, host, and port
- SOCKS enable flag, host, and port
- PAC enable flag and URL
- Automatic proxy discovery flag

Deduplicate explicit proxy endpoints by normalized host and port. Attempt a TCP connection to each unique endpoint with a 3-second per-endpoint timeout. The proxy check may test independent endpoints concurrently while `DiagnosticRunner` continues to serialize the three top-level checks.

Apply these rules in priority order:

1. An enabled explicit proxy with a missing or invalid host or port produces Indeterminate unless another explicit endpoint has already failed.
2. Any explicit endpoint that cannot accept a TCP connection produces Abnormal.
3. PAC or automatic discovery enabled without an explicit failure produces Indeterminate because the preview does not download, execute, or evaluate proxy scripts.
4. If all enabled explicit endpoints accept connections and neither PAC nor automatic discovery is enabled, the check produces Normal.
5. No proxy mechanism enabled produces Normal with the summary "System proxy is not enabled."
6. An unreadable or unclassifiable system proxy configuration produces Indeterminate.

The check confirms only endpoint reachability. It does not authenticate with a proxy or make a proxied web request.

## Overall Conclusion

Aggregate completed results with this precedence:

| Results | Conclusion |
|---|---|
| Network connectivity is Abnormal | Network Unavailable |
| Connectivity is not Abnormal and any check is Abnormal | Needs Attention |
| No check is Abnormal and any check is Indeterminate | Needs Attention |
| All three checks are Normal | Network Normal |

The view model produces no overall conclusion while a run is incomplete or cancelled.

## User Interface

`NetworkDiagnosticsView` uses a full-width desktop diagnostic workbench. It has no control rail, page-level maximum width, fixed workspace height, vertical centering, oversized empty-state illustration, result-card list, or detail dialog.

The workbench has three persistent regions:

- A compact full-width command bar containing the feature description, current state, and Run or Run Again action.
- An optional full-width progress or conclusion strip immediately below the command bar.
- A native result table that consumes the remaining page width and height and owns vertical scrolling.

### Idle

The command bar contains the short explanation and primary Run Diagnostics button. The table region shows a compact top-aligned empty message but no placeholder check rows.

### Running

The progress strip shows the active check, completed count, and a linear progress indicator. The table reveals completed rows plus the active row in execution order; future checks remain hidden. The active row displays Checking. The per-check 0.8-second minimum keeps each active name perceptible without adding a final artificial delay.

### Completed

The progress strip becomes a compact conclusion strip with the overall title and explanation. The table shows every completed result in execution order. Run Again remains in the command bar.

### Full Report

There is no separate Full Report surface. Result details remain directly visible in the workbench table.

The table adapts by available width:

- Regular: separate Check, Status, and Result columns.
- Condensed: Status moves beneath the check name, leaving Check and Result columns.
- Compact: each row becomes one vertically composed cell containing check, status, and result.

Increasing window height reveals more rows. Increasing width adds columns and gives Result more space. Additional checks add scrollable rows without changing the page composition.

### Comfortable Result Table

The result table retains native macOS table semantics while using a calm, comfortable density for non-technical users:

- Disable alternating row backgrounds so unused table space remains visually empty instead of resembling placeholder results.
- Give every populated row a 54-point minimum height, with natural vertical growth when localized copy wraps.
- Vertically center short content and use consistent internal spacing across regular, condensed, and compact modes.
- Render check icons with secondary emphasis so status color remains the primary signal.
- Present the localized status as a compact icon-and-label marker. Text and icon continue to communicate the state without relying on color alone.
- Render result summaries with primary text contrast and comfortable wrapping instead of treating them as muted metadata.
- Use subtle separators and selection feedback rather than rounded cards or strongly striped rows.
- Keep the same information hierarchy while running: the active row uses a progress indicator and a single Checking label without duplicating that label in multiple columns.

Regular mode keeps Check, Status, and Result as separate columns. Condensed mode places Status beneath Check while maintaining alignment with Result. Compact mode uses a vertically composed row with a title-and-status header followed by the result summary.

### Outcome-Oriented Result Copy

Result summaries answer what the outcome means to the user, not how the check was performed. User-facing results must not expose the DNS test domain, proxy endpoint addresses, framework names, or other implementation evidence.

Normal summaries are deliberately short because the Status marker already carries the primary conclusion. Abnormal summaries state the likely user-visible impact and then one concrete next step. Indeterminate summaries avoid implying a fault and, where appropriate, ask the user to retry.

| Check | State | Simplified Chinese result intent |
|---|---|---|
| Network connection | Normal | 连接可用 |
| Network connection | Abnormal | 未连接到可用网络，请检查 Wi-Fi 或网线 |
| Network connection | Indeterminate | 暂时无法确认网络连接状态，请稍后重试 |
| DNS resolution | Normal | 域名解析正常 |
| DNS resolution | Abnormal | 无法解析域名，部分网站可能无法打开；请检查 DNS 设置 |
| DNS resolution | Indeterminate | 暂时无法完成 DNS 检查，请稍后重试 |
| System proxy, disabled | Normal | 未使用系统代理 |
| System proxy, enabled and reachable | Normal | 系统代理可用 |
| System proxy | Abnormal | 系统代理无法连接，可能导致网页无法访问；请检查或关闭代理设置 |
| System proxy | Indeterminate | 无法完整确认系统代理是否可用 |

Equivalent English, German, Spanish, Japanese, and Simplified Chinese localizations preserve meaning rather than literal sentence structure. The internal DNS host and proxy endpoints remain implementation inputs and do not become fields in `NetworkDiagnosticResult`.

The existing main-window detail container keeps pages mounted across route changes, so the page retains its latest result while the user visits another route. Closing the window cancels an active run and releases the page state.

Icons and localized text communicate status without relying on color. Add VoiceOver labels for the run button, conclusion, execution progress, active check, report action, and every report result.

## Localization

Add hierarchical keys under `network_diagnostics` and add the navigation key under `nav`. Manually add every key to `Resources/Localizable.xcstrings` with `"extractionState": "manual"` and explicit English, Japanese, and Simplified Chinese localizations.

User-facing copy avoids the terms DoH and DoT and does not claim that a reachable proxy endpoint can forward traffic.

## Testing

Add Swift Testing unit coverage for:

- Runner ordering and incremental publication.
- Prevention of overlapping view-model runs.
- Reset behavior before a repeated run.
- Per-check minimum presentation duration and the zero-duration test configuration.
- Main-page state switching: no idle placeholders, completed and active rows while running, and every result after completion.
- Regular, condensed, and compact workbench table boundaries.
- Running rows contain completed and active checks but exclude future checks.
- Completed rows expose every summary directly without disclosure controls or another window.
- Result-table presentation constants preserve a 54-point comfortable minimum row height and disable alternating empty-row backgrounds.
- User-facing summary tests verify concise Normal outcomes, actionable Abnormal outcomes, neutral Indeterminate outcomes, and the absence of the DNS test domain from every displayed result.
- Every overall-conclusion aggregation branch.
- `NWPath.Status` and timeout mapping.
- DNS success, explicit failure, timeout, and cancellation mapping.
- HTTP, HTTPS, and SOCKS proxy parsing.
- Endpoint normalization and deduplication.
- Proxy reachability aggregation.
- PAC-only and automatic-discovery outcomes.
- Missing and malformed proxy settings.
- Shared sidebar route requirements and labels.

Add new test files to the WiFiLensTests target's file references, group, Sources build phase, and scheme testables as required by the repository.

Default verification consists of:

1. The WiFiLens unit test bundle through `-only-testing:WiFiLensTests`.
2. A Debug macOS build of the shared app scheme.

Do not run UI test bundles unless the user requests them.

## Future Extension

Future checks can implement `DiagnosticCheck` and join the runner's ordered list. Ping, gateway, IPv6, and remote-host checks require no change to the existing concrete checks. If a future check needs the output of an earlier check, introduce an explicit run context rather than coupling checks through global state.
