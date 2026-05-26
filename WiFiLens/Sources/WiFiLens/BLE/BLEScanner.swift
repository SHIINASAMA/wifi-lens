import CoreBluetooth
import Foundation

// MARK: - Public event types

enum BLEBluetoothState: Sendable {
    case unknown, resetting, unsupported, poweredOff, poweredOn, unauthorized

    var label: String {
        switch self {
        case .unknown:      String(localized: "Unknown")
        case .resetting:    String(localized: "Resetting")
        case .unsupported:  String(localized: "Unsupported")
        case .poweredOff:   String(localized: "Bluetooth Off")
        case .poweredOn:    String(localized: "Ready")
        case .unauthorized: String(localized: "Permission Denied")
        }
    }
}

enum BLEScanEvent: Sendable {
    case deviceBatch([UUID: [BLEAdvertisementEvent]])
    case bluetoothStateChanged(BLEBluetoothState)
    case failure(String)
}

// MARK: - Scanner actor

actor BLEScanner {
    private var delegate: BLEScannerDelegate?
    private var shouldStop = false
    private var currentState = BLEBluetoothState.unknown

    var bluetoothState: BLEBluetoothState { currentState }

    func startScanning(batchInterval: Duration = .seconds(2)) -> AsyncStream<BLEScanEvent> {
        shouldStop = false
        let queue = DispatchQueue(label: "com.wifilens.blescanner", qos: .utility)
        let del = BLEScannerDelegate(queue: queue)
        delegate = del

        return AsyncStream<BLEScanEvent> { continuation in
            del.onStateChange = { [weak self] state in
                Task { [weak self] in
                    await self?.setState(state)
                    continuation.yield(.bluetoothStateChanged(state))
                }
            }

            del.onDiscover = { event in
                del.accumulate(event)
            }

            del.onReady = {
                del.startScan()
                del.beginActivity()
            }

            // Start the central manager (triggers onReady when powered on)
            del.start()

            // Batch flush + scan restart loop
            let streamTask = Task {
                let restartInterval: TimeInterval = 30
                var lastRestart = Date()

                while !shouldStop, !Task.isCancelled {
                    try? await Task.sleep(for: batchInterval)

                    if shouldStop || Task.isCancelled { break }

                    // Restart scan every 30s to prevent macOS callback decay
                    if Date().timeIntervalSince(lastRestart) > restartInterval {
                        del.restartScan()
                        lastRestart = Date()
                    }

                    // Drain accumulated events and yield directly
                    let accum = del.drainAccumulator()
                    if !accum.isEmpty {
                        continuation.yield(.deviceBatch(accum))
                    }
                }
            }

            continuation.onTermination = { _ in
                streamTask.cancel()
                del.stopScan()
                del.endActivity()
                del.stop()
            }
        }
    }

    func stopScanning() {
        shouldStop = true
        delegate?.stopScan()
        delegate?.endActivity()
    }

    // MARK: - Private

    private func setState(_ state: BLEBluetoothState) {
        currentState = state
    }
}

// MARK: - Delegate bridge

private final class BLEScannerDelegate: NSObject, CBCentralManagerDelegate, @unchecked Sendable {
    private let queue: DispatchQueue
    private var centralManager: CBCentralManager?
    private var accumulator: [UUID: [BLEAdvertisementEvent]] = [:]
    private let accumulatorLock = NSLock()
    private var started = false
    private var activityToken: NSObjectProtocol?

    var onStateChange: ((BLEBluetoothState) -> Void)?
    var onDiscover: ((BLEAdvertisementEvent) -> Void)?
    var onReady: (() -> Void)?

    init(queue: DispatchQueue) {
        self.queue = queue
        super.init()
    }

    func start() {
        centralManager = CBCentralManager(delegate: self, queue: queue)
    }

    func stop() {
        centralManager?.delegate = nil
        centralManager = nil
    }

    func startScan() {
        guard !started else { return }
        guard centralManager?.state == .poweredOn else { return }
        started = true
        let options: [String: Any] = [
            CBCentralManagerScanOptionAllowDuplicatesKey: true
        ]
        // Defer to next main-queue iteration — CBCentralManager may report
        // .poweredOn in its delegate callback before its internal state is
        // fully ready. Calling scanForPeripherals synchronously triggers:
        // "API MISUSE: can only accept this command while in the powered on state"
        DispatchQueue.main.async { [weak self] in
            guard self?.started == true else { return }
            self?.centralManager?.scanForPeripherals(withServices: nil, options: options)
        }
    }

    func stopScan() {
        started = false
        centralManager?.stopScan()
    }

    func beginActivity() {
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "BLE device scanning"
        )
    }

    func endActivity() {
        if let token = activityToken {
            ProcessInfo.processInfo.endActivity(token)
            activityToken = nil
        }
    }

    func restartScan() {
        stopScan()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.startScan()
        }
    }

    func accumulate(_ event: BLEAdvertisementEvent) {
        accumulatorLock.lock()
        accumulator[event.peripheralIdentifier, default: []].append(event)
        accumulatorLock.unlock()
    }

    func drainAccumulator() -> [UUID: [BLEAdvertisementEvent]] {
        accumulatorLock.lock()
        let result = accumulator
        accumulator = [:]
        accumulatorLock.unlock()
        return result
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state: BLEBluetoothState = switch central.state {
        case .unknown:      .unknown
        case .resetting:    .resetting
        case .unsupported:  .unsupported
        case .unauthorized: .unauthorized
        case .poweredOff:   .poweredOff
        case .poweredOn:    .poweredOn
        @unknown default:   .unknown
        }

        onStateChange?(state)

        if central.state == .poweredOn, !started {
            onReady?()
        }

        if central.state != .poweredOn {
            stopScan()
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let event = BLEAdvertisementEvent(
            timestamp: Date(),
            peripheralIdentifier: peripheral.identifier,
            localName: (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name,
            rssi: RSSI.intValue,
            txPower: (advertisementData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber)?.intValue,
            manufacturerData: advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data,
            serviceUUIDs: (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?.map(\.uuidString),
            isConnectable: (advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber)?.boolValue ?? false
        )
        onDiscover?(event)
    }
}
