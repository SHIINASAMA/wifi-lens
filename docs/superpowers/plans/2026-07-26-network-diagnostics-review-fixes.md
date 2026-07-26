# Network Diagnostics Review Fixes Implementation Plan

> **Execution note:** Work through the checked steps in order, using the repository's plan-execution workflow and test-driven gates.

**Goal:** Correct proxy-path attribution, ordered fallback behavior, target-specific proxy reporting, dependency blocking, and local-network privacy copy in the macOS network self-check.

**Architecture:** The base endpoint loader will explicitly suppress system proxy inheritance. Proxy resolution will expose an ordered candidate list for each URL, and the proxy check will evaluate independent HTTP and HTTPS target routes through a bounded candidate executor. The runner will apply explicit hard-failure blocking rules while preserving inconclusive evidence.

**Tech Stack:** Swift 6, Foundation `URLSession`, CFNetwork proxy APIs, Network.framework `ProxyConfiguration` and `NWConnection`, Swift Testing, Xcode project build settings.

## Global Constraints

- Support macOS 14.6 and later with public APIs and ordinary app permissions.
- Keep `https://www.apple.com/` and `http://www.msftconnecttest.com/connecttest.txt` as temporary test endpoints.
- Keep the HTTP ATS exception restricted to `www.msftconnecttest.com`.
- Do not claim to bypass VPNs, transparent proxies, Network Extensions, enterprise filters, or router-side interception.
- Do not read or store proxy credentials.
- Preserve ordered proxy candidates and the remaining overall timeout across fallback attempts.
- Keep both pull requests in draft and state that human validation has not occurred.
- Preserve unrelated `Package.resolved` and `.workbuddy/` changes.
- Do not commit without an explicit user request. Before each requested commit ask exactly: `Run the checks relevant to this commit before committing?`
- Do not push rewritten history without explicit user authorization; use `--force-with-lease` when authorized.
- Keep private Pro implementation knowledge out of the public repository.

---

### Task 1: Rebase Both Draft Branches Safely

**Files:**
- Preserve: `wifi-lens.xcworkspace/xcshareddata/swiftpm/Package.resolved`
- Preserve: `.workbuddy/`
- Preserve: `AGENTS.md`
- Preserve: `docs/superpowers/specs/2026-07-26-network-diagnostics-review-fixes-design.md`
- Preserve: `docs/superpowers/plans/2026-07-26-network-diagnostics-review-fixes.md`
- Update pointer after Pro rebase: `Pro`

**Interfaces:**
- Consumes: published branches `codex/network-check` and `codex/network-check-ats`.
- Produces: both branches rebased onto current `origin/master`, with the root branch referencing the rebased Pro commit.

- [ ] **Step 1: Record the current branch, status, submodule commit, and PR heads**

Run:

```bash
git status -sb
git rev-parse HEAD
git -C Pro status -sb
git -C Pro rev-parse HEAD
```

Expected: root branch `codex/network-check`; Pro branch `codex/network-check-ats`; only the documented unrelated and planning files are dirty.

- [ ] **Step 2: Stash only the tracked and planning files that block rebase**

Run:

```bash
git stash push -u -m codex-network-diagnostics-rebase \
  -- AGENTS.md \
  docs/superpowers/specs/2026-07-26-network-diagnostics-review-fixes-design.md \
  docs/superpowers/plans/2026-07-26-network-diagnostics-review-fixes.md \
  wifi-lens.xcworkspace/xcshareddata/swiftpm/Package.resolved
```

Expected: `.workbuddy/` remains untouched; the named files appear in one recoverable stash.

- [ ] **Step 3: Rebase the Pro branch**

Run:

```bash
git -C Pro fetch origin
git -C Pro rebase origin/master
```

Expected: the one temporary ATS commit is replayed onto current Pro `master`. If `WiFiLensPro-Info.plist` conflicts, retain current `master` content plus the narrow `www.msftconnecttest.com` ATS block.

- [ ] **Step 4: Rebase the root branch**

Run:

```bash
git fetch origin
git rebase origin/master
```

Expected: both network-diagnostics commits replay onto current root `master`. Resolve only conflicts in files owned by this feature. Keep current `master` changes outside the network-diagnostics scope.

- [ ] **Step 5: Point the root repository at the rebased Pro commit and restore the stash**

