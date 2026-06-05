import SwiftUI
#if OSS
import Sparkle
#endif

private struct AppRootView: View {
    @Bindable var viewModel: ScannerViewModel
    @Bindable var roamingViewModel: RoamingTestViewModel
    var bleViewModel: BLEViewModel?
    @Binding var sidebarVisibility: NavigationSplitViewVisibility
    @Binding var selectedPage: SidebarPage
    @Binding var showCrashLog: Bool
    @Binding var crashLogText: String
    let sparkleUpdater: SparkleUpdater
    let updateMCPServer: @MainActor () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sidebarWidth: CGFloat = 180
    @State private var sidebarCollapsed = false
    @AppStorage("hideTitleBadge") private var hideTitleBadge = true
    @AppStorage("bleEnabled") private var bleEnabled: Bool = false
    @State private var visitedPages: Set<SidebarPage> = [.overview]

    private var hasLocationAuthorization: Bool {
        viewModel.locationManager.isAuthorizedForSSID
    }

    private var showsLocationPermissionRequiredView: Bool {
        !UITestMode.isActive && selectedPage.requiresLocationAuthorization && !hasLocationAuthorization
    }

    @ViewBuilder
    private var detailContent: some View {
        if showsLocationPermissionRequiredView {
            LocationPermissionRequiredView(
                accessState: viewModel.accessState,
                openLocationPreferences: viewModel.locationManager.openLocationPreferences
            )
        } else if !UITestMode.isActive && selectedPage.requiresWiFi && !viewModel.isWiFiAvailable {
            WiFiOffView()
        } else {
            ZStack {
                if visitedPages.contains(.overview) {
                    OverviewView(viewModel: viewModel)
                        .opacity(selectedPage == .overview ? 1 : 0)
                        .allowsHitTesting(selectedPage == .overview)
                        .disabled(selectedPage != .overview)
                        .accessibilityIdentifier("page-overview")
                }

                if visitedPages.contains(.spectrum) {
                    ContentView(viewModel: viewModel)
                        .opacity(selectedPage == .spectrum ? 1 : 0)
                        .allowsHitTesting(selectedPage == .spectrum)
                        .disabled(selectedPage != .spectrum)
                        .accessibilityIdentifier("page-spectrum")
                }

                if visitedPages.contains(.channels) {
                    ChannelQualityView(channels: viewModel.channelRecommendations)
                        .opacity(selectedPage == .channels ? 1 : 0)
                        .allowsHitTesting(selectedPage == .channels)
                        .disabled(selectedPage != .channels)
                        .accessibilityIdentifier("page-channels")
                }

                if visitedPages.contains(.interfaces) {
                    InterfacesView(interfaces: viewModel.networkInfo, scannerViewModel: viewModel, throughputMonitor: viewModel.throughputMonitor)
                        .opacity(selectedPage == .interfaces ? 1 : 0)
                        .allowsHitTesting(selectedPage == .interfaces)
                        .disabled(selectedPage != .interfaces)
                        .accessibilityIdentifier("page-interfaces")
                }

                if visitedPages.contains(.roaming) {
                    RoamingTestView(viewModel: roamingViewModel)
                        .opacity(selectedPage == .roaming ? 1 : 0)
                        .allowsHitTesting(selectedPage == .roaming)
                        .disabled(selectedPage != .roaming)
                        .accessibilityIdentifier("page-roaming")
                }

                if visitedPages.contains(.bleScanner) {
                    BLEScannerView(viewModel: bleViewModel, bleEnabled: bleEnabled)
                        .opacity(selectedPage == .bleScanner ? 1 : 0)
                        .allowsHitTesting(selectedPage == .bleScanner)
                        .disabled(selectedPage != .bleScanner)
                        .accessibilityIdentifier("page-bleScanner")
                }

                if visitedPages.contains(.settings) {
                    SettingsView(updater: sparkleUpdater, locationPermission: viewModel.locationManager, bluetoothPermission: bleViewModel?.bluetoothPermission, bleEnabled: $bleEnabled)
                        .opacity(selectedPage == .settings ? 1 : 0)
                        .allowsHitTesting(selectedPage == .settings)
                        .disabled(selectedPage != .settings)
                        .accessibilityIdentifier("page-settings")
                }

#if DEBUG
                if visitedPages.contains(.debugChart) {
                    DebugContainerView()
                        .opacity(selectedPage == .debugChart ? 1 : 0)
                        .allowsHitTesting(selectedPage == .debugChart)
                        .disabled(selectedPage != .debugChart)
                        .accessibilityIdentifier("page-debugChart")
                }
#endif
            }
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $sidebarVisibility) {
            SidebarView(selectedPage: $selectedPage, locationManager: viewModel.locationManager, isWiFiAvailable: viewModel.isWiFiAvailable, bleEnabled: bleEnabled)
                .navigationSplitViewColumnWidth(min: 160, ideal: 180)
                .background(
                    GeometryReader { geo in
                        Color.clear.onAppear {
            BandChartViewModel.reduceMotion = reduceMotion
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
                if newPage == .bleScanner, let vm = bleViewModel, !vm.isScanning {
                    Task { await vm.startScanning() }
                } else if newPage != .bleScanner, let vm = bleViewModel, vm.isScanning {
                    vm.stopScanning()
                }
            }
            .onChange(of: viewModel.wifiPowerState) { _, newState in
                roamingViewModel.handleWiFiPowerStateChange(newState)
            }
            .alert(String(localized: "permission.crash_detected_title", comment: "Alert title when previous crash is detected on launch"), isPresented: $showCrashLog) {
                Button(String(localized: "common.action.dismiss", comment: "Dismiss/close alert button"), role: .cancel) {}
            } message: {
                ScrollView { Text(crashLogText).font(.caption.monospaced()).textSelection(.enabled) }
                    .frame(maxHeight: 200)
            }
            .navigationTitle(selectedPage == .overview ? "" : selectedPage.label)
            .alert(String(localized: "permission.location.services_required_title", comment: "Alert title: Location Services permission needed"), isPresented: $viewModel.locationManager.showDeniedAlert) {
                Button(String(localized: "common.action.open_system_settings", comment: "Button to open macOS System Settings")) {
                    viewModel.locationManager.openLocationPreferences()
                }
                Button(String(localized: "common.action.cancel", comment: "Cancel button label"), role: .cancel) {}
            } message: {
                Text(String(localized: "permission.location.services_required_message", comment: "Alert message explaining why Location Services is required"))
            }
        }
        .background(WindowAccessor { window in
            window?.setFrameAutosaveName("WiFiLensMainWindow")
        })
        .onAppear {
            BandChartViewModel.reduceMotion = reduceMotion
            visitedPages.insert(selectedPage)
        }
        .task {
            await viewModel.start()
            roamingViewModel.handleWiFiPowerStateChange(viewModel.wifiPowerState)
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
            if selectedPage == .overview, (BuildConfig.current == .oss || !hideTitleBadge) {
                TitleBadge(config: .current)
                    .padding(.leading, x)
                    .padding(.top, titleBarY)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: x)
            }
        }
    }
}

private struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            let w = view.window
            AppLogger.app.info("WindowAccessor: window=\(w != nil ? "\(w!)" : "nil")")
            onWindow(w)
            w?.titlebarAppearsTransparent = true
            w?.titleVisibility = .visible
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

extension Notification.Name {
    static let exportBandAsPNG = Notification.Name("exportBandAsPNG")
    static let exportBandAsCSV = Notification.Name("exportBandAsCSV")
}

@main
struct WiFiLensApp: App {
    @State private var viewModel = ScannerViewModel()
    @State private var roamingViewModel = RoamingTestViewModel()
    @State private var bleViewModel: BLEViewModel?
    @State private var sparkleUpdater = SparkleUpdater()
    @State private var sidebarVisibility = NavigationSplitViewVisibility.automatic
    @State private var selectedPage: SidebarPage = .overview
    @State private var showCrashLog: Bool = false
    @AppStorage("mcpEnabled") private var mcpEnabled: Bool = false
    @AppStorage("mcpPort") private var mcpPort: Int = 19840
    @AppStorage("appearance") private var appearance: String = "system"
    @AppStorage("bleEnabled") private var bleEnabled: Bool = false

