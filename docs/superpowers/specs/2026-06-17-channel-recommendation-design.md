# Channel Recommendation Design

## Goal

Resolve issue #3 by making channel recommendation explicitly counterfactual.

The recommendation should answer:

> If the current AP were configured to use this channel, would it face meaningfully less external interference than it faces now?

WiFi Lens still displays the observed RF environment, including the current AP. Recommendation selection uses a separate score that excludes the current target AP from the interference calculation.

## Product Semantics

Two distinct channel views are required:

| View | Meaning | Consumer |
|------|---------|----------|
| `qualityScore` | Observed RF quality in the current scan snapshot, including all APs | Charts, diagnostics, current environment display |
| `recommendationScore` | Counterfactual quality after excluding the current target AP | Recommendation selection, advice cards, recommendation ordering |

Observed RF data remains visible because users need to understand what the scanner sees right now. Counterfactual scoring exists so the user's own AP does not make its current channel look artificially bad or make a candidate look artificially good for the wrong reason.

## Target AP Identification

The target AP is the Wi-Fi network the Mac is currently connected to.

Identification order:

1. Current BSSID from CoreWLAN/network interface data (`.exact`)
2. Current SSID fallback when BSSID is unavailable and exactly one AP with that SSID is visible on the current channel (`.ssidFallback`)
3. Unknown target (`.unknown`)

When the target is unknown or SSID fallback is ambiguous, WiFi Lens still computes observed RF scores, but does not make counterfactual recommendations.

## Recommendation Selection

Selection is deterministic and band-local:

- Compute `qualityScore` from all observed APs.
- Compute `recommendationScore` from the same AP set after excluding the target AP.
- If the current channel's `recommendationScore >= 80`, do not recommend a move.
- Candidate channels must have `recommendationScore >= 70`.
- Candidate channels must improve on the current channel by at least 10 points.
- Select at most 2 channels per band.
- Higher `recommendationScore` wins; `qualityScore` and channel number are tie-breakers.

## Pipeline Ownership

The pipeline has one source of truth at each stage:

1. `ScannerViewModel` gathers AP identity and current connection identity.
2. `ChannelQualityCalculator` computes observed RF, counterfactual scores, and pre-regulatory recommendation selection.
3. `RegulatoryPipeline` classifies or downgrades selected candidates.
4. UI surfaces final recommendations after regulatory filtering.

There is no forecasting model, AP trend penalty, EMA occupancy model, or previous-recommendation penalty in this design.

## Regulatory Interaction

A channel can be score-selected and still fail to become a final recommendation.

Examples:

- DFS channel with strong counterfactual quality becomes `.advanced`
- Device-incompatible channel becomes `.restricted`
- Low-confidence region inference can downgrade `.recommended` to `.advanced`

The UI should only show recommendation badges and advice for final recommendations that survive regulatory filtering.

## UI Semantics

- Score bars and environment health use `qualityScore`.
- Recommendation badges and advice cards use final `isRecommended`.
- Advice card score/level uses `recommendationScore`.
- Recommendation ordering prefers `recommendationScore`.

## Non-Goals

This design does not include:

- near-future forecasting
- adoption-rate or previous-recommendation penalties
- global coordination across users
- remote telemetry learning
- replacing regulatory or device compatibility filtering

The model is intentionally local, deterministic, and explainable.

## Testing Strategy

Unit tests should cover:

- target AP exclusion from `recommendationScore`
- external APs still reducing `recommendationScore`
- unknown target suppressing recommendations
- current-good-enough threshold suppressing moves
- minimum improvement threshold
- final `ChannelRecommendation.isRecommended` requiring both score selection and regulatory acceptance

Integration tests should verify:

- `ScannerViewModel` passes BSSID/SSID identity into `ChannelQualityCalculator`
- `OverviewView` and `ChannelQualityView` surface final recommendations, not raw RF placeholders
- regulatory downgrades suppress final recommendation badges while keeping observed RF data intact
