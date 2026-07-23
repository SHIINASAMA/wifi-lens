import SwiftUI
#if OSS
import Sparkle
#endif
import AppKit

struct SettingsView: View {
    @Bindable var macVendorDatabaseManager: MACVendorDatabaseManager
    let updater: SparkleUpdater
    let locationPermission: LocationPermissionManager
    let bluetoothPermission: BluetoothPermissionManager?
    let onScanIntervalChange: (Int) -> Void
    let onRegulatoryRegionChange: (String) -> Void
    @Binding var bleEnabled: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var autoCheck: Bool
    @AppStorage("scanIntervalSeconds") private var scanInterval: Int = 3
    @AppStorage("regulatoryRegionOverride") private var regionOverride: String = "auto"
    @AppStorage("mcpEnabled") private var mcpEnabled: Bool = false
    @AppStorage("mcpPort") private var mcpPort: Int = 19840
    @AppStorage("appearance") private var appearance: String = "system"
    @AppStorage("hideTitleBadge") private var hideTitleBadge = true
    @AppStorage("menuBarEnabled") private var menuBarEnabled = true

    init(
        macVendorDatabaseManager: MACVendorDatabaseManager,
        updater: SparkleUpdater,
        locationPermission: LocationPermissionManager,
        bluetoothPermission: BluetoothPermissionManager?,
        bleEnabled: Binding<Bool>,
        onScanIntervalChange: @escaping (Int) -> Void = { _ in },
        onRegulatoryRegionChange: @escaping (String) -> Void = { _ in }
    ) {
        self.macVendorDatabaseManager = macVendorDatabaseManager
        self.updater = updater
        self.locationPermission = locationPermission
        self.bluetoothPermission = bluetoothPermission
        self.onScanIntervalChange = onScanIntervalChange
        self.onRegulatoryRegionChange = onRegulatoryRegionChange
        _bleEnabled = bleEnabled
        _autoCheck = State(initialValue: updater.automaticallyChecksForUpdates)
    }

