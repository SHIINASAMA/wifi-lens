import SwiftUI
import CoreWLAN
import AppKit

enum TestState {
    case idle
    case ready
    case running
    case stopped
}

@MainActor
@Observable
final class RoamingTestViewModel {

    // MARK: - Device

    let isPortable = DeviceCapabilities.isPortable

    // MARK: - State

    var state: TestState = .idle
    var errorMessage: String?

    // MARK: - Current connection

    var currentSSID: String?
    var currentBSSID: String?
    var currentRSSI: Int = 0
    var currentChannel: Int = 0
    var currentTxRate: Double = 0
    var currentPhyMode: String?
    var routerIP: String?
    var gatewayLatency: Double?

    // MARK: - Test data

    var segments: [RoamingSegment] = []
    var transitions: [APTransitionEvent] = []
    var elapsedTime: TimeInterval = 0
    var totalSamples: Int { segments.reduce(0) { $0 + $1.samples.count } }

    // MARK: - Private

    private var timer: Timer?
    private var startDate: Date?
    private var lastBSSID: String?
    private var lastRSSI: Int?
    private var lastChannel: Int?
    private var currentSegmentIndex: Int = -1
    private let pinger = GatewayPinger()

    // MARK: - Computed

    var canStart: Bool {
        state == .ready || state == .stopped
    }

    var isRunning: Bool {
        state == .running
    }

    // MARK: - Actions

    func checkReadiness() {
        state = .idle
        errorMessage = nil

        guard let iface = CWWiFiClient.shared().interface(),
              let ssid = iface.ssid() else {
            errorMessage = String(localized: "Not connected to any Wi-Fi network. Connect to a network before starting the roaming test.")
            state = .idle
            return
        }

        currentSSID = ssid
        currentBSSID = iface.bssid()
        currentRSSI = iface.rssiValue()
        currentChannel = iface.wlanChannel()?.channelNumber ?? 0
        currentTxRate = iface.transmitRate()
        currentPhyMode = phyModeLabel(iface)
        state = .ready
    }

