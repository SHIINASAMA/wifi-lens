import Foundation
import CoreWLAN
import SystemConfiguration

struct NetworkInterfaceInfo {
    enum InterfaceType: String {
        case wifi
        case ethernet
        case virtual
    }

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

    var interfaceType: InterfaceType {
        if ssid != nil { return .wifi }
        if hardwareMAC != nil { return .ethernet }
        return .virtual
    }

    var displayMAC: String { hardwareMAC ?? String(localized: "Unknown") }
    var displaySSID: String { ssid ?? "n/a" }
    var displayBSSID: String { bssid ?? String(localized: "Unknown") }
    var displayChannel: String { channel.map { "\($0)" } ?? "—" }
    var displayRSSI: String { rssi.map { "\($0) dBm" } ?? "—" }
    var displayTxRate: String { txRate.map { "\(Int($0)) Mbps" } ?? "—" }
    var displaySecurity: String { security }
    var displayPhyMode: String { phyMode ?? "—" }
    var displayIP: String { ipv4Addresses.first ?? "—" }
    var displaySubnet: String { subnetMasks.first ?? "—" }
    var displayRouter: String { router ?? "—" }
    var displayDNS: String { dnsServers.isEmpty ? "—" : dnsServers.joined(separator: ", ") }


    var hasNetworkInfo: Bool { !ipv4Addresses.isEmpty || router != nil || !dnsServers.isEmpty }
}

enum NetworkInfoService {
    /// All available network interfaces, including virtual ones.
    /// Uses `getifaddrs()` for discovery so VPN / VM / bridge adapters
    /// are visible even when they have no SystemConfiguration state.
    static func fetchAll() -> [NetworkInterfaceInfo] {
        let store = SCDynamicStoreCreate(nil, "WiFiLens" as CFString, nil, nil)
        let dns = fetchDNS(store)
        let wifiMAC = fetchWiFiMAC()
        let wifiIface = CWWiFiClient.shared().interface()
        let wifiName = wifiIface?.interfaceName

        // Discover all interfaces via getifaddrs (includes virtual ones)
        var ifaces: [String: (ips: [String], subnets: [String], mac: String?)] = [:]
        var addrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrPtr) == 0, let first = addrPtr else { return [] }
        defer { freeifaddrs(first) }

        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            guard let namePtr = ptr.pointee.ifa_name,
                  let addr = ptr.pointee.ifa_addr else { continue }
            let name = String(cString: namePtr)
            if name == "lo0" { continue }  // skip loopback

            var entry = ifaces[name] ?? (ips: [], subnets: [], mac: nil)

            if addr.pointee.sa_family == sa_family_t(AF_INET) {
                var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(addr, socklen_t(addr.pointee.sa_len), &buffer, socklen_t(buffer.count),
                               nil, 0, NI_NUMERICHOST) == 0 {
                    entry.ips.append(String(decoding: buffer.prefix(while: { $0 != 0 }).map(UInt8.init), as: UTF8.self))
                }
                // Subnet mask
                if let netmask = ptr.pointee.ifa_netmask, netmask.pointee.sa_family == sa_family_t(AF_INET) {
                    var maskBuf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(netmask, socklen_t(netmask.pointee.sa_len), &maskBuf, socklen_t(maskBuf.count),
                                   nil, 0, NI_NUMERICHOST) == 0 {
                        entry.subnets.append(String(decoding: maskBuf.prefix(while: { $0 != 0 }).map(UInt8.init), as: UTF8.self))
                    }
                }
            }

            // MAC from AF_LINK
            if addr.pointee.sa_family == sa_family_t(AF_LINK) {
                let link = ptr.pointee.ifa_addr.withMemoryRebound(to: sockaddr_dl.self, capacity: 1) { $0.pointee }
                if link.sdl_alen > 0 {
                    let macBase = UnsafeRawPointer(ptr.pointee.ifa_addr)
                        .advanced(by: MemoryLayout<sockaddr_dl>.offset(of: \.sdl_data)! + Int(link.sdl_nlen))
                    let bytes = macBase.bindMemory(to: UInt8.self, capacity: Int(link.sdl_alen))
                    entry.mac = (0..<Int(link.sdl_alen)).map {
                        String(format: "%02x", bytes[$0])
                    }.joined(separator: ":")
                }
            }