    var body: some View {
        ScrollView {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                Form {
                // MARK: - General
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "settings.app.title", comment: "App name in Settings about section"))
                            .font(.headline)
                        Text(String(localized: "settings.app.description", comment: "Short app description in Settings"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                // MARK: - Appearance
                Section {
                    Picker(String(localized: "settings.appearance.theme_label", comment: "Theme picker label"), selection: $appearance.animation(reduceMotion ? nil : .bouncy)) {
                        Text(String(localized: "common.label.system", comment: "Follow system setting option")).tag("system")
                        Text(String(localized: "common.label.light", comment: "Light appearance theme option")).tag("light")
                        Text(String(localized: "common.label.dark", comment: "Dark appearance theme option")).tag("dark")
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("settings-theme-picker")
                    if BuildConfig.current == .pro {
                        Toggle(String(localized: "settings.appearance.hide_badge", comment: "Toggle to hide the title badge"), isOn: $hideTitleBadge)
                    }
                } header: {
                    Text(String(localized: "settings.appearance.header", comment: "Appearance settings section header"))
                }

                // MARK: - Scanner
                Section(String(localized: "settings.scan.header", comment: "Scan interval settings section header")) {
                    Picker(String(localized: "settings.scan.interval_label", comment: "Scan refresh interval picker label"), selection: $scanInterval.animation(reduceMotion ? nil : .bouncy)) {
                        Text(String(localized: "settings.scan.interval_1s", comment: "1 second scan interval option")).tag(1)
                        Text(String(localized: "settings.scan.interval_2s", comment: "2 second scan interval option")).tag(2)
                        Text(String(localized: "settings.scan.interval_3s", comment: "3 second scan interval option")).tag(3)
                        Text(String(localized: "settings.scan.interval_5s", comment: "5 second scan interval option")).tag(5)
                        Text(String(localized: "settings.scan.interval_10s", comment: "10 second scan interval option")).tag(10)
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("settings-scan-interval-picker")
                    .onChange(of: scanInterval) { _, newValue in
                        onScanIntervalChange(newValue)
                    }

                    Text(String(localized: "settings.scan.interval_description", comment: "Description clarifying the scan interval only affects the live spectrum view, not recording"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Picker(String(localized: "settings.region.header", comment: "Regulatory region picker label"), selection: $regionOverride.animation(reduceMotion ? nil : .bouncy)) {
                        Text(String(localized: "settings.region.auto_detect", comment: "Auto-detect regulatory region option")).tag("auto")
                        Text(String(localized: "settings.region.us_fcc", comment: "US FCC regulatory region option")).tag("US")
                        Text(String(localized: "settings.region.jp_mic", comment: "Japan MIC regulatory region option")).tag("JP")
                        Text(String(localized: "settings.region.cn_srrc", comment: "China SRRC regulatory region option")).tag("CN")
                        Text(String(localized: "settings.region.eu_etsi", comment: "EU ETSI regulatory region option")).tag("EU")
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("settings-region-picker")
                    .onChange(of: regionOverride) { _, newValue in
                        onRegulatoryRegionChange(newValue)
                    }

                    Text(String(localized: "settings.region.description", comment: "Description of how regional regulation filtering works"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                MACVendorDatabaseSettingsSection(manager: macVendorDatabaseManager)

                EditionComposition.settingsContribution()

                // MARK: - Permissions

                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            Text(String(localized: "settings.permissions.location_label", comment: "Location Services permission row label"))
                                .font(.body)
                            Spacer()
                            PermissionStatusBadge(isAuthorized: locationPermission.isAuthorizedForSSID)
                                .accessibilityIdentifier("permission-location-badge")
                        }
                        PermissionDescriptionText(String(localized: "settings.permissions.location_desc", comment: "Description of why Location Services is needed"))
                        Button(String(localized: "common.action.open_location_settings", comment: "Button to open Location Services settings")) {
                            locationPermission.openLocationPreferences()
                        }
                        .buttonStyle(.link)
                        .font(.callout)
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            Text(String(localized: "settings.permissions.bluetooth_label", comment: "Bluetooth permission row label"))
                                .font(.body)
                            Spacer()
                            PermissionStatusBadge(isAuthorized: bluetoothPermission?.isAuthorized ?? false)
                                .accessibilityIdentifier("permission-bluetooth-badge")
                                .opacity(bluetoothPermission != nil ? 1.0 : 0.5)
                        }
                        PermissionDescriptionText(
                            String(localized: "settings.permissions.bluetooth_desc", comment: "Description of why Bluetooth is needed")
                        )
                        Button(String(localized: "common.action.open_bluetooth_settings", comment: "Button to open Bluetooth settings")) {
                            bluetoothPermission?.openBluetoothPreferences()
                        }
                        .buttonStyle(.link)
                        .font(.callout)
                        .disabled(bluetoothPermission == nil)
                        .opacity(bluetoothPermission == nil ? 0.5 : 1.0)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text(String(localized: "settings.section.permissions", comment: "System permissions subsection header in settings"))
                }
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: bleEnabled)

                // MARK: - MCP
                Section {
                    Toggle(String(localized: "settings.mcp.enable_toggle", comment: "Toggle to enable the MCP HTTP server"), isOn: $mcpEnabled)
                        .accessibilityIdentifier("settings-mcp-toggle")
                    Text(String(localized: "settings.mcp.description", comment: "Description of the MCP server feature"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Text(String(localized: "settings.mcp.port_label", comment: "MCP server port field label"))
                        TextField("", value: $mcpPort, format: .number)
                            .frame(width: 80)
                            .accessibilityLabel(String(localized: "settings.mcp.port_label", comment: "MCP server port field label"))
                            .accessibilityIdentifier("settings-mcp-port-field")
                        Stepper("", value: $mcpPort, in: 1024...65535)
                            .labelsHidden()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "settings.mcp.claude_config_label", comment: "Label for Claude Desktop config snippet"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: String(localized: "format.claude_config_json", comment: "Claude Desktop MCP config JSON template"), mcpPort))
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                    .padding(.top, 4)
                } header: {
                    Text(String(localized: "settings.mcp.header", comment: "MCP settings section header"))
                }

                // MARK: - Updates
                if BuildConfig.current == .oss {
                Section {
                    Toggle(String(localized: "settings.updates.auto_check", comment: "Toggle for automatic update checking"), isOn: $autoCheck)
                        .accessibilityIdentifier("settings-auto-check-toggle")
                        .onChange(of: autoCheck) { _, newValue in
                            updater.automaticallyChecksForUpdates = newValue
                            AppLogger.app.info("Sparkle auto-check \(newValue ? "enabled" : "disabled")")
                        }
                    HStack {
                        Button(String(localized: "common.action.check_now", comment: "Check now button for updates")) {
                            updater.checkForUpdates()
                            AppLogger.app.info("Sparkle manual update check triggered")
                        }
                        .accessibilityIdentifier("settings-check-now-button")
                        Spacer()
                    }
                } header: {
                    Text(String(localized: "settings.updates.header", comment: "Updates settings section header"))
                }
                }

                // MARK: - Diagnostics
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "settings.diagnostics.logs_description", comment: "Explanation that logs are local-only, not collected, and under user control"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button(String(localized: "common.action.reveal_logs", comment: "Button to reveal log files in Finder")) {
                            AppLogger.revealInFinder()
                        }
                        .accessibilityIdentifier("settings-reveal-logs-button")
                    }
                } header: {
                    Text(String(localized: "settings.diagnostics.header", comment: "Diagnostics settings section header"))
                }

                // MARK: - Privacy

                Section {
                    HStack {
                        Button(String(localized: "settings.privacy.view_policy", comment: "Button to view privacy policy")) {
                            open(.privacyPolicy)
                        }
                        .accessibilityIdentifier("settings-privacy-policy-button")
                        Spacer()
                    }
                } header: {
                    Text(String(localized: "settings.privacy.header", comment: "Privacy settings section header"))
                }

                // MARK: - About

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.accentColor)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "settings.about.title", comment: "App name in About section"))
                                    .font(.headline)
                                Text(String(format: String(localized: "settings.about.version_fmt", comment: "App version format string"), Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0", Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Divider()

                        aboutLinkRow(icon: "bag.fill", title: String(localized: "settings.about.app_store", comment: "App Store link"), destination: .appStore)
                        aboutLinkRow(icon: "safari", title: String(localized: "settings.about.website", comment: "Product website link"), destination: .website)
                        aboutLinkRow(icon: "chevron.left.forwardslash.chevron.right", title: String(localized: "settings.about.github", comment: "GitHub repository link"), destination: .github)
                        aboutLinkRow(icon: "bubble.left.and.bubble.right.fill", title: String(localized: "settings.about.x", comment: "X (formerly Twitter) account link"), destination: .xAccount)
                        aboutLinkRow(icon: "person.fill.checkmark", title: String(localized: "settings.about.developer", comment: "Developer profile link"), destination: .developerProfile)

                        Divider()

                        Text(String(localized: "settings.about.dependencies_header", comment: "Core dependencies section header"))
                            .font(.caption)
                            .foregroundColor(.secondary)

                        aboutLinkRow(icon: "chart.xyaxis.line", title: "ChartLens", destination: .chartLensRepository)
                        aboutLinkRow(icon: "server.rack", title: "MCP Swift SDK", destination: .mcpSwiftSDKRepository)
#if OSS
                        aboutLinkRow(icon: "sparkles", title: "Sparkle", destination: .sparkleRepository)
#endif
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text(String(localized: "settings.about.header", comment: "About section header"))
                }
            }
            .formStyle(.grouped)
            .frame(maxWidth: 520)
            .padding(.vertical, 16)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("settings-scroll-view")
        .onAppear {
            refreshPermissionStatuses()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                refreshPermissionStatuses()
            }
        }
    }