Run:

```bash
git stash pop
```

Expected: the root shows the rebased Pro commit as an unstaged pointer update. If the root rebase stopped on a submodule conflict in Step 4, check out the rebased Pro commit, stage only `Pro`, and continue the rebase before restoring the stash. `Package.resolved`, the approved spec, this plan, and `AGENTS.md` are restored; `.workbuddy/` is unchanged.

- [ ] **Step 6: Inspect the rebased scope without committing**

Run:

```bash
git status --short
git diff --submodule=short -- Pro
git diff --check
```

Expected: no whitespace errors; no unrelated file enters the feature diff.

---

### Task 2: Make the Base Endpoint Loader Ignore Explicit System Proxies

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/NetworkDiagnostics/HTTPSControlEndpointCheck.swift`
- Test: `WiFiLens/Tests/WiFiLensTests/NetworkDiagnostics/NetworkDiagnosticsTests.swift`

**Interfaces:**
- Consumes: `SystemControlEndpointLoader.configuration(timeout:)`.
- Produces: `SystemControlEndpointLoader.configuration(timeout:) -> URLSessionConfiguration` with explicit no-proxy settings.

- [ ] **Step 1: Write the failing configuration test**

Add a Swift Testing case that requires both proxy APIs to stop inheriting system defaults:

```swift
@Test("base endpoint configuration does not inherit explicit system proxies")
func baseEndpointDisablesExplicitSystemProxy() {
    let configuration = SystemControlEndpointLoader.configuration(timeout: .seconds(2))

    #expect(configuration.connectionProxyDictionary?.isEmpty == true)
    #expect(configuration.proxyConfigurations.isEmpty)
}
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" \
  -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test \
  -only-testing:WiFiLensTests/NetworkDiagnosticsTests/baseEndpointDisablesExplicitSystemProxy
```

Expected: FAIL because `connectionProxyDictionary` remains `nil`, which inherits system settings.

- [ ] **Step 3: Implement the no-explicit-proxy configuration**

Set an explicit empty classic proxy dictionary and keep the modern proxy list empty:

```swift
configuration.connectionProxyDictionary = [:]
configuration.proxyConfigurations = []
```

Keep caching, connectivity waits, and timeout behavior unchanged.

- [ ] **Step 4: Run the focused test and the existing control-loader tests**

Run the `NetworkDiagnosticsTests` suite. Expected: PASS, with evidence that base requests no longer inherit explicit system proxy settings.

- [ ] **Step 5: Pause at the commit gate**

Do not commit automatically. Record Task 2 files and test results for the next user-authorized commit.

---

### Task 3: Preserve Ordered Static and PAC Proxy Candidates

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/NetworkDiagnostics/ProxyResolution.swift`
- Modify if model placement requires it: `WiFiLens/Sources/WiFiLens/NetworkDiagnostics/SystemProxyCheck.swift`
- Test: `WiFiLens/Tests/WiFiLensTests/NetworkDiagnostics/NetworkDiagnosticsTests.swift`

**Interfaces:**
- Consumes: CFNetwork proxy arrays for one target URL.
- Produces: `ProxyCandidateResolution` and ordered `[EffectiveProxy]` candidates.
- Produces: `ProxyConfigurationResolving.resolutions(for:) -> [ProxyResolutionDirective]`.
- Produces: `ProxyResolving.resolve(for:) async -> ProxyCandidateResolution`.
- Produces: `PACResolving.resolve(pacURL:targetURL:timeout:) async -> ProxyCandidateResolution`.

- [ ] **Step 1: Define desired ordered-result behavior in failing tests**

Add tests for these concrete arrays:

```swift
private func proxyDictionary(
    type: CFString,
    host: String? = nil,
    port: Int? = nil
) -> NSDictionary {
    let dictionary = NSMutableDictionary()
    dictionary[kCFProxyTypeKey] = type
    if let host { dictionary[kCFProxyHostNameKey] = host }
    if let port { dictionary[kCFProxyPortNumberKey] = NSNumber(value: port) }
    return dictionary
}

let candidates = SystemProxyResolver.candidates(from: [
    proxyDictionary(type: kCFProxyTypeHTTP, host: "127.0.0.1", port: 7890),
    proxyDictionary(type: kCFProxyTypeNone),
])
#expect(candidates == [
    .http(.init(host: "127.0.0.1", port: 7890)),
    .direct,
])
```

