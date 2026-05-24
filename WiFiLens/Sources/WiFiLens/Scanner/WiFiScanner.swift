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
    /// On scan failure, retries up to 3 times with exponential backoff (1s → 2s → 4s).
    func startScanning(interval: Duration = Constants.scanInterval) -> AsyncStream<WiFiScanEvent> {
        shouldStop = false
        AppLogger.scanner.debug("startScanning() — reset stop flag")
        return AsyncStream { continuation in
            let task = Task {
                while !shouldStop && !Task.isCancelled {
                    let scanResult = await scanWithRetry()
                    switch scanResult {
                    case .success(let networks):
                        continuation.yield(.networks(networks))
                    case .failure(let error):
                        let msg = String(describing: error)
                        AppLogger.scanner.error("scan exhausted retries: \(msg)")
                        continuation.yield(.failure(msg))
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

    private enum ScanError: Error { case exhausted(String) }

    private func scanWithRetry() async -> Result<[WiFiNetwork], ScanError> {
        for attempt in 1...3 {
            do {
                let networks = try client.interface()?.scanForNetworks(withSSID: nil) ?? []
                let wrapped = networks.map { WiFiNetwork(from: $0) }
                return .success(wrapped)
            } catch {
                let msg = String(describing: error)
                if attempt < 3 {
                    let backoff = Duration.seconds(1 << (attempt - 1))
                    AppLogger.scanner.warning("scan attempt \(attempt) failed, retrying in \(backoff): \(msg)")
                    do { try await Task.sleep(for: backoff) }
                    catch { return .failure(.exhausted("cancelled during retry")) }
                } else {
                    return .failure(.exhausted(msg))
                }
            }
        }
        return .failure(.exhausted("unknown error"))
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