    func startTest() {
        guard canStart else { return }
        guard let iface = CWWiFiClient.shared().interface(),
              let bssid = iface.bssid() else { return }

        segments = []
        transitions = []
        lastBSSID = bssid
        lastRSSI = iface.rssiValue()
        lastChannel = iface.wlanChannel()?.channelNumber ?? 0
        startDate = Date()
        elapsedTime = 0
        errorMessage = nil

        // Create first segment
        let segment = RoamingSegment(bssid: bssid, startTime: Date())
        segments = [segment]
        currentSegmentIndex = 0

        refreshConnectionInfo()
        appendSample()

        state = .running
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    func stopTest() {
        timer?.invalidate()
        timer = nil

        // Close current segment
        if currentSegmentIndex >= 0, currentSegmentIndex < segments.count {
            segments[currentSegmentIndex].endTime = Date()
        }

        refreshConnectionInfo()
        state = .stopped
    }

    // MARK: - Tick

    private func tick() {
        guard state == .running else { return }
        guard let iface = CWWiFiClient.shared().interface() else { return }

        let newBSSID = iface.bssid()
        let newRSSI = iface.rssiValue()
        let newChannel = iface.wlanChannel()?.channelNumber ?? 0

        // Ping gateway asynchronously
        if let router = routerIP {
            Task {
                let latency = await pinger.ping(host: router)
                await MainActor.run {
                    gatewayLatency = latency
                }
            }
        }

        // Detect AP transition
        if let newBSSID, let lastBSSID, newBSSID != lastBSSID {
            let transitionTime = Date()

            // Append final sample to old segment at the exact transition time
            if currentSegmentIndex >= 0, currentSegmentIndex < segments.count {
                let finalSample = RoamingSample(
                    timestamp: transitionTime,
                    rssi: lastRSSI ?? 0,
                    channel: lastChannel ?? 0,
                    txRate: currentTxRate,
                    gatewayLatency: gatewayLatency
                )
                segments[currentSegmentIndex].samples.append(finalSample)
                segments[currentSegmentIndex].endTime = transitionTime
            }

            // Record transition
            let event = APTransitionEvent(
                timestamp: transitionTime,
                fromBSSID: lastBSSID,
                toBSSID: newBSSID,
                rssiBefore: lastRSSI ?? 0,
                rssiAfter: newRSSI,
                channelBefore: lastChannel ?? 0,
                channelAfter: newChannel
            )
            transitions.append(event)

            // Start new segment at the same timestamp
            let segment = RoamingSegment(bssid: newBSSID, startTime: transitionTime)
            segments.append(segment)
            currentSegmentIndex = segments.count - 1
        }

        self.lastBSSID = newBSSID
        self.lastRSSI = newRSSI
        self.lastChannel = newChannel

        refreshConnectionInfo()
        appendSample()
    }

    // MARK: - Helpers

    private func refreshConnectionInfo() {
        guard let iface = CWWiFiClient.shared().interface() else { return }
        currentSSID = iface.ssid()
        currentBSSID = iface.bssid()
        currentRSSI = iface.rssiValue()
        currentChannel = iface.wlanChannel()?.channelNumber ?? 0
        currentTxRate = iface.transmitRate()
        currentPhyMode = phyModeLabel(iface)
        if routerIP == nil {
            routerIP = NetworkInfoService.fetch()?.router
        }
    }

    private func appendSample() {
        guard currentSegmentIndex >= 0, currentSegmentIndex < segments.count else { return }
        let segment = segments[currentSegmentIndex]
        // First sample of a segment uses the segment's startTime,
        // so consecutive segments share the transition timestamp and
        // there is no visual gap on the time axis.
        let timestamp = segment.samples.isEmpty ? segment.startTime : Date()
        let sample = RoamingSample(
            timestamp: timestamp,
            rssi: currentRSSI,
            channel: currentChannel,
            txRate: currentTxRate,
            gatewayLatency: gatewayLatency
        )
        segments[currentSegmentIndex].samples.append(sample)

        if let start = startDate {
            elapsedTime = Date().timeIntervalSince(start)
        }
    }

    private func phyModeLabel(_ iface: CWInterface) -> String? {
        switch iface.activePHYMode() {
        case .mode11be: "802.11be"
        case .mode11ax: "802.11ax"
        case .mode11ac: "802.11ac"
        case .mode11n:  "802.11n"
        case .mode11a:  "802.11a"
        case .mode11b:  "802.11b"
        case .mode11g:  "802.11g"
        default:        nil
        }
    }

    // MARK: - Persistence

    func saveSession() {
        guard !segments.isEmpty else { return }

        let record = RoamingSessionRecord(
            version: RoamingSessionRecord.currentVersion,
            savedAt: Date(),
            ssid: currentSSID ?? String(localized: "Unknown"),
            bssid: currentBSSID,
            phyMode: currentPhyMode,
            channel: currentChannel,
            duration: elapsedTime,
            segments: segments,
            transitions: transitions
        )

        let panel = NSSavePanel()
        panel.title = String(localized: "Save Roaming Session")
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = defaultFileName

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(record)
            try data.write(to: url)
        } catch {
            errorMessage = String(localized: "Failed to save session")
        }
    }

    func loadSession() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Load Roaming Session")
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.urls.first else { return }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let record = try decoder.decode(RoamingSessionRecord.self, from: data)

            segments = record.segments
            transitions = record.transitions
            elapsedTime = record.duration
            currentSSID = record.ssid
            currentBSSID = record.bssid
            currentPhyMode = record.phyMode
            currentChannel = record.channel
            currentRSSI = record.segments.last?.samples.last?.rssi ?? 0
            currentTxRate = record.segments.last?.samples.last?.txRate ?? 0
            state = .stopped
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Failed to load session")
        }
    }

    private var defaultFileName: String {
        let ssid = currentSSID ?? "WiFi"
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HHmmss"
        let ts = f.string(from: Date())
        return "\(ssid)_\(ts).wifi-roam"
    }
}
