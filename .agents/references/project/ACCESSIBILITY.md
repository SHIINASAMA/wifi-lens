# Accessibility

This document tracks the app's accessibility implementation status across all App Store Connect categories. Only macOS-supported features are included.

## App Store Connect Categories

| Category | macOS Support | Status | Notes |
|----------|:---:|:---:|------|
| Dark Mode | ✅ Native | ✅ **Done** | Three-way picker (System/Light/Dark), `preferredColorScheme` |
| Keyboard Navigation | ✅ Native | ✅ **Done** | Cmd+1~6 for sidebar pages, Cmd+, for Settings, Cmd+Shift+E for export |
| VoiceOver | ✅ Native | ✅ **Done** | Controls labeled, Canvas charts have descriptive accessibility labels |
| Voice Control | ✅ Native | ✅ **Done** | VoiceOver labels covered; Canvas interactive via system hit testing |
| Larger Text | ❌ Incomplete | ❌ **Skipped** | macOS SwiftUI `DynamicTypeSize` does not track system setting; `@ScaledMetric` is inert on macOS |
| Differentiate Without Color | ✅ Universal | ✅ **Done** | Data labels on Canvas curves, dBm text + quality text labels augment color |
| Sufficient Contrast | ✅ Universal | ✅ **Done** | System Materials provide adequate contrast; verified via Accessibility Inspector |
| Reduce Motion | ✅ Native | ✅ **Done** | All `.animation(.bouncy)` picker transitions, `withAnimation` calls, and `displayRSSI` Gaussian interpolation skip when Reduce Motion is enabled |
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
