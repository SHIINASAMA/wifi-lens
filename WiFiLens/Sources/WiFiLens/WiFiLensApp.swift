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

    @AppStorage("hideTitleBadge") private var hideTitleBadge = true
    @AppStorage("bleEnabled") private var bleEnabled: Bool = false
    @State private var secondaryToolbarSelections = SecondaryToolbarSelections()
#if PRO
    @State private var spectrumRecordingViewModel: RecordingViewModel?
#endif

    private var hasLocationAuthorization: Bool {
        viewModel.locationManager.isAuthorizedForSSID
    }

    private var showsLocationPermissionRequiredView: Bool {
        !UITestMode.isActive && selectedPage.requiresLocationAuthorization && !hasLocationAuthorization
    }

    private var activeSecondaryToolbarDescriptor: SecondaryToolbarDescriptor? {
        SecondaryToolbarDescriptor.forPage(selectedPage)
    }

    private var activeSecondaryToolbarSelection: Binding<SecondaryToolbarItemID>? {
        guard let descriptor = activeSecondaryToolbarDescriptor else { return nil }

        return Binding(
            get: { secondaryToolbarSelections.selection(for: selectedPage) ?? descriptor.defaultSelection },
            set: { secondaryToolbarSelections.setSelection($0, for: selectedPage) }
        )
    }

    private var channelViewMode: ChannelViewMode {
        ChannelViewMode.fromToolbarSelection(
            secondaryToolbarSelections.channels
        )
    }

    private var interfaceViewMode: InterfaceViewMode {
        InterfaceViewMode.fromToolbarSelection(
            secondaryToolbarSelections.interfaces
        )
    }

#if PRO
    private var spectrumViewMode: SpectrumMode {
        SpectrumMode.fromToolbarSelection(
            secondaryToolbarSelections.spectrum
        )
    }
#endif

    private var detailNavigationTitle: String {
        guard selectedPage != .overview else { return "" }
        return activeSecondaryToolbarDescriptor == nil ? selectedPage.label : ""
    }

    private func handleSelectedPageChange(_ newPage: SidebarPage) {
        let spectrumVisible = newPage == .spectrum
        for vm in viewModel.allBandViewModels {
            vm.isViewVisible = spectrumVisible
        }

        guard let vm = bleViewModel else { return }
        if newPage == .bleScanner {
            if !vm.isScanning {
                Task { await vm.startScanning() }
            }
        } else if vm.isScanning {
            vm.stopScanning()
        }
    }



    @ToolbarContentBuilder
    private var secondaryToolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            if selectedPage == .overview, (BuildConfig.current == .oss || !hideTitleBadge) {
                TitleBadge(config: .current)
                    .fixedSize()
            }
        }
        ToolbarItem(placement: .principal) {
            switch selectedPage {
            case .channels:
                SecondaryToolbarCapsule(
                    descriptor: SecondaryToolbarDescriptor.forPage(.channels)!,
                    selection: $secondaryToolbarSelections.channels
                )
            case .interfaces:
                SecondaryToolbarCapsule(
                    descriptor: SecondaryToolbarDescriptor.forPage(.interfaces)!,
                    selection: $secondaryToolbarSelections.interfaces
                )
            case .spectrum:
                SecondaryToolbarCapsule(
                    descriptor: SecondaryToolbarDescriptor.forPage(.spectrum)!,
                    selection: $secondaryToolbarSelections.spectrum
                )
            default:
                EmptyView()
            }
        }
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
                OverviewView(viewModel: viewModel)
                    .opacity(selectedPage == .overview ? 1 : 0)
                    .allowsHitTesting(selectedPage == .overview)
                    .accessibilityIdentifier("page-overview")

                if selectedPage == .spectrum {
#if PRO
                    ContentView(
                        viewModel: viewModel,
                        mode: spectrumViewMode,
                        recordingViewModel: $spectrumRecordingViewModel
                    )
                        .accessibilityIdentifier("page-spectrum")
#else
                    ContentView(
                        viewModel: viewModel,
                        mode: secondaryToolbarSelections.spectrum
                    )
                        .accessibilityIdentifier("page-spectrum")
#endif
                }

                ChannelQualityView(
                    channels: viewModel.channelRecommendations,
                    mode: channelViewMode
                )
                    .opacity(selectedPage == .channels ? 1 : 0)
                    .allowsHitTesting(selectedPage == .channels)
                    .accessibilityIdentifier("page-channels")

                if selectedPage == .interfaces {
                    InterfacesView(
                        interfaces: viewModel.networkInfo,
                        scannerViewModel: viewModel,
                        throughputMonitor: viewModel.throughputMonitor,
                        mode: interfaceViewMode
                    )
                        .accessibilityIdentifier("page-interfaces")
                }

                RoamingTestView(viewModel: roamingViewModel)
                    .opacity(selectedPage == .roaming ? 1 : 0)
                    .allowsHitTesting(selectedPage == .roaming)
                    .accessibilityIdentifier("page-roaming")

                BLEScannerView(viewModel: bleViewModel, bleEnabled: bleEnabled)
                    .opacity(selectedPage == .bleScanner ? 1 : 0)
                    .allowsHitTesting(selectedPage == .bleScanner)
                    .accessibilityIdentifier("page-bleScanner")

                SettingsView(updater: sparkleUpdater, locationPermission: viewModel.locationManager, bluetoothPermission: bleViewModel?.bluetoothPermission, bleEnabled: $bleEnabled)
                    .opacity(selectedPage == .settings ? 1 : 0)
                    .allowsHitTesting(selectedPage == .settings)
                    .accessibilityIdentifier("page-settings")

