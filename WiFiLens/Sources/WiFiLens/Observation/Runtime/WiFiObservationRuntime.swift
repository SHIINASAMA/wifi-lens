import Foundation

@MainActor
protocol WiFiObservationConsuming: AnyObject {
    func consume(_ observation: WiFiObservation) async throws
}

struct ObservationConsumerDiagnostics: Equatable, Sendable {
    let pendingCount: Int
    let oldestObservationTimestamp: Date?
    let failureCount: Int
}

struct WiFiObservationRuntimeConfiguration: Sendable {
    var scanInterval: Duration
    var userRegionOverride: RegulatoryDomain?
    var userDefaultsRegionOverride: RegulatoryDomain?
}

struct WiFiObservationScanOutput: Sendable {
    let rawNetworks: [WiFiNetwork]
    let cycle: WiFiObservationCycleResult
    let interfaceName: String?
    let supportedBands: Set<ChannelBand>
}

@MainActor
final class WiFiObservationRuntime {
    let store: WiFiObservationStore

    private struct CapabilityCache {
        let interfaceName: String?
        let supportedBands: Set<ChannelBand>
        let supportedChannelsRaw: [(Int, Int)]
        let deviceSupportedChannels: Set<String>
        let deviceCapabilities: DevicePHYCapabilities
    }

    private let pipeline: any WiFiObservationPipelining
    private let scanSource: any WiFiScanStreaming
    private var workers: [ObjectIdentifier: ObservationConsumerWorker] = [:]
    private var scanTask: Task<Void, Never>?
    private var activeScanGeneration: UUID?
    private var outputProjection: (@MainActor (WiFiObservationScanOutput) -> Void)?
    private var requestedOutputProjection: (@MainActor (WiFiObservationScanOutput) -> Void)?
    private var publicationEligibility: (@MainActor () -> Bool)?
    private var requestedPublicationEligibility: (@MainActor () -> Bool)?
    private var latestLifecycleRequestID: UInt64 = 0
    private var lifecycleCommandTail: Task<Void, Never>?
#if DEBUG
    var onActiveScanStoppedForTesting: (@MainActor () -> Void)?
    var onConsumerDrainStartedForTesting: (@MainActor () -> Void)?
#endif

    init(
        store: WiFiObservationStore = .shared,
        pipeline: any WiFiObservationPipelining = WiFiObservationPipeline(),
        scanSource: any WiFiScanStreaming = WiFiScanner()
    ) {
        self.store = store
        self.pipeline = pipeline
        self.scanSource = scanSource
    }

    func addConsumer(_ consumer: any WiFiObservationConsuming) {
        let identifier = ObjectIdentifier(consumer)
        guard workers[identifier] == nil else { return }
        workers[identifier] = ObservationConsumerWorker(consumer: consumer)
    }

    func accept(_ observation: WiFiObservation) {
        store.apply(observation)
        for worker in workers.values {
            worker.enqueue(observation)
        }
    }

    func drainConsumers() async {
#if DEBUG
        onConsumerDrainStartedForTesting?()
#endif
        let tails = workers.values.compactMap(\.tail)
        for tail in tails {
            await tail.value
        }
    }

    func diagnostics() -> [ObjectIdentifier: ObservationConsumerDiagnostics] {
        workers.mapValues(\.diagnostics)
    }

    func startScanning(
        configuration: WiFiObservationRuntimeConfiguration,
        isPublicationEligible: @escaping @MainActor () -> Bool = { true },
        onOutput: @escaping @MainActor (WiFiObservationScanOutput) -> Void
    ) async {
        let replacesRequestedScan = requestedOutputProjection != nil
        requestedOutputProjection = onOutput
        requestedPublicationEligibility = isPublicationEligible
        let command = enqueueLifecycleCommand { [weak self] requestID in
            guard let self else { return }
            await self.executeStartCommand(
                configuration: configuration,
                onOutput: onOutput,
                isPublicationEligible: isPublicationEligible,
                requestID: requestID,
                stopSourceBeforeStart: replacesRequestedScan
            )
        }
        await command.value
    }

    func restartScanning(configuration: WiFiObservationRuntimeConfiguration) async {
        guard let requestedOutputProjection, let requestedPublicationEligibility else { return }
        let command = enqueueLifecycleCommand { [weak self] requestID in
            guard let self else { return }
            await self.executeStartCommand(
                configuration: configuration,
                onOutput: requestedOutputProjection,
                isPublicationEligible: requestedPublicationEligibility,
                requestID: requestID,
                stopSourceBeforeStart: true
            )
        }
        await command.value
    }

    func stopScanning() async {
        let hadRequestedScan = requestedOutputProjection != nil
        requestedOutputProjection = nil
        requestedPublicationEligibility = nil
        let command = enqueueLifecycleCommand { [weak self] _ in
            guard let self else { return }
            await self.stopActiveScan(stopSource: hadRequestedScan)
#if DEBUG
            self.onActiveScanStoppedForTesting?()
#endif
            await self.drainConsumers()
            self.outputProjection = nil
            self.publicationEligibility = nil
        }
        await command.value
    }

