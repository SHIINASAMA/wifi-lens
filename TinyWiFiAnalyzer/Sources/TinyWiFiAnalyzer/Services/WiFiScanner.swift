import CoreWLAN
import Foundation

enum WiFiScanEvent: Sendable {
    case networks([WiFiNetwork])
    case failure(String)
}

actor WiFiScanner {
    private let client = CWWiFiClient.shared()
    private var shouldStop = false

    /// Emits scan results or failures at the configured interval.
    func startScanning(interval: Duration = Constants.scanInterval) -> AsyncStream<WiFiScanEvent> {
        shouldStop = false
        print("[TinyWiFiAnalyzer] WiFiScanner.startScanning(): reset stop flag")
        return AsyncStream { continuation in
            let task = Task {
                while !shouldStop && !Task.isCancelled {
                    do {
                        let networks = try client.interface()?.scanForNetworks(withSSID: nil) ?? []
                        let wrapped = networks.map { WiFiNetwork(from: $0) }
                        continuation.yield(.networks(wrapped))
                    } catch {
                        continuation.yield(.failure(String(describing: error)))
                    }

                    do {
                        try await Task.sleep(for: interval)
                    } catch {
                        break
                    }
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func stopScanning() {
        shouldStop = true
    }

    func interfaceName() -> String? {
        client.interface()?.interfaceName
    }

    func supportedBands() -> Set<ChannelBand> {
        guard let channels = client.interface()?.supportedWLANChannels() else {
            return Set(ChannelBand.allCases)
        }
        var bands = Set<ChannelBand>()
        for channel in channels {
            if let band = ChannelBand(rawValue: channel.channelBand.rawValue) {
                bands.insert(band)
            }
        }
        return bands
    }
}
