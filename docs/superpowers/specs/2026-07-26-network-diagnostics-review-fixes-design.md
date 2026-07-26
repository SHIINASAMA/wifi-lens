# Network Diagnostics Review Fixes

## Status

Approved for implementation on 2026-07-26. The pull requests remain drafts. Human validation has not occurred.

## Problem

The current network self-check can misattribute failures because its base HTTP and HTTPS requests inherit the system proxy, its proxy resolver discards fallback candidates, and its proxy check evaluates one HTTP target. The runner also treats inconclusive DNS evidence as a hard prerequisite failure.

Four build configurations carry different local-network privacy descriptions. The architecture reference still describes the earlier three-check implementation.

## Goals

- Measure a base HTTP and HTTPS path that does not use an explicit system proxy.
- Preserve and evaluate every ordered proxy candidate returned by CFNetwork or PAC execution.
- Resolve proxy behavior independently for the temporary HTTP captive-portal target and the temporary Apple HTTPS target.
- Block downstream probes only after a hard prerequisite failure.
- Use the same local-network privacy description in OSS and Pro Debug and Release builds.
- Keep public architecture guidance consistent with the shared implementation.
- Rebase both draft PR branches onto their current `master` branches before implementation.

## Non-Goals

- Bypassing VPNs, transparent proxies, Network Extensions, enterprise filters, or router-side interception.
- Replacing the temporary Apple and Microsoft endpoints in this change.
- Reading proxy credentials from Keychain or storing credentials.
- Adding privileged packet capture, raw ARP, or system-log inspection.
- Documenting private Pro implementation details in the public repository.

## Design

### Base Path

`SystemControlEndpointLoader` will use a session configuration that disables explicit system proxy selection. The result describes the base network path only. Product text and evidence must not claim that the request bypasses VPNs or transparent interception.

Tests will verify that the configuration does not inherit default system proxy settings.

### Ordered Proxy Candidates

Proxy configuration resolution will return an ordered list instead of one directive. Static resolution will convert every dictionary returned by `CFNetworkCopyProxiesForURL`. PAC execution will convert every dictionary supplied to its callback.

The ordered model will retain HTTP, HTTPS, SOCKS, and `DIRECT` candidates. Invalid entries will produce explicit evidence without discarding valid later candidates. The proxy checker will try candidates in order and stop at the first usable route. A failed proxy followed by `DIRECT` is a valid fallback outcome, not an endpoint failure.

Cancellation and the existing overall timeout remain mandatory across candidate attempts.

### Target Matrix

The proxy checker will resolve two targets independently:

- Microsoft HTTP captive-portal target.
- Apple HTTPS reachability target.

Each target will report its selected route and fallback behavior. A `DIRECT` result applies only to that target. The final proxy result will summarize the matrix without claiming that the system proxy is globally disabled.

The checker will distinguish:

- Both targets direct.
- One target proxied and one direct.
- Both targets proxied through usable routes.
- Authentication required.
- Configured candidates unavailable with no working fallback.
- Resolution or PAC execution indeterminate.

### Dependency Policy

The runner will use explicit blocking rules instead of `status != .normal`.

- `.abnormal` and `.blocked` may block checks with a hard dependency.
- `.indeterminate` will not block internet or IPv6 probes. Those probes can add independent evidence.
- `.skipped` follows the dependency rule for the specific check.
- A failed system path blocks network probes because no usable path exists.
- A confirmed DNS failure may block hostname-dependent direct probes while preserving configuration evidence where possible.

Tests will cover DNS abnormal, DNS indeterminate, path abnormal, and path indeterminate combinations.

### Privacy Description

OSS and Pro Debug and Release configurations will use one English `NSLocalNetworkUsageDescription`. The description will cover the opt-in MCP server and Network Self-Check access to a configured local proxy. It will state that the check does not transmit Wi-Fi scan data.

### Documentation

The public architecture reference will list all five shared checks, five result states, PAC execution, ordered candidates, network-change reruns, and the base-path versus system-proxy distinction. It will not describe private Pro types or behavior.

## Error Handling

- Empty proxy candidate lists produce an indeterminate resolution result.
- Invalid candidates remain evidence while valid later candidates continue.
- PAC timeout and cancellation keep their distinct evidence codes.
- Candidate timeout uses the remaining overall budget rather than resetting the timeout for each candidate.
- A direct fallback after proxy failure records both events without presenting the target as failed.
- A target-specific result never expands into a claim about the full system proxy configuration.

## Test Strategy

Use test-driven development for each behavior:

1. Prove the base loader disables inherited system proxy settings.
2. Prove static and PAC resolvers preserve ordered candidates.
3. Prove failed proxy candidates fall back to later proxy or direct candidates.
4. Prove HTTP and HTTPS targets resolve independently.
5. Prove DNS indeterminate continues internet and IPv6 checks.
6. Prove hard path and DNS failures produce blocked results where required.
7. Prove all four build configurations carry the same local-network description.
8. Update architecture assertions or documentation checks where applicable.

After focused tests pass, run the canonical OSS Debug build, Pro Debug build, and `WiFiLensTests` suite. Run the public knowledge-boundary scan and integrity check. Keep both PRs in draft until a person completes the manual validation matrix.

## Manual Validation Matrix

- No explicit proxy on a normal network.
- Stale local proxy with a working direct path.
- PAC with `PROXY; DIRECT` fallback.
- Different HTTP and HTTPS proxy routes.
- Proxy authentication required.
- Captive portal response replacement.
- DNS partial failure and total failure.
- Network switch during an active run.
- IPv4-only, working IPv6, and broken IPv6 environments.

## Integration

Rebase the Pro branch first, then rebase the root branch and update its submodule pointer. Preserve unrelated local changes outside the PR. Push rewritten branches with `--force-with-lease`, rerun validation, and update both draft PR descriptions with the final evidence and remaining human-validation requirement.
