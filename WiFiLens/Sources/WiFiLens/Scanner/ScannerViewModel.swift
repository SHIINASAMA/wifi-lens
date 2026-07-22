import SwiftUI
import Foundation
import CoreWLAN

enum ScanAccessState: Equatable {
    case waitingForAuthorization
    case denied
    case scanning
    case grantedButSSIDUnavailable
    case scanFailed(String)
}

struct APDisplayState: Hashable {
    var visibility: Bool
    var visibilityLocked: Bool
}

struct NetworkTableRow: Identifiable, Hashable {
    let id: String
    let bandID: String           // "24"/"5"/"6" — raw identifier, never localized
    let bandLabel: String
    let channel: Int
    let rssi: Int
    let ssid: String
    var vendor: String = "—"
    let bssid: String
    let color: Color
    let isFilteredOut: Bool
    let phyMode: String
    let channelWidth: String
    let supportsK: Bool
    let supportsR: Bool
    let supportsV: Bool
    let isHiddenSSID: Bool
    let security: String
    let mcs: String
    let nss: String
    let country: String
    let trendArrow: String
    let trendDelta: Int
    let isVisible: Bool
    let visibilityLocked: Bool
    let qualityScore: Int
    let lastSeen: String
}

@MainActor
@Observable
final class ScannerViewModel {
    var locationManager = LocationPermissionManager()
    let colorHasher = SSIDColorHasher()
    let signalHistory = SignalHistoryStore()
    let mcpServer = MCPServer()
    let throughputMonitor = ThroughputMonitor()
    var hiddenBSSIDs: Set<String> = []
    var hiddenBands: Set<String> = []       // band IDs ("24"/"5"/"6") to hide
    var hideHiddenSSIDs: Bool = false       // hide networks with empty SSID
    private(set) var lastNetworks: [WiFiNetwork] = []  // cached for toggle rebuild + MCP
    private(set) var deduplicatedNetworks: [WiFiNetwork] = []
    private(set) var displayStatesByID: [String: APDisplayState] = [:]
    private(set) var panelFilterQueries: [SpectrumPanelID: String] = [:]
    let wifiPowerMonitor = WiFiPowerMonitor()
    var wifiPowerState: WiFiPowerState = .poweredOn

    var band24 = BandChartViewModel(band: .band24GHz)
    var band5 = BandChartViewModel(band: .band5GHz)
    var band6 = BandChartViewModel(band: .band6GHz)
    private let primaryBand24 = BandChartViewModel(band: .band24GHz)
    private let primaryBand5 = BandChartViewModel(band: .band5GHz)
    private let primaryBand6 = BandChartViewModel(band: .band6GHz)
    private let secondaryBand24 = BandChartViewModel(band: .band24GHz)
    private let secondaryBand5 = BandChartViewModel(band: .band5GHz)
    private let secondaryBand6 = BandChartViewModel(band: .band6GHz)

    var supportedBands: Set<ChannelBand> = []
    var isScanning = false
    var interfaceName: String = ""
    var accessState: ScanAccessState = .waitingForAuthorization
    var isWiFiAvailable: Bool { wifiPowerState == .poweredOn }

    private var hasStarted = false
    private var isStartingScan = false
    private var startupTask: Task<Void, Never>?
    private var wifiMonitoringTask: Task<Void, Never>?
    private var runtimeLifecycleTail: Task<Void, Never>?
    private var terminationStopTask: Task<Void, Never>?
    private var isTerminating = false
    private var activeProjectionGeneration: UUID?

    let store: WiFiObservationStore
    let observationRuntime: WiFiObservationRuntime
    private let authorizationRefresh: @MainActor (LocationPermissionManager) -> Void
    private let userDefaults: UserDefaults
    private let vendorResolver: any MACVendorResolving
    private var userDefaultsRegionOverride: RegulatoryDomain?

