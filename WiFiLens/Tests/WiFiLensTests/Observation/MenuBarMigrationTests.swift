import Foundation
import Testing
@testable import WiFi_Lens

#if PRO
@Suite("MenuBar Migration")
@MainActor
struct MenuBarMigrationTests {
    @Test("qualityLevel reads from store quality result")
    func qualityFromStore() async {
        let store = WiFiObservationStore()
        let controller = WiFiObservationController(store: store)
        let vm = MenuBarStatusViewModel(controller: controller, store: store)

        store.quality = WiFiQualityResult(
            level: .good, signalLabel: "Strong", latencyLabel: "Normal", summary: "Good"
        )
        #expect(vm.qualityLevel == .good)
    }

    @Test("qualityLevel returns unknown when store has no quality")
    func qualityUnknownWhenNil() async {
        let store = WiFiObservationStore()
        let controller = WiFiObservationController(store: store)
        let vm = MenuBarStatusViewModel(controller: controller, store: store)

        #expect(vm.qualityLevel == .unknown)
    }

    @Test("signalLabel reads from store quality result")
    func signalFromStore() async {
        let store = WiFiObservationStore()
        let controller = WiFiObservationController(store: store)
        let vm = MenuBarStatusViewModel(controller: controller, store: store)

        store.quality = WiFiQualityResult(
            level: .fair, signalLabel: "Moderate", latencyLabel: "Normal", summary: "Fair"
        )
        #expect(vm.signalLabel == "Moderate")
    }

    @Test("latencyLabel reads from store quality result")
    func latencyFromStore() async {
        let store = WiFiObservationStore()
        let controller = WiFiObservationController(store: store)
        let vm = MenuBarStatusViewModel(controller: controller, store: store)

        store.quality = WiFiQualityResult(
            level: .poor, signalLabel: "Weak", latencyLabel: "High", summary: "Poor"
        )
        #expect(vm.latencyLabel == "High")
    }

    @Test("fetch updates view model from store after controller refresh")
    func fetchFromPipeline() async {
        let status = WiFiCurrentStatus(
            timestamp: Date(),
            interfaceName: "en0",
            ssid: "TestNet",
            bssid: "AA:BB:CC:DD:EE:FF",
            channel: 36,
            rssi: -45,
            isConnected: true,
            isWiFiPowerOn: true
        )
        let latency = GatewayLatencyResult(timestamp: Date(), latencyMs: 15)
        let quality = WiFiQualityResult(
            level: .good, signalLabel: "Strong", latencyLabel: "Normal", summary: "Good"
        )
        let observation = WiFiObservation(
            currentStatus: status,
            gatewayLatency: latency,
            quality: quality
        )
        let mockPipeline = MockPipeline(
            currentObservation: observation,
            environmentObservation: WiFiObservation(),
            fullObservation: observation
        )
        let store = WiFiObservationStore()
        let controller = WiFiObservationController(pipeline: mockPipeline, store: store)
        let vm = MenuBarStatusViewModel(controller: controller, store: store)

        await vm.fetch()

        #expect(vm.ssid == "TestNet")
        #expect(vm.bssid == "AA:BB:CC:DD:EE:FF")
        #expect(vm.channel == 36)
        #expect(vm.rssi == -45)
        #expect(vm.gatewayLatency == 15)
        #expect(vm.qualityLevel == .good)
        #expect(vm.isLoading == false)
    }

    @Test("fetch sets error when disconnected")
    func fetchDisconnected() async {
        let status = WiFiCurrentStatus(
            timestamp: Date(),
            interfaceName: "en0",
            isConnected: false,
            isWiFiPowerOn: true
        )
        let observation = WiFiObservation(currentStatus: status)
        let mockPipeline = MockPipeline(
            currentObservation: observation,
            environmentObservation: WiFiObservation(),
            fullObservation: observation
        )
        let store = WiFiObservationStore()
        let controller = WiFiObservationController(pipeline: mockPipeline, store: store)
        let vm = MenuBarStatusViewModel(controller: controller, store: store)

        await vm.fetch()

        #expect(vm.ssid == nil)
        #expect(vm.errorMessage != nil)
        #expect(vm.isLoading == false)
    }
}
#endif
