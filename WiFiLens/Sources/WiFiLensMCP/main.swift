import Foundation
import MCP

/// MCP bridge: speaks stdio MCP protocol, queries WiFi Lens GUI app's local HTTP API.
/// Usage: WiFiLensMCP [port]
///   port — HTTP port of the running WiFi Lens GUI app (default 19840)
///
/// Configure Claude Desktop (`claude_desktop_config.json`):
///   {
///     "mcpServers": {
///       "wifi-lens": {
///         "command": "/path/to/WiFiLensMCP",
///         "args": ["19840"]
///       }
///     }
///   }
let port = Int(CommandLine.arguments.dropFirst().first ?? "") ?? 19840
let baseURL = "http://127.0.0.1:\(port)"

let server = Server(
    name: "WiFi Lens",
    version: "1.0.0",
    capabilities: .init(tools: .init(listChanged: true))
)

// MARK: - List tools

await server.withMethodHandler(ListTools.self) { _ in
    let tools = [
        Tool(
            name: "scan_networks",
            description: "Scan nearby Wi-Fi networks returned by WiFi Lens. Returns SSID, BSSID, RSSI, channel, band, PHY mode, channel width, security, MCS/NSS, and country code for each visible network.",
            inputSchema: .object([
                "properties": .object([
                    "band": .object([
                        "type": .string("string"),
                        "enum": .array(["24", "5", "6"].map { .string($0) }),
                        "description": .string("Filter by band: 24 = 2.4 GHz, 5 = 5 GHz, 6 = 6 GHz.")
                    ])
                ]),
                "required": .array([])
            ])
        ),
        Tool(
            name: "get_network_detail",
            description: "Get detailed information about a specific Wi-Fi network by BSSID.",
            inputSchema: .object([
                "properties": .object([
                    "bssid": .object([
                        "type": .string("string"),
                        "description": .string("The BSSID (MAC address) of the target network, e.g. 'aa:bb:cc:dd:ee:ff'.")
                    ])
                ]),
                "required": .array([.string("bssid")])
            ])
        ),
        Tool(
            name: "get_channel_occupancy",
            description: "Get per-channel network count for each band. Useful for finding the least congested channel.",
            inputSchema: .object([
                "properties": .object([:]),
                "required": .array([])
            ])
        ),
    ]
    return .init(tools: tools)
}

// MARK: - Handle tool calls

await server.withMethodHandler(CallTool.self) { params in
    switch params.name {
    case "scan_networks":
        var url = "\(baseURL)/networks"
        if let band = params.arguments?["band"]?.stringValue {
            url += "?band=\(band)"
        }
        let body = try? await httpGet(url)
        let text = body ?? "No data. Make sure WiFi Lens is running with MCP enabled."
        return .init(content: [.text(text: text, annotations: nil, _meta: nil)], isError: body == nil)

    case "get_network_detail":
        guard let bssid = params.arguments?["bssid"]?.stringValue else {
            return .init(content: [.text(text: "Missing required parameter: bssid", annotations: nil, _meta: nil)], isError: true)
        }
        let body = try? await httpGet("\(baseURL)/networks/\(bssid.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? bssid)")
        let text = body ?? "Network not found or WiFi Lens is not running."
        return .init(content: [.text(text: text, annotations: nil, _meta: nil)], isError: body == nil)

    case "get_channel_occupancy":
        let body = try? await httpGet("\(baseURL)/occupancy")
        let text = body ?? "No data. Make sure WiFi Lens is running with MCP enabled."
        return .init(content: [.text(text: text, annotations: nil, _meta: nil)], isError: body == nil)

    default:
        return .init(content: [.text(text: "Unknown tool: \(params.name)", annotations: nil, _meta: nil)], isError: true)
    }
}

// MARK: - HTTP helper

func httpGet(_ urlString: String) async throws -> String? {
    guard let url = URL(string: urlString) else { return nil }
    let (data, response) = try await URLSession.shared.data(from: url)
    guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
        return nil
    }
    return String(data: data, encoding: .utf8)
}

// MARK: - Start

let transport = StdioTransport()
try await server.start(transport: transport)
