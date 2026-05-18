import SwiftUI
import Sparkle

struct SettingsView: View {
    let updater: SparkleUpdater

    @State private var autoCheck: Bool

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
        .frame(width: 400, height: 220)
    }

    @AppStorage("scanIntervalSeconds") private var scanInterval: Int = 3

    private var generalTab: some View {
        Form {
            Text("WiFi Lens")
                .font(.headline)
            Text("A simple Wi-Fi channel and signal strength analyzer for macOS.")
                .font(.caption)
                .foregroundColor(.secondary)

            Picker("Refresh interval", selection: $scanInterval) {
                Text("1 second").tag(1)
                Text("2 seconds").tag(2)
                Text("3 seconds").tag(3)
                Text("5 seconds").tag(5)
                Text("10 seconds").tag(10)
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 280)
        }
        .padding()
    }

    private var updatesTab: some View {
        Form {
            Toggle("Automatically check for updates", isOn: $autoCheck)
                .onChange(of: autoCheck) { _, newValue in
                    updater.automaticallyChecksForUpdates = newValue
                }

            HStack {
                Button("Check Now") {
                    updater.checkForUpdates()
                }
                Spacer()
            }
        }
        .padding()
    }
}
