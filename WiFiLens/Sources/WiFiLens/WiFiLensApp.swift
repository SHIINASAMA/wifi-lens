import SwiftUI
#if OSS
import Sparkle
#endif

private struct AppRootView: View {
    // P0 windowing guardrail:
    // Keep the app window on a standard macOS sizing model.
    // Do not reintroduce scene-level content-driven sizing such as:
    //   .windowResizability(.contentSize)
    // The previous combination of content-size windowing + hidden pages kept alive
    // in this ZStack let page ideal sizes expand the restored window beyond the
    // current screen's visibleFrame, which matched the App Review failure.
    private let mainWindowDefaultSize = CGSize(width: 900, height: 700)
    private let mainWindowMinSize = CGSize(width: 820, height: 620)

    @Bindable var viewModel: ScannerViewModel
    @Bindable var roamingViewModel: RoamingTestViewModel
    var bleViewModel: BLEViewModel?
    @Binding var sidebarVisibility: NavigationSplitViewVisibility
    @Binding var selectedPage: SidebarPage
    @Binding var showCrashLog: Bool
    @Binding var crashLogText: String
    let sparkleUpdater: SparkleUpdater
    let updateMCPServer: @MainActor () -> Void
    let registerMainWindow: @MainActor (NSWindow?) -> Void
    let registerOpenMainWindowAction: @MainActor (@escaping () -> Void) -> Void

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openWindow) private var openWindow

    @AppStorage("hideTitleBadge") private var hideTitleBadge = true
    @AppStorage("bleEnabled") private var bleEnabled: Bool = false
    @State private var secondaryToolbarSelections = SecondaryToolbarSelections()
#if PRO
    @State private var spectrumRecordingViewModel: RecordingViewModel?
    @State private var timelineSearchText = ""
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

    private var timelineRangeFilter: Binding<TimelineRangeFilter> {
        Binding(
            get: {
                switch secondaryToolbarSelections.timeline {
                case .timelineToday:
                    .today
                case .timelineYesterday:
                    .yesterday
                case .timelineThisWeek:
                    .thisWeek
                default:
                    .all
                }
            },
            set: { newValue in
                let selection: SecondaryToolbarItemID = switch newValue {
                case .today:
                    .timelineToday
                case .yesterday:
                    .timelineYesterday
                case .thisWeek:
                    .timelineThisWeek
                case .all:
                    .timelineAll
                }
                secondaryToolbarSelections.timeline = selection
            }
        )
    }

    private var timelineSearchBinding: Binding<String> {
        Binding(
            get: { timelineSearchText },
            set: { timelineSearchText = $0 }
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
            case .timeline:
#if PRO
                SecondaryToolbarCapsule(
                    descriptor: SecondaryToolbarDescriptor.forPage(.timeline)!,
                    selection: $secondaryToolbarSelections.timeline
                )
#else
                EmptyView()
#endif
            default:
                EmptyView()
            }
        }
#if PRO
        ToolbarItem(placement: .primaryAction) {
            if selectedPage == .timeline {
                TimelineToolbarSearchField(text: timelineSearchBinding)
            }
        }
#endif
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
                // These pages stay mounted to preserve page-local state. The detail
                // container must therefore fill the available split-view space
                // explicitly instead of letting hidden pages influence window sizing.
                OverviewView(viewModel: viewModel, store: viewModel.store)
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

                if selectedPage == .timeline {
#if PRO
                    TimelineView(
                        selectedFilter: timelineRangeFilter,
                        searchText: timelineSearchBinding
                    )
                        .accessibilityIdentifier("page-timeline")
#else
                    ProFeaturePlaceholderView(
                        featureName: String(localized: "pro.timeline.title", comment: "Pro timeline feature title"),
                        featureDescription: String(localized: "pro.timeline.description", comment: "Pro timeline feature description"),
                        featureIcon: SidebarPage.timeline.icon
                    )
                        .accessibilityIdentifier("page-timeline")
#endif
                }

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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
        .listStyle(.sidebar)
        .toolbar {
            secondaryToolbarContent
        }
        .background(
            WindowAccessor(
                defaultSize: mainWindowDefaultSize,
                minSize: mainWindowMinSize,
                onResolveWindow: registerMainWindow
            )
        )
        .task {
            registerOpenMainWindowAction {
                openWindow(id: WiFiLensApp.mainWindowSceneID)
            }
            await viewModel.start()
#if PRO
            ProObservationEventBootstrap.start(observationStore: viewModel.store)
#endif
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

#if PRO
private struct TimelineToolbarSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField(
                String(localized: "timeline.search.placeholder", comment: "Timeline search field placeholder"),
                text: $text
            )
            .textFieldStyle(.plain)
            .frame(width: 180)
        }
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
    }
}
#endif

