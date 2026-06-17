# Regulatory Pipeline

Multi-stage pipeline that infers the user's regulatory domain from multiple signals, then filters and classifies channel recommendations based on region rules and device hardware capabilities.

## Architecture

```
WiFiNetwork[] (IE country codes)
System Locale (region identifier)
Hardware Supported Channels (CoreWLAN)  ─┐
                                          ▼
                              RegionInferenceEngine
                                   │
                                   ▼
                           RegionInferenceResult
                     (domain + confidence + contributions)
                                   │
                                   ▼
        RegulatoryFilter — 5-stage pipeline
          1. Wrap ChannelQuality → ChannelRecommendation
          2. Apply region rules (allowed/restricted/DFS/indoor/AFC)
          3. Device compatibility check
          4. User classification overrides
          5. Sort by tier → RF score → band → channel
                                   │
                                   ▼
                        [ChannelRecommendation]
                                   │
                                   ▼
                           OverviewView / ChannelQualityView
```

## Data Flow

`ScannerViewModel` gathers channel qualities via `ChannelQualityCalculator`, then passes them through `DynamicChannelScorer.computePredictedScores()` to produce predicted scores that model future channel state. The predicted-scored qualities are then passed along with network IEs, device capabilities, and user preferences to `RegulatoryPipeline.computeRecommendations()`. The pipeline returns classified `[ChannelRecommendation]` for display in the channel quality views.

## Key Types

| File | Type | Purpose |
|------|------|---------|
| `DynamicChannelScorer.swift` | `final class` | Predictive scoring model — tracks AP history, estimates migration pressure, computes predicted scores |
| `RegulatoryPipeline.swift` | `final class` | `@Observable` orchestrator — collects inputs, calls inference + filter, exposes `inferredRegion` |
| `RegionInferenceEngine.swift` | `enum` | Multi-source region inference with confidence scoring |
| `RegulatoryFilter.swift` | `enum` | 5-stage classification pipeline |
| `RegulatoryDatabase.swift` | `enum` | Static per-region channel rules (US/JP/CN/EU, 2.4/5/6 GHz) |
| `RegulatoryDomain.swift` | `enum` | `US`/`JP`/`CN`/`EU`/`unknown` with locale-based mapping |
| `DeviceCompatibilityFilter.swift` | `enum` | Checks PHY/band/DFS/6 GHz support per device |
| `ChannelRecommendation.swift` | `struct` | Output model: RF score + regulatory classification + restriction reasons |

## Region Inference

`RegionInferenceEngine.infer()` resolves the regulatory domain from up to four sources, in priority order:

| Source | Method | Confidence |
|--------|--------|------------|
| User override | Manual domain selection | `.high` |
| Hardware channels | Jaccard-like fingerprint matching against known region channel sets | `.medium`–`.high` |
| AP beacon country IE | Consensus among visible AP country codes | `.medium`–`.low` |
| System locale | `Locale.region` → `RegulatoryDomain.from(localeRegionCode:)` | `.low` |

### Resolution Logic

1. **User override** — always wins, recorded with `.high` confidence.
2. **Channel fingerprint + AP consensus agree** — `.high` confidence.
3. **Channel fingerprint alone** — `.medium` (hardware/driver is authoritative). If AP disagrees, a conflict is recorded but the hardware wins.
4. **AP consensus alone** — `.medium` (with consensus) / `.low` (without). AP country codes can be wrong (flashed routers, etc.).
5. **Locale alone** — `.low`.
6. **Nothing** — `.unknown` with `.low` confidence.

### Channel Fingerprint

For each known domain (US/JP/CN/EU), builds an expected channel set from `RegulatoryDatabase`, then computes a Jaccard-like score: `|intersection| / |smaller set|`. The domain with the best score wins if > 0.3.

Special signals:
- **JP bonus**: Channel 14 (2.4 GHz) is uniquely Japanese; presence adds +0.15 to JP score.
- **CN negative**: No DFS channels in CN 5 GHz allocation; if no DFS channels are available and the best score is < 0.5, CN is re-evaluated as a candidate.

## Filter Pipeline

`RegulatoryFilter.apply()` runs five stages:

