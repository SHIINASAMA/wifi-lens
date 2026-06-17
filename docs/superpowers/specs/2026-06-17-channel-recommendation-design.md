# Channel Recommendation Design

## Goal

Resolve issue #3 by making channel recommendation explicitly predictive instead of purely snapshot-based.

The recommendation should answer:

> Which channels are most likely to remain good after users act on the recommendation?

WiFi Lens still displays the observed RF environment, but recommendation selection should use a future-looking score that accounts for short-term channel trends and migration pressure caused by prior recommendations.

## Product Semantics

WiFi Lens recommends channels for the Wi-Fi environment the user is inspecting, not a guaranteed globally optimal configuration.

Two distinct channel views are required:

| View | Meaning | Consumer |
|------|---------|----------|
| `qualityScore` | Observed RF quality in the current scan snapshot | Charts, diagnostics, current environment display |
| `predictedScore` | Expected near-future quality after trend and migration penalties | Recommendation selection, advice cards, recommendation ordering |

Observed RF data remains visible because users still need to understand what the scanner is seeing right now. Predictive scoring exists to prevent self-defeating recommendations that immediately degrade after adoption.

## Core Model

`DynamicChannelScorer` is the recommendation authority.

Its inputs are per-channel observed RF measurements from `ChannelQualityCalculator`. Its outputs are:

- `predictedScore`
- `isRecommended`
- recommendation-aware ordering for UI display

The model keeps lightweight per-channel history:

1. AP count history over recent scans
2. EMA-smoothed occupancy trend
3. Whether the channel was recommended in the previous cycle

The predictive score is:

`predictedScore = currentScore - trendPenalty - migrationPenalty`

Where:

- `trendPenalty` penalizes channels whose AP count trend is rising
- `migrationPenalty` penalizes channels that were just recommended, modeling expected follow-on congestion

## Recommendation Selection

Recommendation selection should be simple and deterministic:

- Select recommendations independently per band
- Candidate threshold: `predictedScore >= 70`
- Maximum recommendations per band: 2
- Higher `predictedScore` wins
- `qualityScore` is the tie-breaker after `predictedScore`

This model intentionally stays band-local. Cross-band migration remains a separate product problem because it mixes congestion, compatibility, and coverage tradeoffs.

## Pipeline Ownership

The pipeline must have one clear source of truth at each stage:

1. `ChannelQualityCalculator` computes observed RF only
2. `DynamicChannelScorer` computes predictive recommendation state
3. `RegulatoryPipeline` classifies or downgrades predictive candidates
4. UI surfaces final recommendations after regulatory filtering

`ChannelQualityCalculator` must not make recommendation decisions. It can initialize `predictedScore` to `qualityScore` as the predictive scorer baseline, but recommendation membership belongs to `DynamicChannelScorer`.

## Regulatory Interaction

A channel can be prediction-selected and still fail to become a final recommendation.

Examples:

- DFS channel with strong predicted quality becomes `.advanced`
- Device-incompatible channel becomes `.restricted`
- Low-confidence region inference can downgrade `.recommended` to `.advanced`

This means downstream models should distinguish:

- prediction-selected channels
- final recommended channels

The UI should only show recommendation badges and advice for final recommendations that survive regulatory filtering.

## UI Semantics

The UI should follow these rules:

- Score bars and environment health use `qualityScore`
- Recommendation badges and advice cards use predictive recommendation state
- Recommendation ordering prefers `predictedScore`
- If regulatory filtering downgrades a predictive candidate, it should no longer appear as a final recommendation

This avoids the previous split-brain behavior where sorting changed but recommendation badges did not.

## Non-Goals

This design does not include:

- explicit self-occupancy simulation of a hypothetical future AP
- long-horizon forecasting
- global coordination across users
- learning population-level adoption rates from remote telemetry
- replacing regulatory or device compatibility filtering

The model is intentionally local, lightweight, and explainable.

## Testing Strategy

Unit tests should cover:

- `ChannelQualityCalculator` preserving observed RF only
- `DynamicChannelScorer` selecting recommendations from `predictedScore`
- previously recommended channels receiving migration penalties on later scans
- recommendation selection being independent per band
- final `ChannelRecommendation.isRecommended` requiring both prediction selection and regulatory acceptance

Integration tests should verify:

- `ScannerViewModel` always runs observed RF through the predictive scorer before building recommendations
- `OverviewView` and `ChannelQualityView` surface final recommendations, not raw RF placeholders
- regulatory downgrades suppress final recommendation badges while keeping observed RF data intact
