# Channel Recommendation Implementation Plan

**Goal:** Keep the predictive migration model and make it the single coherent recommendation path across RF scoring, regulatory filtering, UI state, tests, and documentation.

## Accepted Direction

This plan supersedes the earlier counterfactual rewrite direction.

The codebase standard is now:

- observed RF scoring stays in `ChannelQualityCalculator`
- predictive recommendation scoring stays in `DynamicChannelScorer`
- regulatory filtering may downgrade predictive candidates
- the UI only surfaces final recommendations after filtering

## Required Outcomes

1. `ChannelQualityCalculator` no longer selects recommendations.
2. `DynamicChannelScorer` computes `predictedScore` and owns recommendation membership.
3. `ChannelRecommendation.isRecommended` reflects final recommendation state, not stale RF placeholders.
4. UI recommendation badges and advice cards use the final recommendation state.
5. Unused `DynamicScoringModel.swift` is removed.
6. Tests verify the predictive path end to end.
7. Documentation consistently describes the predictive model.

## File-Level Changes

### `WiFiLens/Sources/WiFiLens/Channels/ChannelQualityCalculator.swift`

- Keep observed RF scoring only
- Initialize `predictedScore` as a baseline copy of `qualityScore`
- Do not select recommendations here
- Do not sort by recommendation state here

### `WiFiLens/Sources/WiFiLens/Channels/ChannelQualityCalculator.swift`

- Compute predictive penalties from trend and migration state
- Select up to two recommendations per band from `predictedScore`
- Set `ChannelQuality.isRecommended`
- Recompute `showInSimpleView`
- Return recommendation-aware ordering for display

### `WiFiLens/Sources/WiFiLens/Regulatory/ChannelRecommendation.swift`

- Preserve observed RF fields
- Preserve predictive score
- Track whether the predictive model selected the channel
- Make `isRecommended` require both prediction selection and regulatory acceptance

### `WiFiLens/Sources/WiFiLens/Regulatory/RegulatoryFilter.swift`

- Sort by current channel, classification tier, predictive selection, predicted score, then observed RF score
- Preserve downgraded candidates without presenting them as final recommendations

### `WiFiLens/Sources/WiFiLens/App/OverviewView.swift`

- Filter recommendation cards from final `isRecommended`
- Compare better-channel advice using `predictedScore`
- Show predicted recommendation quality in the advice card

### `WiFiLens/Sources/WiFiLens/Channels/ChannelQualityView.swift`

- Use final `isRecommended` for badges and reason popovers

### `WiFiLens/Sources/WiFiLens/Channels/DynamicScoringModel.swift`

- Remove the file because it is unused and contains placeholder logic

## Verification

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test
```

Then confirm:

- recommendation badges now match predictive ordering
- no source references remain to `DynamicScoringModel`
- documentation no longer describes the counterfactual rewrite as the active direction
