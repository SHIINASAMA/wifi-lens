import CoreLocation
import AppKit

@MainActor
@Observable
final class LocationPermissionManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var waiters: [CheckedContinuation<CLAuthorizationStatus, Never>] = []

    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var showDeniedAlert = false

    var isAuthorizedForSSID: Bool {
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse, .authorized:
            return true
        default:
            return false
        }
    }

    override init() {
        super.init()
        manager.delegate = self
        authorizationStatus = manager.authorizationStatus
    }

    func refreshStatus() {
        let status = manager.authorizationStatus
        authorizationStatus = status
        showDeniedAlert = status == .denied || status == .restricted
    }

    func requestPermissionIfNeeded() {
        refreshStatus()
        print("[WiFiLens] requestPermissionIfNeeded(): status=\(authorizationStatus.rawValue)")
        guard authorizationStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    func waitForInitialDecisionIfNeeded() async -> CLAuthorizationStatus {
        refreshStatus()
        guard authorizationStatus == .notDetermined else { return authorizationStatus }

        return await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            self.showDeniedAlert = status == .denied || status == .restricted
            if status != .notDetermined {
                let continuations = self.waiters
                self.waiters.removeAll()
                for continuation in continuations {
                    continuation.resume(returning: status)
                }
            }
        }
    }

    func openLocationPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
            NSWorkspace.shared.open(url)
        }
    }

    func terminateApp() {
        NSApplication.shared.terminate(nil)
    }
}
