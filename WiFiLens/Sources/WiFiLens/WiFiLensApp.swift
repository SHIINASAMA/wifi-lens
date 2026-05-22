import SwiftUI
import Sparkle

private struct AppRootView: View {
    @Bindable var viewModel: ScannerViewModel
    @Binding var sidebarVisibility: NavigationSplitViewVisibility
    @Binding var selectedPage: SidebarPage
    @Binding var showCrashLog: Bool
    @Binding var crashLogText: String
    let sparkleUpdater: SparkleUpdater
    let updateMCPServer: @MainActor () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var sidebarWidth: CGFloat = 180
    @State private var sidebarCollapsed = false

    var body: some View {
        NavigationSplitView(columnVisibility: $sidebarVisibility) {
            SidebarView(selectedPage: $selectedPage)
                .navigationSplitViewColumnWidth(min: 160, ideal: 180)
                .background(
                    GeometryReader { geo in
                        Color.clear.onAppear {
                            sidebarWidth = geo.size.width
                        }
                        .onChange(of: geo.size.width) { _, w in
                            sidebarWidth = w
                        }
                    }
                )
        } detail: {
            Group {
                switch selectedPage {
                case .overview:
                    OverviewView(viewModel: viewModel)
                case .spectrum:
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
                case .channels:
                    ChannelQualityView(channels: viewModel.channelQualities)
                case .interfaces:
                    InterfacesView(interfaces: viewModel.networkInfo, scannerViewModel: viewModel, throughputMonitor: viewModel.throughputMonitor)
                case .help:
                    HelpCenterView()
                case .settings:
                    SettingsView(updater: sparkleUpdater)
#if DEBUG
                case .debugChart:
                    DebugContainerView()
#endif
                }
            }
            .alert(String(localized: "Previous Crash Detected"), isPresented: $showCrashLog) {
                Button(String(localized: "Dismiss"), role: .cancel) {}
            } message: {
                ScrollView { Text(crashLogText).font(.caption.monospaced()).textSelection(.enabled) }
                    .frame(maxHeight: 200)
            }
            .navigationTitle("")
        }
        .background(WindowAccessor { window in
            window?.setFrameAutosaveName("WiFiLensMainWindow")
        })
        .task {
            await viewModel.start()
            updateMCPServer()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await viewModel.handleSceneDidBecomeActive() }
            }
        }
        .onChange(of: sidebarVisibility) { _, vis in
            sidebarCollapsed = vis == .detailOnly
        }
        .overlay(alignment: .topLeading) {
            // --- position parameters ---
            let trafficLightsX: CGFloat = 149   // clear space for window buttons
            let sidebarGap: CGFloat = 12        // gap between sidebar edge and label
            let titleBarY: CGFloat = 9          // vertical center in title bar
            let x = sidebarCollapsed ? trafficLightsX : sidebarWidth + sidebarGap
            // ---
            let glassLabel = Button {
                // no action yet
            } label: {
                #if OSS
                Text("WiFi Lens·OSS")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(red: 130/255, green: 89/255, blue: 221/255))
                    .frame(height: 34)
                    .padding(.horizontal, 14)
                #endif
            }
            .buttonStyle(.plain)
            .background(Color(red: 130/255, green: 89/255, blue: 221/255).opacity(0.12), in: Capsule())
            .overlay {
                Capsule().stroke(Color(red: 130/255, green: 89/255, blue: 221/255), lineWidth: 1)
            }
            glassLabel
                .padding(.leading, x)
                .padding(.top, titleBarY)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }
}

private struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            onWindow(view.window)
            view.window?.titlebarAppearsTransparent = true
            view.window?.titleVisibility = .hidden
            // Nuke title text after SwiftUI layout settles
            DispatchQueue.main.async {
                view.window?.title = ""
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

extension Notification.Name {
    static let freezeAllBands = Notification.Name("freezeAllBands")
    static let exportBandAsPNG = Notification.Name("exportBandAsPNG")
    static let exportBandAsCSV = Notification.Name("exportBandAsCSV")
}

@main
struct WiFiLensApp: App {
    @State private var viewModel = ScannerViewModel()
    @State private var sparkleUpdater = SparkleUpdater()
    @State private var sidebarVisibility = NavigationSplitViewVisibility.automatic
    @State private var selectedPage: SidebarPage = .overview
//    @State private var selectedPage: SidebarPage = .spectrum
    @State private var showCrashLog: Bool = false
    @AppStorage("mcpEnabled") private var mcpEnabled: Bool = false
    @AppStorage("mcpPort") private var mcpPort: Int = 19840
    @AppStorage("appearance") private var appearance: String = "system"

    init() {
        Log.bootstrap()
        CrashReporter.register()
        if let log = CrashReporter.consumeCrashLog() {
            _crashLogText = State(initialValue: log)
            _showCrashLog = State(initialValue: true)
        }
        Log.app.info("WiFi Lens launched")
    }

    @State private var crashLogText: String = ""

    var body: some Scene {
        WindowGroup {
            AppRootView(
                viewModel: viewModel,
                sidebarVisibility: $sidebarVisibility,
                selectedPage: $selectedPage,
                showCrashLog: $showCrashLog,
                crashLogText: $crashLogText,
                sparkleUpdater: sparkleUpdater,
                updateMCPServer: updateMCPServer
            )
            .preferredColorScheme(colorScheme)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 900, height: 550)
        .onChange(of: mcpEnabled) { _, enabled in
            updateMCPServer()
        }
        .onChange(of: mcpPort) { _, _ in
            if mcpEnabled { updateMCPServer() }
        }
        .commands {
            CommandGroup(after: .toolbar) {
                Menu("Export") {
                    ForEach(viewModel.bandViewModels, id: \.band.id) { vm in
                        Menu(vm.band.displayName) {
                            Button(String(localized: "PNG")) {
                                exportPNG(for: vm)
                            }
                            Button(String(localized: "CSV")) {
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

            CommandGroup(replacing: .appSettings) {
                Button {
                    selectedPage = .settings
                } label: {
                    Label(String(localized: "Settings"), systemImage: "gearshape")
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    sparkleUpdater.checkForUpdates()
                }
            }

        }

    }

    private var colorScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark":  return .dark
        default:      return systemColorScheme
        }
    }

    private var systemColorScheme: ColorScheme {
        let name = NSApp.effectiveAppearance.name
        if name == .darkAqua || name == .vibrantDark || name == .accessibilityHighContrastDarkAqua || name == .accessibilityHighContrastVibrantDark {
            return .dark
        }
        return .light
    }

    @MainActor
    private func updateMCPServer() {
        viewModel.mcpServer.stop()
        guard mcpEnabled else { return }
        viewModel.mcpServer.port = UInt16(mcpPort)
        do {
            try viewModel.mcpServer.start()
        } catch {
            Log.mcp.error("MCP server failed to start: \(error)")
        }
    }

    @MainActor
    private func exportPNG(for vm: BandChartViewModel) {
        let size = vm.chartSize.width > 0 ? vm.chartSize : CGSize(width: 800, height: 300)
        let renderer = ImageRenderer(
            content: BandChartView(viewModel: vm, scannerViewModel: viewModel)
                .frame(width: size.width, height: size.height)
        )
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
        let ts = ISO8601DateFormatter().string(from: Date())
        var csv = "timestamp,band,channel,rssi,ssid,bssid,phy_mode,channel_width,k,r,v,hidden_ssid\n"
        for s in vm.displayedSeriesData {
            let escaped = s.ssid.replacingOccurrences(of: "\"", with: "\"\"")
            csv += "\(ts),\(vm.band.displayName),\(s.channel),\(s.rssi),\"\(escaped)\",\(s.bssid),"
            csv += "\(s.phyMode),\(s.channelWidth),"
            csv += "\(s.supportsK),\(s.supportsR),\(s.supportsV),"
            csv += "\(s.isHiddenSSID)\n"
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
