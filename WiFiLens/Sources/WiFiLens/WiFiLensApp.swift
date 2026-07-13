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
    @Binding var showCrashLog: Bool
    @Binding var crashLogText: String
    let sparkleUpdater: SparkleUpdater
    let updateMCPServer: @MainActor () -> Void
    let registerMainWindow: @MainActor (NSWindow?, MainWindowSceneState) -> Void
    let updateMainWindowRoute: @MainActor (UUID, SidebarPage) -> Void

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openWindow) private var openWindow

    @AppStorage("hideTitleBadge") private var hideTitleBadge = true
    @AppStorage("bleEnabled") private var bleEnabled: Bool = false
    @State private var sceneState = MainWindowSceneState()
    @State private var sidebarVisibility = NavigationSplitViewVisibility.automatic
    @State private var secondaryToolbarSelections = SecondaryToolbarSelections()

    private var selectedPage: SidebarPage { sceneState.selectedPage }

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


    private var detailNavigationTitle: String {
        guard selectedPage != .overview else { return "" }
        return activeSecondaryToolbarDescriptor == nil ? selectedPage.label : ""
    }

    private func handleSelectedPageChange(_ newPage: SidebarPage) {
        updateMainWindowRoute(sceneState.id, newPage)
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
                if let descriptor = SecondaryToolbarDescriptor.forPage(.timeline) {
                    SecondaryToolbarCapsule(
                        descriptor: descriptor,
                        selection: $secondaryToolbarSelections.timeline
                    )
                }
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
                // These pages stay mounted to preserve page-local state. The detail
                // container must therefore fill the available split-view space
                // explicitly instead of letting hidden pages influence window sizing.
                OverviewView(viewModel: viewModel, store: viewModel.store)
                    .opacity(selectedPage == .overview ? 1 : 0)
                    .allowsHitTesting(selectedPage == .overview)
                    .accessibilityIdentifier("page-overview")

                EditionComposition.detailContribution(context: EditionCompositionContext(
                    mainWindowID: sceneState.id,
                    mainWindowState: sceneState.editionWindowState,
                    scannerViewModel: viewModel,
                    selectedPage: Binding(
                        get: { sceneState.selectedPage },
                        set: { sceneState.selectedPage = $0 }
                    ),
                    secondaryToolbarSelections: $secondaryToolbarSelections,
                    bleEnabled: $bleEnabled,
                    openMainWindow: { _ in }
                ))

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

                SettingsView(
                    updater: sparkleUpdater,
                    locationPermission: viewModel.locationManager,
                    bluetoothPermission: bleViewModel?.bluetoothPermission,
                    bleEnabled: $bleEnabled,
                    onRegulatoryRegionChange: viewModel.handleRegulatoryRegionOverrideChange
                )
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

#if DEBUG && PRO
                DebugTimelineContainerView()
                    .opacity(selectedPage == .debugTimeline ? 1 : 0)
                    .allowsHitTesting(selectedPage == .debugTimeline)
                    .accessibilityIdentifier("page-debugTimeline")
#endif
#endif
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $sidebarVisibility) {
            SidebarView(
                selectedPage: Binding(
                    get: { sceneState.selectedPage },
                    set: { sceneState.selectedPage = $0 }
                ),
                locationManager: viewModel.locationManager,
                isWiFiAvailable: viewModel.isWiFiAvailable,
                bleEnabled: bleEnabled
            )
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
                onResolveWindow: { window in
                    registerMainWindow(window, sceneState)
                }
            )
        )
        .task {
            sceneState.installOpenSceneAction {
                openWindow(id: WiFiLensApp.mainWindowSceneID)
            }
            EditionComposition.startLifecycle(observationRuntime: viewModel.observationRuntime)
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

@MainActor
@Observable
final class MainWindowSceneState {
    let id: UUID
    let editionWindowState: AnyObject
    var selectedPage: SidebarPage

    private(set) var pendingRoute: SidebarPage?
    private var openSceneAction: (() -> Void)?

    init(
        id: UUID = UUID(),
        editionWindowState: AnyObject? = nil,
        selectedPage: SidebarPage = .overview
    ) {
        self.id = id
        self.editionWindowState = editionWindowState ?? EditionComposition.makeMainWindowState()
        self.selectedPage = selectedPage
    }

    func route(to page: SidebarPage) {
        selectedPage = page
        pendingRoute = nil
    }

    func installOpenSceneAction(_ action: @escaping () -> Void) {
        openSceneAction = action
    }

    func requestNewScene(route: SidebarPage?) {
        pendingRoute = route
        openSceneAction?()
    }

    func consumePendingRoute(from source: MainWindowSceneState) {
        guard let route = source.pendingRoute else { return }
        source.pendingRoute = nil
        self.route(to: route)
    }
}

struct MainWindowRegistrationClaim {
    fileprivate enum Outcome: Equatable {
        case new
        case existing
        case rejected
    }

    fileprivate let key: ObjectIdentifier?
    fileprivate let registrationID: UUID?
    fileprivate let outcome: Outcome

    var isNewRegistration: Bool { outcome == .new }
    var isExistingRegistration: Bool { outcome == .existing }
    var isRejected: Bool { outcome == .rejected }
}

enum MainWindowRegistrationResult: Equatable {
    case registered
    case alreadyRegistered
    case rejected
    case editionRejected
    case completionRejected

    var isAccepted: Bool {
        self == .registered || self == .alreadyRegistered
    }
}

@MainActor
final class MainWindowLifecycleCoordinator {
    private final class Registration {
        weak var window: NSWindow?
        weak var sceneState: MainWindowSceneState?
        let sceneID: UUID
        let registrationID = UUID()
        let onActivate: @MainActor @Sendable (UUID) -> Void
        let onClose: @MainActor @Sendable (UUID) -> Void
        var observers: [NSObjectProtocol] = []
        var isCommitted = false
        var activationPending = false

        init(
            window: NSWindow,
            sceneState: MainWindowSceneState?,
            sceneID: UUID,
            onActivate: @escaping @MainActor @Sendable (UUID) -> Void,
            onClose: @escaping @MainActor @Sendable (UUID) -> Void
        ) {
            self.window = window
            self.sceneState = sceneState
            self.sceneID = sceneID
            self.onActivate = onActivate
            self.onClose = onClose
        }
    }

    private var registrations: [ObjectIdentifier: Registration] = [:]
    private(set) weak var activeWindow: NSWindow?
    private weak var sceneOpeningFallback: MainWindowSceneState?
    private let isActiveAtRegistration: @MainActor (NSWindow) -> Bool

    var hasWindows: Bool { !registrations.isEmpty }

    init(
        isActiveAtRegistration: @escaping @MainActor (NSWindow) -> Bool = {
            $0.isKeyWindow || $0.isMainWindow
        }
    ) {
        self.isActiveAtRegistration = isActiveAtRegistration
    }

    func claim(
        _ window: NSWindow,
        sceneState: MainWindowSceneState,
        onActivate: @escaping @MainActor @Sendable (UUID) -> Void = { _ in },
        onClose: @escaping @MainActor @Sendable (UUID) -> Void = { _ in }
    ) -> MainWindowRegistrationClaim {
        let key = ObjectIdentifier(window)
        if let existing = registrations[key] {
            guard existing.sceneState === sceneState else {
                return MainWindowRegistrationClaim(
                    key: nil,
                    registrationID: nil,
                    outcome: .rejected
                )
            }
            return MainWindowRegistrationClaim(
                key: key,
                registrationID: existing.registrationID,
                outcome: .existing
            )
        }

        let registration = Registration(
            window: window,
            sceneState: sceneState,
            sceneID: sceneState.id,
            onActivate: onActivate,
            onClose: onClose
        )
        registrations[key] = registration
        installObservers(for: registration, key: key, window: window)
        if isActiveAtRegistration(window) { registration.activationPending = true }
        return MainWindowRegistrationClaim(
            key: key,
            registrationID: registration.registrationID,
            outcome: .new
        )
    }

    @discardableResult
    func complete(_ claim: MainWindowRegistrationClaim) -> Bool {
        guard claim.outcome != .rejected, let key = claim.key,
              let registrationID = claim.registrationID,
              let registration = registrations[key],
              registration.registrationID == registrationID else { return false }
        guard !registration.isCommitted else { return true }
        if let sceneState = registration.sceneState {
            if let fallback = sceneOpeningFallback, fallback !== sceneState {
                sceneState.consumePendingRoute(from: fallback)
            }
            sceneOpeningFallback = sceneState
        }
        registration.isCommitted = true
        if registration.activationPending, let window = registration.window {
            activateRegistration(for: key, window: window)
        }
        return true
    }

    func abort(_ claim: MainWindowRegistrationClaim) {
        guard claim.outcome == .new, let key = claim.key,
              let registrationID = claim.registrationID,
              let registration = registrations[key],
              registration.registrationID == registrationID,
              !registration.isCommitted else { return }
        removeRegistration(for: key)
    }

    @discardableResult
    func register(
        _ window: NSWindow,
        sceneState: MainWindowSceneState,
        registerEdition: () -> Bool,
        rollbackEdition: () -> Void,
        onActivate: @escaping @MainActor @Sendable (UUID) -> Void = { _ in },
        onClose: @escaping @MainActor @Sendable (UUID) -> Void = { _ in }
    ) -> MainWindowRegistrationResult {
        let claim = claim(
            window,
            sceneState: sceneState,
            onActivate: onActivate,
            onClose: onClose
        )
        if claim.isRejected { return .rejected }
        if claim.isExistingRegistration {
            return complete(claim) ? .alreadyRegistered : .completionRejected
        }

        guard registerEdition() else {
            abort(claim)
            return .editionRejected
        }
        guard complete(claim) else {
            rollbackEdition()
            abort(claim)
            return .completionRejected
        }
        return .registered
    }

    func routeActiveWindow(to page: SidebarPage) {
        registration(for: activeWindow)?.sceneState?.route(to: page)
    }

    func requestMainWindow(route: SidebarPage?) {
        if let registration = registration(for: activeWindow), let sceneState = registration.sceneState {
            if let route { sceneState.route(to: route) }
            return
        }
        sceneOpeningFallback?.requestNewScene(route: route)
    }

    func sceneState(for window: NSWindow) -> MainWindowSceneState? {
        registrations[ObjectIdentifier(window)]?.sceneState
    }

    private func installObservers(for registration: Registration, key: ObjectIdentifier, window: NSWindow) {
        let activate: @MainActor @Sendable () -> Void = { [weak self, weak window] in
            guard let self, let window else { return }
            self.activateRegistration(for: key, window: window)
        }
        registration.observers = [
            NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main) { _ in
                MainActor.assumeIsolated { activate() }
            },
            NotificationCenter.default.addObserver(forName: NSWindow.didBecomeMainNotification, object: window, queue: .main) { _ in
                MainActor.assumeIsolated { activate() }
            },
            NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.closeRegistration(for: key) }
            }
        ]
    }

    private func activateRegistration(for key: ObjectIdentifier, window: NSWindow) {
        guard let registration = registrations[key] else { return }
        guard registration.isCommitted else {
            registration.activationPending = true
            return
        }
        activeWindow = window
        registration.activationPending = false
        registration.onActivate(registration.sceneID)
    }

    private func closeRegistration(for key: ObjectIdentifier) {
        guard let registration = registrations[key] else { return }
        removeRegistration(for: key)
        if registration.isCommitted {
            registration.onClose(registration.sceneID)
        }
    }

    private func registration(for window: NSWindow?) -> Registration? {
        guard let window else { return nil }
        return registrations[ObjectIdentifier(window)]
    }

    private func removeRegistration(for key: ObjectIdentifier) {
        guard let registration = registrations.removeValue(forKey: key) else { return }
        registration.observers.forEach(NotificationCenter.default.removeObserver)
        if activeWindow === registration.window {
            activeWindow = nil
        }
    }
}

