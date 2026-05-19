# TODO

## Interaction

- [ ] Scroll-to-zoom on charts
- [ ] Hover tooltip showing SSID / RSSI / channel on chart curves
- [ ] Click curve to select corresponding row in table (reverse of current row→curve highlight)
- [ ] Show/hide individual table columns via context menu
- [ ] Auto-adjust column widths to avoid truncation and wasted space
- [ ] Remember window position and size across launches

## Chart Quality

- [ ] Evaluate replacing Canvas hand-drawing with a proper chart framework for native zoom, tooltips, and axis labels
- [ ] Verify color contrast and readability in dark mode
- [ ] Signal history trend line (not just live snapshot)

## Data Completeness

- [ ] Export all bands at once (single combined CSV / multi-page PNG)
- [ ] Include metadata in CSV export: timestamp, band, PHY mode, channel width, capabilities, hidden SSID flag
- [ ] Persistent scan history / session recording

## Feature Depth

- [x] Connection quality score (weighted: RSSI + noise floor + channel congestion + roaming protocol support)
- [x] Channel occupancy / interference heatmap per band
- [ ] RSSI threshold alert (notify when a monitored network drops below a configurable threshold)

## Engineering

- [ ] UI / integration tests
- [ ] Retry strategy for CoreWLAN scan failures
- [ ] Crash reporting

## Out of Scope (for now)

- iOS / iPad support (CoreWLAN is macOS-only)
- LAN device discovery
- Localization beyond English / Simplified Chinese
