import Foundation

extension ChannelBand {
    static func from(channelNumber: Int) -> ChannelBand? {
        switch channelNumber {
        case 1...16: .band24GHz
        case 17...170: .band5GHz
        case 171...233: .band6GHz
        default: nil
        }
    }
}

protocol WiFiCurrentConnectionProviding: Sendable {
    func fetchCurrentStatus() async -> WiFiCurrentStatus
}

struct WiFiCurrentConnectionProvider: WiFiCurrentConnectionProviding {
    func fetchCurrentStatus() async -> WiFiCurrentStatus {
        await MainActor.run {
            let interfaces = NetworkInfoService.fetchAll()
            guard let wifi = interfaces.first(where: { $0.ssid != nil }) else {
                return WiFiCurrentStatus(
                    timestamp: Date(),
                    isConnected: false,
                    isWiFiPowerOn: true,
                    error: .noWiFiConnection
                )
            }
            return Self.makeStatus(from: wifi, timestamp: Date())
        }
    }

    static func makeStatus(
        from wifi: NetworkInterfaceInfo,
        timestamp: Date
    ) -> WiFiCurrentStatus {
        WiFiCurrentStatus(
            timestamp: timestamp,
            interfaceName: wifi.interfaceName,
            ssid: wifi.ssid,
            bssid: wifi.bssid,
            channel: wifi.channel,
            band: wifi.band,
            rssi: wifi.rssi,
            txRate: wifi.txRate,
            phyMode: wifi.phyMode,
            security: wifi.security,
            routerIP: wifi.router,
            isConnected: true,
            isWiFiPowerOn: true
        )
    }
}
