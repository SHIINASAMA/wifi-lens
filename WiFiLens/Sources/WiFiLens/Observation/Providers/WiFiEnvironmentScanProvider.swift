import Foundation

protocol WiFiEnvironmentScanProviding: Sendable {
    func scanEnvironment() async -> WiFiEnvironmentSnapshot
}

struct WiFiEnvironmentScanProvider: WiFiEnvironmentScanProviding {
    private let scanner = WiFiScanner()

    func scanEnvironment() async -> WiFiEnvironmentSnapshot {
        let startTime = Date()
        var networks: [WiFiNetwork] = []

        let scanStream = await scanner.startScanning(interval: .seconds(0))
        for await event in scanStream {
            if case .networks(let nw) = event {
                networks = nw
                break
            }
        }

        await scanner.stopScanning()

        let currentBSSID: String? = await MainActor.run {
            NetworkInfoService.fetchAll().first(where: { $0.ssid != nil })?.bssid
        }

        let observations = NetworkObservationAdapter.adaptAll(networks, currentBSSID: currentBSSID)
        let interfaceName = await scanner.interfaceName()
        let duration = Date().timeIntervalSince(startTime) * 1000

        return WiFiEnvironmentSnapshot(
            timestamp: Date(),
            interfaceName: interfaceName,
            networks: observations,
            scanDurationMs: duration
        )
    }
}
