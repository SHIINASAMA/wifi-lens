import Foundation
import Testing
@testable import WiFiLens

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

    private func makeRequest(method: String = "GET", path: String) -> Data {
        "\(method) \(path) HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n".data(using: .utf8)!
    }

    private func statusCode(from data: Data?) -> Int {
        guard let data,
              let head = String(data: data, encoding: .utf8)?
                .components(separatedBy: "\r\n").first,
              let codeStr = head.components(separatedBy: " ").dropFirst().first else {
            return -1
        }
        return Int(codeStr) ?? -1
    }

    private func bodyJSON(from data: Data?) -> Any? {
        guard let data else { return nil }
        let parts = String(data: data, encoding: .utf8)?.components(separatedBy: "\r\n\r\n")
        guard let body = parts?.dropFirst().joined(separator: "\r\n\r\n"),
              let bodyData = body.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: bodyData)
    }

    // MARK: - Routing

    @Test func networksReturns200WithArray() {
        let net = makeNetwork()
        let resp = MCPServer.process(makeRequest(path: "/networks"), networks: [net])
        #expect(statusCode(from: resp) == 200)
        let json = bodyJSON(from: resp) as? [[String: Any]]
        #expect(json?.count == 1)
        #expect(json?.first?["ssid"] as? String == "TestNet")
    }

    @Test func networksBandFilter() {
        let n24 = makeNetwork(bssid: "aa:bb:cc:dd:ee:01", channelNumber: 6, band: .band24GHz)
        let n5 = makeNetwork(bssid: "aa:bb:cc:dd:ee:02", channelNumber: 36, band: .band5GHz)
        let resp = MCPServer.process(
            makeRequest(path: "/networks?band=5"),
            networks: [n24, n5]
        )
        let json = bodyJSON(from: resp) as? [[String: Any]]
        #expect(json?.count == 1)
        #expect(json?.first?["bssid"] as? String == "aa:bb:cc:dd:ee:02")
    }

    @Test func networksByBSSIDReturnsDetail() {
        let net = makeNetwork(bssid: "aa:bb:cc:dd:ee:ff", rssi: -42)
        let resp = MCPServer.process(
            makeRequest(path: "/networks/aa:bb:cc:dd:ee:ff"),
            networks: [net]
        )
        #expect(statusCode(from: resp) == 200)
        let dict = bodyJSON(from: resp) as? [String: Any]
        #expect(dict?["bssid"] as? String == "aa:bb:cc:dd:ee:ff")
        #expect(dict?["rssi"] as? Int == -42)
    }

    @Test func networksByBSSIDNotFoundReturns404() {
        let resp = MCPServer.process(
            makeRequest(path: "/networks/xx:xx:xx:xx:xx:xx"),
            networks: []
        )
        #expect(statusCode(from: resp) == 404)
    }

    @Test func occupancyReturns200WithDict() {
        let nets = [
            makeNetwork(bssid: "aa:bb:cc:dd:ee:01", channelNumber: 1),
            makeNetwork(bssid: "aa:bb:cc:dd:ee:02", channelNumber: 1),
            makeNetwork(bssid: "aa:bb:cc:dd:ee:03", channelNumber: 6),
        ]
        let resp = MCPServer.process(makeRequest(path: "/occupancy"), networks: nets)
        #expect(statusCode(from: resp) == 200)
        let json = bodyJSON(from: resp) as? [String: [String: Int]]
        #expect(json?["24"]?["1"] == 2)
        #expect(json?["24"]?["6"] == 1)
    }

    @Test func unknownRouteReturns404() {
        let resp = MCPServer.process(makeRequest(path: "/doesnotexist"), networks: [])
        #expect(statusCode(from: resp) == 404)
    }

    @Test func nonGetMethodReturns405() {
        let resp = MCPServer.process(
            makeRequest(method: "POST", path: "/networks"),
            networks: []
        )
        #expect(statusCode(from: resp) == 405)
    }

    @Test func emptyNetworksReturnsEmptyArray() {
        let resp = MCPServer.process(makeRequest(path: "/networks"), networks: [])
        #expect(statusCode(from: resp) == 200)
        let json = bodyJSON(from: resp) as? [[String: Any]]
        #expect(json?.isEmpty == true)
    }
}