    init(
        store: WiFiObservationStore = .shared,
        userDefaults: UserDefaults = .standard,
        vendorResolver: any MACVendorResolving = MACVendorResolver(),
        authorizationRefresh: @escaping @MainActor (LocationPermissionManager) -> Void = { $0.refreshStatus() }
    ) {
        self.store = store
        self.observationRuntime = WiFiObservationRuntime(store: store)
        self.authorizationRefresh = authorizationRefresh
        self.userDefaults = userDefaults
        self.vendorResolver = vendorResolver
        self.userDefaultsRegionOverride = Self.regionOverride(
            from: userDefaults.string(forKey: "regulatoryRegionOverride") ?? "auto"
        )
        wifiPowerState = wifiPowerMonitor.currentState
        updateMCPDataProvider()
    }

    init(
        observationRuntime: WiFiObservationRuntime,
        userDefaults: UserDefaults = .standard,
        vendorResolver: any MACVendorResolving = MACVendorResolver(),
        authorizationRefresh: @escaping @MainActor (LocationPermissionManager) -> Void = { $0.refreshStatus() }
    ) {
        self.store = observationRuntime.store
        self.observationRuntime = observationRuntime
        self.authorizationRefresh = authorizationRefresh
        self.userDefaults = userDefaults
        self.vendorResolver = vendorResolver
        self.userDefaultsRegionOverride = Self.regionOverride(
            from: userDefaults.string(forKey: "regulatoryRegionOverride") ?? "auto"
        )
        wifiPowerState = wifiPowerMonitor.currentState
        updateMCPDataProvider()
    }

