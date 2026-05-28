import CoreBluetooth
import SwiftUI

@MainActor
@Observable
final class BLEViewModel {
    private enum BluetoothStateChangeSource: String {
        case monitor = "monitor callback"
        case scanner = "scanner stream"
    }

    let scanner = BLEScanner()
    let deviceTracker = BLEDeviceTracker()
    let bluetoothPermission = BluetoothPermissionManager()
    let bluetoothPowerMonitor = BLEPowerMonitor()

    var isScanning = false
    var bluetoothState: BLEBluetoothState = .unknown
    var devices: [BLEDeviceSnapshot] = []
    var selectedDeviceID: String?
    var errorMessage: String?

    private var scanTask: Task<Void, Never>?
    private var bluetoothMonitoringTask: Task<Void, Never>?
    private var shouldResumeScanningAfterPowerRestore = false

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

    init() {
        bluetoothState = bluetoothPowerMonitor.currentState
        startBluetoothMonitoring()
    }

    func requestPermission() {
        bluetoothPermission.requestPermissionIfNeeded()
    }

    func startScanning() async {
        guard !isScanning else { return }

        bluetoothPermission.refreshStatus()
        guard bluetoothPermission.isAuthorized else {
            shouldResumeScanningAfterPowerRestore = false
            if bluetoothPermission.authorizationStatus == .notDetermined {
                bluetoothPermission.requestPermissionIfNeeded()
            }
            errorMessage = bluetoothPermission.authorizationStatus == .denied
                ? String(localized: "ble.permission.denied_message", comment: "Bluetooth permission denied error message")
                : String(localized: "ble.permission.required_message", comment: "Bluetooth permission required explanation")
            return
        }

        shouldResumeScanningAfterPowerRestore = true
        isScanning = true
        errorMessage = nil

        let stream = await scanner.startScanning()
        scanTask = Task {
            for await event in stream {
                switch event {
                case .deviceBatch(let eventsByDevice):
                    devices = deviceTracker.processBatch(eventsByDevice)

                case .bluetoothStateChanged(let state):
                    await handleBluetoothStateChange(state, fromScanner: true)

                case .failure(let message):
                    errorMessage = message
                    AppLogger.ble.error("scan failure: \(message)")
                }
            }
        }
    }

    func stopScanning() {
        shouldResumeScanningAfterPowerRestore = false
        stopScanning(preserveResumeIntent: false)
    }

    private func stopScanning(preserveResumeIntent: Bool) {
        isScanning = false
        scanTask?.cancel()
        scanTask = nil
        Task { await scanner.stopScanning() }
        if !preserveResumeIntent {
            shouldResumeScanningAfterPowerRestore = false
        }
    }

    private func startBluetoothMonitoring() {
        guard bluetoothMonitoringTask == nil else { return }

        bluetoothMonitoringTask = Task { [weak self] in
            guard let self else { return }
            for await state in self.bluetoothPowerMonitor.events {
                await self.handleBluetoothStateChange(state, fromScanner: false)
            }
        }
    }

    private func handleBluetoothStateChange(_ state: BLEBluetoothState, fromScanner: Bool) async {
        let previousState = bluetoothState
        bluetoothState = state
        bluetoothPermission.refreshStatus()

        if previousState != state {
            let source = fromScanner ? BluetoothStateChangeSource.scanner : BluetoothStateChangeSource.monitor
            AppLogger.ble.info("Bluetooth state changed [\(source.rawValue)]: \(previousState.logLabel) -> \(state.logLabel)")
        }

        switch state {
        case .poweredOn:
            errorMessage = nil
            if shouldResumeScanningAfterPowerRestore, !isScanning {
                AppLogger.ble.info("Bluetooth scan resumed after power restored")
                await startScanning()
            }

        case .poweredOff, .resetting:
            if isScanning {
                AppLogger.ble.warning("Bluetooth scan paused because adapter is \(state.logLabel)")
                stopScanning(preserveResumeIntent: true)
            }

        case .unauthorized:
            shouldResumeScanningAfterPowerRestore = false
            if isScanning {
                AppLogger.ble.warning("Bluetooth scan stopped because authorization is unavailable")
                stopScanning(preserveResumeIntent: false)
            }
            errorMessage = String(localized: "ble.permission.required_with_action", comment: "Bluetooth permission required with action instruction")

        case .unsupported:
            shouldResumeScanningAfterPowerRestore = false
            if isScanning {
                AppLogger.ble.error("Bluetooth scan stopped because hardware is unsupported")
                stopScanning(preserveResumeIntent: false)
            }
            errorMessage = String(localized: "ble.state.unsupported", comment: "BLE state: hardware does not support BLE")

        case .unknown:
            break
        }
    }
}

final class BLEPowerMonitor: NSObject, CBCentralManagerDelegate {
    private var continuation: AsyncStream<BLEBluetoothState>.Continuation?
    private var centralManager: CBCentralManager?
    private(set) var currentState: BLEBluetoothState = .unknown

    var events: AsyncStream<BLEBluetoothState> {
        AsyncStream { continuation in
            self.continuation = continuation
            continuation.yield(currentState)
        }
    }

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    deinit {
        centralManager?.delegate = nil
        centralManager = nil
    }

    private func updateState(from central: CBCentralManager) {
        let nextState: BLEBluetoothState = switch central.state {
        case .unknown:      .unknown
        case .resetting:    .resetting
        case .unsupported:  .unsupported
        case .unauthorized: .unauthorized
        case .poweredOff:   .poweredOff
        case .poweredOn:    .poweredOn
        @unknown default:   .unknown
        }

        guard nextState != currentState else { return }
        currentState = nextState
        continuation?.yield(nextState)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        updateState(from: central)
    }
}

private extension BLEBluetoothState {
    var logLabel: String {
        switch self {
        case .unknown: return "unknown"
        case .resetting: return "resetting"
        case .unsupported: return "unsupported"
        case .poweredOff: return "poweredOff"
        case .poweredOn: return "poweredOn"
        case .unauthorized: return "unauthorized"
        }
    }
}
