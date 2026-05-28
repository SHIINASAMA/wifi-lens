import CoreWLAN
import Foundation

enum WiFiPowerState: Sendable {
    case poweredOn
    case poweredOff
    case interfaceUnavailable
}

@MainActor
final class WiFiPowerMonitor: NSObject, CWEventDelegate {
    private enum StateChangeSource: String {
        case callback = "system callback"
        case polling = "polling fallback"
    }

    private var continuation: AsyncStream<WiFiPowerState>.Continuation?
    private var pollingTask: Task<Void, Never>?
    private(set) var currentState: WiFiPowerState = .poweredOn

    var events: AsyncStream<WiFiPowerState> {
        AsyncStream { continuation in
            self.continuation = continuation
            continuation.yield(currentState)
        }
    }

    override init() {
        super.init()
        CWWiFiClient.shared().delegate = self
        try? CWWiFiClient.shared().startMonitoringEvent(with: .powerDidChange)
        refreshState(source: .callback)
        startPolling()
    }

    deinit {
        pollingTask?.cancel()
        try? CWWiFiClient.shared().stopMonitoringEvent(with: .powerDidChange)
    }

    private func refreshState(source: StateChangeSource) {
        let previous = currentState
        if let iface = CWWiFiClient.shared().interface() {
            currentState = iface.powerOn() ? .poweredOn : .poweredOff
        } else {
            currentState = .interfaceUnavailable
        }
        if currentState != previous {
            AppLogger.scanner.info("WiFi power state changed [\(source.rawValue)]: \(previous.logLabel) -> \(currentState.logLabel)")
            continuation?.yield(currentState)
        }
    }

    private func startPolling() {
        guard pollingTask == nil else { return }

        pollingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    self.refreshState(source: .polling)
                }
            }
        }
    }

    // MARK: - CWEventDelegate

    nonisolated func powerStateDidChangeForWiFiInterface(withName interfaceName: String) {
        Task { @MainActor in
            refreshState(source: .callback)
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