Add a PAC callback test that returns `PROXY` followed by `DIRECT` and expects both candidates in order. Add an invalid-first, valid-second test and require the valid candidate to survive with resolution evidence.

- [ ] **Step 2: Run the proxy-resolution tests and verify RED**

Expected: FAIL because current protocols return one `EffectiveProxy` and both static and PAC paths read `firstObject`.

- [ ] **Step 3: Add the ordered resolution model**

Introduce:

```swift
struct ProxyCandidateResolution: Equatable, Sendable {
    let candidates: [EffectiveProxy]
    let evidenceCodes: [String]
}
```

Add `SystemProxyResolver.directives(from values: [Any]) -> [ProxyResolutionDirective]`. Change `ProxyConfigurationResolving` to return every directive for the URL. Change `ProxyResolving.resolve(for:)` and `PACResolving.resolve(pacURL:targetURL:timeout:)` to return `ProxyCandidateResolution`.

`SystemProxyResolver` will walk the static directives in order. It appends explicit HTTP, HTTPS, SOCKS, and `DIRECT` candidates. When it reaches `.pac(URL)`, it executes that PAC URL and appends all returned PAC candidates at the same position before continuing with later static directives. Invalid directives add evidence without removing later valid candidates. Represent array-level failure with an empty candidate list and an evidence code such as `resolution-empty`, `pac-timeout`, or `pac-execution-failed`.

- [ ] **Step 4: Update PAC cancellation and timeout completion**

Change `PACResolutionContext` continuations from `EffectiveProxy` to `ProxyCandidateResolution`. Preserve source invalidation, run-loop stopping, cancellation, and one-resume locking.

- [ ] **Step 5: Run focused proxy-resolution tests and verify GREEN**

Expected: ordered candidates match CFNetwork order, `DIRECT` remains available after a failed proxy candidate, and PAC timeout/cancellation evidence remains distinct.

- [ ] **Step 6: Run all network-diagnostics tests**

Expected: compile failures from old stub signatures are resolved without weakening the new ordered-list assertions.

- [ ] **Step 7: Pause at the commit gate**

Do not commit automatically. Record Task 3 files and test results.

---

### Task 4: Evaluate HTTP and HTTPS Proxy Routes Independently

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/NetworkDiagnostics/SystemProxyCheck.swift`
- Modify: `WiFiLens/Sources/WiFiLens/NetworkDiagnostics/ProxyResolution.swift`
- Modify: `WiFiLens/Sources/WiFiLens/Resources/Localizable.xcstrings`
- Test: `WiFiLens/Tests/WiFiLensTests/NetworkDiagnostics/NetworkDiagnosticsTests.swift`

**Interfaces:**
- Consumes: `ProxyCandidateResolution` from Task 3.
- Produces: `ProxyTargetRouteResult` for one URL and an aggregate `SystemProxyCheck` result.
- Produces: ordered candidate execution with one overall target timeout.

Use these target-level types:

```swift
enum ProxyTargetRouteStatus: Equatable, Sendable {
    case direct
    case proxied
    case authenticationRequired
    case unavailable
    case indeterminate
}

