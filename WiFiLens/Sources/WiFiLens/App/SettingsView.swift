import SwiftUI
import Sparkle

struct SettingsView: View {
    let updater: SparkleUpdater
    let locationPermission: LocationPermissionManager
    let bluetoothPermission: BluetoothPermissionManager?

    @State private var autoCheck: Bool
    @AppStorage("scanIntervalSeconds") private var scanInterval: Int = 3
    @AppStorage("regulatoryRegionOverride") private var regionOverride: String = "auto"
    @AppStorage("mcpEnabled") private var mcpEnabled: Bool = false
    @AppStorage("mcpPort") private var mcpPort: Int = 19840
    @AppStorage("appearance") private var appearance: String = "system"
    @AppStorage("hideTitleBadge") private var hideTitleBadge = false

    init(updater: SparkleUpdater, locationPermission: LocationPermissionManager, bluetoothPermission: BluetoothPermissionManager?) {
        self.updater = updater
        self.locationPermission = locationPermission
        self.bluetoothPermission = bluetoothPermission
        _autoCheck = State(initialValue: updater.automaticallyChecksForUpdates)
        if BuildConfig.current == .pro {
            updater.automaticallyChecksForUpdates = false
            AppLogger.app.info("Sparkle auto-update disabled (PRO build)")
        }
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
                    Picker(String(localized: "settings.appearance.theme_label", comment: "Theme picker label"), selection: $appearance) {
                        Text(String(localized: "common.label.system", comment: "Follow system setting option")).tag("system")
                        Text(String(localized: "common.label.light", comment: "Light appearance theme option")).tag("light")
                        Text(String(localized: "common.label.dark", comment: "Dark appearance theme option")).tag("dark")
                    }
                    .pickerStyle(.segmented)
                    if BuildConfig.current == .pro {
                        Toggle(String(localized: "settings.appearance.hide_badge", comment: "Toggle to hide the title badge"), isOn: $hideTitleBadge)
                    }
                } header: {
                    Text(String(localized: "settings.appearance.header", comment: "Appearance settings section header"))
                }

                // MARK: - Scanner
                Section(String(localized: "settings.scan.header", comment: "Scan interval settings section header")) {
                    Picker(String(localized: "settings.scan.interval_label", comment: "Scan refresh interval picker label"), selection: $scanInterval) {
                        Text(String(localized: "settings.scan.interval_1s", comment: "1 second scan interval option")).tag(1)
                        Text(String(localized: "settings.scan.interval_2s", comment: "2 second scan interval option")).tag(2)
                        Text(String(localized: "settings.scan.interval_3s", comment: "3 second scan interval option")).tag(3)
                        Text(String(localized: "settings.scan.interval_5s", comment: "5 second scan interval option")).tag(5)
                        Text(String(localized: "settings.scan.interval_10s", comment: "10 second scan interval option")).tag(10)
                    }
                    .pickerStyle(.menu)

                    Picker(String(localized: "settings.region.header", comment: "Regulatory region picker label"), selection: $regionOverride) {
                        Text(String(localized: "settings.region.auto_detect", comment: "Auto-detect regulatory region option")).tag("auto")
                        Text(String(localized: "settings.region.us_fcc", comment: "US FCC regulatory region option")).tag("US")
                        Text(String(localized: "settings.region.jp_mic", comment: "Japan MIC regulatory region option")).tag("JP")
                        Text(String(localized: "settings.region.cn_srrc", comment: "China SRRC regulatory region option")).tag("CN")
                        Text(String(localized: "settings.region.eu_etsi", comment: "EU ETSI regulatory region option")).tag("EU")
                    }
                    .pickerStyle(.menu)

                    Text(String(localized: "settings.region.description", comment: "Description of how regional regulation filtering works"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // MARK: - MCP
                Section {
                    Toggle(String(localized: "settings.mcp.enable_toggle", comment: "Toggle to enable the MCP HTTP server"), isOn: $mcpEnabled)
                    Text(String(localized: "settings.mcp.description", comment: "Description of the MCP server feature"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Text(String(localized: "settings.mcp.port_label", comment: "MCP server port field label"))
                        TextField("", value: $mcpPort, format: .number)
                            .frame(width: 80)
                        Stepper("", value: $mcpPort, in: 1024...65535)
                            .labelsHidden()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "settings.mcp.claude_config_label", comment: "Label for Claude Desktop config snippet"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(#"{"mcpServers":{"wifi-lens":{"command":"WiFiLensMCP","args":["\#(mcpPort)"]}}}"#)
                            .font(.system(size: 10, design: .monospaced))
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
                        .onChange(of: autoCheck) { _, newValue in
                            updater.automaticallyChecksForUpdates = newValue
                            AppLogger.app.info("Sparkle auto-check \(newValue ? "enabled" : "disabled")")
                        }
                    HStack {
                        Button(String(localized: "common.action.check_now", comment: "Check now button for updates")) {
                            updater.checkForUpdates()
                            AppLogger.app.info("Sparkle manual update check triggered")
                        }
                        Spacer()
                    }
                } header: {
                    Text(String(localized: "settings.updates.header", comment: "Updates settings section header"))
                }
                }

                // MARK: - Permissions

                Section {
                    // Location
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            Text(String(localized: "settings.permissions.location_label", comment: "Location Services permission row label"))
                                .font(.body)
                            Spacer()
                            PermissionStatusBadge(isAuthorized: locationPermission.isAuthorizedForSSID)
                        }
                        Text(String(localized: "settings.permissions.location_desc", comment: "Description of why Location Services is needed"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button(String(localized: "common.action.open_location_settings", comment: "Button to open Location Services settings")) {
                            locationPermission.openLocationPreferences()
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                    .padding(.vertical, 4)

                    // Bluetooth
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            Text(String(localized: "settings.permissions.bluetooth_label", comment: "Bluetooth permission row label"))
                                .font(.body)
                            Spacer()
                            if let bp = bluetoothPermission {
                                PermissionStatusBadge(isAuthorized: bp.isAuthorized)
                            }
                        }
                        Text(String(localized: "settings.permissions.bluetooth_desc", comment: "Description of why Bluetooth is needed"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button(String(localized: "common.action.open_bluetooth_settings", comment: "Button to open Bluetooth settings")) {
                            bluetoothPermission?.openBluetoothPreferences()
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text(String(localized: "settings.permissions.header", comment: "Permissions settings section header"))
                }

                // MARK: - Diagnostics

                Section {
                    HStack {
                        Button(String(localized: "common.action.reveal_logs", comment: "Button to reveal log files in Finder")) {
                            AppLogger.revealInFinder()
                        }
                        Spacer()
                    }
                } header: {
                    Text(String(localized: "settings.diagnostics.header", comment: "Diagnostics settings section header"))
                }
            }
            .formStyle(.grouped)
            .frame(maxWidth: 520)
            .padding(.vertical, 16)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PermissionStatusBadge: View {
    let isAuthorized: Bool

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isAuthorized ? Color.green : Color.orange)
                .frame(width: 6, height: 6)
            Text(isAuthorized ? String(localized: "common.label.granted", comment: "Permission granted status") : String(localized: "common.label.required", comment: "Required status label"))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}