/// Aggregates route visibility for process-shared scanners without owning any
/// per-edition or per-window feature state.
@MainActor
final class MainWindowRouteResourceCoordinator {
    private var routes: [UUID: SidebarPage] = [:]
    private var setSpectrumActive: @MainActor (Bool) -> Void
    private var startBLE: @MainActor () async -> Void
    private var stopBLE: @MainActor () -> Void
    private var bleStartTask: Task<Void, Never>?
    private var spectrumResourceIDs: [ObjectIdentifier] = []
    private var bleResourceID: ObjectIdentifier?

    init(
        setSpectrumActive: @escaping @MainActor (Bool) -> Void = { _ in },
        setBLEActive: @escaping @MainActor (Bool) -> Void = { _ in }
    ) {
        self.setSpectrumActive = setSpectrumActive
        self.startBLE = { setBLEActive(true) }
        self.stopBLE = { setBLEActive(false) }
    }

    func bind(spectrumViewModels: [BandChartViewModel], bleViewModel: BLEViewModel?) {
        let nextSpectrumIDs = spectrumViewModels.map(ObjectIdentifier.init)
        if nextSpectrumIDs != spectrumResourceIDs {
            if !spectrumResourceIDs.isEmpty { setSpectrumActive(false) }
            spectrumResourceIDs = nextSpectrumIDs
            setSpectrumActive = { [spectrumViewModels] active in
                spectrumViewModels.forEach { $0.isViewVisible = active }
            }
            setSpectrumActive(hasSpectrumLease)
        }

        let nextBLEID = bleViewModel.map(ObjectIdentifier.init)
        if nextBLEID != bleResourceID {
            bleStartTask?.cancel()
            bleStartTask = nil
            if bleResourceID != nil { stopBLE() }
            bleResourceID = nextBLEID
            startBLE = { [weak bleViewModel] in
                guard let bleViewModel, !bleViewModel.isScanning else { return }
                await bleViewModel.startScanning()
            }
            stopBLE = { [weak bleViewModel] in
                if bleViewModel?.isScanning == true {
                    bleViewModel?.stopScanning()
                }
            }
            publishBLEState(hasBLELease)
        }
    }

