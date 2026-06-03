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
    /// Scans are scheduled at wall-clock intervals (every `interval` seconds from the
    /// first scan), so scan duration does not push the next scan later.
    /// On scan failure, retries up to 3 times with exponential backoff (1s → 2s → 4s).
    func startScanning(interval: Duration = Constants.scanInterval) -> AsyncStream<WiFiScanEvent> {
        shouldStop = false
        AppLogger.scanner.debug("startScanning() — reset stop flag")
        let intervalSec = Double(interval.components.seconds) + Double(interval.components.attoseconds) / 1e18
        return AsyncStream { continuation in
            let task = Task {
                let startTime = Date()
                var scanIndex = 0
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

                    scanIndex += 1
                    let nextTarget = startTime.addingTimeInterval(Double(scanIndex) * intervalSec)
                    let remaining = nextTarget.timeIntervalSinceNow
                    if remaining > 0.01 {
                        do {
                            try await Task.sleep(for: .seconds(remaining))
                        } catch {
                            break
                        }
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
                let wrapped = networks.compactMap { WiFiNetwork(from: $0) }
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

    /// Returns the full set of (band, channel) tuples the hardware can use.
    /// This reflects the OS regulatory database + driver capabilities.
    func supportedChannels() -> [(ChannelBand, Int)] {
        guard let channels = client.interface()?.supportedWLANChannels() else {
            return []
        }
        return channels.compactMap { cw in
            guard let band = ChannelBand(rawValue: cw.channelBand.rawValue) else { return nil }
            return (band, cw.channelNumber)
        }
    }

    /// Returns raw (band raw value, channel number) pairs for region fingerprinting.
    /// These are Sendable, unlike CWChannel.
    func supportedWLANChannelsRaw() -> [(Int, Int)] {
        guard let channels = client.interface()?.supportedWLANChannels() else { return [] }
        return channels.map { (Int($0.channelBand.rawValue), $0.channelNumber) }
    }

    /// Derives device PHY capabilities from the active interface.
    func devicePHYCapabilities() -> DevicePHYCapabilities {
        guard let iface = client.interface() else {
            return .default
        }
        let phy = iface.activePHYMode()
        let allChannels = supportedChannels()
        let is6Ghz = allChannels.contains(where: { $0.0 == .band6GHz })
        let channelNumbers = Set(allChannels.map(\.1))
        let dfsChannelSet: Set<Int> = [
            52, 56, 60, 64, 100, 104, 108, 112, 116,
            120, 124, 128, 132, 136, 140, 144,
        ]
        let supportsDFS = !channelNumbers.intersection(dfsChannelSet).isEmpty
        return DevicePHYCapabilities(
            supportsAX: phy.rawValue >= 5,
            supportsAC: phy.rawValue >= 4,
            supportsN: phy.rawValue >= 3,
            supportsBE: phy.rawValue >= 6,
            supports6GHz: is6Ghz,
            supportsDFS: supportsDFS,
            supports160MHz: false
        )
    }
}
