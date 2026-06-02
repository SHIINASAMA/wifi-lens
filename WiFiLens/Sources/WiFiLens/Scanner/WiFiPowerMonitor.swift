import CoreWLAN
import Foundation

enum WiFiPowerState: Sendable {
    case poweredOn
    case poweredOff
    case interfaceUnavailable
}

@MainActor
final class WiFiPowerMonitor: NSObject, CWEventDelegate {
    private var continuation: AsyncStream<WiFiPowerState>.Continuation?
    private var pollingTask: Task<Void, Never>?
    private var isMonitoring = false
    private(set) var currentState: WiFiPowerState = .poweredOn

    var events: AsyncStream<WiFiPowerState> {
        AsyncStream { continuation in
            self.continuation = continuation
            continuation.yield(currentState)
        }
    }

    override init() {
        super.init()
    }

    deinit {
        pollingTask?.cancel()
        guard isMonitoring else { return }
        try? CWWiFiClient.shared().stopMonitoringEvent(with: .powerDidChange)
    }

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        CWWiFiClient.shared().delegate = self
        try? CWWiFiClient.shared().startMonitoringEvent(with: .powerDidChange)
        refreshState()
        startPolling()
    }

    func refreshState() {
        guard isMonitoring else { return }
        let previous = currentState
        if let iface = CWWiFiClient.shared().interface() {
            currentState = iface.powerOn() ? .poweredOn : .poweredOff
        } else {
            currentState = .interfaceUnavailable
        }
        if currentState != previous {
            AppLogger.scanner.info("WiFi power state changed: \(previous.logLabel) -> \(currentState.logLabel)")
            continuation?.yield(currentState)
        }
    }

    /// Low-frequency polling as safety net — CoreWLAN callbacks can occasionally miss events
    /// when the user toggles WiFi rapidly from the menu bar.
    private func startPolling() {
        guard pollingTask == nil else { return }

        pollingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    self.refreshState()
                }
            }
        }
    }

    // MARK: - CWEventDelegate

    nonisolated func powerStateDidChangeForWiFiInterface(withName interfaceName: String) {
        Task { @MainActor in
            refreshState()
        }
    }
}

private extension WiFiPowerState {
    var logLabel: String {
        switch self {
        case .poweredOn: return "poweredOn"
        case .poweredOff: return "poweredOff"
        case .interfaceUnavailable: return "interfaceUnavailable"
        }
    }
}
