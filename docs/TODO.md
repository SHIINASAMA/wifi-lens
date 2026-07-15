# TODO

## Feature Depth

- [ ] Integrate SpectrumPanelView filter with `APFilterQueryParser` (support structured queries like `band:5G AND rssi:>-60`) — target v1.5.x
- [ ] RSSI threshold alert (notify when a monitored network drops below a configurable threshold)
- [x] Fix BLEScanner delegate retain cycles — `onDiscover`/`onReady` closures strongly capture `del`, and `stopScanning()` never clears `delegate` or closure properties, leaking the delegate and `AsyncStream.Continuation` on each 30s scan restart
- [x] Implement JP channel 14 bonus weighting in `RegionInferenceEngine.channelFingerprint()` — the `if domain == .JP && hardwareChannels.contains("1-14")` body is empty (`/* weighted */`), making JP inference fragile (relies on array iteration order instead of signal strength)

## Product Directions

- [ ] Unify export into a single reporting flow: multi-band export, richer CSV schema, and session snapshots suitable for sharing/debugging
- [x] Replace custom chart hit-testing/zoom/labels with a charting approach that supports hover, selection, and accessibility more naturally — achieved via universal `Chart<Overlay>` engine (see `.agents/references/project/CHARTS.md`)
- [ ] Turn signal history into a first-class session model: persisted timelines, monitored SSIDs, threshold alerts, and historical comparisons
- [ ] Add a small verification matrix for UI regressions across light/dark mode, localization, and no-permission / no-data states

## Engineering

- [ ] UI / integration tests
- [ ] Before the next Mac App Store submission, update `NSLocalNetworkUsageDescription` for both OSS and Pro targets to disclose that Network Self-Check may connect to a configured local proxy, in addition to the existing MCP server use case
- [x] Update `.agents/references/project/ARCHITECTURE.md` Source Layout table with `BLE/` and `Regulatory/` directories

## Out of Scope (for now)

- iOS / iPad support (CoreWLAN is macOS-only)
- LAN device discovery
- Localization beyond English / Simplified Chinese
