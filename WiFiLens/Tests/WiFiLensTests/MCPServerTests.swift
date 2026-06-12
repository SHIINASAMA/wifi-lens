import Foundation
import Testing
import MCP
@testable import WiFi_Lens

@Suite struct MCPServerTests {

    private func makeNetwork(
        ssid: String? = "TestNet",
        bssid: String = "aa:bb:cc:dd:ee:ff",
        rssi: Int = -50,
        channelNumber: Int = 6,
        band: ChannelBand = .band24GHz
    ) -> WiFiNetwork {
        let ch = WiFiChannel(band: band, channelNumber: channelNumber)
        return WiFiNetwork(ssid: ssid, bssid: bssid, rssi: rssi, channel: ch)
    }

    private func resultText(from result: CallTool.Result) -> String {
        if case .text(let text, _, _) = result.content.first {
            return text
        }
        return ""
    }

    private func resultJSON(from result: CallTool.Result) -> Any? {
        let text = resultText(from: result)
        guard let data = text.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    // MARK: - scan_networks

    @Test func scanNetworksReturnsAllNetworks() {
        let net = makeNetwork()
        let result = MCPServer.handleCallTool(name: "scan_networks", arguments: nil, networks: [net])

        let json = resultJSON(from: result) as? [[String: Any]]
        #expect(json?.count == 1)
        #expect(json?.first?["ssid"] as? String == "TestNet")
    }

    @Test func scanNetworksBandFilter() {
        let n24 = makeNetwork(bssid: "aa:bb:cc:dd:ee:01", channelNumber: 6, band: .band24GHz)
        let n5 = makeNetwork(bssid: "aa:bb:cc:dd:ee:02", channelNumber: 36, band: .band5GHz)
        let args: [String: Value] = ["band": .string("5")]
        let result = MCPServer.handleCallTool(name: "scan_networks", arguments: args, networks: [n24, n5])

        let json = resultJSON(from: result) as? [[String: Any]]
        #expect(json?.count == 1)
        #expect(json?.first?["bssid"] as? String == "aa:bb:cc:dd:ee:02")
    }

    @Test func scanNetworksEmptyReturnsEmptyArray() {
        let result = MCPServer.handleCallTool(name: "scan_networks", arguments: nil, networks: [])
        let json = resultJSON(from: result) as? [[String: Any]]
        #expect(json?.isEmpty == true)
    }

    // MARK: - get_network_detail

    @Test func getNetworkDetailByBSSID() {
        let net = makeNetwork(bssid: "aa:bb:cc:dd:ee:ff", rssi: -42)
        let args: [String: Value] = ["bssid": .string("aa:bb:cc:dd:ee:ff")]
        let result = MCPServer.handleCallTool(name: "get_network_detail", arguments: args, networks: [net])

        let dict = resultJSON(from: result) as? [String: Any]
        #expect(dict?["bssid"] as? String == "aa:bb:cc:dd:ee:ff")
        #expect(dict?["rssi"] as? Int == -42)
    }

    @Test func getNetworkDetailNotFoundReturnsError() {
        let args: [String: Value] = ["bssid": .string("xx:xx:xx:xx:xx:xx")]
        let result = MCPServer.handleCallTool(name: "get_network_detail", arguments: args, networks: [])

        #expect(result.isError == true)
        #expect(resultText(from: result).contains("not found"))
    }

    @Test func getNetworkDetailMissingBSSIDReturnsError() {
        let result = MCPServer.handleCallTool(name: "get_network_detail", arguments: nil, networks: [])

        #expect(result.isError == true)
        #expect(resultText(from: result).contains("missing"))
    }

    // MARK: - get_channel_occupancy

    @Test func channelOccupancyReturnsGroupedCounts() {
        let nets = [
            makeNetwork(bssid: "aa:bb:cc:dd:ee:01", channelNumber: 1),
            makeNetwork(bssid: "aa:bb:cc:dd:ee:02", channelNumber: 1),
            makeNetwork(bssid: "aa:bb:cc:dd:ee:03", channelNumber: 6),
        ]
        let result = MCPServer.handleCallTool(name: "get_channel_occupancy", arguments: nil, networks: nets)

        let json = resultJSON(from: result) as? [String: [String: Int]]
        #expect(json?["24"]?["1"] == 2)
        #expect(json?["24"]?["6"] == 1)
    }

    // MARK: - Unknown tool

    @Test func unknownToolReturnsError() {
        let result = MCPServer.handleCallTool(name: "nonexistent_tool", arguments: nil, networks: [])
        #expect(result.isError == true)
        #expect(resultText(from: result).contains("Unknown tool"))
    }
}