#if DEBUG
                SpectrumDebugContainerView()
                    .opacity(selectedPage == .spectrumDebugChart ? 1 : 0)
                    .allowsHitTesting(selectedPage == .spectrumDebugChart)
                    .accessibilityIdentifier("page-spectrumDebugChart")

                DebugContainerView()
                    .opacity(selectedPage == .debugChart ? 1 : 0)
                    .allowsHitTesting(selectedPage == .debugChart)
                    .accessibilityIdentifier("page-debugChart")
#endif
            }
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $sidebarVisibility) {
            SidebarView(selectedPage: $selectedPage, locationManager: viewModel.locationManager, isWiFiAvailable: viewModel.isWiFiAvailable, bleEnabled: bleEnabled)
                .navigationSplitViewColumnWidth(min: 160, ideal: 180)
                .background(
                    GeometryReader { _ in
                        Color.clear.onAppear {
                            BandChartViewModel.reduceMotion = reduceMotion
                        }
                    }
                )
        } detail: {
            Group {
                detailContent
            }
            .onChange(of: selectedPage) { _, newPage in
                handleSelectedPageChange(newPage)
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
            .navigationTitle(detailNavigationTitle)
            .alert(String(localized: "permission.location.services_required_title", comment: "Alert title: Location Services permission needed"), isPresented: $viewModel.locationManager.showDeniedAlert) {
                Button(String(localized: "common.action.open_system_settings", comment: "Button to open macOS System Settings")) {
                    viewModel.locationManager.openLocationPreferences()
                }
                Button(String(localized: "common.action.cancel", comment: "Cancel button label"), role: .cancel) {}
            } message: {
                Text(String(localized: "permission.location.services_required_message", comment: "Alert message explaining why Location Services is required"))
            }
        }
        .toolbar {
            secondaryToolbarContent
        }
        .background(WindowAccessor { window in
            window?.setFrameAutosaveName("WiFiLensMainWindow")
        })
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
            CommandGroup(before: .toolbar) {
                Button(String(localized: "nav.overview", comment: "Navigate to Overview page")) {
                    selectedPage = .overview
                }
                .keyboardShortcut("1", modifiers: .command)

                Button(String(localized: "nav.spectrum", comment: "Navigate to Spectrum page")) {
                    selectedPage = .spectrum
                }
                .keyboardShortcut("2", modifiers: .command)

                Button(String(localized: "nav.channels", comment: "Navigate to Channels page")) {
                    selectedPage = .channels
                }
                .keyboardShortcut("3", modifiers: .command)

                Button(String(localized: "nav.interfaces", comment: "Navigate to Interfaces page")) {
                    selectedPage = .interfaces
                }
                .keyboardShortcut("4", modifiers: .command)

                Button(String(localized: "nav.roaming_test", comment: "Navigate to Roaming page")) {
                    selectedPage = .roaming
                }
                .keyboardShortcut("5", modifiers: .command)

                Button(String(localized: "nav.ble_scanner", comment: "Navigate to BLE Scanner page")) {
                    selectedPage = .bleScanner
                }
                .keyboardShortcut("6", modifiers: .command)
            }

            CommandGroup(after: .toolbar) {
                Menu(String(localized: "common.action.export", comment: "Export menu item or button")) {
                    Button(String(localized: "export.snapshot_image", comment: "Export chart snapshot as single PNG image")) {
                        exportSnapshotImage()
                    }
                    .keyboardShortcut("e", modifiers: [.command, .shift])

#if PRO
                    Button(String(localized: "export.snapshot_markdown", comment: "Export as self-contained Markdown report")) {
                        exportSnapshotMarkdown()
                    }
                    .keyboardShortcut("m", modifiers: [.command, .shift])
#else
                    Button(String(localized: "export.snapshot_markdown", comment: "Export as Markdown report")) { }
                        .disabled(true)
                        .help(String(localized: "pro.markdown.unavailable", comment: "Tooltip for unavailable Markdown export"))
#endif

                    Divider()

                    ForEach(viewModel.bandViewModels, id: \.band.id) { vm in
                        Button(String(format: String(localized: "spectrum.export.csv_fmt", comment: "CSV export menu item with band name"), vm.band.displayName)) {
                            exportCSV(for: vm)
                        }
                    }
                }
                .disabled(viewModel.bandViewModels.isEmpty)
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
        Task { @MainActor in
            do {
                try await viewModel.mcpServer.start()
            } catch {
                AppLogger.mcp.error("MCP server failed to start: \(error)")
            }
        }
    }

    @MainActor
    private func exportSnapshotImage() {
        ExportService.exportImage(viewModel: viewModel)
    }

#if PRO
    @MainActor
    private func exportSnapshotMarkdown() {
        MarkdownExportService.export(viewModel: viewModel)
    }
#endif

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