### Stage 1: Wrap
Each `ChannelQuality` is wrapped into a `ChannelRecommendation`, preserving the original RF score/level/AP counts verbatim.

### Stage 2: Region rules
For each recommendation, looks up `RegulatoryDatabase.rules[region][band]`:
- **Not in database** → `.restricted` (`REGION_UNKNOWN`)
- **Channel not allowed** → `.restricted` (`REGION_BLOCKED`)
- **DFS channel** → `.advanced` (`DFS`)
- **Indoor-only** → `.advanced` or lower (`INDOOR_ONLY`)
- **AFC-required** → `.restricted` (`AFC_REQUIRED`)
- **Low confidence region** → downgrade `.recommended` → `.advanced` (`REGION_LOW_CONFIDENCE`)
- Other metadata flags (`radarSensitive`, `requiresCAC`) are recorded as restriction reasons but do not change classification.

### Stage 3: Device compatibility
`DeviceCompatibilityFilter.check()` verifies:
1. Channel is in hardware's supported set
2. 6 GHz channels require 6 GHz hardware support
3. AFC-required channels not supported
4. DFS channels require DFS hardware support

If incompatible → `.restricted` (`DEVICE_INCOMPATIBLE`).

### Stage 4: User overrides
Manual classification overrides are applied on top.

### Stage 5: Sort
Current channel first, then by classification tier (recommended > advanced > restricted), then RF-recommended first, then score descending, then band/channel.

Restricted channels are hidden by default (`showInSimpleView = false`).

## Regulatory Database

`RegulatoryDatabase` is a static, data-driven lookup table. No business logic — pure channel data sourced from public allocation tables.

| Domain | 2.4 GHz | 5 GHz | 6 GHz |
|--------|---------|-------|-------|
| US (FCC) | 1–11 | 36–165 (DFS on 52–144) | 1–181 LPI (no AFC) |
| JP (MIC) | 1–14 (ch14: 802.11b only) | 36–144 (DFS on W53/W56) | 1–93 LPI |
| CN (SRRC) | 1–13 | 36–48, 149–165 (no DFS) | None |
| EU (ETSI) | 1–13 | 36–144 (DFS on 52–144) | 1–93 LPI |

`RegulatoryChannelMeta` attaches per-channel caveats (DFS, radar sensitivity, CAC, indoor-only, max EIRP, AFC, Wi-Fi 6E/7 availability).

## Dynamic Channel Scoring

The recommendation algorithm faces a feedback loop: recommending an optimal channel changes the environment when users follow the recommendation. `DynamicChannelScorer` addresses this by predicting future channel state instead of relying on static snapshots.

### Model

1. **AP count history** — Each channel maintains a rolling window of 5 scan results, smoothed via EMA (α=0.4). This captures occupancy trends (growing, stable, declining).

2. **Migration pressure** — Channels recommended in the previous scan are assigned a migration pressure factor (30%). This models the expected influx of APs from users who act on the recommendation.

3. **Predicted score** — Computed as: `currentScore - trendPenalty - migrationPenalty`. The predicted score is used for top-2 recommendation selection (replacing raw RF score).

### Effect

- Recently recommended channels are automatically penalized, preventing repeated self-defeating recommendations.
- Channels with rising AP trends are down-ranked before they become congested.
- The model self-stabilizes: once a channel is no longer recommended, the penalty decays over subsequent scans.

## Key Patterns

- **Decoupled RF + regulatory**: `ChannelQualityCalculator` is never modified by the regulatory pipeline — RF scoring and regulatory filtering are completely independent.
- **Verbatim RF preservation**: Original RF score, level, and AP counts are preserved as-is in `ChannelRecommendation.rfScore`/`rfLevel`/`apCount`. The regulatory layer only adds classification and restrictions.
- **Confidence downgrade**: Low-confidence region inference downgrades all `.recommended` channels to `.advanced` rather than `.restricted`, so users still see useful recommendations with a caveat.
- **Comparable sort order**: `ChannelRecommendation.Classification.order` (recommended=2, advanced=1, restricted=0) enables tiered sorting by simple integer comparison.
