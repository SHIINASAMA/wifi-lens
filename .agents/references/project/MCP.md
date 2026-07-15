# MCP Server

The app runs an embedded MCP Streamable HTTP server on `127.0.0.1:19840`, exposing live Wi‑Fi scan data via JSON‑RPC 2.0 tools. No external network access — only processes on the same machine can reach it.

## Protocol

- **Transport**: MCP Streamable HTTP (`StatelessHTTPServerTransport` from `swift-mcp-server`)
- **Encoding**: JSON‑RPC 2.0 over HTTP/1.1 `POST`, `Content‑Type: application/json`
- **Server identity**: `WiFi Lens` v1.0.0, capabilities: `tools` with `listChanged`
- **Startup**: Runs when `ScannerViewModel` starts scanning (Wi-Fi on) and stops
  when scanning stops.

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/` | JSON‑RPC requests (`initialize`, `tools/list`, `tools/call`, `ping`) |
| `GET`  | `/` | SSE stream (notifications, session ID) |

## Tools

### `scan_networks`

List nearby Wi‑Fi networks. Returns an array of network objects.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `band` | `"24"` \| `"5"` \| `"6"` | No | Filter by frequency band |

**Response** — array of `NetworkEntry` objects:

```json
[
  {
    "ssid": "MyWiFi",
    "bssid": "aa:bb:cc:dd:ee:ff",
    "rssi": -48,
    "channel": 6,
    "band": "24",
    "channelWidthMHz": 20,
    "phyMode": "ax",
    "channelWidth": "80",
    "supports80211k": true,
    "supports80211r": false,
    "supports80211v": true,
    "supports80211w": true,
    "supportsWPA3": true,
    "isHiddenSSID": false,
    "security": "WPA3-Personal",
    "mcs": "0-11",
    "nss": "2",
    "country": "US"
  }
]
```

Fields are derived from the latest scan and parsed Information Elements (IE). `phyMode` labels are `ax` (Wi‑Fi 6/6E), `ac`, `n`, or empty. `channelWidth` is the IE‑reported maximum: `160`, `80`, `40`, or empty.

### `get_network_detail`

Get detailed information for a single network by BSSID.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `bssid` | string | Yes | MAC address, e.g. `"aa:bb:cc:dd:ee:ff"` |

Same response shape as `scan_networks` entries, plus `isIBSS: bool`.

Returns error `{"error":"network not found"}` when the BSSID isn't in the current scan set, and `{"error":"missing required parameter: bssid"}` when the parameter is absent.

### `get_channel_occupancy`

Channel occupancy counts grouped by band. No parameters.

```json
{
  "24": { "1": 3, "6": 5, "11": 2 },
  "5": { "36": 1, "149": 4 },
  "6": {}
}
```

## Integration

Clients that speak MCP Streamable HTTP can connect directly:

```json
// → {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18",...}}
// → {"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"scan_networks"}}
```

For ad‑hoc scripting, any HTTP client works:

```sh
# List tools
curl -s -X POST http://127.0.0.1:19840/ \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'

# Scan networks
curl -s -X POST http://127.0.0.1:19840/ \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"scan_networks"}}'
```

## Architecture

```
ScannerViewModel.lastNetworks
  └── MCPServer.dataProvider (closure, lock-protected)
        └── handleCallTool(name:arguments:networks:)
              └── Tool dispatch (scan_networks / get_network_detail / get_channel_occupancy)
                    └── JSON serialization → CallTool.Result
```

`ScannerViewModel.updateMCPDataProvider()` wires the server's `dataProvider` closure to `lastNetworks` so every tool invocation reads the most recent scan without extra copies.
