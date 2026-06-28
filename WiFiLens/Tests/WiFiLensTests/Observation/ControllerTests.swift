import Foundation
import Testing
@testable import WiFi_Lens

@Suite("WiFiObservationController")
@MainActor
struct ControllerTests {
    @Test("refreshCurrentConnection updates store")
    func controllerUpdatesStore() async {
        let status = WiFiCurrentStatus(
            timestamp: Date(), ssid: "Test", bssid: "AA:BB", channel: 36,
            rssi: -50, isConnected: true, isWiFiPowerOn: true
        )
        let latency = GatewayLatencyResult(timestamp: Date(), latencyMs: 20)
        let observation = WiFiObservation(
            currentStatus: status,
            gatewayLatency: latency,
            quality: WiFiQualityEvaluator.evaluate(currentStatus: status, gatewayLatency: latency)
        )
        let mockPipeline = MockPipeline(
            currentObservation: observation,
            environmentObservation: WiFiObservation(),
            fullObservation: observation
        )
        let store = WiFiObservationStore()
        let controller = WiFiObservationController(pipeline: mockPipeline, store: store)
        await controller.refreshCurrentConnection()
        #expect(store.lastUpdated != nil)
        #expect(store.isRefreshingCurrent == false)
    }

    @Test("refreshEnvironmentScan updates store snapshot")
    func controllerUpdatesSnapshot() async {
        let snapshot = WiFiEnvironmentSnapshot(
            timestamp: Date(), interfaceName: "en0", networks: []
        )
        let observation = WiFiObservation(environmentSnapshot: snapshot)
        let mockPipeline = MockPipeline(
            currentObservation: WiFiObservation(),
            environmentObservation: observation,
            fullObservation: observation
        )
        let store = WiFiObservationStore()
        let controller = WiFiObservationController(pipeline: mockPipeline, store: store)
        await controller.refreshEnvironmentScan()
        #expect(store.latestEnvironmentSnapshot != nil)
        #expect(store.isScanningEnvironment == false)
    }
}
