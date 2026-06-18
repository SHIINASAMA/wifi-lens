# AGENTS.md

This file provides guidance to AI coding agents (Codex, Copilot, Cursor, Windsurf, Claude Code, and others) when working in this repository.

## Docs Directory

All detailed documentation lives under `docs/`. When adding or updating documentation, always place it there. Never create standalone `.md` files at the repo root (except this file, `CLAUDE.md`, and `README.md`).

| File | Purpose |
|------|---------|
| `docs/ARCHITECTURE.md` | Architecture, data flow, key patterns, design conventions |
| `docs/CHARTS.md` | Universal Chart engine, types, rendering pipeline, WiFi spectrum integration |
| `docs/BLE.md` | BLE scanner architecture, data flow, types, views |
| `docs/ACCESSIBILITY.md` | Accessibility implementation status, App Store Connect categories, gaps, testing |
| `docs/MCP.md` | MCP Streamable HTTP server (port, protocol, tools, data format, integration) |
| `docs/REGULATORY.md` | Regulatory pipeline, region inference, channel recommendation |
| `docs/TESTING.md` | Test architecture, UI test setup, launch arguments, Pro target setup, common issues |
| `docs/COLLABORATION_RULES.md` | AI assistant behavior rules — enforced prohibitions and must-follows |
| `docs/TODO.md` | Feature roadmap and checked-off items |
| `docs/ISSUES.md` | Bugs, regressions, and deferred work with status |
| `docs/superpowers/specs/2026-06-18-debug-multi-ap-chart-design.md` | Design spec for the DebugChartView multi-AP chart workbench |
| `docs/superpowers/plans/2026-06-18-debug-multi-ap-chart.md` | Implementation plan for the DebugChartView multi-AP chart workbench |
| `Pro/docs/ARCHITECTURE.md` | Pro feature docs (Recording, Session, StoreKit) — in submodule |

## Build & Test

```sh
# App — always use xcodebuild, never swift build / swift test
# Build configurations: Debug / Release
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests
xed WiFiLens/WiFiLens.xcodeproj                   # open in Xcode GUI

# Website — Vite + Tailwind CSS, outputs to _site/
npm ci && npm run dev                    # dev server at localhost:5173/wifi-lens/
npm run build                            # production build
npm run preview                          # preview production build
```

The product name is `WiFi Lens.app` (with space). Unit tests use Swift Testing (`@Test`) with `TEST_HOST` — the test bundle is injected into the app process for `@testable import` symbol resolution. All test `.swift` files must be added to the WiFiLensTests target's Sources build phase (in `project.pbxproj`) for `xcodebuild test` to compile and run them. The `WiFiLensTests` scheme must reference the test bundle in both `<Testables>` and `<MacroExpansion>`.

Do not run UI test bundles (`WiFiLensUITests`, `WiFiLensProUITests`) or full scheme test commands that include UI tests unless the user explicitly asks for UI tests. Default verification is build plus `-only-testing:WiFiLensTests`.

When adding new test files, ensure they are:
1. Added as PBXFileReference in project.pbxproj
2. Added to the WiFiLensTests PBXGroup
3. Added as PBXBuildFile (assigned to WiFiLensTests target)
4. Listed in the WiFiLensTests target's Sources build phase (`files = (...)`)
5. Listed in the WiFiLensTests scheme's `<Testables>`

## Key Facts

- macOS 14+, Swift 6.0, SwiftUI + AppKit interop with CoreWLAN and CoreBluetooth
- `ScannerViewModel` is `@Observable`, passed via `@Bindable`
- Tests use Swift Testing (`@Test`, `#expect()`) with `@testable import WiFiLens`
- Localization: `String(localized: "domain.component.element", comment: "Context for translators")` → `Resources/Localizable.xcstrings` (`en`, `ja`, `zh-Hans`)
- Keys use hierarchical dot-notation (e.g., `settings.scan.interval_1s`, `overview.diagnosis.great.title`) — see `docs/ARCHITECTURE.md` for full convention
- New strings must be manually added to `.xcstrings` with `"extractionState": "manual"` and explicit `en` localization — auto-extraction is off
- Use `String(format: String(localized: "format.key"), args...)` for parameterized strings, not string interpolation in keys

## Rules

- Never commit without explicit user instruction
- Never push unless asked
- **English is the primary language.** All docs, code comments, commit messages, and communication must be in English. Only `.xcstrings` localization files are exceptions.
- **All `.md` docs go in `docs/`** — this AGENTS.md, CLAUDE.md, and README are the only exceptions
- When creating new docs, update the table in this file
