# Channel Recommendation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace static top-2 channel recommendations and the rejected predictive migration model with counterfactual deployment scoring for the currently connected AP.

**Architecture:** Keep observed RF scoring for environment display, and add a separate recommendation score that excludes the current target AP from external interference. Recommendation selection becomes conservative: recommend up to two channels only when they clearly improve on the current channel after regulatory/device filtering.

**Tech Stack:** Swift 6, Swift Testing, SwiftUI, AppKit/CoreWLAN, Xcode project build system.

## Global Constraints

- Use `xcodebuild`, never `swift build` or `swift test`.
- Do not commit unless the user explicitly asks.
- Keep all docs under `docs/`; update `AGENTS.md` when adding docs.
- New localized strings must be added to `Resources/Localizable.xcstrings` with `"extractionState": "manual"` and explicit English localization.
- Preserve existing regulatory filtering and device compatibility behavior.
- The implementation follows [docs/superpowers/specs/2026-06-17-channel-recommendation-design.md](../specs/2026-06-17-channel-recommendation-design.md).

---

## File Structure

- Modify `WiFiLens/Sources/WiFiLens/Channels/ChannelQualityCalculator.swift`
  - Add AP identity fields to `APInfo`.
  - Add `recommendationScore`, `recommendationLevel`, `recommendationConfidence`, and `recommendationState` to `ChannelQuality`.
  - Compute observed scores from all APs and recommendation scores from the external AP set.
  - Select recommendations using conservative thresholds.
- Modify `WiFiLens/Sources/WiFiLens/Scanner/ScannerViewModel.swift`
  - Remove `DynamicChannelScorer`.
  - Build `APInfo` with BSSID/SSID.
  - Pass current BSSID/SSID/channel into the calculator.
- Modify `WiFiLens/Sources/WiFiLens/Regulatory/ChannelRecommendation.swift`
  - Preserve observed RF fields.
  - Add recommendation score/state fields.
  - Make `isRecommended` reflect recommendation selection, not raw RF ranking.
- Modify `WiFiLens/Sources/WiFiLens/Regulatory/RegulatoryFilter.swift`
  - Sort by recommendation state/score after classification.
- Modify `WiFiLens/Sources/WiFiLens/Channels/RecommendationReason.swift`
  - Add reason identifiers for external interference, current channel already good, insufficient improvement, and low-confidence target AP.
- Modify `WiFiLens/Sources/WiFiLens/Channels/RecommendationReasonCalculator.swift`
  - Generate reasons from recommendation score deltas and target AP confidence.
- Modify `WiFiLens/Sources/WiFiLens/Channels/ChannelQualityView.swift`
  - Display recommendation badges from the new recommendation state.
  - Keep observed score bars as observed score.
- Modify `WiFiLens/Sources/WiFiLens/App/OverviewView.swift`
  - Show no-switch-needed state when there are no recommended channels and the current channel is good enough.
- Delete `WiFiLens/Sources/WiFiLens/Channels/DynamicChannelScorer.swift`
- Delete `WiFiLens/Sources/WiFiLens/Channels/DynamicScoringModel.swift`
- Delete `WiFiLens/Tests/WiFiLensTests/DynamicChannelScorerTests.swift`
- Create `WiFiLens/Tests/WiFiLensTests/ChannelRecommendationScoringTests.swift`
- Modify `WiFiLens/WiFiLens.xcodeproj/project.pbxproj`
  - Remove deleted dynamic scorer/test references.
  - Add `ChannelRecommendationScoringTests.swift` to the WiFiLensTests target.
- Modify `docs/REGULATORY.md`
  - Replace dynamic scoring documentation with counterfactual recommendation scoring.

---

### Task 1: Remove the Rejected Dynamic Scoring Path