struct ProxyTargetRouteResult: Equatable, Sendable {
    let target: URL
    let status: ProxyTargetRouteStatus
    let selectedCandidateIndex: Int?
    let selectedProxy: EffectiveProxy?
    let evidence: [NetworkDiagnosticEvidence]
}
```

- [ ] **Step 1: Write failing candidate-fallback tests**

Cover these behaviors:

```swift
@Test("failed proxy candidate falls back to DIRECT for the same target")
@Test("failed first proxy tries the next proxy candidate")
@Test("candidate attempts share one overall timeout")
```

The first test supplies `[.http(staleEndpoint), .direct]` and expects a successful direct fallback with evidence for the failed endpoint and selected direct route.

- [ ] **Step 2: Write failing HTTP/HTTPS matrix tests**

Add a resolver recorder keyed by URL. Require `SystemProxyCheck` to resolve exactly:

```swift
[
    "http://www.msftconnecttest.com/connecttest.txt",
    "https://www.apple.com/",
]
```

The test resolver stores each requested `URL.absoluteString` in an actor-isolated array and returns a `ProxyCandidateResolution` from a `[URL: ProxyCandidateResolution]` fixture. Test both-direct, HTTP-direct/HTTPS-proxy, both-proxied, authentication-required, and no-working-candidate results. Verify that no summary claims the system proxy is globally disabled.

- [ ] **Step 3: Run the new tests and verify RED**

Expected: FAIL because the current check resolves one HTTP URL and returns after one candidate.

- [ ] **Step 4: Implement the bounded candidate executor**

Add a focused type or private method with this behavior:

```swift
func evaluate(
    target: URL,
    resolution: ProxyCandidateResolution,
    timeout: Duration
) async -> ProxyTargetRouteResult
```

For each candidate, allocate `clock.now.duration(to: deadline) / Double(remainingCandidateCount)`. A proxy candidate must pass endpoint connection and egress loading. A direct candidate records the target-specific selected route without sending the request through `SystemProxyEgressLoader`; the separate base endpoint check supplies reachability evidence. Stop at the first usable candidate. Preserve 407 authentication evidence.

- [ ] **Step 5: Aggregate the two target results**

Resolve and evaluate Microsoft HTTP and Apple HTTPS separately. Return one proxy check result whose evidence includes target scheme, route type, candidate index, fallback use, endpoint status, authentication status, and egress status. Use target-scoped localized summaries such as mixed routing, proxy routes available, authentication required, route unavailable, and unable to determine.

- [ ] **Step 6: Update localization with the repository workflow**

Add manual English, Japanese, and Simplified Chinese entries to `Localizable.xcstrings`. Run the repository localization completeness workflow from `.agents/skills/i18n-completer/` before declaring the task complete.

- [ ] **Step 7: Run all network-diagnostics tests and verify GREEN**

Expected: ordered fallback and two-target routing tests pass; existing proxy endpoint, PAC, authentication, and egress behavior remains covered.

- [ ] **Step 8: Pause at the commit gate**

Do not commit automatically. Record Task 4 files and test results.

---

### Task 5: Replace Generic Dependency Blocking With Hard-Failure Rules

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/NetworkDiagnostics/DiagnosticRunner.swift`
- Test: `WiFiLens/Tests/WiFiLensTests/NetworkDiagnostics/NetworkDiagnosticsTests.swift`

**Interfaces:**
- Consumes: ordered `NetworkDiagnosticResult` values.
- Produces: `blockingResult(for:from:)` that blocks only on explicit hard-failure states for each dependency.

- [ ] **Step 1: Write the failing dependency matrix tests**

Add separate tests for:

```swift
@Test("indeterminate DNS does not block internet or IPv6")
@Test("abnormal DNS blocks hostname-dependent internet and IPv6 checks")
@Test("indeterminate path continues independent evidence probes")
@Test("abnormal path blocks network probes")
```

Each test must assert both result statuses and actual probe invocation IDs.

- [ ] **Step 2: Run the dependency tests and verify RED**

Expected: the DNS-indeterminate and path-indeterminate tests fail because `status != .normal` blocks all dependencies.

- [ ] **Step 3: Implement explicit blocking policy**

Represent dependencies and blocking statuses together:

```swift
struct DiagnosticDependency {
    let id: NetworkDiagnosticCheckID
    let blockingStatuses: Set<NetworkDiagnosticStatus>
}
```

Use `[.abnormal, .blocked]` for hard path and DNS dependencies. Do not block on `.indeterminate`. Keep optional IPv6 `.skipped` behavior unchanged.

- [ ] **Step 4: Run the dependency tests and all network-diagnostics tests**

Expected: only confirmed hard failures synthesize `.blocked`; inconclusive upstream probes allow downstream evidence collection.

- [ ] **Step 5: Pause at the commit gate**

Do not commit automatically. Record Task 5 files and test results.

---

### Task 6: Unify Privacy Copy and Correct Architecture Guidance

**Files:**
- Modify: `WiFiLens/WiFiLens.xcodeproj/project.pbxproj`
- Modify: `.agents/references/project/ARCHITECTURE.md`
- Modify: `AGENTS.md`
- Keep: `docs/superpowers/specs/2026-07-26-network-diagnostics-review-fixes-design.md`
- Keep: `docs/superpowers/plans/2026-07-26-network-diagnostics-review-fixes.md`
- Test: `WiFiLens/Tests/WiFiLensTests/NetworkDiagnostics/NetworkDiagnosticsTests.swift`