    /// Trigger the Location Services authorization flow:
    /// - `.notDetermined` → system dialog
    /// - `.denied` → alert offering to open System Settings
    func requestAuthorization() {
        locationManager.refreshStatus()
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestPermissionIfNeeded()
        } else {
            locationManager.showDeniedAlert = true
        }
    }

    var globalFilterQuery: String = "" {
        didSet { applyGlobalFilterToBands() }
    }
    var selectedNetworkID: String?
    var networkInfo: [NetworkInterfaceInfo] = []
    var channelQualities: [ChannelQuality] = []

    // Regulatory-aware recommendations (Phase 2: computed alongside channelQualities)
    let regulatoryPipeline = RegulatoryPipeline()
    var channelRecommendations: [ChannelRecommendation] = []
    var inferredRegion: RegionInferenceResult? { regulatoryPipeline.inferredRegion }
    var userRegionOverride: RegulatoryDomain? {
        get { regulatoryPipeline.userRegionOverride }
        set { regulatoryPipeline.userRegionOverride = newValue }
    }

    var bandViewModels: [BandChartViewModel] {
        [band24, band5, band6].filter { supportedBands.contains($0.band) }
    }

    var allBandViewModels: [BandChartViewModel] {
        [band24, band5, band6, primaryBand24, primaryBand5, primaryBand6, secondaryBand24, secondaryBand5, secondaryBand6]
    }

    func bandViewModel(for panelID: SpectrumPanelID, selection: BandPanelSelection) -> BandChartViewModel {
        switch (panelID, selection) {
        case (.primary, .band24): return primaryBand24
        case (.primary, .band5): return primaryBand5
        case (.primary, .band6): return primaryBand6
        case (.secondary, .band24): return secondaryBand24
        case (.secondary, .band5): return secondaryBand5
        case (.secondary, .band6): return secondaryBand6
        case (.primary, .trend): return primaryBand24
        case (.secondary, .trend): return secondaryBand24
        }
    }

    func filterQuery(for panelID: SpectrumPanelID) -> String {
        panelFilterQueries[panelID, default: ""]
    }

    func setFilterQuery(_ query: String, for panelID: SpectrumPanelID) {
        panelFilterQueries[panelID] = query
        refreshPanelBandViewModels(panelID)
    }

    func panelBandViewModels(for panelID: SpectrumPanelID) -> [BandChartViewModel] {
        [
            bandViewModel(for: panelID, selection: .band24),
            bandViewModel(for: panelID, selection: .band5),
            bandViewModel(for: panelID, selection: .band6),
        ]
        .filter { supportedBands.contains($0.band) }
    }

    var combinedTableRows: [NetworkTableRow] {
        let qualityScores = Dictionary(uniqueKeysWithValues: bandViewModels.flatMap { vm in
            vm.allSeriesData.map { ($0.id, $0.qualityScore) }
        })

        return deduplicatedNetworks.map { network in
            let seriesID = network.id
            let ie = network.ieData.map { IEParser.parse(data: $0) }
            let trend = signalHistory.trend(for: network.bssid)
            let isHiddenSSID = (ie?.isHiddenSSID ?? false) || (network.ssid ?? "").isEmpty
            let displayState = displayStatesByID[seriesID] ?? APDisplayState(
                visibility: automaticVisibility(for: network),
                visibilityLocked: false
            )

            return NetworkTableRow(
                id: seriesID,
                bandID: network.channel.band.id,
                bandLabel: network.channel.band.displayName,
                channel: network.channel.channelNumber,
                rssi: network.rssi,
                ssid: (network.ssid?.isEmpty == false ? network.ssid! : "n/a"),
                vendor: vendorDisplayName(for: network.bssid),
                bssid: network.bssid,
                color: colorHasher.color(for: network.ssid, bssid: network.bssid),
                isFilteredOut: false,
                phyMode: ie.map { phyLabel($0) } ?? "",
                channelWidth: ie.map { chanWidthLabel($0) } ?? "",
                supportsK: ie?.supports80211k ?? false,
                supportsR: ie?.supports80211r ?? false,
                supportsV: ie?.supports80211v ?? false,
                isHiddenSSID: isHiddenSSID,
                security: ie?.securitySummary ?? "",
                mcs: ie?.mcsSummary ?? "",
                nss: ie?.nssSummary ?? "",
                country: ie?.countryCode ?? "",
                trendArrow: trendArrow(for: trend?.direction),
                trendDelta: trend?.delta ?? 0,
                isVisible: displayState.visibility,
                visibilityLocked: displayState.visibilityLocked,
                qualityScore: qualityScores[seriesID] ?? 0,
                lastSeen: ""
            )
        }
    }

    private func vendorDisplayName(for bssid: String) -> String {
        if case let .registered(organization) = vendorResolver.resolve(bssid) {
            return organization
        }
        return "—"
    }

    /// Effective scan interval in seconds. Writes update the user's requested
    /// interval, while active leases may keep the effective value lower.
    var scanIntervalSeconds: Int {
        get { effectiveScanIntervalSeconds }
        set {
            requestedScanIntervalSeconds = max(1, newValue)
            applyEffectiveScanInterval()
        }
    }

    private var requestedScanIntervalSeconds = 3
    private var effectiveScanIntervalSeconds = 3
    private var scanIntervalLeases: [UUID: Int] = [:]

    var activeScanIntervalLeaseCount: Int { scanIntervalLeases.count }

    func acquireScanIntervalLease(seconds: Int) -> UUID {
        let token = UUID()
        if scanIntervalLeases.isEmpty {
            let configuredInterval = userDefaults.integer(forKey: "scanIntervalSeconds")
            if configuredInterval > 0 {
                requestedScanIntervalSeconds = configuredInterval
            }
        }
        scanIntervalLeases[token] = max(1, seconds)
        applyEffectiveScanInterval()
        return token
    }

    func releaseScanIntervalLease(_ token: UUID) {
        guard scanIntervalLeases.removeValue(forKey: token) != nil else { return }
        applyEffectiveScanInterval()
    }

    private func applyEffectiveScanInterval() {
        let leasedInterval = scanIntervalLeases.values.min()
        let nextInterval = leasedInterval.map {
            min(requestedScanIntervalSeconds, $0)
        } ?? requestedScanIntervalSeconds
        guard effectiveScanIntervalSeconds != nextInterval else { return }

        let previousInterval = effectiveScanIntervalSeconds
        effectiveScanIntervalSeconds = nextInterval
        guard isScanning else { return }
        AppLogger.scanner.info("scanIntervalSeconds changed \(previousInterval) → \(nextInterval), restarting scan loop")
        restartScanLoop()
    }

    func start() async {
        guard !isTerminating else { return }
        wifiPowerMonitor.startMonitoring()
        if let startupTask {
            await startupTask.value
            return
        }
        guard !hasStarted else { return }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            guard !isTerminating else { return }
            AppLogger.scanner.info("start() — begin")

            locationManager.onAuthorizationGranted = { [weak self] in
                guard let self else { return }
                Task { @MainActor in
                    await self.startScanningAfterAuth()
                }
            }

            locationManager.requestPermissionIfNeeded()
            locationManager.refreshStatus()

            // Observe WiFi power state changes — drives scan start/stop
            startWiFiMonitoring()
            reconcileWiFiState(wifiPowerState)
        }

        startupTask = task
        await task.value
        startupTask = nil
    }

    private func startScanningAfterAuth() async {
        guard !isTerminating else { return }
        guard !isStartingScan else { return }
        guard !isScanning else { return }
        guard wifiPowerState == .poweredOn else { return }
        isStartingScan = true
        defer { isStartingScan = false }
        let stored = userDefaults.integer(forKey: "scanIntervalSeconds")
        scanIntervalSeconds = stored > 0 ? stored : 3
        await startScanLoop()
        hasStarted = true
    }

    func handleSceneDidBecomeActive() async {
        guard !isTerminating else { return }
        locationManager.refreshStatus()
        wifiPowerMonitor.refreshState()
        reconcileWiFiState(wifiPowerMonitor.currentState)
    }

    private func startWiFiMonitoring() {
        guard !isTerminating else { return }
        guard wifiMonitoringTask == nil else { return }

        wifiMonitoringTask = Task { [weak self] in
            guard let self else { return }
            let stream = self.wifiPowerMonitor.events
            for await state in stream {
                self.reconcileWiFiState(state)
            }
        }
    }

    private func reconcileWiFiState(_ state: WiFiPowerState) {
        wifiPowerState = state
        updateMCPDataProvider()
        guard !isTerminating else { return }

        switch state {
        case .poweredOn:
            if locationManager.isAuthorizedForSSID {
                Task { await startScanningAfterAuth() }
            } else if locationManager.authorizationStatus == .notDetermined {
                accessState = .waitingForAuthorization
                AppLogger.scanner.info("reconcileWiFiState() — waiting for authorization callback")
            } else {
                AppLogger.scanner.warning("reconcileWiFiState() — authorization denied/restricted")
                accessState = .denied
                stop()
            }

        case .poweredOff, .interfaceUnavailable:
            stop()
        }
    }

    private func updateMCPDataProvider() {
        if isWiFiAvailable {
            mcpServer.dataProvider = { [weak self] in self?.lastNetworks ?? [] }
        } else {
            mcpServer.dataProvider = { [] }
        }
    }

    private func restartScanLoop() {
        guard !isTerminating else { return }
        let configuration = runtimeConfiguration
        enqueueRuntimeLifecycle { [weak self] in
            await self?.observationRuntime.restartScanning(configuration: configuration)
        }
    }

    private func startScanLoop() async {
        guard !isTerminating else { return }
        AppLogger.scanner.info("startScanLoop() — starting with interval \(scanIntervalSeconds)s")
        isScanning = true
        accessState = .scanning
        throughputMonitor.start()
        let configuration = runtimeConfiguration
        let generation = UUID()
        activeProjectionGeneration = generation
        let command = enqueueRuntimeLifecycle { [weak self] in
            guard let self else { return }
            await self.observationRuntime.startScanning(
                configuration: configuration,
                isPublicationEligible: { [weak self] in
                    self?.isRuntimePublicationEligible(for: generation) ?? false
                }
            ) { [weak self] output in
                self?.handleRuntimeOutput(output, generation: generation)
            }
        }
        await command.value
    }

    private var runtimeConfiguration: WiFiObservationRuntimeConfiguration {
        return WiFiObservationRuntimeConfiguration(
            scanInterval: .seconds(effectiveScanInterval(configured: scanIntervalSeconds)),
            userRegionOverride: userRegionOverride,
            userDefaultsRegionOverride: userDefaultsRegionOverride
        )
    }

    private func effectiveScanInterval(configured: Int) -> Int {
        let configured = max(1, configured)
        guard let leasedInterval = scanIntervalLeases.values.min() else { return configured }
        return min(configured, leasedInterval)
    }

    func handleRegulatoryRegionOverrideChange(_ rawValue: String) {
        let newOverride = Self.regionOverride(from: rawValue)
        guard newOverride != userDefaultsRegionOverride else { return }
        userDefaultsRegionOverride = newOverride
        if isScanning {
            restartScanLoop()
        }
    }

    private static func regionOverride(from rawValue: String) -> RegulatoryDomain? {
        rawValue == "auto" ? nil : RegulatoryDomain(rawValue: rawValue)
    }

    private func handleRuntimeOutput(_ output: WiFiObservationScanOutput, generation: UUID) {
        guard activeProjectionGeneration == generation, isScanning else { return }
        supportedBands = output.supportedBands
        interfaceName = output.interfaceName ?? output.cycle.observation.currentStatus?.interfaceName ?? ""
        for viewModel in allBandViewModels {
            viewModel.updateInterfaceName(interfaceName)
        }
        networkInfo = output.interfaceSnapshot.interfaces

        if let error = output.cycle.observation.environmentSnapshot?.error {
            AppLogger.scanner.error("scan failure: \(String(describing: error))")
            accessState = .scanning
            return
        }

        channelQualities = output.cycle.observation.channelAnalysis ?? []
        channelRecommendations = output.cycle.observation.channelRecommendation ?? []
        regulatoryPipeline.inferredRegion = output.cycle.inferredRegion

        applyNetworks(output.rawNetworks)
    }

    private func deduplicateNetworks(_ networks: [WiFiNetwork]) -> [WiFiNetwork] {
        var seen: [String: Int] = [:]
        var deduplicated: [WiFiNetwork] = []
        for nw in networks {
            let key = "\(nw.bssid)-\(nw.channel.channelNumber)-\(nw.channel.band.rawValue)"
            if let index = seen[key] {
                if nw.rssi > deduplicated[index].rssi {
                    deduplicated[index] = nw
                }
            } else {
                seen[key] = deduplicated.count
                deduplicated.append(nw)
            }
        }
        return deduplicated
    }

    private func makeSnapshot(for network: WiFiNetwork, timestamp: Date) -> NetworkSnapshot {
        let ie = network.ieData.map { IEParser.parse(data: $0) }
        let phyMode = ie.map { phyLabel($0) } ?? ""
        let channelWidth = ie.map { chanWidthLabel($0) } ?? ""
        let ssid = network.ssid ?? ""
        let mcs = ie?.mcsSummary ?? ""
        let nss = ie?.nssSummary ?? ""
        let security = ie?.securitySummary ?? ""
        let country = ie?.countryCode ?? ""
        let supportsK = ie?.supports80211k ?? false
        let supportsR = ie?.supports80211r ?? false
        let supportsV = ie?.supports80211v ?? false
        let supportsWPA3 = ie?.supportsWPA3 ?? false
        let isHiddenSSID = ie?.isHiddenSSID ?? false

        return NetworkSnapshot(
            timestamp: timestamp,
            bssid: network.bssid,
            ssid: ssid,
            rssi: network.rssi,
            channel: network.channel.channelNumber,
            band: network.channel.band.id,
            phyMode: phyMode,
            channelWidth: channelWidth,
            mcs: mcs,
            nss: nss,
            security: security,
            country: country,
            supportsK: supportsK,
            supportsR: supportsR,
            supportsV: supportsV,
            supportsWPA3: supportsWPA3,
            isHiddenSSID: isHiddenSSID
        )
    }

    private func makeTrends(for networks: [WiFiNetwork]) -> [String: (direction: TrendDirection, delta: Int)] {
        var trends: [String: (direction: TrendDirection, delta: Int)] = [:]
        for network in networks {
            if let trend = signalHistory.trend(for: network.bssid) {
                trends[network.bssid] = trend
            }
        }
        return trends
    }

    private func makeSnapshots(for networks: [WiFiNetwork]) -> [String: [NetworkSnapshot]] {
        var snapshots: [String: [NetworkSnapshot]] = [:]
        for network in networks {
            if let history = signalHistory.snapshotHistory(for: network.bssid) {
                snapshots[network.bssid] = history
            }
        }
        return snapshots
    }

    private func recomputeDisplayStates(for networks: [WiFiNetwork]) -> [String: APDisplayState] {
        var nextStates: [String: APDisplayState] = [:]
        for network in networks {
            let seriesID = network.id
            let previous = displayStatesByID[seriesID] ?? APDisplayState(
                visibility: automaticVisibility(for: network),
                visibilityLocked: false
            )

            if previous.visibilityLocked {
                nextStates[seriesID] = previous
            } else {
                nextStates[seriesID] = APDisplayState(
                    visibility: automaticVisibility(for: network),
                    visibilityLocked: false
                )
            }
        }
        return nextStates
    }

    private func recomputePanelDisplayStates(
        for networks: [WiFiNetwork],
        panelID: SpectrumPanelID
    ) -> [String: APDisplayState] {
        let needle = filterQuery(for: panelID).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else {
            return displayStatesByID
        }

        var nextStates: [String: APDisplayState] = [:]
        for network in networks {
            let seriesID = network.id
            let baseState = displayStatesByID[seriesID] ?? APDisplayState(
                visibility: automaticVisibility(for: network),
                visibilityLocked: false
            )

            if baseState.visibilityLocked {
                nextStates[seriesID] = baseState
                continue
            }

            let ssid = (network.ssid ?? "").lowercased()
            let bssid = network.bssid.lowercased()
            let queryMatches = ssid.contains(needle) || bssid.contains(needle)
            nextStates[seriesID] = APDisplayState(
                visibility: baseState.visibility && queryMatches,
                visibilityLocked: false
            )
        }
        return nextStates
    }

    private func refreshBandViewModels(
        for panelID: SpectrumPanelID,
        with networks: [WiFiNetwork],
        trends: [String: (direction: TrendDirection, delta: Int)],
        snapshots: [String: [NetworkSnapshot]]
    ) {
        let panelDisplayStates = recomputePanelDisplayStates(for: networks, panelID: panelID)

        let sorted24 = networks
            .filter { $0.channel.band == .band24GHz }
            .sorted { $0.channel.channelNumber < $1.channel.channelNumber }
        if supportedBands.contains(.band24GHz) {
            bandViewModel(for: panelID, selection: .band24).updateNetworks(
                sorted24,
                colorHasher: colorHasher,
                displayStatesByID: panelDisplayStates,
                trends: trends,
                snapshots: snapshots
            )
        }

        let sorted5 = networks
            .filter { $0.channel.band == .band5GHz }
            .sorted { $0.channel.channelNumber < $1.channel.channelNumber }
        if supportedBands.contains(.band5GHz) {
            bandViewModel(for: panelID, selection: .band5).updateNetworks(
                sorted5,
                colorHasher: colorHasher,
                displayStatesByID: panelDisplayStates,
                trends: trends,
                snapshots: snapshots
            )
        }

        let sorted6 = networks
            .filter { $0.channel.band == .band6GHz }
            .sorted { $0.channel.channelNumber < $1.channel.channelNumber }
        if supportedBands.contains(.band6GHz) {
            bandViewModel(for: panelID, selection: .band6).updateNetworks(
                sorted6,
                colorHasher: colorHasher,
                displayStatesByID: panelDisplayStates,
                trends: trends,
                snapshots: snapshots
            )
        }
    }

    private func refreshPanelBandViewModels(_ panelID: SpectrumPanelID) {
        refreshBandViewModels(
            for: panelID,
            with: deduplicatedNetworks,
            trends: makeTrends(for: deduplicatedNetworks),
            snapshots: makeSnapshots(for: deduplicatedNetworks)
        )
    }

    private func automaticVisibility(for network: WiFiNetwork) -> Bool {
        if hiddenBands.contains(network.channel.band.id) {
            return false
        }

        let ie = network.ieData.map { IEParser.parse(data: $0) }
        let isHiddenSSID = (ie?.isHiddenSSID ?? false) || (network.ssid ?? "").isEmpty
        if hideHiddenSSIDs && isHiddenSSID {
            return false
        }

        return true
    }

    private func trendArrow(for direction: TrendDirection?) -> String {
        switch direction {
        case .up: "▲"
        case .down: "▼"
        case .stable: "●"
        case .none: ""
        }
    }


    private func applyNetworks(_ networks: [WiFiNetwork]) {
        lastNetworks = networks
        let deduped = deduplicateNetworks(networks)
        deduplicatedNetworks = deduped

        // Record RSSI history + snapshots, build trend/history/snapshot lookups
        let now = Date()
        for nw in deduped {
            let snap = makeSnapshot(for: nw, timestamp: now)
            signalHistory.record(bssid: nw.bssid, rssi: nw.rssi, snapshot: snap)
        }
        var trends: [String: (direction: TrendDirection, delta: Int)] = [:]
        for nw in deduped {
            if let t = signalHistory.trend(for: nw.bssid) {
                trends[nw.bssid] = t
            }
        }
        var snapshotDict: [String: [NetworkSnapshot]] = [:]
        for nw in deduped {
            if let snaps = signalHistory.snapshotHistory(for: nw.bssid) { snapshotDict[nw.bssid] = snaps }
        }
        displayStatesByID = recomputeDisplayStates(for: deduped)

        let sorted24 = deduped
            .filter { $0.channel.band == .band24GHz }
            .sorted { $0.channel.channelNumber < $1.channel.channelNumber }
        if supportedBands.contains(.band24GHz) {
            band24.updateNetworks(sorted24, colorHasher: colorHasher, filterQuery: globalFilterQuery, trends: trends, snapshots: snapshotDict, hiddenBSSIDs: hiddenBSSIDs, hiddenBands: hiddenBands, hideHiddenSSIDs: hideHiddenSSIDs)
        }

        let sorted5 = deduped
            .filter { $0.channel.band == .band5GHz }
            .sorted { $0.channel.channelNumber < $1.channel.channelNumber }
        if supportedBands.contains(.band5GHz) {
            band5.updateNetworks(sorted5, colorHasher: colorHasher, filterQuery: globalFilterQuery, trends: trends, snapshots: snapshotDict, hiddenBSSIDs: hiddenBSSIDs, hiddenBands: hiddenBands, hideHiddenSSIDs: hideHiddenSSIDs)
        }

        let sorted6 = deduped
            .filter { $0.channel.band == .band6GHz }
            .sorted { $0.channel.channelNumber < $1.channel.channelNumber }
        if supportedBands.contains(.band6GHz) {
            band6.updateNetworks(sorted6, colorHasher: colorHasher, filterQuery: globalFilterQuery, trends: trends, snapshots: snapshotDict, hiddenBSSIDs: hiddenBSSIDs, hiddenBands: hiddenBands, hideHiddenSSIDs: hideHiddenSSIDs)
        }
        refreshBandViewModels(for: .primary, with: deduped, trends: trends, snapshots: snapshotDict)
        refreshBandViewModels(for: .secondary, with: deduped, trends: trends, snapshots: snapshotDict)

        // Validate selected network still exists in the new scan
        if let selectedID = selectedNetworkID {
            let allIDs = bandViewModels.flatMap { $0.allSeriesData.map(\.id) }
            if !allIDs.contains(selectedID) {
                selectedNetworkID = nil
            }
        }

        let ssidCount = bandViewModels.reduce(0) { count, vm in
            count + vm.allSeriesData.filter { $0.ssid != "n/a" }.count
        }
        accessState = ssidCount > 0 ? .scanning : .grantedButSSIDUnavailable
    }

    func applyGlobalFilterToBands() {
        band24.applyFilter(globalFilterQuery, hiddenBands: hiddenBands, hideHiddenSSIDs: hideHiddenSSIDs)
        band5.applyFilter(globalFilterQuery, hiddenBands: hiddenBands, hideHiddenSSIDs: hideHiddenSSIDs)
        band6.applyFilter(globalFilterQuery, hiddenBands: hiddenBands, hideHiddenSSIDs: hideHiddenSSIDs)
        displayStatesByID = recomputeDisplayStates(for: deduplicatedNetworks)
        refreshPanelBandViewModels(.primary)
        refreshPanelBandViewModels(.secondary)
    }

    func toggleVisibility(seriesID: String) {
        let current = displayStatesByID[seriesID] ?? APDisplayState(visibility: true, visibilityLocked: false)
        displayStatesByID[seriesID] = APDisplayState(
            visibility: !current.visibility,
            visibilityLocked: current.visibilityLocked
        )
        refreshPanelBandViewModels(.primary)
        refreshPanelBandViewModels(.secondary)
    }

    func toggleVisibilityLocked(seriesID: String) {
        let current = displayStatesByID[seriesID] ?? APDisplayState(visibility: true, visibilityLocked: false)
        displayStatesByID[seriesID] = APDisplayState(
            visibility: current.visibility,
            visibilityLocked: !current.visibilityLocked
        )
        refreshPanelBandViewModels(.primary)
        refreshPanelBandViewModels(.secondary)
    }

    func toggleVisibility(bssid: String) {
        if hiddenBSSIDs.contains(bssid) {
            hiddenBSSIDs.remove(bssid)
        } else {
            hiddenBSSIDs.insert(bssid)
        }
        applyNetworks(lastNetworks)
    }

    func stop() {
        activeProjectionGeneration = nil
        transitionToStoppedState()
        guard !isTerminating else { return }
        enqueueRuntimeLifecycle { [weak self] in
            await self?.observationRuntime.stopScanning()
        }
    }

    func stopForTermination() async {
        if let terminationStopTask {
            await terminationStopTask.value
            return
        }

        isTerminating = true
        startupTask?.cancel()
        startupTask = nil
        wifiMonitoringTask?.cancel()
        wifiMonitoringTask = nil
        wifiPowerMonitor.stopMonitoring()
        runtimeLifecycleTail?.cancel()
        activeProjectionGeneration = nil
        transitionToStoppedState()

        let runtime = observationRuntime
        let stopTask = Task { @MainActor in
            await runtime.stopScanning()
        }
        terminationStopTask = stopTask
        runtimeLifecycleTail = stopTask
        await stopTask.value
    }

    private func isRuntimePublicationEligible(for generation: UUID) -> Bool {
        guard activeProjectionGeneration == generation, isScanning else { return false }

        wifiPowerMonitor.refreshState()
        let currentPowerState = wifiPowerMonitor.currentState
        if currentPowerState != .poweredOn {
            wifiPowerState = currentPowerState
            updateMCPDataProvider()
            transitionToStoppedState()
            return false
        }

        authorizationRefresh(locationManager)
        guard locationManager.isAuthorizedForSSID else {
            transitionToStoppedState()
            accessState = locationManager.authorizationStatus == .notDetermined
                ? .waitingForAuthorization
                : .denied
            return false
        }
        return true
    }

    private func transitionToStoppedState() {
        isScanning = false
        throughputMonitor.stop()
    }

    @discardableResult
    private func enqueueRuntimeLifecycle(
        _ operation: @escaping @MainActor () async -> Void
    ) -> Task<Void, Never> {
        guard !isTerminating else { return Task {} }
        let previous = runtimeLifecycleTail
        let command = Task { @MainActor [weak self] in
            await previous?.value
            guard !Task.isCancelled, let self, !self.isTerminating else { return }
            await operation()
        }
        runtimeLifecycleTail = command
        return command
    }

    private func phyLabel(_ ie: IEData) -> String {
        if ie.heSupported { return "ax" }
        if ie.vhtSupported { return "ac" }
        if ie.htSupported { return "n" }
        return ""
    }

    private func chanWidthLabel(_ ie: IEData) -> String {
        if ie.supports160MHz { return "160" }
        if ie.supports80MHz { return "80" }
        if ie.supports40MHz { return "40" }
        return ""
    }
}

#if DEBUG
extension ScannerViewModel {
    func debugApplyNetworksForTesting(_ networks: [WiFiNetwork], supportedBands: Set<ChannelBand>) {
        self.supportedBands = supportedBands
        applyNetworks(networks)
    }

    func debugStartScanLoopForTesting() async {
        await startScanLoop()
    }

    func debugReconcileWiFiStateForTesting(_ state: WiFiPowerState) {
        reconcileWiFiState(state)
    }

    func debugDrainRuntimeLifecycleForTesting() async {
        await runtimeLifecycleTail?.value
    }

    func debugStartWiFiMonitoringForTesting() {
        wifiPowerMonitor.startMonitoring()
        startWiFiMonitoring()
    }

    var debugHasActiveWiFiMonitoringForTesting: Bool {
        wifiMonitoringTask != nil && wifiPowerMonitor.debugIsMonitoringForTesting
    }
}
#endif