    init() {
        if UITestMode.isActive {
            // UI tests pass -ApplePersistenceIgnoreState YES as a launch argument
            // to disable window state restoration.
        }

        AppLogger.bootstrap()
        CrashReporter.register()
        MetricKitManager.start()
        if let log = CrashReporter.consumeCrashLog() {
            _crashLogText = State(initialValue: log)
            _showCrashLog = State(initialValue: true)
        }
        let bleOn = UserDefaults.standard.bool(forKey: "bleEnabled") && !UITestMode.isActive
        _bleViewModel = State(initialValue: bleOn ? BLEViewModel() : nil)
        AppLogger.app.info("WiFi Lens launched\(UITestMode.isActive ? " (UI test mode)" : "")")
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
        .defaultSize(width: 900, height: 700)
        .onChange(of: appearance) { _, newValue in
            let target: NSAppearance?
            switch newValue {
            case "light": target = NSAppearance(named: .aqua)
            case "dark":  target = NSAppearance(named: .darkAqua)
            default:
                let name = NSApp.effectiveAppearance.name
                target = name == .darkAqua || name == .vibrantDark
                    ? NSAppearance(named: .darkAqua)
                    : NSAppearance(named: .aqua)
            }
            guard let target else { return }
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.4
                ctx.allowsImplicitAnimation = true
                for window in NSApp.windows {
                    window.animator().appearance = target
                }
            }
        }
        .onChange(of: bleEnabled) { _, enabled in
            if enabled {
                bleViewModel = BLEViewModel()
            } else {
                bleViewModel?.stopScanning()
                bleViewModel = nil
            }
        }
        .onChange(of: mcpEnabled) { _, enabled in
            updateMCPServer()
        }
        .onChange(of: mcpPort) { _, _ in
            if mcpEnabled { updateMCPServer() }
        }
        .commands {
            CommandGroup(after: .toolbar) {
                Menu(String(localized: "common.action.export", comment: "Export menu item or button")) {
                    ForEach(viewModel.bandViewModels, id: \.band.id) { vm in
                        Menu(vm.band.displayName) {
                            Button(String(localized: "spectrum.export.png_short", comment: "PNG export format short label")) {
                                exportPNG(for: vm)
                            }
                            Button(String(localized: "spectrum.export.csv_short", comment: "CSV export format short label")) {
                                exportCSV(for: vm)
                            }
                        }
                    }
                }
                .disabled(viewModel.bandViewModels.isEmpty)
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .appSettings) {
                Button {
                    selectedPage = .settings
                } label: {
                    Label(String(localized: "common.action.settings", comment: "Settings button or menu item"), systemImage: "gearshape")
                }
                .keyboardShortcut(",", modifiers: .command)
            }

#if OSS
            CommandGroup(after: .appInfo) {
                Button(String(localized: "common.action.check_for_updates", comment: "Check for updates menu item")) {
                    sparkleUpdater.checkForUpdates()
                }
            }
#endif

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
            content: WiFiBandChart(
                model: vm.renderModel,
                selectedNetworkID: $viewModel.selectedNetworkID,
                onResetZoom: { vm.resetZoom() },
                onToggleExpand: { vm.toggleExpand() },
                onApplyZoom: { lo, hi in vm.applyZoom(lo: lo, hi: hi) }
            )
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
