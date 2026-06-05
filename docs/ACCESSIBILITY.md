# Accessibility

This document tracks the app's accessibility implementation status across all App Store Connect categories. Only macOS-supported features are included.

## App Store Connect Categories

| Category | macOS Support | Status | Notes |
|----------|:---:|:---:|------|
| Dark Mode | ✅ Native | ✅ **Done** | Three-way picker (System/Light/Dark), `preferredColorScheme` |
| VoiceOver | ✅ Native | ⚠️ **Partial** | Controls labeled; Canvas charts lack accessibility representation |
| Voice Control | ✅ Native | ⚠️ **Partial** | Same gap as VoiceOver — Canvas hit targets not exposed |
| Larger Text | ❌ Incomplete | ❌ **Skipped** | macOS SwiftUI `DynamicTypeSize` does not track system setting; `@ScaledMetric` is inert on macOS |
| Differentiate Without Color | ✅ Universal | ⚠️ **Partial** | Quality labels + RSSI values augment color; Canvas curves need legend overlay |
| Sufficient Contrast | ✅ Universal | ✅ **Done** | System Materials provide adequate contrast; verified via Accessibility Inspector |
| Reduce Motion | ✅ Native | ✅ **Done** | Gaussian curve animations, `.bouncy` transitions need motion-respecting guard |
| Captions / Audio Description | N/A | — | No video/audio content |

## Architecture

### Reduce Motion

When enabled via System Settings → Accessibility → Display → Reduce motion, the app should:

- Replace `.animation(.bouncy)` with `.animation(.none)` or no animation
- Skip `displayRSSI` Gaussian curve interpolation — jump directly to target value
- Suppress `contentTransition(.opacity)` effects
- Disable Sparkle update sheet animation (if Sparkle respects system setting, no action needed)

Detection: `@Environment(\.accessibilityReduceMotion)` on any SwiftUI `View`.

Implementation approach: add a `@Environment(\.accessibilityReduceMotion)` check at View level where animations are defined, branching to `.animation(.none, value: ...)` when enabled.

### Differentiate Without Color

Gaps identified:

| Location | Current | Fix |
|----------|---------|-----|
| Spectrum chart (Canvas) | Gaussian curves colored by SSID, no legend | Add overlay legend with SSID labels |
| BLE trend chart | Raw/smoothed lines colored only | Add pattern distinction (dashed/solid) or legend |
| Quality level cards | Hex color + text label ✅ | Already good |
| RSSI bars | Color + dBm value ✅ | Already good |

### VoiceOver / Canvas

The Chart engine renders via `Canvas` / `context.draw(Text(...))`. VoiceOver cannot read Canvas content. Mitigations:

- Add `.accessibilityElement(children: .ignore)` + `.accessibilityLabel(...)` on each band chart, describing network count and strongest signal
- NativeTableView (AppKit `NSTableView`) has built-in accessibility; verify sort/select state is conveyed
- Band chart expand button has `.accessibilityLabel` ✅

## Testing

```sh
# Accessibility Inspector
open -a "Accessibility Inspector"

# Verify:
# 1. Every control has a label in the inspector tree
# 2. Canvas charts have a descriptive accessibility label
# 3. Reduce Motion toggle in System Settings suppresses animations
```

## Related Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) — App architecture and key patterns
- [CHARTS.md](CHARTS.md) — Chart engine rendering pipeline
- [TESTING.md](TESTING.md) — UI test setup, accessibility identifiers