**Interfaces:**
- Produces: identical `NSLocalNetworkUsageDescription` in OSS Debug, OSS Release, Pro Debug, and Pro Release.
- Produces: public architecture text matching the five-check implementation without private Pro details.

- [ ] **Step 1: Write the failing build-setting test**

Add or extend a source-level project configuration test that extracts every app-target `INFOPLIST_KEY_NSLocalNetworkUsageDescription` and requires four identical values containing both `MCP server` and `Network Self-Check`.

- [ ] **Step 2: Run the test and verify RED**

Expected: FAIL because only Pro Release has the Network Self-Check proxy wording.

- [ ] **Step 3: Update each target configuration with verified context**

Before editing each `project.pbxproj` block, confirm its `baseConfigurationReference` is `OSS.xcconfig` or `PRO.xcconfig`. Set this exact copy in all four app configurations:

```text
WiFi Lens uses local networking when you enable its MCP server and when Network Self-Check tests reachability of your configured network proxy. These checks do not collect or transmit your Wi-Fi scan data.
```

Do not use a global replacement without configuration context.

- [ ] **Step 4: Correct the public architecture description**

Update the manual network diagnostics section to cover path, sampled DNS, base HTTP/HTTPS, forced IPv6, ordered proxy/PAC candidates, target-specific routing, network-change reruns, and five result states. Remove the obsolete claim that PAC scripts are not executed. Do not name private Pro symbols.

- [ ] **Step 5: Index both approved planning documents**

Keep the existing spec index row and add this plan to the `AGENTS.md` documentation table.

- [ ] **Step 6: Run the privacy-copy test and knowledge-boundary checks**

Run:

```bash
python3 .agents/skills/protect-knowledge-boundary/scripts/check_public_knowledge.py
python3 .agents/skills/protect-knowledge-boundary/scripts/verify_integrity.py
```

Expected: privacy test PASS; public scan PASS; integrity PASS.

- [ ] **Step 7: Pause at the commit gate**

Do not commit automatically. Record Task 6 files and check results.

---

### Task 7: Final Verification and Draft PR Update

**Files:**
- Verify all files changed in Tasks 1 through 6.
- Update externally: root PR #30 and Pro PR #6 descriptions and comments only after explicit authorization.

**Interfaces:**
- Consumes: the completed network-diagnostics implementation.
- Produces: verified draft branches with documented automated evidence and an explicit human-validation gap.

- [ ] **Step 1: Run the focused network-diagnostics suite**

Run:

```bash
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" \
  -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test \
  -only-testing:WiFiLensTests/NetworkDiagnosticsTests
```

Expected: all network-diagnostics tests pass.

- [ ] **Step 2: Run canonical repository verification**

Run:

```bash
.agents/skills/verify-build/scripts/verify.sh
```

Expected: OSS Debug build PASS; Pro Debug build PASS; `WiFiLensTests` PASS; no UI tests run.

- [ ] **Step 3: Run final static checks**

Run:

```bash
git diff --check
plutil -lint WiFiLens/WiFiLens-Info.plist
python3 .agents/skills/protect-knowledge-boundary/scripts/check_public_knowledge.py
python3 .agents/skills/protect-knowledge-boundary/scripts/verify_integrity.py
```

Expected: all commands PASS.

- [ ] **Step 4: Record the human validation boundary**

Report that automated checks passed and human validation remains incomplete. Keep both PRs in draft. Do not claim the feature is release-ready.

- [ ] **Step 5: Request commit consent if the user asks for commits**

Ask exactly:

```text
Run the checks relevant to this commit before committing?
```

Follow the answer for each root or Pro commit separately.

- [ ] **Step 6: Request push authorization for rebased history**

Explain that rebase changed commit IDs. When the user authorizes the push, publish Pro first and root second with `git push --force-with-lease`.

- [ ] **Step 7: Update both Draft PRs after push authorization**

Add final automated test counts, retain the human-validation warning, link the companion PRs, and summarize which blocking review items were resolved. Do not resolve or reply to the review comment unless the user explicitly asks.
