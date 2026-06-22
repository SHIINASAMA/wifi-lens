import Foundation

protocol WiFiEnvironmentScanProviding: Sendable {
    func scanEnvironment() async -> WiFiEnvironmentSnapshot
}

struct WiFiEnvironmentScanProvider: WiFiEnvironmentScanProviding {
    private let scanner = WiFiScanner()

    func scanEnvironment() async -> WiFiEnvironmentSnapshot {
        let startTime = Date()
        var networks: [WiFiNetwork] = []
        var scanError: String?

        let scanStream = await scanner.startScanning(interval: .seconds(0))
        defer { Task { await scanner.stopScanning() } }

        let deadline = Date().addingTimeInterval(10)
        for await event in scanStream {
            if Date() > deadline {
                scanError = "Scan timed out after 10 seconds"
                break
            }
            switch event {
            case .networks(let nw):
                networks = nw
                break
            case .failure(let msg):
                scanError = msg
                break
            }
        }

        if let scanError {
            return WiFiEnvironmentSnapshot(
                timestamp: Date(),
                interfaceName: nil,
                networks: [],
                scanDurationMs: Date().timeIntervalSince(startTime) * 1000,
                error: WiFiObservationError.environmentScanFailed(scanError)
            )
        }

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
