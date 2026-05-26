import Foundation
import Network

/// Minimal HTTP API server on localhost for the MCP bridge to query.
/// Only accessible from this machine — no external network exposure.
final class MCPServer: @unchecked Sendable {
    private let lock = NSLock()
    private var listener: NWListener?
    private(set) var isRunning = false
    var port: UInt16 = 19840

    /// Called on each request to supply live scan data. Must be set before starting.
    /// Thread-safe: read under lock.
    var dataProvider: (() -> [WiFiNetwork])? {
        get { lock.withLock { _dataProvider } }
        set { lock.withLock { _dataProvider = newValue } }
    }
    private var _dataProvider: (() -> [WiFiNetwork])?

    func start() throws {
        guard !isRunning else { return }
        let params = NWParameters.tcp
        params.requiredLocalEndpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!)
        listener = try NWListener(using: params)
        listener?.newConnectionHandler = { [weak self] conn in
            self?.handle(conn)
        }
        listener?.start(queue: .global(qos: .utility))
        isRunning = true
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    // MARK: - Connection / HTTP parsing

    private func handle(_ conn: NWConnection) {
        conn.start(queue: .global(qos: .utility))
        receiveHeaders(conn, Data())
    }

    private func receiveHeaders(_ conn: NWConnection, _ buf: Data) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            guard let self, error == nil, let data else { conn.cancel(); return }
            var accumulated = buf
            accumulated.append(data)
            if accumulated.range(of: Data("\r\n\r\n".utf8)) != nil {
                let nets = self.dataProvider?() ?? []
                let resp = Self.process(accumulated, networks: nets)
                conn.send(content: resp ?? Data(), completion: .contentProcessed { _ in conn.cancel() })
            } else if accumulated.count < 65536 {
                self.receiveHeaders(conn, accumulated)
            } else { conn.cancel() }
        }
    }

    static func process(_ raw: Data, networks: [WiFiNetwork]) -> Data? {
        guard let req = String(data: raw, encoding: .utf8) else { return nil }
        let lines = req.components(separatedBy: "\r\n")
        guard lines.count >= 1 else { return nil }
        let parts = lines[0].components(separatedBy: " ")
        guard parts.count >= 2, parts[0] == "GET" else {
            return response(405, body: "Method Not Allowed")
        }

        let path = parts[1]
        let urlParts = path.components(separatedBy: "?")
        let route = urlParts[0]

        switch route {
        case "/networks":
            var nets = networks
            // Parse query params
            if urlParts.count > 1 {
                let query = urlParts[1]
                for param in query.components(separatedBy: "&") {
                    let kv = param.components(separatedBy: "=")
                    if kv.count == 2, kv[0] == "band", let band = kv[1].removingPercentEncoding {
                        nets = nets.filter { $0.channel.band.id == band }
                    }
                }
            }
            let entries = nets.map { net in
                let ie = net.ieData.map { IEParser.parse(data: $0) }
                return [
                    "ssid": net.ssid ?? "n/a",
                    "bssid": net.bssid,
                    "rssi": net.rssi,
                    "channel": net.channel.channelNumber,
                    "band": net.channel.band.id,
                    "phyMode": ie.map { phyLabel($0) } ?? "",
                    "channelWidth": ie.map { widthLabel($0) } ?? "",
                    "security": ie?.securitySummary ?? "",
                    "mcs": ie?.mcsSummary ?? "",
                    "nss": ie?.nssSummary ?? "",
                    "country": ie?.countryCode ?? "",
                ] as [String: Any]
            }
            return Self.jsonResponse(entries)

        case "/occupancy":
            var bands: [String: [Int: Int]] = [:]
            for nw in networks {
                bands[nw.channel.band.id, default: [:]][nw.channel.channelNumber, default: 0] += 1
            }
            return Self.jsonResponse(bands.mapValues { $0.mapValues { $0 } })

        default:
            // /networks/:bssid
            if route.hasPrefix("/networks/") {
                let bssid = String(route.dropFirst(10)).removingPercentEncoding ?? ""
                guard let nw = networks.first(where: { $0.bssid.caseInsensitiveCompare(bssid) == .orderedSame }) else {
                    return Self.response(404, body: #"{"error":"not found"}"#)
                }
                let ie = nw.ieData.map { IEParser.parse(data: $0) }
                let entry: [String: Any] = [
                    "ssid": nw.ssid ?? "n/a",
                    "bssid": nw.bssid,
                    "rssi": nw.rssi,
                    "channel": nw.channel.channelNumber,
                    "band": nw.channel.band.id,
                    "channelWidthMHz": nw.channel.channelWidthMHz,
                    "phyMode": ie.map { phyLabel($0) } ?? "",
                    "channelWidth": ie.map { widthLabel($0) } ?? "",
                    "security": ie?.securitySummary ?? "",
                    "mcs": ie?.mcsSummary ?? "",
                    "nss": ie?.nssSummary ?? "",
                    "country": ie?.countryCode ?? "",
                ]
                return Self.jsonResponse(entry)
            }
            return Self.response(404, body: "Not Found")
        }
    }

    // MARK: - Helpers

    private static func phyLabel(_ ie: IEData) -> String {
        if ie.heSupported { return "ax" }
        if ie.vhtSupported { return "ac" }
        if ie.htSupported { return "n" }
        return ""
    }

    private static func widthLabel(_ ie: IEData) -> String {
        if ie.supports160MHz { return "160" }
        if ie.supports80MHz { return "80" }
        if ie.supports40MHz { return "40" }
        return ""
    }

    private static func jsonResponse(_ obj: Any) -> Data? {
        guard JSONSerialization.isValidJSONObject(obj),
              let data = try? JSONSerialization.data(withJSONObject: obj, options: .prettyPrinted) else {
            return response(500, body: "JSON Error")
        }
        return response(200, bodyData: data)
    }

    private static func response(_ status: Int, body: String) -> Data? {
        response(status, bodyData: body.data(using: .utf8) ?? Data())
    }

    private static func response(_ status: Int, bodyData: Data) -> Data? {
        let reason: String = switch status { case 200: "OK"; case 404: "Not Found"; case 405: "Method Not Allowed"; default: "Error" }
        let header = """
        HTTP/1.1 \(status) \(reason)\r
        Content-Type: application/json\r
        Content-Length: \(bodyData.count)\r
        Access-Control-Allow-Origin: *\r
        \r\n
        """
        return (header.data(using: .ascii) ?? Data()) + bodyData
    }
}
