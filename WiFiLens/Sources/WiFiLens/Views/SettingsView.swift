import SwiftUI
import Sparkle

struct SettingsView: View {
    let updater: SparkleUpdater

    @State private var autoCheck: Bool
    @AppStorage("scanIntervalSeconds") private var scanInterval: Int = 3

    init(updater: SparkleUpdater) {
        self.updater = updater
        _autoCheck = State(initialValue: updater.automaticallyChecksForUpdates)
    }

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
            updatesTab
                .tabItem { Label("Updates", systemImage: "arrow.down.circle") }
        }
        .frame(width: 420, height: 260)
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("WiFi Lens")
                        .font(.headline)
                    Text("A simple Wi-Fi channel and signal strength analyzer for macOS.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Scan Interval") {
                Picker("Refresh interval", selection: $scanInterval) {
                    Text("1 second").tag(1)
                    Text("2 seconds").tag(2)
                    Text("3 seconds").tag(3)
                    Text("5 seconds").tag(5)
                    Text("10 seconds").tag(10)
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 200)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Updates

    private var updatesTab: some View {
        Form {
            Section {
                Toggle("Automatically check for updates", isOn: $autoCheck)
                    .onChange(of: autoCheck) { _, newValue in
                        updater.automaticallyChecksForUpdates = newValue
                    }
            }

            Section {
                HStack {
                    Button("Check Now") {
                        updater.checkForUpdates()
                    }
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
    }
}
