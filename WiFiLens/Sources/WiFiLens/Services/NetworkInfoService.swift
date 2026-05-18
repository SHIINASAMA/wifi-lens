import Foundation
import CoreWLAN
import SystemConfiguration

struct NetworkInterfaceInfo {
    let interfaceName: String
    let hardwareMAC: String?
    let ipv4Addresses: [String]
    let subnetMasks: [String]
    let router: String?
    let dnsServers: [String]

    // Wi-Fi specific (nil if not a Wi-Fi interface)
    let ssid: String?
    let bssid: String?
    let channel: Int?
    let rssi: Int?
    let txRate: Double?
    let phyMode: String?
    let security: String

    var displayMAC: String { hardwareMAC ?? "Unknown" }
    var displaySSID: String { ssid ?? "n/a" }
    var displayBSSID: String { bssid ?? "Unknown" }
    var displayChannel: String { channel.map { "\($0)" } ?? "—" }
    var displayRSSI: String { rssi.map { "\($0) dBm" } ?? "—" }
    var displayTxRate: String { txRate.map { "\(Int($0)) Mbps" } ?? "—" }
    var displaySecurity: String { security }
    var displayPhyMode: String { phyMode ?? "—" }
    var displayIP: String { ipv4Addresses.first ?? "—" }
    var displaySubnet: String { subnetMasks.first ?? "—" }
    var displayRouter: String { router ?? "—" }
    var displayDNS: String { dnsServers.isEmpty ? "—" : dnsServers.joined(separator: ", ") }
}

enum NetworkInfoService {
    static func fetch() -> NetworkInterfaceInfo? {
        let client = CWWiFiClient.shared()
        guard let iface = client.interface(),
              let name = iface.interfaceName else { return nil }

        // Wi-Fi specifics from CoreWLAN
        let ssid = iface.ssid()
        let bssid = iface.bssid()
        let channel = iface.wlanChannel()?.channelNumber
        let rssi = iface.rssiValue()
        let txRate = iface.transmitRate()
        let security: String = {
            switch iface.security().rawValue {
            case 0: return "None"
            case 1: return "WEP"
            case 2: return "WPA Personal"
            case 3: return "WPA/WPA2 Personal"
            case 4: return "WPA2 Personal"
            case 5: return "Personal"
            case 6: return "Dynamic WEP"
            case 7: return "WPA Enterprise"
            case 8: return "WPA/WPA2 Enterprise"
            case 9: return "WPA2 Enterprise"
            case 10: return "Enterprise"
            case 13: return "WPA3 Personal"
            case 14: return "WPA3 Enterprise"
            case 15: return "WPA3 Transition"
            default: return "—"
            }
        }()
        let phyMode: String? = {
            switch iface.activePHYMode() {
            case .mode11a:  return "802.11a"
            case .mode11b:  return "802.11b"
            case .mode11g:  return "802.11g"
            case .mode11n:  return "802.11n"
            case .mode11ac: return "802.11ac"
            case .mode11ax: return "802.11ax"
            case .mode11be: return "802.11be"
            case .modeNone: return nil
            @unknown default: return nil
            }
        }()
        let hwMAC = iface.hardwareAddress()

        // IPv4 / Router from SystemConfiguration
        var ipv4s: [String] = []
        var subnets: [String] = []
        var router: String?

        let store = SCDynamicStoreCreate(nil, "WiFiLens" as CFString, nil, nil)
        if let store,
           let ipv4Dict = SCDynamicStoreCopyValue(store, "State:/Network/Interface/\(name)/IPv4" as CFString) as? [String: Any] {
            ipv4s = ipv4Dict["Addresses"] as? [String] ?? []
            subnets = ipv4Dict["SubnetMasks"] as? [String] ?? []
            // Router may be a String or [String]; try both
            if let r = ipv4Dict["Router"] as? String {
                router = r
            } else if let rArr = ipv4Dict["Router"] as? [String], let first = rArr.first {
                router = first
            }
        }

        // Fallback: try Service-based path for router
        if router == nil, let store {
            let servicePattern = "State:/Network/Service/.*/IPv4"
            if let serviceKeys = SCDynamicStoreCopyKeyList(store, servicePattern as CFString) as? [String] {
                for key in serviceKeys {
                    if let svcDict = SCDynamicStoreCopyValue(store, key as CFString) as? [String: Any] {
                        if let svcInterface = svcDict["InterfaceName"] as? String, svcInterface == name {
                            if ipv4s.isEmpty {
                                ipv4s = svcDict["Addresses"] as? [String] ?? []
                            }
                            if subnets.isEmpty {
                                subnets = svcDict["SubnetMasks"] as? [String] ?? []
                            }
                            if router == nil {
                                if let r = svcDict["Router"] as? String {
                                    router = r
                                } else if let rArr = svcDict["Router"] as? [String], let first = rArr.first {
                                    router = first
                                }
                            }
                            break
                        }
                    }
                }
            }
        }

        // DNS servers
        var dnsServers: [String] = []
        if let store,
           let dnsDict = SCDynamicStoreCopyValue(store, "State:/Network/Global/DNS" as CFString) as? [String: Any],
           let servers = dnsDict["ServerAddresses"] as? [String] {
            dnsServers = servers
        }

        return NetworkInterfaceInfo(
            interfaceName: name,
            hardwareMAC: hwMAC,
            ipv4Addresses: ipv4s,
            subnetMasks: subnets,
            router: router,
            dnsServers: dnsServers,
            ssid: ssid,
            bssid: bssid,
            channel: channel,
            rssi: rssi,
            txRate: txRate,
            phyMode: phyMode,
            security: security
        )
    }
}
