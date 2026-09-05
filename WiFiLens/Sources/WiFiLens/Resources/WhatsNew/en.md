# What's New in 1.6.0

WiFi Lens 1.6.0 expands the live Wi-Fi workspace for OSS and Pro with AP Radar, a componentized Spectrum workspace, and a new aggregate Heatmap — while Pro continues the path from live diagnosis to history, reporting, and analysis.

## Join the Community

Questions, feedback, or just want to talk about WiFi Lens?

**Join us on Discord:** https://discord.gg/gH6sTCYaJ7

## Highlights

### AP Radar (Preview)

* Select an access point and follow its received signal strength as you move around.
* See whether the signal is getting stronger, getting weaker, or staying stable, with a clear signal-lost state when the target disappears.
* Optional pulse audio changes with signal strength; sound controls and pulse presets are available in Settings.
* AP Radar provides RSSI-based guidance. It does not determine an access point’s exact direction or distance.

### Componentized Spectrum Workspace

* Spectrum panels are now componentized, so each panel can be switched between Spectrum, Trend, Table, and Heatmap views.
* The existing network table is easier to tailor: choose the columns you want to keep visible alongside the network details that matter to you.
* Band selection and view-specific controls stay together, making it easier to build the workspace that fits your current task.

### Aggregate Spectrum Heatmap

* See where Wi-Fi activity is concentrated across frequency and signal strength.
* Compare the current environment as an aggregate view instead of following one access point at a time.
* Switch between supported 2.4 GHz, 5 GHz, and 6 GHz bands with a band-aware heatmap.

### WiFi Lens Pro

* Timeline can export an anonymized Markdown report and provides richer localized event details.
* Statistics and Insights now have clearer localized actions and feedback entry points.
* Pro connects live observation with recording, historical events, recurring-pattern analysis, menu-bar access, and export workflows.

## Reliability, Localization, and Accessibility

* Heatmap rendering now uses hardware acceleration when available and falls back safely when it is not.
* Improved rendering stability for concurrent updates, changing scan results, and sparse channel plans.
* Expanded localization and accessibility coverage across AP Radar and the new Spectrum workspace.

## Edition Availability

The componentized Spectrum workspace, aggregate Heatmap, AP Radar Preview, and core live Wi-Fi analysis are available in both the open-source (OSS) and Pro editions.

WiFi Lens Pro adds recording, Timeline history, Statistics, Insights, menu-bar access, and extended export workflows for longer-term observation and analysis.

**Full Changelog:** [v1.5.1...v1.6.0](https://github.com/SHIINASAMA/wifi-lens/compare/v1.5.1...v1.6.0)
