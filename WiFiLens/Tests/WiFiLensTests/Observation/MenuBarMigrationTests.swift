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
        let vm = MenuBarStatusViewModel(store: store)

        store.apply(WiFiObservation(
            quality: WiFiQualityResult(
                level: .good, signalLabel: "Strong", latencyLabel: "Normal", summary: "Good"
            )
        ))
        #expect(vm.qualityLevel == .good)
    }

    @Test("qualityLevel returns unknown when store has no quality")
    func qualityUnknownWhenNil() async {
        let store = WiFiObservationStore()
        let vm = MenuBarStatusViewModel(store: store)

        #expect(vm.qualityLevel == .unknown)
    }

    @Test("signalLabel reads from store quality result")
    func signalFromStore() async {
        let store = WiFiObservationStore()
        let vm = MenuBarStatusViewModel(store: store)

        store.apply(WiFiObservation(
            quality: WiFiQualityResult(
                level: .fair, signalLabel: "Moderate", latencyLabel: "Normal", summary: "Fair"
            )
        ))
        #expect(vm.signalLabel == "Moderate")
    }

    @Test("latencyLabel reads from store quality result")
    func latencyFromStore() async {
        let store = WiFiObservationStore()
        let vm = MenuBarStatusViewModel(store: store)

        store.apply(WiFiObservation(
            quality: WiFiQualityResult(
                level: .poor, signalLabel: "Weak", latencyLabel: "High", summary: "Poor"
            )
        ))
        #expect(vm.latencyLabel == "High")
    }

    @Test("store update propagates to view model")
    func storeUpdatePropagates() async {
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
        let store = WiFiObservationStore()
        let vm = MenuBarStatusViewModel(store: store)

        store.apply(WiFiObservation(
            currentStatus: status,
            gatewayLatency: latency,
            quality: quality
        ))

        #expect(vm.ssid == "TestNet")
        #expect(vm.bssid == "AA:BB:CC:DD:EE:FF")
        #expect(vm.channel == 36)
        #expect(vm.rssi == -45)
        #expect(vm.gatewayLatency == 15)
        #expect(vm.qualityLevel == .good)
    }

    @Test("disconnected status sets error message")
    func disconnectedSetsError() async {
        let status = WiFiCurrentStatus(
            timestamp: Date(),
            interfaceName: "en0",
            isConnected: false,
            isWiFiPowerOn: true
        )
        let store = WiFiObservationStore()
        let vm = MenuBarStatusViewModel(store: store)

        store.apply(WiFiObservation(currentStatus: status))

        #expect(vm.ssid == nil)
        #expect(vm.errorMessage != nil)
    }

    @Test("trend data updates in real-time from store")
    func trendDataRealTime() async {
        let store = WiFiObservationStore()
        let vm = MenuBarStatusViewModel(store: store)

        for rssi in [-50, -55, -60] {
            store.apply(WiFiObservation(
                currentStatus: WiFiCurrentStatus(
                    timestamp: Date(),
                    interfaceName: "en0",
                    ssid: "TestNet",
                    channel: 36,
                    rssi: rssi,
                    isConnected: true,
                    isWiFiPowerOn: true
                )
            ))
        }

        #expect(vm.signalTrendData.count == 3)
        #expect(vm.signalTrendData == [-50, -55, -60])
    }

    @Test("status row icon styling stays fixed while value styling changes")
    func statusRowIconStylingIsFixed() async {
        let weakSignalStyle = MenuBarStatusRowStyle.signal(
            rssi: -82,
            trendLabel: "Degrading"
        )
        let strongSignalStyle = MenuBarStatusRowStyle.signal(
            rssi: -48,
            trendLabel: "Improving"
        )

        #expect(weakSignalStyle.icon == "cellularbars")
        #expect(strongSignalStyle.icon == "cellularbars")
        #expect(weakSignalStyle.iconColor == strongSignalStyle.iconColor)
        #expect(weakSignalStyle.valueColor != strongSignalStyle.valueColor)
    }
}
#endif
