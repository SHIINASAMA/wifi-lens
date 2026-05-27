import SwiftUI

@MainActor
@Observable
final class BLEViewModel {
    let scanner = BLEScanner()
    let deviceTracker = BLEDeviceTracker()
    let bluetoothPermission = BluetoothPermissionManager()

    var isScanning = false
    var bluetoothState: BLEBluetoothState = .unknown
    var devices: [BLEDeviceSnapshot] = []
    var selectedDeviceID: String?
    var errorMessage: String?

    private var scanTask: Task<Void, Never>?

    var displayedDevices: [BLEDeviceSnapshot] {
        devices.sorted { $0.rssi > $1.rssi }
    }

    var selectedDevice: BLEDeviceSnapshot? {
        guard let id = selectedDeviceID else { return nil }
        return devices.first { $0.id == id }
    }

    var selectedDeviceHistory: [BLERSSISample]? {
        guard let id = selectedDeviceID,
              let uuid = UUID(uuidString: id) else { return nil }
        return deviceTracker.rssiHistory(for: uuid)
    }

    // MARK: - Actions

    func requestPermission() {
        bluetoothPermission.requestPermissionIfNeeded()
    }

    func startScanning() async {
        guard !isScanning else { return }

        bluetoothPermission.refreshStatus()
        guard bluetoothPermission.isAuthorized else {
            if bluetoothPermission.authorizationStatus == .notDetermined {
                bluetoothPermission.requestPermissionIfNeeded()
            }
            errorMessage = bluetoothPermission.authorizationStatus == .denied
                ? String(localized: "ble.permission.denied_message", comment: "Bluetooth permission denied error message")
                : String(localized: "ble.permission.required_message", comment: "Bluetooth permission required explanation")
            return
        }

        isScanning = true
        errorMessage = nil

        let stream = await scanner.startScanning()
        scanTask = Task {
            for await event in stream {
                switch event {
                case .deviceBatch(let eventsByDevice):
                    devices = deviceTracker.processBatch(eventsByDevice)

                case .bluetoothStateChanged(let state):
                    bluetoothState = state
                    bluetoothPermission.refreshStatus()
                    if state == .poweredOff || state == .unauthorized {
                        stopScanning()
                    }
                    if state == .unauthorized {
                        errorMessage = String(localized: "ble.permission.required_with_action", comment: "Bluetooth permission required with action instruction")
                    }

                case .failure(let message):
                    errorMessage = message
                    AppLogger.ble.error("scan failure: \(message)")
                }
            }
        }
    }

    func stopScanning() {
        isScanning = false
        scanTask?.cancel()
        scanTask = nil
        Task { await scanner.stopScanning() }
    }
}