private struct WindowAccessor: NSViewRepresentable {
    let defaultSize: CGSize
    let minSize: CGSize
    let onResolveWindow: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(view.window)
            onResolveWindow(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(nsView.window)
            onResolveWindow(nsView.window)
        }
    }

    private func configure(_ window: NSWindow?) {
        guard let window else {
            AppLogger.app.info("WindowAccessor: window=nil")
            return
        }

        AppLogger.app.info("WindowAccessor: window=\(window)")
        window.setFrameAutosaveName("WiFiLensMainWindow")
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .visible
        window.minSize = minSize
        window.contentMinSize = minSize

        guard let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame else {
            return
        }

        // P0 regression guard:
        // Restored NSWindow frames are not trusted blindly because App Review hit a
        // case where a saved frame + content-driven sizing pushed the main window
        // behind the Dock and broke full-screen transitions. We always normalize
        // against the current screen's visibleFrame before the user sees the window.
        guard WindowFramePolicy.shouldNormalizeLiveWindowFrame(
            currentFrame: window.frame,
            screenFrame: window.screen?.frame ?? NSScreen.main?.frame,
            visibleFrame: visibleFrame,
            isFullScreen: window.styleMask.contains(.fullScreen)
        ) else {
            return
        }

        let normalized = WindowFramePolicy.normalizedFrame(
            restoredFrame: window.frame,
            visibleFrame: visibleFrame,
            defaultSize: defaultSize
        )
        if normalized != window.frame {
            window.setFrame(normalized, display: true)
        }
    }
}

private final class WeakMainWindowReference {
    weak var window: NSWindow?
}

enum MainWindowRouteIntent: Equatable {
    case preserveCurrentPage
    case navigate(SidebarPage)
}

enum MainWindowActivationAction: Equatable {
    case keepCurrentPolicy
    case switchToRegular
    case switchToAccessory
}

enum ResolvedMainWindowFocusIntent: Equatable {
    case noFollowUpFocus
    case focusResolvedWindow
}

func routeIntent(for route: SidebarPage?) -> MainWindowRouteIntent {
    guard let route else { return .preserveCurrentPage }
    return .navigate(route)
}

func closeAction(menuBarEnabled: Bool) -> MainWindowActivationAction {
    menuBarEnabled ? .switchToAccessory : .keepCurrentPolicy
}

func reopenAction(menuBarEnabled: Bool, currentPolicy: NSApplication.ActivationPolicy) -> MainWindowActivationAction {
    guard menuBarEnabled, currentPolicy == .accessory else { return .keepCurrentPolicy }
    return .switchToRegular
}

func resolvedWindowFocusIntent(hasExistingMainWindow: Bool) -> ResolvedMainWindowFocusIntent {
    hasExistingMainWindow ? .noFollowUpFocus : .focusResolvedWindow
}

@main
struct WiFiLensApp: App {
    static let mainWindowSceneID = "WiFiLensMainWindowScene"

    @State private var viewModel = ScannerViewModel()
    @State private var roamingViewModel = RoamingTestViewModel()
    @State private var bleViewModel: BLEViewModel?
    @State private var sparkleUpdater = SparkleUpdater()
    @State private var sidebarVisibility = NavigationSplitViewVisibility.automatic
    @State private var selectedPage: SidebarPage = .overview
    @State private var showCrashLog: Bool = false
    @State private var mainWindowReference = WeakMainWindowReference()
    @State private var mainWindowCloseObserver: NSObjectProtocol?
    @State private var openMainWindowAction: (() -> Void)?
    @State private var pendingMainWindowRoute: SidebarPage?
    @State private var pendingResolvedMainWindowFocus = false
    @AppStorage("mcpEnabled") private var mcpEnabled: Bool = false
    @AppStorage("mcpPort") private var mcpPort: Int = 19840
    @AppStorage("appearance") private var appearance: String = "system"
    @AppStorage("bleEnabled") private var bleEnabled: Bool = false
    @AppStorage("menuBarEnabled") private var menuBarEnabled: Bool = true

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
        WindowGroup(id: Self.mainWindowSceneID) {
            AppRootView(
                viewModel: viewModel,
                roamingViewModel: roamingViewModel,
                bleViewModel: bleViewModel,
                sidebarVisibility: $sidebarVisibility,
                selectedPage: $selectedPage,
                showCrashLog: $showCrashLog,
                crashLogText: $crashLogText,
                sparkleUpdater: sparkleUpdater,
                updateMCPServer: updateMCPServer,
                registerMainWindow: registerMainWindow,
                registerOpenMainWindowAction: registerOpenMainWindowAction
            )
            .preferredColorScheme(colorScheme)
        }
        // Keep a default launch size only. The app window must remain a normal
        // resizable macOS window; do not add `.windowResizability(.contentSize)`.
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