**Files:**
- Delete: `WiFiLens/Sources/WiFiLens/Channels/DynamicChannelScorer.swift`
- Delete: `WiFiLens/Sources/WiFiLens/Channels/DynamicScoringModel.swift`
- Delete: `WiFiLens/Tests/WiFiLensTests/DynamicChannelScorerTests.swift`
- Modify: `WiFiLens/Sources/WiFiLens/Scanner/ScannerViewModel.swift`
- Modify: `WiFiLens/WiFiLens.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: Existing `ScannerViewModel.computeChannelQualities() -> [ChannelQuality]`.
- Produces: A clean baseline where no dynamic migration predictor participates in scan updates.

- [ ] **Step 1: Remove the dynamic scorer property and call**

In `WiFiLens/Sources/WiFiLens/Scanner/ScannerViewModel.swift`, remove:

```swift
let dynamicScorer = DynamicChannelScorer()
```

And change the scan update block from:

```swift
channelQualities = computeChannelQualities()
channelQualities = dynamicScorer.computePredictedScores(channelQualities)
channelRecommendations = computeChannelRecommendations()
```

to:

```swift
channelQualities = computeChannelQualities()
channelRecommendations = computeChannelRecommendations()
```

- [ ] **Step 2: Remove dynamic scorer files from the Xcode project**

Remove these entries from `WiFiLens/WiFiLens.xcodeproj/project.pbxproj`:

```text
DynamicChannelScorer.swift in Sources
DynamicChannelScorerTests.swift in Sources
DynamicChannelScorer.swift
DynamicChannelScorerTests.swift
```

Also remove the corresponding children from the `Channels` group and `WiFiLensTests` group.

- [ ] **Step 3: Delete the rejected files**

Delete:

```text
WiFiLens/Sources/WiFiLens/Channels/DynamicChannelScorer.swift
WiFiLens/Sources/WiFiLens/Channels/DynamicScoringModel.swift
WiFiLens/Tests/WiFiLensTests/DynamicChannelScorerTests.swift
```

- [ ] **Step 4: Verify the rejected path is gone**

Run:

```sh
rg -n "DynamicChannelScorer|DynamicScoringModel|predictedScore" WiFiLens/Sources/WiFiLens WiFiLens/Tests/WiFiLensTests
```

Expected:

```text
No matches for DynamicChannelScorer or DynamicScoringModel.
```

`predictedScore` may still appear until Task 2 replaces it; remove it in Task 2.

---

### Task 2: Add Counterfactual Recommendation Fields and AP Identity

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/Channels/ChannelQualityCalculator.swift`
- Modify: `WiFiLens/Sources/WiFiLens/Scanner/ScannerViewModel.swift`
- Test: `WiFiLens/Tests/WiFiLensTests/ChannelRecommendationScoringTests.swift`
- Modify: `WiFiLens/WiFiLens.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `NetworkInterfaceInfo.bssid`, `NetworkInterfaceInfo.ssid`, `NetworkInterfaceInfo.channel`.
- Produces:
  - `ChannelQuality.recommendationScore: Int`
  - `ChannelQuality.recommendationLevel: ChannelQuality.QualityLevel`
  - `ChannelQuality.recommendationConfidence: RecommendationConfidence`
  - `ChannelQuality.recommendationState: RecommendationState`
  - `ChannelQualityCalculator.APInfo.bssid: String`
  - `ChannelQualityCalculator.APInfo.ssid: String?`
  - `ChannelQualityCalculator.TargetAP`

- [ ] **Step 1: Write failing tests for self-AP exclusion**

Create `WiFiLens/Tests/WiFiLensTests/ChannelRecommendationScoringTests.swift`:

```swift
import Testing
@testable import WiFi_Lens

struct ChannelRecommendationScoringTests {
    private func ap(
        _ channel: Int,
        _ rssi: Int,
        bssid: String,
        ssid: String? = "Home",
        band: ChannelBand = .band5GHz,
        width: String = "20"
    ) -> ChannelQualityCalculator.APInfo {
        ChannelQualityCalculator.APInfo(
            channel: channel,
            rssi: rssi,
            channelWidth: width,
            band: band.id,
            apex: 0,
            bssid: bssid,
            ssid: ssid
        )
    }

