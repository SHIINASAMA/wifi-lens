# Channel Recommendation Implementation Plan

**Goal:** Implement counterfactual channel recommendation consistently across RF scoring, regulatory filtering, UI state, tests, and documentation.

## Accepted Direction

The codebase standard is:

- observed RF scoring stays in `ChannelQualityCalculator`
- recommendation scoring is counterfactual and excludes the current target AP
- regulatory filtering may downgrade score-selected candidates
- the UI only surfaces final recommendations after filtering
- no forecasting, EMA occupancy, or previous-recommendation penalty model remains

## Required Outcomes

1. `ChannelQualityCalculator` computes both `qualityScore` and `recommendationScore`.
2. `ChannelQualityCalculator` selects up to two counterfactual recommendations per band.
3. `ScannerViewModel` passes current BSSID/SSID identity into RF scoring.
4. `ChannelRecommendation.isRecommended` reflects final recommendation state, not raw RF placeholders.
5. UI recommendation badges and advice cards use final recommendation state and `recommendationScore`.
6. Legacy dynamic scorer files and tests are removed.
7. Documentation consistently describes the counterfactual model.

## File-Level Changes

### `WiFiLens/Sources/WiFiLens/Channels/ChannelQualityCalculator.swift`

- Add AP identity fields (`bssid`, `ssid`) to `APInfo`.
- Add `TargetAP` input.
- Preserve observed RF fields.
- Compute `recommendationScore` using the AP set with the target AP excluded.
- Track recommendation confidence (`exact`, `ssidFallback`, `unknown`).
- Select recommendations using current-good-enough, minimum score, and minimum-improvement thresholds.

### `WiFiLens/Sources/WiFiLens/Scanner/ScannerViewModel.swift`

- Remove `DynamicChannelScorer`.
- Build `TargetAP` from current network interface BSSID/SSID/channel.
- Pass AP identity into `ChannelQualityCalculator.compute`.

### `WiFiLens/Sources/WiFiLens/Regulatory/ChannelRecommendation.swift`

- Preserve observed RF fields.
- Preserve counterfactual recommendation fields.
- Make `isRecommended` require both score selection and regulatory acceptance.

### `WiFiLens/Sources/WiFiLens/Regulatory/RegulatoryFilter.swift`

- Sort by current channel, classification tier, counterfactual selection, recommendation score, then observed RF score.
- Preserve downgraded candidates without presenting them as final recommendations.

### `WiFiLens/Sources/WiFiLens/App/OverviewView.swift`

- Filter recommendation cards from final `isRecommended`.
- Compare better-channel advice using `recommendationScore`.
- Show counterfactual recommendation quality in the advice card.

### Removed Files

- `WiFiLens/Sources/WiFiLens/Channels/DynamicChannelScorer.swift`
- `WiFiLens/Tests/WiFiLensTests/DynamicChannelScorerTests.swift`
- Any unused `DynamicScoringModel.swift` file if present

## Verification

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates -only-testing:WiFiLensTests test
```

Then confirm:

- target AP exclusion increases `recommendationScore` compared with observed RF when the target AP is the only interferer
- external APs still reduce `recommendationScore`
- no source references remain to legacy dynamic scorer files, old predicted-score fields, forecasting scorers, or previous-recommendation penalties