    func register(windowID: UUID, route: SidebarPage) {
        guard routes[windowID] == nil else { return }
        transition(windowID: windowID, to: route)
    }

    func update(windowID: UUID, route: SidebarPage) {
        guard routes[windowID] != nil else { return }
        transition(windowID: windowID, to: route)
    }

    func release(windowID: UUID) {
        guard routes[windowID] != nil else { return }
        let hadSpectrumLease = hasSpectrumLease
        let hadBLELease = hasBLELease
        routes.removeValue(forKey: windowID)
        publishEdges(hadSpectrumLease: hadSpectrumLease, hadBLELease: hadBLELease)
    }

    private func transition(windowID: UUID, to route: SidebarPage) {
        let hadSpectrumLease = hasSpectrumLease
        let hadBLELease = hasBLELease
        routes[windowID] = route
        publishEdges(hadSpectrumLease: hadSpectrumLease, hadBLELease: hadBLELease)
    }

    private func publishEdges(hadSpectrumLease: Bool, hadBLELease: Bool) {
        if hadSpectrumLease != hasSpectrumLease {
            setSpectrumActive(hasSpectrumLease)
        }
        if hadBLELease != hasBLELease {
            publishBLEState(hasBLELease)
        }
    }

    private func publishBLEState(_ isActive: Bool) {
        bleStartTask?.cancel()
        bleStartTask = nil
        guard isActive else {
            stopBLE()
            return
        }

        let resourceID = bleResourceID
        let startBLE = startBLE
        let stopBLE = stopBLE
        bleStartTask = Task { @MainActor [weak self] in
            guard let self, !Task.isCancelled,
                  self.hasBLELease,
                  self.bleResourceID == resourceID else { return }
            await startBLE()
            guard !Task.isCancelled,
                  self.hasBLELease,
                  self.bleResourceID == resourceID else {
                stopBLE()
                return
            }
        }
    }

