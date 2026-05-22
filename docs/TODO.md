# TODO

## Interaction

- [x] Drag-to-zoom on charts
- [x] Hover tooltip showing SSID / RSSI / channel on chart curves
- [x] Click curve to select corresponding row in table (reverse of current row→curve highlight)
- [x] Show/hide individual table columns via context menu
- [x] Auto-adjust column widths to avoid truncation and wasted space
- [x] Remember window position and size across launches

## Chart Quality

- [ ] Evaluate replacing Canvas hand-drawing with a proper chart framework for native zoom, tooltips, and axis labels
- [x] Verify color contrast and readability in dark mode
- [x] Signal history trend line (not just live snapshot)

## Data Completeness

- [ ] Export all bands at once (single combined CSV / multi-page PNG)
- [ ] Include metadata in CSV export: timestamp, band, PHY mode, channel width, capabilities, hidden SSID flag
- [ ] Persistent scan history / session recording

## Feature Depth

- [x] Connection quality score (weighted: RSSI + noise floor + channel congestion + roaming protocol support)
- [x] Channel occupancy / interference heatmap per band
- [ ] RSSI threshold alert (notify when a monitored network drops below a configurable threshold)

## Product Directions

- [ ] Build a real Overview dashboard as the app landing page: current connection health, top channel recommendations, recent scan summary, and quick actions
- [ ] Unify export into a single reporting flow: multi-band export, richer CSV schema, and session snapshots suitable for sharing/debugging
- [ ] Replace custom chart hit-testing/zoom/labels with a charting approach that supports hover, selection, and accessibility more naturally
- [ ] Turn signal history into a first-class session model: persisted timelines, monitored SSIDs, threshold alerts, and historical comparisons
- [ ] Harden MCP into an intentional automation surface: stable response schema, better protocol compatibility, and optional richer analytics endpoints
- [ ] Add a small verification matrix for UI regressions across light/dark mode, localization, and no-permission / no-data states

## Engineering

- [ ] UI / integration tests
- [x] Retry strategy for CoreWLAN scan failures
- [x] Crash reporting
- [x] Structured logging (swift-log → OSLog)

## Out of Scope (for now)

- iOS / iPad support (CoreWLAN is macOS-only)
- LAN device discovery
- Localization beyond English / Simplified Chinese