    private func executeStartCommand(
        configuration: WiFiObservationRuntimeConfiguration,
        onOutput: @escaping @MainActor (WiFiObservationScanOutput) -> Void,
        isPublicationEligible: @escaping @MainActor () -> Bool,
        requestID: UInt64,
        stopSourceBeforeStart: Bool
    ) async {
        await stopActiveScan(stopSource: stopSourceBeforeStart)
        guard isLatestLifecycleRequest(requestID) else { return }

        let interfaceName = await scanSource.interfaceName()
        guard isLatestLifecycleRequest(requestID) else { return }
        let supportedBands = await scanSource.supportedBands()
        guard isLatestLifecycleRequest(requestID) else { return }
        let supportedChannels = await scanSource.supportedChannels()
        guard isLatestLifecycleRequest(requestID) else { return }
        let supportedChannelsRaw = await scanSource.supportedWLANChannelsRaw()
        guard isLatestLifecycleRequest(requestID) else { return }
        let deviceCapabilities = await scanSource.devicePHYCapabilities()
        guard isLatestLifecycleRequest(requestID) else { return }
        let cache = CapabilityCache(
            interfaceName: interfaceName,
            supportedBands: supportedBands,
            supportedChannelsRaw: supportedChannelsRaw,
            deviceSupportedChannels: Set(supportedChannels.map { "\($0.0.rawValue)-\($0.1)" }),
            deviceCapabilities: deviceCapabilities
        )
        let stream = await scanSource.startScanning(interval: configuration.scanInterval)
        guard isLatestLifecycleRequest(requestID) else {
            await scanSource.stopScanning()
            return
        }
        let generation = UUID()
        activeScanGeneration = generation
        outputProjection = onOutput
        publicationEligibility = isPublicationEligible
        scanTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.consumeScanStream(
                stream,
                configuration: configuration,
                cache: cache,
                generation: generation
            )
        }
    }

    private func consumeScanStream(
        _ stream: AsyncStream<WiFiScanEvent>,
        configuration: WiFiObservationRuntimeConfiguration,
        cache: CapabilityCache,
        generation: UUID
    ) async {
        defer {
            if activeScanGeneration == generation {
                activeScanGeneration = nil
                scanTask = nil
                publicationEligibility = nil
            }
        }
        for await event in stream {
            guard ownsScanLifecycle(generation) else { break }
            let shouldContinue = await processScanEvent(
                event,
                configuration: configuration,
                cache: cache,
                generation: generation
            )
            if !shouldContinue { break }
        }
    }

    private func processScanEvent(
        _ event: WiFiScanEvent,
        configuration: WiFiObservationRuntimeConfiguration,
        cache: CapabilityCache,
        generation: UUID
    ) async -> Bool {
        let networks: [WiFiNetwork]
        let environmentError: WiFiObservationError?
        switch event {
        case .networks(let scannedNetworks):
            networks = scannedNetworks
            environmentError = nil
        case .failure(let message):
            networks = []
            environmentError = .environmentScanFailed(message)
        }

        let cycle = await pipeline.produceCycle(
            networks: networks,
            context: WiFiObservationCycleContext(
                timestamp: Date(),
                interfaceName: cache.interfaceName,
                supportedBands: cache.supportedBands,
                supportedChannelsRaw: cache.supportedChannelsRaw,
                deviceSupportedChannels: cache.deviceSupportedChannels,
                deviceCapabilities: cache.deviceCapabilities,
                userRegionOverride: configuration.userRegionOverride,
                userDefaultsRegionOverride: configuration.userDefaultsRegionOverride,
                environmentError: environmentError
            )
        )
        guard activeScanGeneration == generation, !Task.isCancelled else { return false }
        guard publicationEligibility?() != false else {
            clearPublicationRequestAfterRejection()
            await scanSource.stopScanning()
            return false
        }
        accept(cycle.observation)
        outputProjection?(WiFiObservationScanOutput(
            rawNetworks: networks,
            cycle: cycle,
            interfaceName: cache.interfaceName,
            supportedBands: cache.supportedBands
        ))
        return true
    }

    private func clearPublicationRequestAfterRejection() {
        requestedOutputProjection = nil
        requestedPublicationEligibility = nil
        outputProjection = nil
        publicationEligibility = nil
    }

    private func stopActiveScan(stopSource: Bool) async {
        let task = scanTask
        scanTask = nil
        activeScanGeneration = nil
        publicationEligibility = nil
        task?.cancel()
        if stopSource || task != nil {
            await scanSource.stopScanning()
        }
        await task?.value
    }

    private func ownsScanLifecycle(_ generation: UUID) -> Bool {
        activeScanGeneration == generation && !Task.isCancelled
    }

    private func enqueueLifecycleCommand(
        _ operation: @escaping @MainActor (UInt64) async -> Void
    ) -> Task<Void, Never> {
        latestLifecycleRequestID &+= 1
        let requestID = latestLifecycleRequestID
        let previousCommand = lifecycleCommandTail
        let command = Task { @MainActor [weak self] in
            await previousCommand?.value
            guard let self, self.isLatestLifecycleRequest(requestID) else { return }
            await operation(requestID)
        }
        lifecycleCommandTail = command
        return command
    }

    private func isLatestLifecycleRequest(_ requestID: UInt64) -> Bool {
        latestLifecycleRequestID == requestID
    }
}

@MainActor
private final class ObservationConsumerWorker {
    let consumer: any WiFiObservationConsuming
    private(set) var tail: Task<Void, Never>?

    private var pendingTimestamps: [Date] = []
    private var failureCount = 0

    init(consumer: any WiFiObservationConsuming) {
        self.consumer = consumer
    }

    var diagnostics: ObservationConsumerDiagnostics {
        ObservationConsumerDiagnostics(
            pendingCount: pendingTimestamps.count,
            oldestObservationTimestamp: pendingTimestamps.first,
            failureCount: failureCount
        )
    }

    func enqueue(_ observation: WiFiObservation) {
        pendingTimestamps.append(observation.timestamp)
        let previousTail = tail
        tail = Task { @MainActor in
            await previousTail?.value
            do {
                try await consumer.consume(observation)
            } catch {
                failureCount += 1
                AppLogger.general.error(
                    "Observation consumer failed: \(String(describing: error))"
                )
            }
            pendingTimestamps.removeFirst()
        }
    }
}
