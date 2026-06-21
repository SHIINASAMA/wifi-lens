# ProFeaturePlaceholderView Design Document

## Overview

Add Pro feature guidance entry points to the OSS version of WiFi Lens, allowing users to understand the additional value provided by the Pro version without interrupting core workflows.

## Problem Statement

The connection between the OSS and Pro versions is currently too weak. If Pro-only features have no visible entry points in the OSS version, users won't be aware of the Pro version's existence or understand its additional value.

## Design Goals

1. Retain Pro feature entry points in the OSS version
2. Display entry points as Pro guidance pages via conditional compilation
3. No pop-ups, no interrupting core functionality
4. Clearly communicate the boundary between OSS and Pro versions
5. Guide users to the App Store rather than forcefully interrupting them

## User Value Proposition

```
OSS version solves current analysis problems.
Pro version solves long-term monitoring, history tracking, and report export problems.
```

## Technical Feasibility

**High** — The project already uses `#if PRO` / `#if OSS` conditional compilation. Adding new components and conditional compilation blocks requires minimal effort.

## Design Approach

### Approach Comparison

| Approach | Pros | Cons | Recommended |
|----------|------|------|-------------|
| A: Inline Card Placeholder | Doesn't interrupt workflow, contextually relevant | Requires integration at each location | ✅ |
| B: Dedicated Pro Features Page | Centralized display, easy maintenance | Requires new sidebar item, less contextually relevant | |
| C: Modal Popup | Clear presentation, can include pricing | Interrupts workflow (doesn't meet requirements) | |

**Recommended Approach: A (Inline Card Placeholder)**

### ProFeaturePlaceholderView Component Design

```swift
struct ProFeaturePlaceholderView: View {
    let featureName: String
    let featureDescription: String
    let featureIcon: String
    
    var body: some View {
        VStack(spacing: 12) {
            // Feature icon
            Image(systemName: featureIcon)
                .font(.system(size: 36))
                .foregroundColor(.accentColor)
            
            // Feature name
            Text(featureName)
                .font(.title3)
                .fontWeight(.semibold)
            
            // Feature description
            Text(featureDescription)
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // PRO badge
            Text("PRO")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor)
                .clipShape(Capsule())
            
            // Learn more button
            Button("Learn More") {
                openAppStore()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassBackground(.regular, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func openAppStore() {
        if let url = URL(string: ProConstants.appStoreURL) {
            NSWorkspace.shared.open(url)
        }
    }
}
```

### Integration Points

#### 1. Recording Mode (Spectrum Page)

In `ContentView.swift`'s `contentArea`, the OSS version displays a placeholder card instead of the recording view:

```swift
#else
ProFeaturePlaceholderView(
    featureName: "Session Recording",
    featureDescription: "Record and replay Wi-Fi sessions to analyze signal trends over time",
    featureIcon: "record.circle"
)
#endif
```

**Note:** Currently `ContentView.swift` displays `dashboardContent` directly in the `#else` branch. This should be modified to show `ProFeaturePlaceholderView` when users attempt to switch to recording mode.

#### 2. Markdown Export (Export Menu)

In `WiFiLensApp.swift`'s export menu, disable Markdown export and add a tooltip:

```swift
#if OSS
Button(String(localized: "export.snapshot_markdown", comment: "Export as Markdown report")) { }
    .disabled(true)
    .help(String(localized: "pro.markdown.unavailable", comment: "Tooltip for unavailable Markdown export"))
#endif
```

#### 3. App Store URL

Define the constant in `ProFeaturePlaceholderView.swift`:

```swift
enum ProConstants {
    static let appStoreURL = "https://apps.apple.com/app/wifi-lens-pro/idXXXXXXXXXX"
}
```

### Visual Design Specifications

- Use existing `.glassBackground(.regular, in: RoundedRectangle(cornerRadius: 12))`
- 16pt padding, consistent with other cards
- Feature icon: SF Symbols (e.g., `record.circle` for recording)
- Title: Feature name
- Description: Brief explanation of Pro value
- Badge: "PRO" with accent color
- Button: "Learn More" opens App Store

### Localization

All strings use `String(localized:comment:)` format:

```swift
String(localized: "pro.recording.title", comment: "Pro recording feature title")
String(localized: "pro.recording.description", comment: "Pro recording feature description")
String(localized: "pro.markdown.title", comment: "Pro markdown export feature title")
String(localized: "pro.markdown.description", comment: "Pro markdown export feature description")
String(localized: "pro.learn_more", comment: "Learn more button for Pro features")
```

### Testing Strategy

1. Unit tests: ProFeaturePlaceholderView rendering tests
2. UI tests: Verify OSS version shows placeholder, Pro version does not
3. Manual testing: Verify App Store redirect works correctly

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| App Store URL changes | Extract URL as constant for easy updates |
| Incomplete localization | Provide English first, add Chinese/Japanese later |
| Pro version build affected | Use conditional compilation, Pro version code unchanged |

## Next Steps

1. Implement ProFeaturePlaceholderView component
2. Integrate into Export menu Markdown item
3. Add localization strings
4. Verify build
