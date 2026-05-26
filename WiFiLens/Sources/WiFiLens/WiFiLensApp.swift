import SwiftUI
import Sparkle

private struct AppRootView: View {
    @Bindable var viewModel: ScannerViewModel
    @Bindable var roamingViewModel: RoamingTestViewModel
    @Bindable var bleViewModel: BLEViewModel
    @Binding var sidebarVisibility: NavigationSplitViewVisibility
    @Binding var selectedPage: SidebarPage
    @Binding var showCrashLog: Bool
    @Binding var crashLogText: String
    let sparkleUpdater: SparkleUpdater
    let updateMCPServer: @MainActor () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var sidebarWidth: CGFloat = 180
    @State private var sidebarCollapsed = false
    @AppStorage("hideTitleBadge") private var hideTitleBadge = false
    @State private var visitedPages: Set<SidebarPage> = [.overview]

    private var hasLocationAuthorization: Bool {
        viewModel.locationManager.isAuthorizedForSSID
    }

    private var showsLocationPermissionRequiredView: Bool {
        selectedPage.requiresLocationAuthorization && !hasLocationAuthorization
    }

    @ViewBuilder
    private var detailContent: some View {
        if showsLocationPermissionRequiredView {
            LocationPermissionRequiredView(
                accessState: viewModel.accessState,
                openLocationPreferences: viewModel.locationManager.openLocationPreferences
            )
        } else {
            ZStack {
                if visitedPages.contains(.overview) {
                    OverviewView(viewModel: viewModel)
                        .opacity(selectedPage == .overview ? 1 : 0)
                        .allowsHitTesting(selectedPage == .overview)
                        .disabled(selectedPage != .overview)
                }

                if visitedPages.contains(.spectrum) {
                    ContentView(viewModel: viewModel)
                        .opacity(selectedPage == .spectrum ? 1 : 0)
                        .allowsHitTesting(selectedPage == .spectrum)
                        .disabled(selectedPage != .spectrum)
                        .onReceive(NotificationCenter.default.publisher(for: .freezeAllBands)) { _ in
                            guard selectedPage == .spectrum else { return }
                            for vm in viewModel.bandViewModels {
                                vm.toggleFreeze()
                            }
                        }
                }

                if visitedPages.contains(.channels) {
                    ChannelQualityView(channels: viewModel.channelRecommendations)
                        .opacity(selectedPage == .channels ? 1 : 0)
                        .allowsHitTesting(selectedPage == .channels)
                        .disabled(selectedPage != .channels)
                }

                if visitedPages.contains(.interfaces) {
                    InterfacesView(interfaces: viewModel.networkInfo, scannerViewModel: viewModel, throughputMonitor: viewModel.throughputMonitor)
                        .opacity(selectedPage == .interfaces ? 1 : 0)
                        .allowsHitTesting(selectedPage == .interfaces)
                        .disabled(selectedPage != .interfaces)
                }

                if visitedPages.contains(.roaming) {
                    RoamingTestView(viewModel: roamingViewModel)
                        .opacity(selectedPage == .roaming ? 1 : 0)
                        .allowsHitTesting(selectedPage == .roaming)
                        .disabled(selectedPage != .roaming)
                }

                if visitedPages.contains(.bleScanner) {
                    BLEScannerView(viewModel: bleViewModel)
                        .opacity(selectedPage == .bleScanner ? 1 : 0)
                        .allowsHitTesting(selectedPage == .bleScanner)
                        .disabled(selectedPage != .bleScanner)
                }

                if visitedPages.contains(.help) {
                    HelpCenterView()
                        .opacity(selectedPage == .help ? 1 : 0)
                        .allowsHitTesting(selectedPage == .help)
                        .disabled(selectedPage != .help)
                }

                if visitedPages.contains(.settings) {
                    SettingsView(updater: sparkleUpdater)
                        .opacity(selectedPage == .settings ? 1 : 0)
                        .allowsHitTesting(selectedPage == .settings)
                        .disabled(selectedPage != .settings)
                }

#if DEBUG
                if visitedPages.contains(.debugChart) {
                    DebugContainerView()
                        .opacity(selectedPage == .debugChart ? 1 : 0)
                        .allowsHitTesting(selectedPage == .debugChart)
                        .disabled(selectedPage != .debugChart)
                }
#endif
            }
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $sidebarVisibility) {
            SidebarView(selectedPage: $selectedPage, locationManager: viewModel.locationManager)
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
                detailContent
            }
            .onChange(of: selectedPage) { _, newPage in
                visitedPages.insert(newPage)
                let spectrumVisible = newPage == .spectrum
                for vm in viewModel.allBandViewModels {
                    vm.isViewVisible = spectrumVisible
                }
                if newPage == .bleScanner, !bleViewModel.isScanning {
                    Task { await bleViewModel.startScanning() }
                } else if newPage != .bleScanner, bleViewModel.isScanning {
                    bleViewModel.stopScanning()
                }
            }
            .alert(String(localized: "Previous Crash Detected"), isPresented: $showCrashLog) {
                Button(String(localized: "Dismiss"), role: .cancel) {}
            } message: {
                ScrollView { Text(crashLogText).font(.caption.monospaced()).textSelection(.enabled) }
                    .frame(maxHeight: 200)
            }
            .navigationTitle(selectedPage == .overview ? "" : selectedPage.label)
            .alert(String(localized: "Location Services Required"), isPresented: $viewModel.locationManager.showDeniedAlert) {
                Button(String(localized: "Open System Settings")) {
                    viewModel.locationManager.openLocationPreferences()
                }
                Button(String(localized: "Cancel"), role: .cancel) {}
            } message: {
                Text(String(localized: "Location Services permission is required to read Wi-Fi network names. Please enable it in System Settings."))
            }
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
            let trafficLightsX: CGFloat = 149
            let sidebarGap: CGFloat = 12
            let titleBarY: CGFloat = 9
            let x = sidebarCollapsed ? trafficLightsX : sidebarWidth + sidebarGap
            // ---
            if selectedPage == .overview, !(BuildConfig.current == .pro && hideTitleBadge) {
                TitleBadge(config: .current)
                    .padding(.leading, x)
                    .padding(.top, titleBarY)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 0.25), value: x)
            }
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
            view.window?.titleVisibility = .visible
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
    @State private var roamingViewModel = RoamingTestViewModel()
    @State private var bleViewModel = BLEViewModel()
    @State private var sparkleUpdater = SparkleUpdater()
    @State private var sidebarVisibility = NavigationSplitViewVisibility.automatic
    @State private var selectedPage: SidebarPage = .overview
//    @State private var selectedPage: SidebarPage = .spectrum
    @State private var showCrashLog: Bool = false
    @AppStorage("mcpEnabled") private var mcpEnabled: Bool = false
    @AppStorage("mcpPort") private var mcpPort: Int = 19840
    @AppStorage("appearance") private var appearance: String = "system"

    init() {
        AppLogger.bootstrap()
        CrashReporter.register()
        MetricKitManager.start()
        if let log = CrashReporter.consumeCrashLog() {
            _crashLogText = State(initialValue: log)
            _showCrashLog = State(initialValue: true)
        }
        AppLogger.app.info("WiFi Lens launched")
    }

    @State private var crashLogText: String = ""

    var body: some Scene {
        WindowGroup {
            AppRootView(
                viewModel: viewModel,
                roamingViewModel: roamingViewModel,
                bleViewModel: bleViewModel,
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
            AppLogger.mcp.error("MCP server failed to start: \(error)")
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