    private var hasSpectrumLease: Bool {
        routes.values.contains(.spectrum)
    }

    private var hasBLELease: Bool {
        routes.values.contains(.bleScanner)
    }
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

enum MainWindowOpenSource: Equatable {
    case app
    case menuBar
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

@MainActor
final class ApplicationTerminationCoordinator: NSObject, NSApplicationDelegate {
    typealias TerminationStep = @MainActor () async -> Void

    static let defaultTerminationDeadline: Duration = .seconds(3)

    private var stopRuntime: TerminationStep = {}
    private var terminateEdition: TerminationStep = {}
    private let terminationDeadline: Duration
    private let reply: @MainActor (Bool) -> Void
    private var terminationTask: Task<Void, Never>?
    private var deadlineTask: Task<Void, Never>?
    private var hasReplied = false

    override convenience init() {
        self.init(
            terminationDeadline: Self.defaultTerminationDeadline,
            reply: { NSApp.reply(toApplicationShouldTerminate: $0) }
        )
    }

    init(
        terminationDeadline: Duration = defaultTerminationDeadline,
        reply: @escaping @MainActor (Bool) -> Void
    ) {
        self.terminationDeadline = terminationDeadline
        self.reply = reply
        super.init()
    }

    func configure(
        stopRuntime: @escaping TerminationStep,
        terminateEdition: @escaping TerminationStep
    ) {
        guard terminationTask == nil, !hasReplied else { return }
        self.stopRuntime = stopRuntime
        self.terminateEdition = terminateEdition
    }

