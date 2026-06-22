import Foundation
@testable import WiFi_Lens

struct MockCurrentConnectionProvider: WiFiCurrentConnectionProviding {
    var result: WiFiCurrentStatus
    func fetchCurrentStatus() async -> WiFiCurrentStatus { result }
}

struct MockEnvironmentScanProvider: WiFiEnvironmentScanProviding {
    var result: WiFiEnvironmentSnapshot
    func scanEnvironment() async -> WiFiEnvironmentSnapshot { result }
}

struct MockGatewayLatencyProvider: GatewayLatencyProviding {
    var result: GatewayLatencyResult
    func measure(routerIP: String?) async -> GatewayLatencyResult { result }
}

struct MockRoamingProbeProvider: RoamingProbeProviding {
    var result: WiFiCurrentStatus
    func fetchCurrentProbe() async -> WiFiCurrentStatus { result }
}

struct MockDeviceCapabilitiesProvider: DeviceCapabilitiesProviding {
    var channelsRaw: [(Int, Int)] = []
    var capabilities: DevicePHYCapabilities = .default
    func supportedWLANChannelsRaw() async -> [(Int, Int)] { channelsRaw }
    func devicePHYCapabilities() async -> DevicePHYCapabilities { capabilities }
}

struct MockPipeline: WiFiObservationPipelining {
    var currentObservation: WiFiObservation
    var environmentObservation: WiFiObservation
    var fullObservation: WiFiObservation

    func refreshCurrentConnection() async -> WiFiObservation { currentObservation }
    func refreshEnvironmentScan() async -> WiFiObservation { environmentObservation }
    func refreshFullObservation() async -> WiFiObservation { fullObservation }
}
