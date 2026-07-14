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
| `docs/superpowers/specs/2026-06-17-channel-recommendation-design.md` | Channel recommendation redesign for issue #3 |
| `docs/superpowers/plans/2026-06-17-channel-recommendation.md` | Implementation plan for counterfactual channel recommendation |
| `docs/TESTING.md` | Test architecture, UI test setup, launch arguments, Pro target setup, common issues |
| `docs/COLLABORATION_RULES.md` | AI assistant behavior rules — enforced prohibitions and must-follows |
| `docs/TODO.md` | Feature roadmap and checked-off items |
| `docs/ISSUES.md` | Bugs, regressions, and deferred work with status |
| `docs/LOCALIZATION_TERMS.md` | Standardized translation terminology for all languages |
| `docs/WINDOWING.md` | Main window sizing/restoration policy, P0 incident record, and anti-regression rules |
| `docs/superpowers/specs/2026-06-18-debug-multi-ap-chart-design.md` | Design spec for the DebugChartView multi-AP chart workbench |
| `docs/superpowers/plans/2026-06-18-debug-multi-ap-chart.md` | Implementation plan for the DebugChartView multi-AP chart workbench |
| `docs/superpowers/specs/2026-06-22-unified-wifi-observation-pipeline-design.md` | Design spec for unified Wi-Fi observation pipeline (models, providers, analyzers, pipeline, store) |
| `docs/superpowers/plans/2026-06-22-unified-wifi-observation-pipeline.md` | Implementation plan for unified Wi-Fi observation pipeline (Phases 1–5) |
| `docs/superpowers/plans/2026-06-22-unified-wifi-observation-pipeline-migration.md` | Implementation plan for migrating UI consumers to observation pipeline (Phases 6–10) |
| `docs/superpowers/specs/2026-06-24-ap-filter-design.md` | Design spec for structured AP filter query parser and filter service |
| `docs/superpowers/plans/2026-06-24-ap-filter.md` | Implementation plan for AP filter query parser and filter service |
| `docs/superpowers/specs/2026-07-10-timeline-event-semantics-design.md` | Design spec for Pro timeline connection semantics, event snapshots, and detail layout |
| `docs/superpowers/plans/2026-07-10-timeline-event-semantics.md` | Implementation plan for Pro timeline connection classification and visual fixes |
| `docs/superpowers/specs/2026-07-05-external-links-centralization-design.md` | Design spec for centralizing app business external links into a single Swift source of truth |
| `docs/superpowers/specs/2026-07-10-pro-unified-event-timeline-design.md` | Design spec for the Pro-only unified menu-bar and event timeline pipeline |
| `docs/superpowers/specs/2026-07-10-timeline-date-range-normalization-design.md` | Design spec for normalizing inverted custom date ranges in the Pro timeline (P2 #1) |
| `docs/superpowers/plans/2026-07-10-pro-unified-event-timeline.md` | Implementation plan for the Pro-only unified menu-bar and event timeline pipeline |
| `docs/superpowers/plans/2026-07-10-pro-timeline-consistency-controller.md` | Implementation plan for the Pro timeline generation controller, clear barrier, and lifecycle-safe date synchronization |
| `docs/superpowers/specs/2026-07-11-observation-runtime-migration-design.md` | Design spec for immutable observation publication and migration to a single production observation runtime |
| `docs/superpowers/plans/2026-07-11-immutable-observation-publication.md` | Implementation plan for ordered immutable observation publication and Pro event consumption |
| `docs/superpowers/plans/2026-07-11-production-observation-runtime-migration.md` | Implementation plan for migrating production scan-cycle orchestration into the observation runtime |
| `docs/superpowers/specs/2026-07-11-pro-event-journal-design.md` | Design spec for consolidating Pro event ingestion, recent publication, persistence, query, and clear consistency into one deep journal module |
| `docs/superpowers/plans/2026-07-11-pro-event-journal.md` | Implementation plan for the Pro-only deep event journal and deletion of the shallow event lifecycle modules |
| `docs/superpowers/specs/2026-07-12-structured-network-identity-design.md` | Design spec for making structured SSID/BSSID payloads the sole Pro connection-event identity and resetting the development schema |
| `docs/superpowers/plans/2026-07-12-structured-network-identity.md` | Implementation plan for structured Pro connection-event identity, shared presentation formatting, and the destructive SQLite v2 upgrade |
| `docs/superpowers/specs/2026-07-12-edition-composition-seam-design.md` | Design spec for target-selected OSS/Pro composition adapters with behavior-preserving lifecycle ownership |
| `docs/superpowers/plans/2026-07-12-edition-composition-seam.md` | Implementation plan for behavior-preserving target-selected OSS/Pro composition adapters |
| `docs/superpowers/specs/2026-07-13-runtime-backpressure-and-pro-state-design.md` | Design spec for Pro state preservation, single-snapshot scan cycles, and bounded latest-only runtime processing |
| `docs/superpowers/plans/2026-07-13-runtime-backpressure-and-pro-state.md` | Implementation plan for per-window Pro state, single-snapshot scans, and bounded runtime delivery |
| `docs/superpowers/specs/2026-07-14-pr-review-hardening-design.md` | Design spec for a shared Pro termination budget and idempotent event persistence after PR review |
| `docs/superpowers/plans/2026-07-14-pr-review-hardening.md` | Implementation plan for shared Pro termination timing and idempotent SQLite event replay |
| `Pro/docs/ARCHITECTURE.md` | Pro feature docs (Recording, Session, StoreKit) — in submodule |

## Skills Directory

Custom repository skills live under `.skills/`.

| File | Purpose |
|------|---------|
| `.skills/i18n-completer/SKILL.md` | Scan `Localizable.xcstrings` for missing translations and fill them via the repository scripts while enforcing glossary terminology |

## Build & Test

```sh
# App — always use xcodebuild, never swift build / swift test
# Build configurations: Debug / Release
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build
xcodebuild -project WiFiLens/WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests
xed WiFiLens/WiFiLens.xcodeproj                   # open in Xcode GUI

# ChartLens library (standalone Swift Package)
cd ChartLens && swift build                        # build
cd ChartLens && swift test                         # test

# ChartLens Demo app (Xcode project)
xcodebuild -project ChartLensDemo/ChartLensDemo.xcodeproj -scheme "ChartLensDemo" -configuration Debug -destination 'platform=macOS' build
xed ChartLensDemo/ChartLensDemo.xcodeproj

# Website — redirect page to wifi-lens.shiinalabs.com (Astro + pnpm, outputs to dist/)
cd web && pnpm install --config.minimum-release-age=0
cd web && pnpm dev                           # dev server at localhost:4321
cd web && pnpm --config.minimum-release-age=0 build
cd web && pnpm preview                       # preview production build
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
