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
                        Text(String(localized: "WiFi Lens"))
                            .font(.headline)
                        Text(String(localized: "A simple Wi-Fi channel and signal strength analyzer for macOS."))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                // MARK: - Appearance
                Section {
                    Picker(String(localized: "Theme"), selection: $appearance) {
                        Text(String(localized: "System")).tag("system")
                        Text(String(localized: "Light")).tag("light")
                        Text(String(localized: "Dark")).tag("dark")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    if BuildConfig.current == .pro {
                        Toggle(String(localized: "Hide title badge"), isOn: $hideTitleBadge)
                    }
                } header: {
                    Text(String(localized: "Appearance"))
                }

                // MARK: - Scanner
                Section(String(localized: "Scan Interval")) {
                    Picker(String(localized: "Refresh interval"), selection: $scanInterval) {
                        Text(String(localized: "1 second")).tag(1)
                        Text(String(localized: "2 seconds")).tag(2)
                        Text(String(localized: "3 seconds")).tag(3)
                        Text(String(localized: "5 seconds")).tag(5)
                        Text(String(localized: "10 seconds")).tag(10)
                    }
                    .pickerStyle(.menu)

                    Picker(String(localized: "Regulatory Region"), selection: $regionOverride) {
                        Text(String(localized: "Auto-detect")).tag("auto")
                        Text(String(localized: "United States (FCC)")).tag("US")
                        Text(String(localized: "Japan (MIC)")).tag("JP")
                        Text(String(localized: "China (SRRC)")).tag("CN")
                        Text(String(localized: "European Union (ETSI)")).tag("EU")
                    }
                    .pickerStyle(.menu)

                    Text(String(localized: "Channel recommendations are filtered by regional regulations. Auto-detect uses system locale, hardware capabilities, and nearby AP information."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // MARK: - MCP
                Section {
                    Toggle(String(localized: "Enable MCP server"), isOn: $mcpEnabled)
                    Text(String(localized: "Expose current Wi-Fi scan data as a local HTTP API for AI tools (Claude Desktop, etc.) to query via MCP."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Text(String(localized: "Port:"))
                        TextField("", value: $mcpPort, format: .number)
                            .frame(width: 80)
                        Stepper("", value: $mcpPort, in: 1024...65535)
                            .labelsHidden()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "Claude Desktop config"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(#"{"mcpServers":{"wifi-lens":{"command":"WiFiLensMCP","args":["\#(mcpPort)"]}}}"#)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                    .padding(.top, 4)
                } header: {
                    Text(String(localized: "MCP"))
                }

                // MARK: - Updates
                if BuildConfig.current == .oss {
                Section {
                    Toggle(String(localized: "Automatically check for updates"), isOn: $autoCheck)
                        .onChange(of: autoCheck) { _, newValue in
                            updater.automaticallyChecksForUpdates = newValue
                            AppLogger.app.info("Sparkle auto-check \(newValue ? "enabled" : "disabled")")
                        }
                    HStack {
                        Button(String(localized: "Check Now")) {
                            updater.checkForUpdates()
                            AppLogger.app.info("Sparkle manual update check triggered")
                        }
                        Spacer()
                    }
                } header: {
                    Text(String(localized: "Updates"))
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
                            Text(String(localized: "Location Services"))
                                .font(.body)
                            Spacer()
                            PermissionStatusBadge(isAuthorized: locationPermission.isAuthorizedForSSID)
                        }
                        Text(String(localized: "Required to read Wi-Fi network names (SSID). Without it, network names show as \"n/a\" but signal data is still available."))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button(String(localized: "Open Location Settings")) {
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
                            Text(String(localized: "Bluetooth"))
                                .font(.body)
                            Spacer()
                            if let bp = bluetoothPermission {
                                PermissionStatusBadge(isAuthorized: bp.isAuthorized)
                            }
                        }
                        Text(String(localized: "Required to scan for nearby BLE devices and measure signal strength for network analysis."))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button(String(localized: "Open Bluetooth Settings")) {
                            bluetoothPermission?.openBluetoothPreferences()
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text(String(localized: "Permissions"))
                }

                // MARK: - Diagnostics

                Section {
                    HStack {
                        Button(String(localized: "Reveal Logs in Finder")) {
                            AppLogger.revealInFinder()
                        }
                        Spacer()
                    }
                } header: {
                    Text(String(localized: "Diagnostics"))
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
            Text(isAuthorized ? String(localized: "Granted") : String(localized: "Required"))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}
