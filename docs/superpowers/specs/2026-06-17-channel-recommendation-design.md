# Channel Recommendation Design

## Goal

Resolve issue #3 by redefining channel recommendation as a counterfactual deployment decision for the currently connected Wi-Fi router/AP.

The recommendation should answer:

> If the current AP were configured to use this channel, would it face meaningfully less external interference than it does now?

This replaces the earlier static interpretation:

> Which channels look empty in the current scan snapshot?

It also avoids the predictive migration model direction. WiFi Lens does not need to predict whether other users will follow recommendations. The immediate problem is that the existing scoring model can treat the target AP itself as channel occupancy, causing a recommended channel to stop looking recommended after the user moves their router there.

## Product Semantics

WiFi Lens recommends channels for the Wi-Fi network the Mac is currently connected to.

The user action implied by a recommendation is not that macOS changes channel directly. The user is expected to configure the router/AP backing the current Wi-Fi network.

The recommendation is therefore specific to the current target AP. It is not a global "best channel for everyone nearby" ranking.

## Core Model

The channel pipeline should maintain two separate scores:

| Score | Meaning | Consumer |
|-------|---------|----------|
| `observedScore` | Current observed channel quality, including every AP seen in the scan | Environment display and diagnostics |
| `recommendationScore` | Counterfactual score after excluding the current target AP from external interference | Recommendation selection |

The target AP is the AP/router associated with the Mac's current Wi-Fi connection. When computing recommendation scores, the target AP is not counted as external congestion or interference.

This means a channel can remain recommended after the router is moved there, as long as the surrounding external RF environment remains good.

## Data Flow

1. Gather Wi-Fi scan results as today.
2. Identify the target AP from current connection metadata.
3. Build an external AP set by excluding the target AP from scan results.
4. Compute observed channel quality from the full AP set.
5. Compute recommendation quality from the external AP set.
6. Compare candidate recommendation scores against the current channel's recommendation score.
7. Pass the resulting recommendations through regulatory and device compatibility filtering.
8. Display recommendations only when they represent a meaningful improvement over the current channel.

## Target AP Identification

Prefer exact identifiers:

1. Current BSSID, if available.
2. Current SSID plus matching BSSID from scan results.
3. Current SSID only as a low-confidence fallback.

SSID-only matching is ambiguous in mesh and multi-AP deployments. If only SSID-level identification is available, the recommendation should be treated as lower confidence rather than pretending the target AP is known exactly.

If the target AP cannot be identified, the system should fall back to observed environment scoring and avoid strong channel-switch advice.

## Recommendation Strategy

Recommendations should be conservative.

The app should not always force a top-2 result. Router channel changes are manual, disruptive, and should only be suggested when there is a clear benefit.

Recommended behavior:

- If the current channel is already good enough, recommend no switch.
- If the best candidate improves the current channel by less than a configured margin, recommend no switch.
- If one or more candidates clearly improve the current channel, recommend up to two channels.
- Regulatory and device compatibility rules can downgrade or hide otherwise good candidates.

Initial thresholds can be simple and testable:

- Current channel good enough: `recommendationScore >= 80`
- Minimum improvement to suggest switching: `candidateScore - currentScore >= 10`
- Minimum candidate quality: `candidateScore >= 70`
- Maximum recommendations: 2

These constants should live in one configuration surface so they can be tuned without changing the algorithm shape.

## Band Handling

Recommendation selection should remain band-aware, but it should not imply that all bands are equally interchangeable.

Within a band, compare candidate channels against the current channel when the current AP is already using that band.

Across bands, the pipeline should preserve existing device and regulatory constraints. If future work recommends cross-band changes, it should account for client compatibility and coverage tradeoffs separately from channel congestion.

## UI Semantics

The UI should distinguish between "no better channel" and "no data".

Expected states:

- Current channel is good: show that no channel change is needed.
- Better channel exists: show up to two recommended channels and explain the improvement.
- Target AP unknown: show lower-confidence advice or avoid strong recommendations.
- Regulatory/device restrictions apply: keep the existing classification and reasons.

Recommendation reasons should explain external interference, not just raw emptiness. For example:

- "Less external co-channel interference than the current channel"
- "Lower adjacent-channel overlap"
- "Current channel is already good; no switch needed"
- "Current AP could not be identified exactly, so advice is lower confidence"

## Non-Goals

This design does not include:

- Predicting whether other users will migrate to recommended channels.
- Penalizing recently recommended channels because they were recommended.
- Learning global adoption rates from local scan history.
- Coordinating recommendations across multiple WiFi Lens users.
- Replacing regulatory or device compatibility filtering.

Those behaviors solve a broader distributed-system problem and rely on assumptions WiFi Lens cannot observe locally.

## Testing Strategy

Unit tests should cover the algorithm as a counterfactual scorer:

- The target AP is excluded from recommendation scoring.
- The target AP is still included in observed scoring.
- Moving the target AP to a recommended channel does not automatically invalidate the recommendation.
- No recommendation is produced when the current channel is already good.
- No recommendation is produced when improvement is below the threshold.
- Up to two candidates are produced when they clearly improve the current channel.
- Exact BSSID matching is preferred over SSID fallback.
- SSID-only fallback marks recommendation confidence as low.
- Regulatory/device filtering still downgrades or hides incompatible channels.

Integration tests should verify that `ScannerViewModel`, the recommendation pipeline, and the channel views consume the recommendation score rather than the observed score when deciding which channels are recommended.

## Open Implementation Questions

The implementation plan should confirm:

- Which current connection API provides BSSID reliably on supported macOS versions.
- Whether scan results always include the currently connected AP.
- How mesh networks and repeated SSIDs should be represented in the UI.
- Whether the existing `ChannelQuality` model should hold both scores or whether a separate recommendation model should own `recommendationScore`.
