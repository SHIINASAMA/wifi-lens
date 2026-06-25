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
    let scanner = WiFiScanner()
    var locationManager = LocationPermissionManager()
    let colorHasher = SSIDColorHasher()
    let signalHistory = SignalHistoryStore()
    let mcpServer = MCPServer()
    let throughputMonitor = ThroughputMonitor()
    var hiddenBands: Set<String> = []       // band IDs ("24"/"5"/"6") to hide
    var hideHiddenSSIDs: Bool = false       // hide networks with empty SSID
    private(set) var lastNetworks: [WiFiNetwork] = []  // cached for toggle rebuild + MCP
    private(set) var deduplicatedNetworks: [WiFiNetwork] = []
    private(set) var displayStatesByID: [String: APDisplayState] = [:]
    private(set) var panelFilterQueries: [SpectrumPanelID: String] = [:]
    let wifiPowerMonitor = WiFiPowerMonitor()
    var wifiPowerState: WiFiPowerState = .poweredOn

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
    private var startupTask: Task<Void, Never>?
    private var wifiMonitoringTask: Task<Void, Never>?

    init() {
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
        SpectrumPanelID.allCases.flatMap { panelID in
            panelBandViewModels(for: panelID)
        }
    }

    var allBandViewModels: [BandChartViewModel] {
        [
            primaryBand24,
            primaryBand5,
            primaryBand6,
            secondaryBand24,
            secondaryBand5,
            secondaryBand6,
        ]
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
        let qualityScores = Dictionary(uniqueKeysWithValues: panelBandViewModels(for: .primary).flatMap { vm in
            vm.allSeriesData.map { ($0.id, $0.qualityScore) }
        })

        return deduplicatedNetworks.map { network in
            let seriesID = network.id
            let ie = network.ieData.map { IEParser.parse(data: $0) }
            let trend = signalHistory.trend(for: network.bssid)
            let isHiddenSSID = (ie?.isHiddenSSID ?? false) || (network.ssid ?? "").isEmpty
            let displayState = displayStatesByID[seriesID] ?? APDisplayState(
                visibility: true,
                visibilityLocked: false
            )

            return NetworkTableRow(
                id: seriesID,
                bandID: network.channel.band.id,
                bandLabel: network.channel.band.displayName,
                channel: network.channel.channelNumber,
                rssi: network.rssi,
                ssid: (network.ssid?.isEmpty == false ? network.ssid! : "n/a"),
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

    private var scanTask: Task<Void, Never>?

    /// Current scan interval in seconds. Set to override the UserDefaults-configured
    /// interval (e.g. 1 s during recording). When changed while scanning, the scan
    /// loop is restarted with the new interval.
    var scanIntervalSeconds: Int = 3 {
        didSet {
            guard oldValue != scanIntervalSeconds else { return }
            guard isScanning else { return }
            AppLogger.scanner.info("scanIntervalSeconds changed \(oldValue) → \(scanIntervalSeconds), restarting scan loop")
            restartScanLoop()
        }
    }

    func start() async {
        wifiPowerMonitor.startMonitoring()
        if let startupTask {
            await startupTask.value
            return
        }
        guard !hasStarted else { return }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
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
        guard !isScanning else { return }
        guard wifiPowerState == .poweredOn else { return }
        supportedBands = await scanner.supportedBands()
        AppLogger.scanner.info("start() — supported bands = \(supportedBands.map { $0.id }.sorted())")
        // Fetch device capabilities once for the regulatory pipeline
        let rawChannels = await scanner.supportedChannels()
        regulatoryPipeline.deviceSupportedChannels = Set(rawChannels.map { "\($0.0.rawValue)-\($0.1)" })
        regulatoryPipeline.deviceCachedCapabilities = await scanner.devicePHYCapabilities()
        regulatoryPipeline.cachedSupportedChannelsRaw = await scanner.supportedWLANChannelsRaw()
        AppLogger.scanner.debug("device — supported \(rawChannels.count) channels, PHY=\(regulatoryPipeline.deviceCachedCapabilities.phySummary), DFS=\(regulatoryPipeline.deviceCachedCapabilities.supportsDFS), 6GHz=\(regulatoryPipeline.deviceCachedCapabilities.supports6GHz)")
        updateInterfaceName()
        let stored = UserDefaults.standard.integer(forKey: "scanIntervalSeconds")
        scanIntervalSeconds = max(1, stored > 0 ? stored : 3)
        startScanLoop()
        hasStarted = true
    }

    func handleSceneDidBecomeActive() async {
        locationManager.refreshStatus()
        updateInterfaceName()
        wifiPowerMonitor.refreshState()
        reconcileWiFiState(wifiPowerMonitor.currentState)
    }

    private func startWiFiMonitoring() {
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
        scanTask?.cancel()
        startScanLoop()
    }

    private func startScanLoop() {
        AppLogger.scanner.info("startScanLoop() — starting with interval \(scanIntervalSeconds)s")
        scanTask?.cancel()
        isScanning = true
        accessState = .scanning
        throughputMonitor.start()

        scanTask = Task {
            let interval: Duration = .seconds(max(1, scanIntervalSeconds))
            let stream = await scanner.startScanning(interval: interval)
            for await event in stream {
                guard !Task.isCancelled else { break }

                // Guard: stop scanning immediately if WiFi was turned off.
                // CoreWLAN callbacks handle the common case; this covers missed events.
                wifiPowerMonitor.refreshState()
                guard isWiFiAvailable else {
                    AppLogger.scanner.info("startScanLoop() — WiFi unavailable, stopping")
                    stop()
                    break
                }

                locationManager.refreshStatus()

                if !locationManager.isAuthorizedForSSID {
                    AppLogger.scanner.warning("startScanLoop() — lost authorization")
                    stop()
                    accessState = locationManager.authorizationStatus == .notDetermined
                        ? .waitingForAuthorization
                        : .denied
                    break
                }

                switch event {
                case .failure(let message):
                    AppLogger.scanner.error("scan failure: \(message)")
                    if isWiFiAvailable {
                        accessState = .scanning
                    }

                case .networks(let networks):
                    applyNetworks(networks)
                    networkInfo = NetworkInfoService.fetchAll()
                    channelQualities = computeChannelQualities()
                    channelRecommendations = computeChannelRecommendations()
                }
            }
        }
    }

    private func deduplicateNetworks(_ networks: [WiFiNetwork]) -> [WiFiNetwork] {
        var seen = [String: WiFiNetwork]()
        for nw in networks {
            let key = "\(nw.bssid)-\(nw.channel.channelNumber)-\(nw.channel.band.rawValue)"
            if let existing = seen[key] {
                if nw.rssi > existing.rssi {
                    seen[key] = nw
                }
            } else {
                seen[key] = nw
            }
        }
        return Array(seen.values)
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


    private func applyNetworks(_ networks: [WiFiNetwork]) {
        lastNetworks = networks
        let deduped = deduplicateNetworks(networks).sorted {
            if $0.channel.band != $1.channel.band {
                return $0.channel.band.rawValue < $1.channel.band.rawValue
            }
            if $0.channel.channelNumber != $1.channel.channelNumber {
                return $0.channel.channelNumber < $1.channel.channelNumber
            }
            return $0.bssid < $1.bssid
        }
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
        refreshAllBandViewModels(with: deduped, trends: trends, snapshots: snapshotDict)
        updateInterfaceName()

        // Validate selected network still exists in the new scan
        if let selectedID = selectedNetworkID {
            let allIDs = deduped.map(\.id)
            if !allIDs.contains(selectedID) {
                selectedNetworkID = nil
            }
        }

        let ssidCount = deduped.filter { ($0.ssid ?? "n/a") != "n/a" }.count
        accessState = ssidCount > 0 ? .scanning : .grantedButSSIDUnavailable
    }

    func applyGlobalFilterToBands() {
        displayStatesByID = recomputeDisplayStates(for: deduplicatedNetworks)
        refreshAllBandViewModels(
            with: deduplicatedNetworks,
            trends: makeTrends(for: deduplicatedNetworks),
            snapshots: makeSnapshots(for: deduplicatedNetworks)
        )
    }

    private func refreshAllBandViewModels(
        with networks: [WiFiNetwork],
        trends: [String: (direction: TrendDirection, delta: Int)],
        snapshots: [String: [NetworkSnapshot]]
    ) {
        for panelID in SpectrumPanelID.allCases {
            refreshBandViewModels(
                for: panelID,
                with: networks,
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
            let baseState = displayStatesByID[seriesID] ?? APDisplayState(visibility: true, visibilityLocked: false)

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

    private func updateInterfaceName() {
        Task {
            if let name = await scanner.interfaceName() {
                await MainActor.run {
                    self.interfaceName = name
                    for vm in self.bandViewModels {
                        vm.updateInterfaceName(name)
                    }
                }
            }
        }
    }

    private func computeChannelQualities() -> [ChannelQuality] {
        let currentWiFi = networkInfo.first(where: { $0.ssid != nil || $0.bssid != nil })
        let currentChannel = currentWiFi?.channel
        let targetAP = ChannelQualityCalculator.TargetAP(
            bssid: currentWiFi?.bssid,
            ssid: currentWiFi?.ssid,
            channel: currentChannel
        )

        // Deduplicate by BSSID+band: wide channels may report the same AP on
        // multiple primary channel numbers; keep only the strongest RSSI per band.
        var seen = [String: ChannelQualityCalculator.APInfo]()
        for nw in lastNetworks {
            let key = "\(nw.bssid)-\(nw.channel.band.rawValue)"
            let ie = nw.ieData.map { IEParser.parse(data: $0) }
            let width = ie.map { chanWidthLabel($0) } ?? "20"
            let left = ChannelSpanCalculator.channelBlock(
                primaryChannel: nw.channel.channelNumber,
                widthMHz: nw.channel.channelWidthMHz,
                band: nw.channel.band,
                spanDirection: nw.channel.spanDirection
            ).left
            let right = ChannelSpanCalculator.channelBlock(
                primaryChannel: nw.channel.channelNumber,
                widthMHz: nw.channel.channelWidthMHz,
                band: nw.channel.band,
                spanDirection: nw.channel.spanDirection
            ).right
            let info = ChannelQualityCalculator.APInfo(
                channel: nw.channel.channelNumber,
                rssi: nw.rssi,
                channelWidth: width,
                band: nw.channel.band.id,
                apex: Double(left + right) / 2.0,
                bssid: nw.bssid,
                ssid: nw.ssid
            )
            if let existing = seen[key] {
                if info.rssi > existing.rssi { seen[key] = info }
            } else {
                seen[key] = info
            }
        }
        let aps = Array(seen.values)
        return ChannelQualityCalculator.compute(
            aps: aps,
            currentChannel: currentChannel,
            supportedBands: Set(supportedBands.map(\.id)),
            targetAP: targetAP
        )
    }

    /// Run the regulatory-aware filtering pipeline on top of RF results.
    private func computeChannelRecommendations() -> [ChannelRecommendation] {
        let override: RegulatoryDomain? = {
            let raw = UserDefaults.standard.string(forKey: "regulatoryRegionOverride") ?? "auto"
            return raw == "auto" ? nil : RegulatoryDomain(rawValue: raw)
        }()
        let regulatoryResults = regulatoryPipeline.computeRecommendations(
            from: channelQualities,
            networks: lastNetworks,
            userDefaultsOverride: override
        )
        return RecommendationReasonCalculator.compute(for: regulatoryResults)
    }

    func toggleVisibility(seriesID: String) {
        let current = displayStatesByID[seriesID] ?? APDisplayState(visibility: true, visibilityLocked: false)
        displayStatesByID[seriesID] = APDisplayState(
            visibility: !current.visibility,
            visibilityLocked: current.visibilityLocked
        )
        refreshAllBandViewModels(
            with: deduplicatedNetworks,
            trends: makeTrends(for: deduplicatedNetworks),
            snapshots: makeSnapshots(for: deduplicatedNetworks)
        )
    }

    func toggleVisibilityLocked(seriesID: String) {
        let current = displayStatesByID[seriesID] ?? APDisplayState(visibility: true, visibilityLocked: false)
        displayStatesByID[seriesID] = APDisplayState(
            visibility: current.visibility,
            visibilityLocked: !current.visibilityLocked
        )
        refreshAllBandViewModels(
            with: deduplicatedNetworks,
            trends: makeTrends(for: deduplicatedNetworks),
            snapshots: makeSnapshots(for: deduplicatedNetworks)
        )
    }

    func stop() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        throughputMonitor.stop()
        Task { await scanner.stopScanning() }
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
}
#endif
