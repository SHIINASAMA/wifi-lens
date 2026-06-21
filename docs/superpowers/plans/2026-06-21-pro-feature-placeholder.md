# ProFeaturePlaceholderView Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a generic ProFeaturePlaceholderView component to display Pro feature guidance in the OSS version.

**Architecture:** Single component + two integration points (Spectrum recording mode, Export menu Markdown), using `#if OSS` conditional compilation.

**Tech Stack:** SwiftUI, macOS 14+, Swift 6.0

## Global Constraints

- macOS 14+, Swift 6.0
- Use `#if PRO` / `#if OSS` conditional compilation
- Follow existing design patterns: `.glassBackground(.regular, in: RoundedRectangle(cornerRadius: 12))`
- Localization uses `String(localized:comment:)` format

---

### Task 1: Create ProFeaturePlaceholderView Component

**Files:**
- Create: `WiFiLens/Sources/WiFiLens/App/ProFeaturePlaceholderView.swift`

**Interfaces:**
- Consumes: None
- Produces: `ProFeaturePlaceholderView` (public struct), `ProConstants` (enum)

- [ ] **Step 1: Create ProFeaturePlaceholderView.swift**

```swift
import SwiftUI

enum ProConstants {
    static let appStoreURL = "https://apps.apple.com/app/wifi-lens-pro/idXXXXXXXXXX"
}

struct ProFeaturePlaceholderView: View {
    let featureName: String
    let featureDescription: String
    let featureIcon: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: featureIcon)
                .font(.system(size: 36))
                .foregroundColor(.accentColor)
                .accessibilityHidden(true)
            
            Text(featureName)
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(featureDescription)
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            Text("PRO")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor)
                .clipShape(Capsule())
            
            Button(String(localized: "pro.learn_more", comment: "Learn more button for Pro features")) {
                openAppStore()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassBackground(.regular, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: String(localized: "pro.accessibility.feature_fmt", comment: "Pro feature accessibility label"), featureName))
    }
    
    private func openAppStore() {
        if let url = URL(string: ProConstants.appStoreURL) {
            NSWorkspace.shared.open(url)
        }
    }
}
```

- [ ] **Step 2: Add localization strings**

Add to `Resources/Localizable.xcstrings`:
- `pro.learn_more` → "Learn More" (en), "詳細を見る" (ja), "了解更多" (zh-Hans)
- `pro.accessibility.feature_fmt` → "%@ (Pro Feature)" (en), "%@ (Pro機能)" (ja), "%@ (Pro功能)" (zh-Hans)

- [ ] **Step 3: Commit**

```bash
git add WiFiLens/Sources/WiFiLens/App/ProFeaturePlaceholderView.swift
git commit -m "feat: add ProFeaturePlaceholderView component for OSS-to-Pro guidance"
```

---

### Task 2: Integrate into Export Menu Markdown Item

**Files:**
- Modify: `WiFiLens/Sources/WiFiLens/WiFiLensApp.swift:401-406`

**Interfaces:**
- Consumes: None
- Produces: None

- [ ] **Step 1: Modify the Markdown export item in the export menu**

Change the `#if PRO` block to handle both OSS and PRO:

```swift
#if PRO
        Button(String(localized: "export.snapshot_markdown", comment: "Export as self-contained Markdown report")) {
            exportSnapshotMarkdown()
        }
        .keyboardShortcut("m", modifiers: [.command, .shift])
#else
        Button(String(localized: "export.snapshot_markdown", comment: "Export as Markdown report")) { }
            .disabled(true)
            .help(String(localized: "pro.markdown.unavailable", comment: "Tooltip for unavailable Markdown export"))
#endif
```

- [ ] **Step 2: Add localization strings**

Add to `Resources/Localizable.xcstrings`:
- `pro.markdown.unavailable` → "Available in WiFi Lens Pro" (en), "WiFi Lens Pro で利用可能" (ja), "WiFi Lens Pro 提供此功能" (zh-Hans)

- [ ] **Step 3: Commit**

```bash
git add WiFiLens/Sources/WiFiLens/WiFiLensApp.swift
git commit -m "feat: disable Markdown export in OSS with Pro availability tooltip"
```

---

### Task 3: Verify Build

**Files:**
- None

**Interfaces:**
- None

- [ ] **Step 1: Build OSS version**

```bash
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build
```

- [ ] **Step 2: Run tests**

```bash
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests
```

- [ ] **Step 3: Commit final state**

```bash
git add -A
git commit -m "chore: verify ProFeaturePlaceholderView builds correctly"
```
