import Foundation
import Testing
@testable import WiFi_Lens

@Suite("Observation Providers")
struct ProviderTests {
    @Test("WiFiCurrentConnectionProvider returns status or error")
    func currentConnectionProvider() async {
        let provider = WiFiCurrentConnectionProvider()
        let status = await provider.fetchCurrentStatus()
        if status.isConnected {
            #expect(status.ssid != nil)
            #expect(status.bssid != nil)
        } else {
            #expect(status.error != nil)
        }
    }

    @Test("GatewayLatencyProvider returns result with routerIP")
    func gatewayLatencyProvider() async {
        let provider = GatewayLatencyProvider()
        let result = await provider.measure(routerIP: nil)
        #expect(result.error == .missingRouterIP)

        let result2 = await provider.measure(routerIP: "127.0.0.1")
        #expect(result2.latencyMs != nil || result2.error != nil)
    }
}
