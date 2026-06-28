import Foundation
import Testing
@testable import WiFi_Lens

@Suite("WiFiObservationPipeline")
struct PipelineTests {
    @Test("refreshCurrentConnection returns currentStatus + quality, no environment")
    func currentConnectionOnly() async {
        let status = WiFiCurrentStatus(
            timestamp: Date(), ssid: "Test", bssid: "AA:BB", channel: 36,
            rssi: -50, isConnected: true, isWiFiPowerOn: true
        )
        let latency = GatewayLatencyResult(timestamp: Date(), latencyMs: 20)
        let pipeline = WiFiObservationPipeline(
            currentConnectionProvider: MockCurrentConnectionProvider(result: status),
            environmentScanProvider: MockEnvironmentScanProvider(result: WiFiEnvironmentSnapshot(
                timestamp: Date(), interfaceName: "en0", networks: []
            )),
            gatewayLatencyProvider: MockGatewayLatencyProvider(result: latency),
            deviceCapabilitiesProvider: MockDeviceCapabilitiesProvider()
        )
        let obs = await pipeline.refreshCurrentConnection()
        #expect(obs.currentStatus != nil)
        #expect(obs.quality != nil)
        #expect(obs.environmentSnapshot == nil)
    }

    @Test("refreshEnvironmentScan returns snapshot, no currentStatus")
    func environmentScanOnly() async {
        let snapshot = WiFiEnvironmentSnapshot(
            timestamp: Date(), interfaceName: "en0", networks: []
        )
        let pipeline = WiFiObservationPipeline(
            currentConnectionProvider: MockCurrentConnectionProvider(result: WiFiCurrentStatus(
                timestamp: Date(), isConnected: false, isWiFiPowerOn: true
            )),
            environmentScanProvider: MockEnvironmentScanProvider(result: snapshot),
            gatewayLatencyProvider: MockGatewayLatencyProvider(result: GatewayLatencyResult(
                timestamp: Date()
            )),
            deviceCapabilitiesProvider: MockDeviceCapabilitiesProvider()
        )
        let obs = await pipeline.refreshEnvironmentScan()
        #expect(obs.environmentSnapshot != nil)
        #expect(obs.currentStatus == nil)
    }

    @Test("refreshFullObservation returns all fields")
    func fullObservation() async {
        let status = WiFiCurrentStatus(
            timestamp: Date(), ssid: "Test", bssid: "AA:BB", channel: 36,
            rssi: -50, isConnected: true, isWiFiPowerOn: true
        )
        let latency = GatewayLatencyResult(timestamp: Date(), latencyMs: 20)
        let snapshot = WiFiEnvironmentSnapshot(
            timestamp: Date(), interfaceName: "en0", networks: []
        )
        let pipeline = WiFiObservationPipeline(
            currentConnectionProvider: MockCurrentConnectionProvider(result: status),
            environmentScanProvider: MockEnvironmentScanProvider(result: snapshot),
            gatewayLatencyProvider: MockGatewayLatencyProvider(result: latency),
            deviceCapabilitiesProvider: MockDeviceCapabilitiesProvider()
        )
        let obs = await pipeline.refreshFullObservation()
        #expect(obs.currentStatus != nil)
        #expect(obs.environmentSnapshot != nil)
        #expect(obs.channelRecommendation != nil)
        #expect(obs.diagnosis != nil)
    }

    @Test("refreshFullObservation propagates scan errors")
    func fullObservationScanError() async {
        let status = WiFiCurrentStatus(
            timestamp: Date(), ssid: "Test", bssid: "AA:BB", channel: 36,
            rssi: -50, isConnected: true, isWiFiPowerOn: true
        )
        let latency = GatewayLatencyResult(timestamp: Date(), latencyMs: 20)
        let errorSnapshot = WiFiEnvironmentSnapshot(
            timestamp: Date(),
            interfaceName: nil,
            networks: [],
            error: .environmentScanFailed("permission denied")
        )
        let pipeline = WiFiObservationPipeline(
            currentConnectionProvider: MockCurrentConnectionProvider(result: status),
            environmentScanProvider: MockEnvironmentScanProvider(result: errorSnapshot),
            gatewayLatencyProvider: MockGatewayLatencyProvider(result: latency),
            deviceCapabilitiesProvider: MockDeviceCapabilitiesProvider()
        )
        let obs = await pipeline.refreshFullObservation()
        #expect(obs.errors.count == 1)
        if case .environmentScanFailed(let msg) = obs.errors.first {
            #expect(msg == "permission denied")
        } else {
            Issue.record("Expected environmentScanFailed error")
        }
    }

    @Test("refreshCurrentConnection propagates current-status and latency errors")
    func currentConnectionAggregatesErrors() async {
        let status = WiFiCurrentStatus(
            timestamp: Date(),
            isConnected: false,
            isWiFiPowerOn: true,
            error: .noWiFiConnection
        )
        let latency = GatewayLatencyResult(
            timestamp: Date(),
            routerIP: "192.0.2.1",
            error: .gatewayPingFailed("192.0.2.1")
        )
        let pipeline = WiFiObservationPipeline(
            currentConnectionProvider: MockCurrentConnectionProvider(result: status),
            environmentScanProvider: MockEnvironmentScanProvider(result: WiFiEnvironmentSnapshot(
                timestamp: Date(), interfaceName: "en0", networks: []
            )),
            gatewayLatencyProvider: MockGatewayLatencyProvider(result: latency),
            deviceCapabilitiesProvider: MockDeviceCapabilitiesProvider()
        )

        let obs = await pipeline.refreshCurrentConnection()

        #expect(obs.errors.count == 2)
        #expect(obs.errors.contains(.noWiFiConnection))
        #expect(obs.errors.contains(.gatewayPingFailed("192.0.2.1")))
    }

    @Test("refreshFullObservation aggregates current, latency, and scan errors")
    func fullObservationAggregatesAllErrors() async {
        let status = WiFiCurrentStatus(
            timestamp: Date(),
            isConnected: false,
            isWiFiPowerOn: true,
            error: .noWiFiConnection
        )
        let latency = GatewayLatencyResult(
            timestamp: Date(),
            routerIP: "192.0.2.1",
            error: .gatewayPingFailed("192.0.2.1")
        )
        let snapshot = WiFiEnvironmentSnapshot(
            timestamp: Date(),
            interfaceName: nil,
            networks: [],
            error: .environmentScanFailed("permission denied")
        )
        let pipeline = WiFiObservationPipeline(
            currentConnectionProvider: MockCurrentConnectionProvider(result: status),
            environmentScanProvider: MockEnvironmentScanProvider(result: snapshot),
            gatewayLatencyProvider: MockGatewayLatencyProvider(result: latency),
            deviceCapabilitiesProvider: MockDeviceCapabilitiesProvider()
        )

        let obs = await pipeline.refreshFullObservation()

        #expect(obs.errors.count == 3)
        #expect(obs.errors.contains(.noWiFiConnection))
        #expect(obs.errors.contains(.gatewayPingFailed("192.0.2.1")))
        #expect(obs.errors.contains(.environmentScanFailed("permission denied")))
    }
}