            ifaces[name] = entry
        }

        // Merge IPv4 / router from SystemConfiguration where available
        if let store,
           let ipv4Keys = SCDynamicStoreCopyKeyList(store, "State:/Network/Interface/.*/IPv4" as CFString) as? [String] {
            for key in ipv4Keys {
                let name = key.components(separatedBy: "/").dropLast().last ?? key
                guard let dict = SCDynamicStoreCopyValue(store, key as CFString) as? [String: Any] else { continue }
                if ifaces[name] == nil {
                    ifaces[name] = (ips: [], subnets: [], mac: nil)
                }
                if ifaces[name]?.ips.isEmpty ?? true {
                    ifaces[name]?.ips = dict["Addresses"] as? [String] ?? []
                }
                if ifaces[name]?.subnets.isEmpty ?? true {
                    ifaces[name]?.subnets = dict["SubnetMasks"] as? [String] ?? []
                }
            }
        }

        // Build result, enriching with Wi-Fi details where applicable
        var result: [NetworkInterfaceInfo] = []
        for (name, entry) in ifaces {
            let isWiFi = name == wifiName
            let wiFiInfo: (ssid: String?, bssid: String?, channel: Int?, rssi: Int?, txRate: Double?, phyMode: String?, security: String)? = {
                guard isWiFi, let iface = wifiIface else { return nil }
                return fetchWiFiDetails(iface)
            }()

            // Router lookup from SystemConfiguration (Interface path)
            var router: String? = nil
            if let store,
               let ipv4Dict = SCDynamicStoreCopyValue(store, "State:/Network/Interface/\(name)/IPv4" as CFString) as? [String: Any] {
                if let r = ipv4Dict["Router"] as? String { router = r }
                else if let arr = ipv4Dict["Router"] as? [String], let first = arr.first { router = first }
            }

            // Fallback: try Service-based path for router
            if router == nil, let store {
                if let serviceKeys = SCDynamicStoreCopyKeyList(store, "State:/Network/Service/.*/IPv4" as CFString) as? [String] {
                    for key in serviceKeys {
                        if let svcDict = SCDynamicStoreCopyValue(store, key as CFString) as? [String: Any],
                           let svcInterface = svcDict["InterfaceName"] as? String, svcInterface == name {
                            if let r = svcDict["Router"] as? String {
                                router = r
                            } else if let arr = svcDict["Router"] as? [String], let first = arr.first {
                                router = first
                            }
                            if router != nil { break }
                        }
                    }
                }
            }

            result.append(NetworkInterfaceInfo(
                interfaceName: name,
                hardwareMAC: isWiFi ? wifiMAC : entry.mac,
                ipv4Addresses: entry.ips,
                subnetMasks: entry.subnets,
                router: router,
                dnsServers: dns,
                ssid: wiFiInfo?.ssid,
                bssid: wiFiInfo?.bssid,
                channel: wiFiInfo?.channel,
                rssi: wiFiInfo?.rssi,
                txRate: wiFiInfo?.txRate,
                phyMode: wiFiInfo?.phyMode,
                security: wiFiInfo?.security ?? "—"
            ))
        }
        return result.sorted { a, b in
            let aWiFi = a.ssid != nil
            let bWiFi = b.ssid != nil
            if aWiFi != bWiFi { return aWiFi }
            return a.interfaceName < b.interfaceName
        }
    }

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
        let security: String = securityLabel(iface)
        let phyMode: String? = phyModeLabel(iface)
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

    // MARK: - Helpers for fetchAll

    private static func fetchDNS(_ store: SCDynamicStore?) -> [String] {
        guard let store,
              let dict = SCDynamicStoreCopyValue(store, "State:/Network/Global/DNS" as CFString) as? [String: Any],
              let servers = dict["ServerAddresses"] as? [String] else { return [] }
        return servers
    }

    private static func fetchWiFiMAC() -> String? {
        CWWiFiClient.shared().interface()?.hardwareAddress()
    }

    private static func securityLabel(_ iface: CWInterface) -> String {
        switch iface.security().rawValue {
        case 0: return String(localized: "None")
        case 1: return String(localized: "WEP")
        case 2: return String(localized: "WPA Personal")
        case 3: return String(localized: "WPA/WPA2 Personal")
        case 4: return String(localized: "WPA2 Personal")
        case 5: return String(localized: "Personal")
        case 6: return String(localized: "Dynamic WEP")
        case 7: return String(localized: "WPA Enterprise")
        case 8: return String(localized: "WPA/WPA2 Enterprise")
        case 9: return String(localized: "WPA2 Enterprise")
        case 10: return String(localized: "Enterprise")
        case 13: return String(localized: "WPA3 Personal")
        case 14: return String(localized: "WPA3 Enterprise")
        case 15: return String(localized: "WPA3 Transition")
        default: return "—"
        }
    }

    private static func phyModeLabel(_ iface: CWInterface) -> String? {
        switch iface.activePHYMode().rawValue {
        case 0: return String(localized: "802.11a")
        case 1: return String(localized: "802.11b")
        case 2: return String(localized: "802.11g")
        case 3: return String(localized: "802.11n")
        case 4: return String(localized: "802.11ac")
        case 5: return String(localized: "802.11ax")
        case 6: return String(localized: "802.11be")
        default: return nil
        }
    }

    private static func fetchWiFiDetails(_ iface: CWInterface) -> (ssid: String?, bssid: String?, channel: Int?, rssi: Int?, txRate: Double?, phyMode: String?, security: String)? {
        return (iface.ssid(), iface.bssid(), iface.wlanChannel()?.channelNumber, iface.rssiValue(), iface.transmitRate(), phyModeLabel(iface), securityLabel(iface))
    }

}
