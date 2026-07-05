# External Links Centralization Design

Date: 2026-07-05
Status: Proposed

## Summary

WiFi Lens currently hardcodes business-facing external links in multiple Swift source files. The same product and dependency links appear in `SettingsView`, `ProFeaturePlaceholderView`, and related UI paths as raw string literals. This makes link updates error-prone, encourages copy-paste expansion, and obscures the authoritative source of truth.

This design centralizes App-owned business links for the macOS app into one Swift utility file. The scope is intentionally narrow: only static external business links inside the app are included. System settings URLs such as `x-apple.systempreferences:` are explicitly out of scope for this change.

## Goals

- Create one authoritative source of truth for business-facing external links used by the macOS app.
- Remove raw `https://` business URLs from UI and feature views.
- Keep the implementation static and compile-time defined.
- Preserve the current behavior and destinations with no product-facing flow changes.

## Non-Goals

- Do not include the `web/` project.
- Do not unify or abstract system settings URLs.
- Do not introduce runtime configuration, remote config, localization-based link selection, or environment-based routing.
- Do not add analytics, telemetry, or advanced link-opening services in this phase.

## Current Problems

The app currently has these maintainability issues:

- Business links are duplicated across multiple files as string literals.
- Callers construct `URL` values ad hoc, so there is no semantic representation of destinations.
- Finding the canonical URL for a destination requires searching multiple files.
- Future link changes risk partial updates and stale references.

Observed app-side destinations include:

- Privacy policy
- App Store Pro page
- Product website
- GitHub repository
- X account
- Developer profile
- ChartLens repository
- MCP Swift SDK repository
- Sparkle repository

## Proposed Design

Add a new utility file:

- `WiFiLens/Sources/WiFiLens/Utilities/ExternalLinks.swift`

This file will define:

1. `ExternalDestination`
2. `ExternalLinks`

### `ExternalDestination`

`ExternalDestination` is a semantic enum representing each supported external business destination in the app.

Planned cases:

- `privacyPolicy`
- `appStore`
- `website`
- `github`
- `xAccount`
- `developerProfile`
- `chartLensRepository`
- `mcpSwiftSDKRepository`
- `sparkleRepository`

The enum is the public interface callers use. Call sites should express intent by naming a destination rather than embedding a URL string.

### `ExternalLinks`

`ExternalLinks` is a small namespace responsible for mapping `ExternalDestination` values to `URL` instances.

Suggested surface:

```swift
enum ExternalLinks {
    static func url(for destination: ExternalDestination) -> URL? {
        switch destination {
        ...
        }
    }
}
```

The source of truth for raw URL strings lives only inside this mapping.

## Usage Pattern

Views and feature code should stop storing business URLs as local constants or inline string literals. Instead, call sites should reference `ExternalDestination` and resolve the URL through `ExternalLinks`.

Example pattern:

```swift
if let url = ExternalLinks.url(for: .privacyPolicy) {
    NSWorkspace.shared.open(url)
}
```

This keeps the scope of the change small while still centralizing ownership.

## Why This Design

This design is preferred over a plain string constant bag because it introduces semantic destinations rather than only moving literals into another file. It keeps the abstraction level low enough for the current problem while reducing the chance that raw strings spread again.

This design is preferred over a dedicated `LinkOpener` service because the current requirement is link centralization, not open-flow orchestration. A service layer can be added later if analytics, logging, or test doubles become necessary.

## Files Expected To Change During Implementation

- `WiFiLens/Sources/WiFiLens/Utilities/ExternalLinks.swift` (new)
- `WiFiLens/Sources/WiFiLens/App/SettingsView.swift`
- `WiFiLens/Sources/WiFiLens/App/ProFeaturePlaceholderView.swift`

System permission managers are intentionally not part of this implementation because their URLs are out of scope.

## Behavioral Expectations

- No visible UX change.
- All existing app business links continue to open the same targets.
- The About section, Privacy section, and Pro upsell surfaces continue to behave exactly as before.

## Testing Strategy

This change is primarily structural. Verification can remain lightweight:

- Build the app target.
- Confirm no business `https://` literals remain in the migrated app UI files.
- Manually inspect the migrated call sites to ensure each destination maps to the same URL as before.

Dedicated unit tests are optional in this phase because the mapping is static and small, but they can be added later if the list grows.

## Migration Rules

- New app business links must be added to `ExternalDestination` first.
- App UI and feature code should not introduce new raw business `https://` literals.
- If future requirements need per-build or per-region routing, extend `ExternalLinks` rather than bypassing it.

## Open Questions

None. The implementation scope is intentionally narrow and fully specified:

- App-only
- Static links only
- Business links only
- System settings URLs excluded
