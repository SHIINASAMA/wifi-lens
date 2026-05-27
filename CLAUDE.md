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
# App — always use xcodebuild, never swift build / swift test
# Build configurations: Debug-OSS / Debug-PRO / Release-OSS / Release-PRO
xcodebuild -project WiFiLens.xcodeproj -scheme WiFiLens -configuration "Debug-OSS" -destination 'platform=macOS' build
xcodebuild -project WiFiLens.xcodeproj -scheme WiFiLens -configuration "Debug-OSS" -destination 'platform=macOS' test
xed WiFiLens.xcodeproj                   # open in Xcode GUI

# Website — Vite + Tailwind CSS, outputs to _site/
npm ci && npm run dev                    # dev server at localhost:5173/wifi-lens/
npm run build                            # production build
npm run preview                          # preview production build
```

The product name is `WiFi Lens.app` (with space). If Xcode regenerates the project and `TEST_HOST` breaks, fix it to: `$(BUILT_PRODUCTS_DIR)/WiFi Lens.app/Contents/MacOS/WiFi Lens`.

The website deploys to GitHub Pages via `.github/workflows/pages.yml`, triggered on push when any site source file changes.

## Key Facts

- macOS 14+, Swift 6.0, SwiftUI + AppKit interop with CoreWLAN
- `ScannerViewModel` is `@Observable`, passed via `@Bindable`
- Tests use Swift Testing (`@Test`, `#expect()`) with `@testable import WiFiLens`
- Localization: `String(localized: "domain.component.element", comment: "Context for translators")` → `Resources/Localizable.xcstrings` (`en`, `ja`, `zh-Hans`)
- Keys use hierarchical dot-notation (e.g., `settings.scan.interval_1s`, `overview.diagnosis.great.title`) — see `docs/ARCHITECTURE.md` for full convention
- New strings must be manually added to `.xcstrings` with `"extractionState": "manual"` and explicit `en` localization — auto-extraction is off
- Use `String(format: String(localized: "format.key"), args...)` for parameterized strings, not string interpolation in keys

## Rules

- Never commit without explicit user instruction
- Never push unless asked
- **All `.md` docs go in `docs/`** — this CLAUDE.md and README are the only exceptions
- When creating new docs, update the table in this file
