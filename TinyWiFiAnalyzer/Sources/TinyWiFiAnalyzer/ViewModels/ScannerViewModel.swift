import SwiftUI

enum ScanAccessState: Equatable {
    case waitingForAuthorization
    case denied
    case scanning
    case grantedButSSIDUnavailable
    case scanFailed(String)
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

    var bandViewModels: [BandChartViewModel] {
        [band24, band5, band6].filter { supportedBands.contains($0.band) }
    }

    private var scanTask: Task<Void, Never>?

    func start() async {
        guard !isScanning else { return }
        isScanning = true

        print("[TinyWiFiAnalyzer] start(): begin (reserved isScanning=true)")
        locationManager.requestPermissionIfNeeded()
        print("[TinyWiFiAnalyzer] start(): auth after request = \(locationManager.authorizationStatus.rawValue)")

        supportedBands = await scanner.supportedBands()
        print("[TinyWiFiAnalyzer] start(): supportedBands = \(supportedBands.map { $0.id }.sorted())")
        updateInterfaceName()

        if locationManager.authorizationStatus == .notDetermined {
            accessState = .waitingForAuthorization
            print("[TinyWiFiAnalyzer] start(): waiting for initial authorization decision")
            _ = await locationManager.waitForInitialDecisionIfNeeded()
            print("[TinyWiFiAnalyzer] start(): authorization settled = \(locationManager.authorizationStatus.rawValue)")
        } else {
            locationManager.refreshStatus()
        }

        guard locationManager.isAuthorizedForSSID else {
            print("[TinyWiFiAnalyzer] start(): authorization denied/restricted")
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
        print("[TinyWiFiAnalyzer] startScanLoop(): starting")
        scanTask?.cancel()
        isScanning = true
        accessState = .scanning

        scanTask = Task {
            let stream = await scanner.startScanning()
            for await event in stream {
                guard !Task.isCancelled else { break }
                locationManager.refreshStatus()

                if !locationManager.isAuthorizedForSSID {
                    print("[TinyWiFiAnalyzer] startScanLoop(): lost authorization")
                    stop()
                    accessState = locationManager.authorizationStatus == .notDetermined
                        ? .waitingForAuthorization
                        : .denied
                    break
                }

                switch event {
                case .failure(let message):
                    print("[TinyWiFiAnalyzer] scan failure: \(message)")
                    accessState = .scanFailed(message)

                case .networks(let networks):
                    print("[TinyWiFiAnalyzer] scan success: networks=\(networks.count)")
                    applyNetworks(networks)
                }
            }
        }
    }

    private func applyNetworks(_ networks: [WiFiNetwork]) {
        let sorted24 = networks
            .filter { $0.channel.band == .band24GHz }
            .sorted { $0.channel.channelNumber < $1.channel.channelNumber }
        if supportedBands.contains(.band24GHz) {
            band24.updateNetworks(sorted24, colorHasher: colorHasher)
        }

        let sorted5 = networks
            .filter { $0.channel.band == .band5GHz }
            .sorted { $0.channel.channelNumber < $1.channel.channelNumber }
        if supportedBands.contains(.band5GHz) {
            band5.updateNetworks(sorted5, colorHasher: colorHasher)
        }

        let sorted6 = networks
            .filter { $0.channel.band == .band6GHz }
            .sorted { $0.channel.channelNumber < $1.channel.channelNumber }
        if supportedBands.contains(.band6GHz) {
            band6.updateNetworks(sorted6, colorHasher: colorHasher)
        }

        updateInterfaceName()

        let ssidCount = bandViewModels.reduce(0) { count, vm in
            count + vm.allSeriesData.filter { $0.ssid != "n/a" }.count
        }
        accessState = ssidCount > 0 ? .scanning : .grantedButSSIDUnavailable
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