                Button(String(localized: "nav.timeline", comment: "Navigate to Timeline page")) {
                    selectedPage = .timeline
                }
                .keyboardShortcut("7", modifiers: .command)
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
                    Button {
                    } label: {
                        Label {
                            Text(String(localized: "export.snapshot_markdown", comment: "Export as Markdown report"))
                        } icon: {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.yellow)
                        }
                    }
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
                    showMainWindow(route: .settings)
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

#if PRO
        MenuBarScene(
            onOpenMainWindow: { showMainWindow(route: nil) },
            onOpenTimeline: { showMainWindow(route: .timeline) },
            onOpenSettings: { showMainWindow(route: .settings) },
            onQuit: { NSApp.terminate(nil) }
        )
#endif
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

    private var menuBarWindowManagementEnabled: Bool {
#if PRO
        menuBarEnabled
#else
        false
#endif
    }

    @MainActor
    private func showMainWindow(route: SidebarPage? = nil) {
        switch reopenAction(menuBarEnabled: menuBarWindowManagementEnabled, currentPolicy: NSApp.activationPolicy()) {
        case .switchToRegular:
            NSApp.setActivationPolicy(.regular)
        case .keepCurrentPolicy, .switchToAccessory:
            break
        }

        switch routeIntent(for: route) {
        case .navigate(let page):
            selectedPage = page
            pendingMainWindowRoute = page
        case .preserveCurrentPage:
            pendingMainWindowRoute = nil
        }

        let hasExistingMainWindow = mainWindowReference.window != nil
        pendingResolvedMainWindowFocus = (
            resolvedWindowFocusIntent(hasExistingMainWindow: hasExistingMainWindow) == .focusResolvedWindow
        )

        NSApp.activate(ignoringOtherApps: true)

        if let mainWindow = mainWindowReference.window {
            if mainWindow.isMiniaturized {
                mainWindow.deminiaturize(nil)
            }
            mainWindow.makeKeyAndOrderFront(nil)
            return
        }

        openMainWindowAction?()
    }

    @MainActor
    private func registerMainWindow(_ window: NSWindow?) {
        guard let window else { return }

        mainWindowReference.window = window
        replaceMainWindowCloseObserver(for: window)

        if let pendingRoute = pendingMainWindowRoute {
            selectedPage = pendingRoute
            pendingMainWindowRoute = nil
        }

        guard pendingResolvedMainWindowFocus else { return }

        pendingResolvedMainWindowFocus = false
        NSApp.activate(ignoringOtherApps: true)
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
    }

    @MainActor
    private func handleMainWindowWillClose(_ closingWindow: NSWindow) {
        guard mainWindowReference.window === closingWindow else { return }

        mainWindowReference.window = nil
        clearMainWindowCloseObserver()
        pendingResolvedMainWindowFocus = false

        switch closeAction(menuBarEnabled: menuBarWindowManagementEnabled) {
        case .switchToAccessory:
            NSApp.setActivationPolicy(.accessory)
        case .keepCurrentPolicy, .switchToRegular:
            break
        }
    }

    @MainActor
    private func replaceMainWindowCloseObserver(for window: NSWindow) {
        clearMainWindowCloseObserver()
        mainWindowCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                handleMainWindowWillClose(window)
            }
        }
    }

    @MainActor
    private func clearMainWindowCloseObserver() {
        guard let mainWindowCloseObserver else { return }
        NotificationCenter.default.removeObserver(mainWindowCloseObserver)
        self.mainWindowCloseObserver = nil
    }

    @MainActor
    private func registerOpenMainWindowAction(_ action: @escaping () -> Void) {
        openMainWindowAction = action
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