    @Test func targetAPIsExcludedFromRecommendationScore() async throws {
        let target = ChannelQualityCalculator.TargetAP(
            bssid: "aa:bb:cc:dd:ee:01",
            ssid: "Home",
            channel: 36
        )
        let result = ChannelQualityCalculator.compute(
            aps: [ap(36, -30, bssid: "aa:bb:cc:dd:ee:01")],
            currentChannel: 36,
            supportedBands: ["5"],
            targetAP: target
        )
        let current = try #require(result.first { $0.band == "5" && $0.channel == 36 })
        #expect(current.qualityScore < 100)
        #expect(current.recommendationScore == 100)
        #expect(current.recommendationConfidence == .exact)
    }

    @Test func externalAPStillReducesRecommendationScore() async throws {
        let target = ChannelQualityCalculator.TargetAP(
            bssid: "aa:bb:cc:dd:ee:01",
            ssid: "Home",
            channel: 36
        )
        let result = ChannelQualityCalculator.compute(
            aps: [
                ap(36, -30, bssid: "aa:bb:cc:dd:ee:01"),
                ap(36, -30, bssid: "aa:bb:cc:dd:ee:02", ssid: "Neighbor")
            ],
            currentChannel: 36,
            supportedBands: ["5"],
            targetAP: target
        )
        let current = try #require(result.first { $0.band == "5" && $0.channel == 36 })
        #expect(current.qualityScore < current.recommendationScore)
        #expect(current.recommendationScore < 100)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test
```

Expected:

```text
error: extra arguments at positions ... bssid, ssid
error: type 'ChannelQualityCalculator' has no member 'TargetAP'
error: value of type 'ChannelQuality' has no member 'recommendationScore'
```

- [ ] **Step 3: Add recommendation fields and target AP types**

In `ChannelQualityCalculator.swift`, replace the top of `ChannelQuality` with:

```swift
struct ChannelQuality: Identifiable {
    let channel: Int
    let band: String
    let bandDisplay: String
    let qualityScore: Int
    let qualityLevel: QualityLevel
    let recommendationScore: Int
    let recommendationLevel: QualityLevel
    let recommendationConfidence: RecommendationConfidence
    var recommendationState: RecommendationState
    let apCount: Int
    let coChannelCount: Int
    let adjacentCount: Int
    let interferenceScore: Int
    let overlapLevel: OverlapLevel
    let strongestNeighborRSSI: Int
    var isRecommended: Bool = false
    var isCurrentChannel: Bool = false
    var showInSimpleView: Bool = true

    var id: String { "\(band)-\(channel)" }

    enum RecommendationConfidence: String {
        case exact
        case ssidOnly
        case unknown
    }

    enum RecommendationState: String {
        case recommended
        case currentGood
        case insufficientImprovement
        case unavailable
    }
```

In `ChannelQualityCalculator`, replace `APInfo` with:

```swift
struct APInfo {
    let channel: Int
    let rssi: Int
    let channelWidth: String
    let band: String
    let apex: Double
    let bssid: String
    let ssid: String?
}

struct TargetAP {
    let bssid: String?
    let ssid: String?
    let channel: Int?
}
```

- [ ] **Step 4: Add target AP matching**

Add this helper inside `ChannelQualityCalculator`:

```swift
private static func isTargetAP(_ ap: APInfo, targetAP: TargetAP?) -> Bool {
    guard let targetAP else { return false }
    if let bssid = targetAP.bssid, !bssid.isEmpty, bssid != "unknown" {
        return ap.bssid.caseInsensitiveCompare(bssid) == .orderedSame
    }
    if let targetSSID = targetAP.ssid, !targetSSID.isEmpty,
       let apSSID = ap.ssid, !apSSID.isEmpty {
        return apSSID == targetSSID
    }
    return false
}

private static func confidence(for targetAP: TargetAP?) -> ChannelQuality.RecommendationConfidence {
    guard let targetAP else { return .unknown }
    if let bssid = targetAP.bssid, !bssid.isEmpty, bssid != "unknown" { return .exact }
    if let ssid = targetAP.ssid, !ssid.isEmpty { return .ssidOnly }
    return .unknown
}
```

- [ ] **Step 5: Update `compute` signature**

Change:

```swift
static func compute(aps: [APInfo], currentChannel: Int? = nil, supportedBands: Set<String> = ["24", "5", "6"]) -> [ChannelQuality]
```

to:

```swift
static func compute(
    aps: [APInfo],
    currentChannel: Int? = nil,
    supportedBands: Set<String> = ["24", "5", "6"],
    targetAP: TargetAP? = nil
) -> [ChannelQuality]
```

Inside the loop for each band, add:

```swift
let externalBandAPs = bandAPs.filter { !isTargetAP($0, targetAP: targetAP) }
let recConfidence = confidence(for: targetAP)
```

Compute observed and recommendation scores separately:

```swift
let interference = computeInterference(channel: ch, band: band, aps: bandAPs)
let score = max(0, min(100, 100 - interference))
let recommendationInterference = computeInterference(channel: ch, band: band, aps: externalBandAPs)
let recommendationScore = max(0, min(100, 100 - recommendationInterference))
```

Construct `ChannelQuality` with:

```swift
qualityScore: score,
qualityLevel: .from(score: score),
recommendationScore: recommendationScore,
recommendationLevel: .from(score: recommendationScore),
recommendationConfidence: recConfidence,
recommendationState: .unavailable,
```

- [ ] **Step 6: Update ScannerViewModel AP construction**

In `computeChannelQualities()`, define:

```swift
let currentWiFi = networkInfo.first(where: { $0.ssid != nil })
let currentChannel = currentWiFi?.channel
let targetAP = ChannelQualityCalculator.TargetAP(
    bssid: currentWiFi?.bssid,
    ssid: currentWiFi?.ssid,
    channel: currentWiFi?.channel
)
```

When constructing `APInfo`, add:

```swift
bssid: nw.bssid,
ssid: nw.ssid
```

Call:

```swift
return ChannelQualityCalculator.compute(
    aps: aps,
    currentChannel: currentChannel,
    supportedBands: Set(supportedBands.map(\.id)),
    targetAP: targetAP
)
```

- [ ] **Step 7: Update existing test helpers**

In `ChannelQualityCalculatorTests.swift`, update the helper to include identity:

```swift
private func ap(
    _ channel: Int,
    _ rssi: Int,
    width: TestChannelWidth = .mhz20,
    band: ChannelBand = .band5GHz,
    apex: Double = 0,
    bssid: String = UUID().uuidString,
    ssid: String? = "Test"
) -> ChannelQualityCalculator.APInfo {
    ChannelQualityCalculator.APInfo(
        channel: channel,
        rssi: rssi,
        channelWidth: width.rawValue,
        band: band.id,
        apex: apex,
        bssid: bssid,
        ssid: ssid
    )
}
```

- [ ] **Step 8: Add the new test file to Xcode project**

Add `ChannelRecommendationScoringTests.swift` as:

```text
PBXFileReference in WiFiLensTests group
PBXBuildFile assigned to WiFiLensTests target
entry in WiFiLensTests Sources build phase
```

Follow the existing pattern for `ChannelQualityCalculatorTests.swift`.

- [ ] **Step 9: Run tests**

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test
```

Expected:

```text
TEST SUCCEEDED
```

---

### Task 3: Implement Conservative Recommendation Selection

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/Channels/ChannelQualityCalculator.swift`
- Test: `WiFiLens/Tests/WiFiLensTests/ChannelRecommendationScoringTests.swift`

**Interfaces:**
- Consumes: `ChannelQuality.recommendationScore`.
- Produces: `ChannelQuality.isRecommended` and `ChannelQuality.recommendationState` using conservative thresholds.

- [ ] **Step 1: Add failing tests for threshold behavior**

Append to `ChannelRecommendationScoringTests`:

```swift
@Test func currentGoodProducesNoRecommendation() async throws {
    let target = ChannelQualityCalculator.TargetAP(
        bssid: "aa:bb:cc:dd:ee:01",
        ssid: "Home",
        channel: 36
    )
    let result = ChannelQualityCalculator.compute(
        aps: [ap(36, -80, bssid: "aa:bb:cc:dd:ee:01")],
        currentChannel: 36,
        supportedBands: ["5"],
        targetAP: target
    )
    #expect(result.filter { $0.band == "5" && $0.isRecommended }.isEmpty)
    let current = try #require(result.first { $0.band == "5" && $0.channel == 36 })
    #expect(current.recommendationState == .currentGood)
}

@Test func recommendsOnlyWhenCandidateClearlyImprovesCurrent() async throws {
    let target = ChannelQualityCalculator.TargetAP(
        bssid: "aa:bb:cc:dd:ee:01",
        ssid: "Home",
        channel: 36
    )
    let result = ChannelQualityCalculator.compute(
        aps: [
            ap(36, -30, bssid: "aa:bb:cc:dd:ee:01"),
            ap(36, -30, bssid: "aa:bb:cc:dd:ee:02", ssid: "Neighbor"),
            ap(40, -100, bssid: "aa:bb:cc:dd:ee:03", ssid: "Distant")
        ],
        currentChannel: 36,
        supportedBands: ["5"],
        targetAP: target
    )
    let recommended = result.filter { $0.band == "5" && $0.isRecommended }
    #expect(recommended.count <= 2)
    #expect(recommended.contains { $0.channel == 40 })
    #expect(recommended.allSatisfy { $0.recommendationState == .recommended })
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test
```

Expected:

```text
Expectation failed: result.filter { ... }.isEmpty
```

or:

```text
Expectation failed: current.recommendationState == .currentGood
```

- [ ] **Step 3: Add recommendation configuration**

Inside `ChannelQualityCalculator`, add:

```swift
private enum RecommendationConfig {
    static let currentGoodEnoughScore = 80
    static let minimumImprovement = 10
    static let minimumCandidateScore = 70
    static let maxRecommendationsPerBand = 2
}
```

- [ ] **Step 4: Replace top-2 selection logic**

Replace the current eligible recommendation block with:

```swift
let currentRecommendationScore = scored
    .first { $0.channel == currentChannel && $0.band == band }?
    .recommendationScore

let currentIsGood = (currentRecommendationScore ?? 100) >= RecommendationConfig.currentGoodEnoughScore

let eligible: [ChannelQuality]
if currentIsGood {
    eligible = []
} else if let currentRecommendationScore {
    eligible = Array(scored
        .filter { !$0.isCurrentChannel }
        .filter { $0.recommendationScore >= RecommendationConfig.minimumCandidateScore }
        .filter { $0.recommendationScore - currentRecommendationScore >= RecommendationConfig.minimumImprovement }
        .sorted { $0.recommendationScore > $1.recommendationScore }
        .prefix(RecommendationConfig.maxRecommendationsPerBand))
} else {
    eligible = Array(scored
        .filter { $0.recommendationScore >= RecommendationConfig.minimumCandidateScore }
        .sorted { $0.recommendationScore > $1.recommendationScore }
        .prefix(RecommendationConfig.maxRecommendationsPerBand))
}

let recIDs = Set(eligible.map(\.id))
results += scored.map { q in
    var q = q
    q.isRecommended = recIDs.contains(q.id)
    if q.isRecommended {
        q.recommendationState = .recommended
    } else if q.isCurrentChannel && currentIsGood {
        q.recommendationState = .currentGood
    } else if currentRecommendationScore != nil {
        q.recommendationState = .insufficientImprovement
    } else {
        q.recommendationState = .unavailable
    }
    q.showInSimpleView = q.isCurrentChannel || q.isRecommended || q.apCount > 0
    return q
}
```

- [ ] **Step 5: Sort by recommendation score**

Replace the final sort with:

```swift
return results.sorted { a, b in
    if a.isCurrentChannel != b.isCurrentChannel { return a.isCurrentChannel }
    if a.isRecommended != b.isRecommended { return a.isRecommended }
    if a.recommendationScore != b.recommendationScore {
        return a.recommendationScore > b.recommendationScore
    }
    if a.qualityScore != b.qualityScore { return a.qualityScore > b.qualityScore }
    if a.band != b.band { return a.band < b.band }
    return a.channel < b.channel
}
```

- [ ] **Step 6: Run tests**

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test
```

Expected:

```text
TEST SUCCEEDED
```

---

### Task 4: Propagate Recommendation Score Through Regulatory and UI Models

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/Regulatory/ChannelRecommendation.swift`
- Modify: `WiFiLens/Sources/WiFiLens/Regulatory/RegulatoryFilter.swift`
- Modify: `WiFiLens/Sources/WiFiLens/App/OverviewView.swift`
- Modify: `WiFiLens/Sources/WiFiLens/Channels/ChannelQualityView.swift`
- Modify: `WiFiLens/Sources/WiFiLens/Channels/RecommendationReason.swift`
- Modify: `WiFiLens/Sources/WiFiLens/Channels/RecommendationReasonCalculator.swift`
- Modify: `WiFiLens/Sources/WiFiLens/Resources/Localizable.xcstrings`
- Test: `WiFiLens/Tests/WiFiLensTests/RegulatoryFilterTests.swift`

**Interfaces:**
- Consumes: `ChannelQuality.recommendationScore`, `ChannelQuality.recommendationState`, `ChannelQuality.recommendationConfidence`.
- Produces:
  - `ChannelRecommendation.recommendationScore`
  - `ChannelRecommendation.recommendationLevel`
  - `ChannelRecommendation.recommendationConfidence`
  - `ChannelRecommendation.recommendationState`
  - `ChannelRecommendation.isRecommended`

- [ ] **Step 1: Add failing regulatory propagation test**

Add to `RegulatoryFilterTests.swift`:

```swift
@Test func regulatoryFilterSortsRecommendedChannelsByRecommendationScore() async throws {
    let highObservedLowRecommendation = makeQuality(
        channel: 36,
        band: "5",
        score: 95,
        recommendationScore: 72
    )
    let lowerObservedHighRecommendation = makeQuality(
        channel: 40,
        band: "5",
        score: 85,
        recommendationScore: 90
    )
    let input = RegulatoryFilter.FilterInput(
        rfResults: [highObservedLowRecommendation, lowerObservedHighRecommendation],
        inferredRegion: RegionInferenceResult(
            domain: .US,
            confidence: .high,
            contributions: [],
            conflicts: []
        ),
        deviceSupportedChannels: [],
        deviceCapabilities: .default,
        userClassificationOverrides: nil
    )
    let result = RegulatoryFilter.apply(to: input)
    #expect(result.first { $0.channel == 40 }?.recommendationScore == 90)
    #expect(result.first?.channel == 40)
}
```

Update the local `makeQuality` helper in that test file to accept:

```swift
recommendationScore: Int? = nil
```

and pass:

```swift
recommendationScore: recommendationScore ?? score,
recommendationLevel: .from(score: recommendationScore ?? score),
recommendationConfidence: .exact,
recommendationState: score >= 70 ? .recommended : .insufficientImprovement,
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test
```

Expected:

```text
error: value of type 'ChannelRecommendation' has no member 'recommendationScore'
```

- [ ] **Step 3: Update `ChannelRecommendation`**

In `ChannelRecommendation.swift`, add fields:

```swift
let recommendationScore: Int
let recommendationLevel: ChannelQuality.QualityLevel
let recommendationConfidence: ChannelQuality.RecommendationConfidence
var recommendationState: ChannelQuality.RecommendationState
```

Change:

```swift
var isRecommended: Bool { rfIsRecommended }
```

to:

```swift
var isRecommended: Bool { recommendationState == .recommended }
```

In `init(from rf: ChannelQuality)`, add:

```swift
self.recommendationScore = rf.recommendationScore
self.recommendationLevel = rf.recommendationLevel
self.recommendationConfidence = rf.recommendationConfidence
self.recommendationState = rf.recommendationState
```

- [ ] **Step 4: Update regulatory sort**

In `RegulatoryFilter.apply`, replace RF-recommended sort priority with recommendation state:

```swift
if a.isRecommended != b.isRecommended {
    return a.isRecommended
}
if a.recommendationScore != b.recommendationScore {
    return a.recommendationScore > b.recommendationScore
}
if a.rfScore != b.rfScore {
    return a.rfScore > b.rfScore
}
```

- [ ] **Step 5: Update badges and overview filters**

In `ChannelQualityView.swift`, replace:

```swift
if channel.rfIsRecommended { badge(...) }
if channel.rfIsRecommended && !channel.recommendationReasons.isEmpty {
```

with:

```swift
if channel.isRecommended { badge(...) }
if channel.isRecommended && !channel.recommendationReasons.isEmpty {
```

In `OverviewView.swift`, keep:

```swift
viewModel.channelRecommendations.filter(\.isRecommended)
```

because `isRecommended` now reflects counterfactual recommendations.

- [ ] **Step 6: Add no-switch-needed copy**

Add localized keys to `WiFiLens/Sources/WiFiLens/Resources/Localizable.xcstrings`:

```json
"overview.channel_advice.current_good.title": {
  "extractionState": "manual",
  "localizations": {
    "en": {
      "stringUnit": {
        "state": "translated",
        "value": "Current channel is good"
      }
    }
  }
},
"overview.channel_advice.current_good.message": {
  "extractionState": "manual",
  "localizations": {
    "en": {
      "stringUnit": {
        "state": "translated",
        "value": "No channel change is needed right now."
      }
    }
  }
}
```

Then update the channel advice card in `OverviewView.swift` to display this state when `recommendedChannels.isEmpty` and `current.recommendationState == .currentGood`.

- [ ] **Step 7: Run tests**

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test
```

Expected:

```text
TEST SUCCEEDED
```

---

### Task 5: Update Documentation and Final Verification

**Files:**
- Modify: `docs/REGULATORY.md`
- Modify: `docs/TESTING.md`

**Interfaces:**
- Consumes: Implemented counterfactual recommendation model.
- Produces: Documentation matching the shipped behavior.

- [ ] **Step 1: Replace dynamic scoring docs**

In `docs/REGULATORY.md`, replace the `Dynamic Channel Scoring` section with:

```markdown
## Counterfactual Channel Recommendation

WiFi Lens recommends channels for the currently connected Wi-Fi router/AP.

The pipeline keeps observed environment scoring separate from recommendation scoring:

| Score | Meaning |
|-------|---------|
| `observedScore` / `rfScore` | Current RF environment, including every scanned AP |
| `recommendationScore` | External interference score after excluding the current target AP |

Recommendation selection uses `recommendationScore`, not raw observed emptiness. This prevents a recommendation from invalidating itself after the user moves the router to the recommended channel.

The app recommends no switch when the current channel is already good enough or when the best candidate does not improve the current channel by the configured margin.
```

- [ ] **Step 2: Update test coverage docs**

In `docs/TESTING.md`, add `ChannelRecommendationScoringTests` to the covered pure-logic modules list.

- [ ] **Step 3: Verify no rejected dynamic model remains**

Run:

```sh
rg -n "DynamicChannelScorer|DynamicScoringModel|migration pressure|predictedScore" WiFiLens/Sources/WiFiLens WiFiLens/Tests/WiFiLensTests docs
```

Expected:

```text
No matches.
```

- [ ] **Step 4: Run full app tests**

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test
```

Expected:

```text
TEST SUCCEEDED
```

- [ ] **Step 5: Run debug build**

Run:

```sh
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build
```

Expected:

```text
BUILD SUCCEEDED
```

---

## Self-Review

- Spec coverage: The plan covers target AP identification, observed vs recommendation scores, conservative thresholds, regulatory propagation, UI semantics, rejected non-goals, and tests.
- Placeholder scan: The plan contains no placeholder markers or undefined future work.
- Type consistency: `recommendationScore`, `recommendationLevel`, `recommendationConfidence`, `recommendationState`, `TargetAP`, `APInfo.bssid`, and `APInfo.ssid` are introduced before later tasks consume them.
- Repository constraint check: The upstream writing-plans skill recommends commit steps, but this repository explicitly forbids commits without user instruction, so this plan omits commit steps.
