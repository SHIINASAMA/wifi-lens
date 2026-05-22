# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Docs Directory

All detailed documentation lives under `docs/`. When adding or updating documentation, always place it there. Never create standalone `.md` files at the repo root (except this file and README).

| File | Purpose |
|------|---------|
| `docs/ARCHITECTURE.md` | Architecture, data flow, key patterns, design conventions |
| `docs/TODO.md` | Feature roadmap and checked-off items |
| `docs/ISSUES.md` | Bugs, regressions, and deferred work with status |

## Build & Test

```sh
# Always use xcodebuild — do NOT use swift build / swift test
xcodebuild -project WiFiLens.xcodeproj -scheme WiFiLens -configuration Debug -destination 'platform=macOS' build
xcodebuild -project WiFiLens.xcodeproj -scheme WiFiLens -configuration Debug -destination 'platform=macOS' test
xed WiFiLens.xcodeproj                   # open in Xcode GUI
```

The product name is `WiFi Lens.app` (with space). If Xcode regenerates the project and `TEST_HOST` breaks, fix it to: `$(BUILT_PRODUCTS_DIR)/WiFi Lens.app/Contents/MacOS/WiFi Lens`.

## Key Facts

- macOS 14+, Swift 6.0, SwiftUI + AppKit interop with CoreWLAN
- `ScannerViewModel` is `@Observable`, passed via `@Bindable`
- Tests use Swift Testing (`@Test`, `#expect()`) with `@testable import WiFiLens`
- Localization: `String(localized:)` → `Resources/Localizable.xcstrings` (`en` + `zh-Hans`)
- New i18n strings must be manually added to `.xcstrings` — auto-extraction is off

## Rules

- Never commit without explicit user instruction
- Never push unless asked
- **All `.md` docs go in `docs/`** — this CLAUDE.md and README are the only exceptions
- When creating new docs, update the table in this file
