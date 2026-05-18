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

    private var generalTab: some View {
        Form {
            Text("Tiny Wi-Fi Analyzer")
                .font(.headline)
            Text("A simple Wi-Fi channel and signal strength analyzer for macOS.")
                .font(.caption)
                .foregroundColor(.secondary)
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
