import SwiftUI
import Sparkle

struct SettingsView: View {
    let updater: SparkleUpdater

    @State private var autoCheck: Bool
    @AppStorage("scanIntervalSeconds") private var scanInterval: Int = 3
    @AppStorage("mcpEnabled") private var mcpEnabled: Bool = false
    @AppStorage("mcpPort") private var mcpPort: Int = 19840
    @AppStorage("appearance") private var appearance: String = "system"

    init(updater: SparkleUpdater) {
        self.updater = updater
        _autoCheck = State(initialValue: updater.automaticallyChecksForUpdates)
    }

    var body: some View {
        ScrollView {
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
                Section {
                    Toggle(String(localized: "Automatically check for updates"), isOn: $autoCheck)
                        .onChange(of: autoCheck) { _, newValue in
                            updater.automaticallyChecksForUpdates = newValue
                        }
                    HStack {
                        Button(String(localized: "Check Now")) {
                            updater.checkForUpdates()
                        }
                        Spacer()
                    }
                } header: {
                    Text(String(localized: "Updates"))
                }
            }
            .formStyle(.grouped)
            .frame(maxWidth: 520)
            .padding(.vertical, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
