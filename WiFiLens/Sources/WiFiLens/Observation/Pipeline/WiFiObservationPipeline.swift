import Foundation

protocol DeviceCapabilitiesProviding: Sendable {
    func supportedWLANChannelsRaw() async -> [(Int, Int)]
    func devicePHYCapabilities() async -> DevicePHYCapabilities
}

struct WiFiDeviceCapabilitiesProvider: DeviceCapabilitiesProviding {
    private let scanner = WiFiScanner()
    func supportedWLANChannelsRaw() async -> [(Int, Int)] { await scanner.supportedWLANChannelsRaw() }
    func devicePHYCapabilities() async -> DevicePHYCapabilities { await scanner.devicePHYCapabilities() }
}

protocol WiFiObservationPipelining: Sendable {
    func refreshCurrentConnection() async -> WiFiObservation
    func refreshEnvironmentScan() async -> WiFiObservation
    func refreshFullObservation() async -> WiFiObservation
}

struct WiFiObservationPipeline: WiFiObservationPipelining {
    let currentConnectionProvider: WiFiCurrentConnectionProviding
    let environmentScanProvider: WiFiEnvironmentScanProviding
    let gatewayLatencyProvider: GatewayLatencyProviding
    let deviceCapabilitiesProvider: DeviceCapabilitiesProviding

    init(
        currentConnectionProvider: WiFiCurrentConnectionProviding = WiFiCurrentConnectionProvider(),
        environmentScanProvider: WiFiEnvironmentScanProviding = WiFiEnvironmentScanProvider(),
        gatewayLatencyProvider: GatewayLatencyProviding = GatewayLatencyProvider(),
        deviceCapabilitiesProvider: DeviceCapabilitiesProviding = WiFiDeviceCapabilitiesProvider()
    ) {
        self.currentConnectionProvider = currentConnectionProvider
        self.environmentScanProvider = environmentScanProvider
        self.gatewayLatencyProvider = gatewayLatencyProvider
        self.deviceCapabilitiesProvider = deviceCapabilitiesProvider
    }

    func refreshCurrentConnection() async -> WiFiObservation {
        let status = await currentConnectionProvider.fetchCurrentStatus()
        let latency = await gatewayLatencyProvider.measure(routerIP: status.routerIP)
        let quality = WiFiQualityEvaluator.evaluate(currentStatus: status, gatewayLatency: latency)
        return WiFiObservation(
            currentStatus: status,
            gatewayLatency: latency,
            quality: quality
        )
    }

    func refreshEnvironmentScan() async -> WiFiObservation {
        let snapshot = await environmentScanProvider.scanEnvironment()
        let currentChannel = await MainActor.run {
            NetworkInfoService.fetchAll().first(where: { $0.ssid != nil })?.channel
        }
        let channelAnalysis = ChannelOccupancyAnalyzer.analyze(
            snapshot: snapshot,
            currentChannel: currentChannel,
            supportedBands: ["24", "5", "6"],
            targetAP: nil
        )

        let rawChannels = await deviceCapabilitiesProvider.supportedWLANChannelsRaw()
        let deviceCapabilities = await deviceCapabilitiesProvider.devicePHYCapabilities()
        let deviceSupportedChannels = Set(rawChannels.map { "\($0.0)-\($0.1)" })

        let apCountryCodes: [String] = snapshot.networks.compactMap { $0.capabilities.countryCode }
        let inferredRegion = RegulatoryDomainResolver.resolve(
            userOverride: nil,
            userDefaultsOverride: nil,
            supportedChannelsRaw: rawChannels,
            apCountryCodes: apCountryCodes
        )

        let channelRecommendation = ChannelRecommendationEngine.recommend(
            channelAnalysis: channelAnalysis,
            snapshot: snapshot,
            inferredRegion: inferredRegion,
            deviceSupportedChannels: deviceSupportedChannels,
            deviceCapabilities: deviceCapabilities
        )

        var errors: [WiFiObservationError] = []
        if let snapshotError = snapshot.error {
            errors.append(snapshotError)
        }
        return WiFiObservation(
            environmentSnapshot: snapshot,
            channelAnalysis: channelAnalysis,
            channelRecommendation: channelRecommendation,
            errors: errors
        )
    }

    func refreshFullObservation() async -> WiFiObservation {
        let current = await refreshCurrentConnection()
        let scan = await refreshEnvironmentScan()

        var observation = current
        observation.environmentSnapshot = scan.environmentSnapshot
        observation.channelAnalysis = scan.channelAnalysis
        observation.channelRecommendation = scan.channelRecommendation
        observation.errors.append(contentsOf: scan.errors)
        observation.diagnosis = DiagnosticEvaluator.evaluate(
            currentStatus: current.currentStatus ?? WiFiCurrentStatus(
                timestamp: Date(), isConnected: false, isWiFiPowerOn: true
            ),
            quality: current.quality,
            channelAnalysis: scan.channelAnalysis,
            channelRecommendations: scan.channelRecommendation
        )
        return observation
    }
}
