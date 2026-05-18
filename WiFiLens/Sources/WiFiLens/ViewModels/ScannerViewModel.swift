import SwiftUI
import Foundation

enum ScanAccessState: Equatable {
    case waitingForAuthorization
    case denied
    case scanning
    case grantedButSSIDUnavailable
    case scanFailed(String)
}

struct NetworkTableRow: Identifiable, Hashable {
    let id: String
    let bandLabel: String
    let channel: Int
    let rssi: Int
    let ssid: String
    let bssid: String
    let color: Color
    let isFilteredOut: Bool
    let phyMode: String
    let channelWidth: String
    let supportsK: Bool
    let supportsR: Bool
    let supportsV: Bool
    let supportsWPA3: Bool
    let isHiddenSSID: Bool
}

@MainActor
@Observable
final class ScannerViewModel {
    let scanner = WiFiScanner()
    var locationManager = LocationPermissionManager()
    let colorHasher = SSIDColorHasher()

    var band24 = BandChartViewModel(band: .band24GHz)
    var band5 = BandChartViewModel(band: .band5GHz)
    var band6 = BandChartViewModel(band: .band6GHz)

    var supportedBands: Set<ChannelBand> = []
    var isScanning = false
    var interfaceName: String = ""
    var accessState: ScanAccessState = .waitingForAuthorization

    var globalFilterQuery: String = "" {
        didSet { applyGlobalFilterToBands() }
    }
    var selectedNetworkID: String?
    var networkInfo: NetworkInterfaceInfo?

    var bandViewModels: [BandChartViewModel] {
        [band24, band5, band6].filter { supportedBands.contains($0.band) }
    }

    var combinedTableRows: [NetworkTableRow] {
        bandViewModels.flatMap { vm in
            vm.displayedSeriesData.map { series in
                NetworkTableRow(
                    id: series.id,
                    bandLabel: vm.band.displayName,
                    channel: series.channel,
                    rssi: series.rssi,
                    ssid: series.displaySSID,
                    bssid: series.bssid,
                    color: series.color,
                    isFilteredOut: series.isFilteredOut,
                    phyMode: series.phyMode,
                    channelWidth: series.channelWidth,
                    supportsK: series.supportsK,
                    supportsR: series.supportsR,
                    supportsV: series.supportsV,
                    supportsWPA3: series.supportsWPA3,
                    isHiddenSSID: series.isHiddenSSID
                )
            }
        }
    }

    private var scanTask: Task<Void, Never>?

    func start() async {
        guard !isScanning else { return }
        isScanning = true

        print("[WiFiLens] start(): begin (reserved isScanning=true)")
        locationManager.requestPermissionIfNeeded()
        print("[WiFiLens] start(): auth after request = \(locationManager.authorizationStatus.rawValue)")

        supportedBands = await scanner.supportedBands()
        print("[WiFiLens] start(): supportedBands = \(supportedBands.map { $0.id }.sorted())")
        updateInterfaceName()

        if locationManager.authorizationStatus == .notDetermined {
            accessState = .waitingForAuthorization
            print("[WiFiLens] start(): waiting for initial authorization decision")
            _ = await locationManager.waitForInitialDecisionIfNeeded()
            print("[WiFiLens] start(): authorization settled = \(locationManager.authorizationStatus.rawValue)")
        } else {
            locationManager.refreshStatus()
        }

        guard locationManager.isAuthorizedForSSID else {
            print("[WiFiLens] start(): authorization denied/restricted")
            accessState = .denied
            isScanning = false
            return
        }

        startScanLoop()
    }

    func handleSceneDidBecomeActive() async {
        locationManager.refreshStatus()
        updateInterfaceName()

        if locationManager.isAuthorizedForSSID {
            if !isScanning {
                startScanLoop()
            }
        } else {
            stop()
            accessState = locationManager.authorizationStatus == .notDetermined
                ? .waitingForAuthorization
                : .denied
        }
    }