    func requestTermination() -> NSApplication.TerminateReply {
        guard terminationTask == nil, !hasReplied else { return .terminateLater }
        let stopRuntime = stopRuntime
        let terminateEdition = terminateEdition
        terminationTask = Task { @MainActor [weak self] in
            await stopRuntime()
            guard !Task.isCancelled else { return }
            await terminateEdition()
            self?.finishTermination(cancelOperation: false)
        }
        deadlineTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: terminationDeadline)
            } catch {
                return
            }
            finishTermination(cancelOperation: true)
        }
        return .terminateLater
    }

    private func finishTermination(cancelOperation: Bool) {
        guard !hasReplied else { return }
        hasReplied = true
        if cancelOperation {
            terminationTask?.cancel()
        } else {
            deadlineTask?.cancel()
        }
        reply(true)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        requestTermination()
    }
}

@main
struct WiFiLensApp: App {
    static let mainWindowSceneID = "WiFiLensMainWindowScene"

    @NSApplicationDelegateAdaptor(ApplicationTerminationCoordinator.self)
    private var terminationCoordinator
    @State private var viewModel = ScannerViewModel()
    @State private var roamingViewModel = RoamingTestViewModel()
    @State private var bleViewModel: BLEViewModel?
    @State private var sparkleUpdater = SparkleUpdater()
    @State private var showCrashLog: Bool = false
    @State private var mainWindowLifecycle = MainWindowLifecycleCoordinator()
    @State private var routeResources = MainWindowRouteResourceCoordinator()
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
            Group {
                AppRootView(
                    viewModel: viewModel,
                    roamingViewModel: roamingViewModel,
                    bleViewModel: bleViewModel,
                    showCrashLog: $showCrashLog,
                    crashLogText: $crashLogText,
                    sparkleUpdater: sparkleUpdater,
                    updateMCPServer: updateMCPServer,
                    registerMainWindow: registerMainWindow,
                    updateMainWindowRoute: { windowID, route in
                        routeResources.update(windowID: windowID, route: route)
                    }
                )
            }
            .preferredColorScheme(colorScheme)
            .task {
                terminationCoordinator.configure(
                    stopRuntime: { await viewModel.stopForTermination() },
                    terminateEdition: { await EditionComposition.prepareForTermination() }
                )
            }
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
            routeResources.bind(
                spectrumViewModels: viewModel.allBandViewModels,
                bleViewModel: bleViewModel
            )
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
                    showMainWindow(route: .overview)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button(String(localized: "nav.spectrum", comment: "Navigate to Spectrum page")) {
                    showMainWindow(route: .spectrum)
                }
                .keyboardShortcut("2", modifiers: .command)

                Button(String(localized: "nav.channels", comment: "Navigate to Channels page")) {
                    showMainWindow(route: .channels)
                }
                .keyboardShortcut("3", modifiers: .command)

                Button(String(localized: "nav.interfaces", comment: "Navigate to Interfaces page")) {
                    showMainWindow(route: .interfaces)
                }
                .keyboardShortcut("4", modifiers: .command)

                Button(String(localized: "nav.roaming_test", comment: "Navigate to Roaming page")) {
                    showMainWindow(route: .roaming)
                }
                .keyboardShortcut("5", modifiers: .command)

                Button(String(localized: "nav.ble_scanner", comment: "Navigate to BLE Scanner page")) {
                    showMainWindow(route: .bleScanner)
                }
                .keyboardShortcut("6", modifiers: .command)

