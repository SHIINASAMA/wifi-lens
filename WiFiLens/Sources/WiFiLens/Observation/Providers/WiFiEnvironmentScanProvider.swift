import Foundation

protocol WiFiEnvironmentScanProviding: Sendable {
    func scanEnvironment() async -> WiFiEnvironmentSnapshot
}

struct WiFiEnvironmentScanProvider: WiFiEnvironmentScanProviding {
    private let scanner = WiFiScanner()

    func scanEnvironment() async -> WiFiEnvironmentSnapshot {
        let startTime = Date()
        var result: WiFiEnvironmentSnapshot?

        let scanStream = await scanner.startScanning(interval: .seconds(0))
        defer { Task { await scanner.stopScanning() } }

        let deadline = Date().addingTimeInterval(10)
        scanLoop: for await event in scanStream {
            if Date() > deadline {
                result = WiFiEnvironmentSnapshot(
                    timestamp: Date(),
                    interfaceName: nil,
                    networks: [],
                    scanDurationMs: Date().timeIntervalSince(startTime) * 1000,
                    error: .environmentScanFailed("Scan timed out after 10 seconds")
                )
                break scanLoop
            }
            switch event {
            case .networks(let nw):
                let currentBSSID: String? = await MainActor.run {
                    NetworkInfoService.fetchAll().first(where: { $0.ssid != nil })?.bssid
                }
                let observations = NetworkObservationAdapter.adaptAll(nw, currentBSSID: currentBSSID)
                let interfaceName = await scanner.interfaceName()
                result = WiFiEnvironmentSnapshot(
                    timestamp: Date(),
                    interfaceName: interfaceName,
                    networks: observations,
                    scanDurationMs: Date().timeIntervalSince(startTime) * 1000
                )
                break scanLoop
            case .failure(let msg):
                result = WiFiEnvironmentSnapshot(
                    timestamp: Date(),
                    interfaceName: nil,
                    networks: [],
                    scanDurationMs: Date().timeIntervalSince(startTime) * 1000,
                    error: .environmentScanFailed(msg)
                )
                break scanLoop
            }
        }

        return result ?? WiFiEnvironmentSnapshot(
            timestamp: Date(),
            interfaceName: nil,
            networks: [],
            scanDurationMs: Date().timeIntervalSince(startTime) * 1000,
            error: .environmentScanFailed("Scan produced no results")
        )
    }
}