    private func startScanLoop() {
        print("[WiFiLens] startScanLoop(): starting")
        scanTask?.cancel()
        isScanning = true
        accessState = .scanning

        scanTask = Task {
            let intervalSeconds = UserDefaults.standard.integer(forKey: "scanIntervalSeconds")
            let interval: Duration = .seconds(max(1, intervalSeconds > 0 ? intervalSeconds : 3))
            let stream = await scanner.startScanning(interval: interval)
            for await event in stream {
                guard !Task.isCancelled else { break }
                locationManager.refreshStatus()

                if !locationManager.isAuthorizedForSSID {
                    print("[WiFiLens] startScanLoop(): lost authorization")
                    stop()
                    accessState = locationManager.authorizationStatus == .notDetermined
                        ? .waitingForAuthorization
                        : .denied
                    break
                }

                switch event {
                case .failure(let message):
                    print("[WiFiLens] scan failure: \(message)")
                    accessState = .scanFailed(message)

                case .networks(let networks):
                    print("[WiFiLens] scan success: networks=\(networks.count)")
                    applyNetworks(networks)
                    networkInfo = NetworkInfoService.fetch()
                }
            }
        }
    }

    private func deduplicateNetworks(_ networks: [WiFiNetwork]) -> [WiFiNetwork] {
        var seen = [String: WiFiNetwork]()
        for nw in networks {
            let key = "\(nw.bssid)-\(nw.channel.channelNumber)-\(nw.channel.band.rawValue)"
            if let existing = seen[key] {
                if nw.rssi > existing.rssi {
                    seen[key] = nw
                }
            } else {
                seen[key] = nw
            }
        }
        return Array(seen.values)
    }

    private func applyNetworks(_ networks: [WiFiNetwork]) {
        let deduped = deduplicateNetworks(networks)
        let sorted24 = deduped
            .filter { $0.channel.band == .band24GHz }
            .sorted { $0.channel.channelNumber < $1.channel.channelNumber }
        if supportedBands.contains(.band24GHz) {
            band24.updateNetworks(sorted24, colorHasher: colorHasher, filterQuery: globalFilterQuery)
        }

        let sorted5 = deduped
            .filter { $0.channel.band == .band5GHz }
            .sorted { $0.channel.channelNumber < $1.channel.channelNumber }
        if supportedBands.contains(.band5GHz) {
            band5.updateNetworks(sorted5, colorHasher: colorHasher, filterQuery: globalFilterQuery)
        }

        let sorted6 = deduped
            .filter { $0.channel.band == .band6GHz }
            .sorted { $0.channel.channelNumber < $1.channel.channelNumber }
        if supportedBands.contains(.band6GHz) {
            band6.updateNetworks(sorted6, colorHasher: colorHasher, filterQuery: globalFilterQuery)
        }

        updateInterfaceName()

        // Validate selected network still exists in the new scan
        if let selectedID = selectedNetworkID {
            let allIDs = bandViewModels.flatMap { $0.allSeriesData.map(\.id) }
            if !allIDs.contains(selectedID) {
                selectedNetworkID = nil
            }
        }

        let ssidCount = bandViewModels.reduce(0) { count, vm in
            count + vm.allSeriesData.filter { $0.ssid != "n/a" }.count
        }
        accessState = ssidCount > 0 ? .scanning : .grantedButSSIDUnavailable
    }

    private func applyGlobalFilterToBands() {
        band24.applyFilter(globalFilterQuery)
        band5.applyFilter(globalFilterQuery)
        band6.applyFilter(globalFilterQuery)
    }

    private func updateInterfaceName() {
        Task {
            if let name = await scanner.interfaceName() {
                await MainActor.run {
                    self.interfaceName = name
                    for vm in self.bandViewModels {
                        vm.updateInterfaceName(name)
                    }
                }
            }
        }
    }

    func stop() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        Task { await scanner.stopScanning() }
    }
}
