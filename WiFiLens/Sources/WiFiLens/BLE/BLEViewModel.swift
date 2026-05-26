import SwiftUI

@MainActor
@Observable
final class BLEViewModel {
    let scanner = BLEScanner()
    let deviceTracker = BLEDeviceTracker()

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

    func startScanning() async {
        guard !isScanning else { return }
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
                    if state == .poweredOff || state == .unauthorized {
                        stopScanning()
                    }
                    if state == .unauthorized {
                        errorMessage = String(localized:
                            "Bluetooth permission is required. Enable it in System Settings.")
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