                Button(String(localized: "nav.timeline", comment: "Navigate to Timeline page")) {
                    showMainWindow(route: .timeline)
                }
                .keyboardShortcut("7", modifiers: .command)
            }

            CommandGroup(after: .toolbar) {
                Menu(String(localized: "common.action.export", comment: "Export menu item or button")) {
                    Button(String(localized: "export.snapshot_image", comment: "Export chart snapshot as single PNG image")) {
                        exportSnapshotImage()
                    }
                    .keyboardShortcut("e", modifiers: [.command, .shift])

                    switch EditionComposition.markdownExportCommandContribution {
                    case .available(let export):
                        Button(String(localized: "export.snapshot_markdown", comment: "Export as self-contained Markdown report")) {
                            export(viewModel)
                        }
                        .keyboardShortcut("m", modifiers: [.command, .shift])
                    case .lockedPreview:
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
                    }

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

        EditionComposition.menuBarScene(
            openMainWindow: { route in showMainWindow(route: route, source: .menuBar) },
            terminate: { NSApp.terminate(nil) }
        )
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
        EditionComposition.menuBarWindowManagementEnabled && menuBarEnabled
    }

    @MainActor
    private func showMainWindow(route: SidebarPage? = nil, source: MainWindowOpenSource = .app) {
        if source == .menuBar {
            dismissTransientMenuBarWindowIfNeeded()
            Task { @MainActor in
                await Task.yield()
                openMainWindow(route: route)
            }
            return
        }

        openMainWindow(route: route)
    }

    @MainActor
    private func openMainWindow(route: SidebarPage? = nil) {
        switch reopenAction(menuBarEnabled: menuBarWindowManagementEnabled, currentPolicy: NSApp.activationPolicy()) {
        case .switchToRegular:
            NSApp.setActivationPolicy(.regular)
        case .keepCurrentPolicy, .switchToAccessory:
            break
        }

        let hasExistingMainWindow = mainWindowLifecycle.hasWindows
        pendingResolvedMainWindowFocus = (
            resolvedWindowFocusIntent(hasExistingMainWindow: hasExistingMainWindow) == .focusResolvedWindow
        )

        NSApp.activate(ignoringOtherApps: true)

        if let mainWindow = mainWindowLifecycle.activeWindow {
            if let route {
                mainWindowLifecycle.routeActiveWindow(to: route)
            }
            bringMainWindowToFront(mainWindow)
            return
        }

        mainWindowLifecycle.requestMainWindow(route: route)
    }

    @MainActor
    private func dismissTransientMenuBarWindowIfNeeded() {
        guard let keyWindow = NSApp.keyWindow else { return }
        guard keyWindow !== mainWindowLifecycle.activeWindow else { return }
        keyWindow.close()
    }

    @MainActor
    private func registerMainWindow(_ window: NSWindow?, sceneState: MainWindowSceneState) {
        guard let window else { return }

        routeResources.bind(
            spectrumViewModels: viewModel.allBandViewModels,
            bleViewModel: bleViewModel
        )

        let registration = mainWindowLifecycle.register(
            window,
            sceneState: sceneState,
            registerEdition: {
                routeResources.register(windowID: sceneState.id, route: sceneState.selectedPage)
                guard EditionComposition.registerMainWindowState(
                    sceneState.editionWindowState,
                    for: sceneState.id
                ) else {
                    routeResources.release(windowID: sceneState.id)
                    return false
                }
                return true
            },
            rollbackEdition: {
                routeResources.release(windowID: sceneState.id)
                EditionComposition.unregisterMainWindowState(
                    sceneState.editionWindowState,
                    for: sceneState.id
                )
            },
            onActivate: { windowID in
                EditionComposition.mainWindowDidBecomeActive(windowID)
            },
            onClose: { windowID in
                routeResources.release(windowID: windowID)
                EditionComposition.mainWindowWillClose(windowID)
                handleMainWindowWillClose()
            }
        )
        guard registration.isAccepted else { return }

        guard pendingResolvedMainWindowFocus else { return }

        pendingResolvedMainWindowFocus = false
        bringMainWindowToFront(window)
    }

    @MainActor
    private func bringMainWindowToFront(_ window: NSWindow) {
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        NSApp.activate(ignoringOtherApps: true)
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.orderFrontRegardless()
        window.makeMain()
        window.makeKey()
        window.makeKeyAndOrderFront(nil)
    }

    @MainActor
    private func handleMainWindowWillClose() {
        pendingResolvedMainWindowFocus = false

        guard !mainWindowLifecycle.hasWindows else { return }
        switch closeAction(menuBarEnabled: menuBarWindowManagementEnabled) {
        case .switchToAccessory:
            NSApp.setActivationPolicy(.accessory)
        case .keepCurrentPolicy, .switchToRegular:
            break
        }
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