    private func refreshPermissionStatuses() {
        locationPermission.refreshStatus()
        bluetoothPermission?.refreshStatus()
    }

    private func aboutLinkRow(icon: String, title: String, destination: ExternalDestination) -> some View {
        Button {
            open(destination)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                    .frame(width: 20)
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func open(_ destination: ExternalDestination) {
        guard let url = ExternalLinks.url(for: destination) else { return }
        NSWorkspace.shared.open(url)
    }
}

private struct PermissionStatusBadge: View {
    let isAuthorized: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var statusText: String {
        isAuthorized
            ? String(localized: "common.label.granted", comment: "Permission granted status")
            : String(localized: "common.label.required", comment: "Required status label")
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isAuthorized ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: isAuthorized)
            ZStack {
                Text(String(localized: "common.label.granted", comment: "Permission granted status"))
                    .opacity(isAuthorized ? 1 : 0)
                Text(String(localized: "common.label.required", comment: "Required status label"))
                    .opacity(isAuthorized ? 0 : 1)
            }
                .font(.caption)
                .foregroundColor(.secondary)
                .contentTransition(.opacity)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: isAuthorized)
        }
        .accessibilityLabel(statusText)
    }
}

private struct PermissionDescriptionText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}


struct BLEFeatureSettingsRow: View {
    @AppStorage("bleEnabled") private var bleEnabled = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right").foregroundColor(.blue).frame(width: 20)
                Text(String(localized: "settings.features.ble_label", comment: "Bluetooth analysis feature toggle label")).font(.body)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { bleEnabled },
                    set: { newValue in
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { bleEnabled = newValue }
                    }
                ))
                .labelsHidden()
                .accessibilityLabel(String(localized: "settings.features.ble_label", comment: "Bluetooth analysis feature toggle label"))
                .accessibilityIdentifier("settings-ble-toggle")
            }
            Text(String(localized: "settings.features.ble_description", comment: "Description of Bluetooth analysis feature"))
                .font(.callout).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}
