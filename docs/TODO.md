# TODO

## Product

- [ ] Integrate SpectrumPanelView filter with `APFilterQueryParser` (support structured queries like `band:5G AND rssi:>-60`) — target v1.5.x
- [ ] RSSI threshold alert (notify when a monitored network drops below a configurable threshold)
- [ ] Unify export into a single reporting flow: multi-band export, richer CSV schema, and session snapshots suitable for sharing/debugging
- [ ] Turn signal history into a first-class session model: persisted timelines, monitored SSIDs, threshold alerts, and historical comparisons

## Engineering

- [ ] UI / integration tests
- [ ] Add a small verification matrix for UI regressions across light/dark mode, localization, and no-permission / no-data states
- [ ] Before the next Mac App Store submission, update `NSLocalNetworkUsageDescription` for both OSS and Pro targets to disclose that Network Self-Check may connect to a configured local proxy, in addition to the existing MCP server use case

## Out of Scope (for now)

- iOS / iPad support (CoreWLAN is macOS-only)
- LAN device discovery
