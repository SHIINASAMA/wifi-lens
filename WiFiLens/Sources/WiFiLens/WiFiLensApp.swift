import SwiftUI
import Sparkle

extension Notification.Name {
    static let freezeAllBands = Notification.Name("freezeAllBands")
    static let exportBandAsPNG = Notification.Name("exportBandAsPNG")
    static let exportBandAsCSV = Notification.Name("exportBandAsCSV")
}

@main
struct WiFiLensApp: App {
    @State private var viewModel = ScannerViewModel()
    @State private var sparkleUpdater = SparkleUpdater()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .alert("Location Services are disabled", isPresented: $viewModel.locationManager.showDeniedAlert) {
                    Button("Open Preferences") {
                        viewModel.locationManager.openLocationPreferences()
                    }
                    Button("Ignore", role: .cancel) {}
                    Button("Quit", role: .destructive) {
                        viewModel.locationManager.terminateApp()
                    }
                } message: {
                    Text("On macOS 14 Sonoma and Later, Location Services permission is required to get Wi-Fi SSIDs.\nPlease enable Location Services in System Preferences > Security & Privacy > Privacy > Location Services.")
                }
                .onReceive(NotificationCenter.default.publisher(for: .freezeAllBands)) { _ in
                    for vm in viewModel.bandViewModels {
                        vm.toggleFreeze()
                    }
                }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .toolbar) {
                Menu("Export") {
                    ForEach(viewModel.bandViewModels, id: \.band.id) { vm in
                        Menu(vm.band.displayName) {
                            Button("PNG") {
                                exportPNG(for: vm)
                            }
                            Button("CSV") {
                                exportCSV(for: vm)
                            }
                        }
                    }
                }
                .disabled(viewModel.bandViewModels.isEmpty)
                .keyboardShortcut("e", modifiers: [.command, .shift])

                Divider()

                Button("Freeze All") {
                    NotificationCenter.default.post(name: .freezeAllBands, object: nil)
                }
                .keyboardShortcut(".", modifiers: [.command])
            }

            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    sparkleUpdater.checkForUpdates()
                }
            }
        }

        Settings {
            SettingsView(updater: sparkleUpdater)
        }
    }

    @MainActor
    private func exportPNG(for vm: BandChartViewModel) {
        let renderer = ImageRenderer(content: BandChartView(viewModel: vm, scannerViewModel: viewModel))
        renderer.scale = 2.0
        guard let nsImage = renderer.nsImage,
              let tiff = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:])
        else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "\(vm.band.displayName.lowercased().replacingOccurrences(of: " ", with: "-"))_wifi.png"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? png.write(to: url)
            }
        }
    }

    @MainActor
    private func exportCSV(for vm: BandChartViewModel) {
        var csv = "channel,rssi,ssid,bssid\n"
        for s in vm.displayedSeriesData {
            let escaped = s.ssid.replacingOccurrences(of: "\"", with: "\"\"")
            csv += "\(s.channel),\(s.rssi),\"\(escaped)\",\(s.bssid)\n"
        }
        guard let data = csv.data(using: .utf8) else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "\(vm.band.displayName.lowercased().replacingOccurrences(of: " ", with: "-"))_wifi.csv"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? data.write(to: url)
            }
        }
    }
}
