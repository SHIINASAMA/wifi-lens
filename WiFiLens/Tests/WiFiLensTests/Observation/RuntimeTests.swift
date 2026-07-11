import Foundation
import CoreLocation
import Testing
@testable import WiFi_Lens

@Suite("WiFiObservationRuntime")
@MainActor
struct RuntimeTests {
    @Test("scanner and runtime share the injected store")
    func scannerRuntimeUsesInjectedStore() {
        let store = WiFiObservationStore()
        let scanner = ScannerViewModel(store: store)
        #expect(scanner.observationRuntime.store === store)
    }

    @Test("runtime injection makes its store the scanner store")
    func injectedRuntimeOwnsScannerStore() {
        let runtime = WiFiObservationRuntime(store: WiFiObservationStore())
        let scanner = ScannerViewModel(observationRuntime: runtime)
        #expect(scanner.store === runtime.store)
    }

    @Test("accepted observations update the store and preserve consumer order")
    func orderedDelivery() async {
        let store = WiFiObservationStore()
        let consumer = CapturingObservationConsumer()
        let runtime = WiFiObservationRuntime(store: store)
        runtime.addConsumer(consumer)

        let first = WiFiObservation(timestamp: Date(timeIntervalSince1970: 1))
        let second = WiFiObservation(timestamp: Date(timeIntervalSince1970: 2))
        runtime.accept(first)
        runtime.accept(second)

        #expect(store.lastUpdated != nil)
        await runtime.drainConsumers()
        #expect(consumer.observations == [first, second])
    }

    @Test("a suspended consumer does not delay store publication")
    func storeIsImmediate() async {
        let store = WiFiObservationStore()
        let consumer = SuspendedObservationConsumer()
        let runtime = WiFiObservationRuntime(store: store)
        runtime.addConsumer(consumer)

        let status = WiFiCurrentStatus(
            timestamp: Date(), ssid: "Office", bssid: "AA:BB",
            isConnected: true, isWiFiPowerOn: true
        )
        runtime.accept(WiFiObservation(currentStatus: status))

        await consumer.waitUntilEntered()
        #expect(store.currentStatus == status)
        consumer.resume()
        await runtime.drainConsumers()
    }

    @Test("normal stop drains accepted consumer work after stopping the scan source")
    func stopDrainsAcceptedConsumerWork() async {
        let source = ScriptedScanSource()
        let consumer = SuspendedObservationConsumer()
        let activeScanStopped = MainActorMilestone()
        let consumerDrainStarted = MainActorMilestone()
        let runtime = WiFiObservationRuntime(
            store: WiFiObservationStore(),
            scanSource: source
        )
        runtime.onActiveScanStoppedForTesting = {
            activeScanStopped.reach()
        }
        runtime.onConsumerDrainStartedForTesting = {
            consumerDrainStarted.reach()
        }
        runtime.addConsumer(consumer)

        await runtime.startScanning(configuration: WiFiObservationRuntimeConfiguration(
            scanInterval: .seconds(4)
        )) { _ in }
        let observation = WiFiObservation(timestamp: Date(timeIntervalSince1970: 42))
        runtime.accept(observation)
        await consumer.waitUntilEntered()

        let stopCompletion = AsyncCompletionProbe()
        let stopTask = Task { @MainActor in
            await runtime.stopScanning()
            await stopCompletion.markCompleted()
        }

        await source.waitUntilStopCompleted()
        await activeScanStopped.waitUntilReached()
        await consumerDrainStarted.waitUntilReached()

        #expect(await source.snapshot().activeStreamCount == 0)
        #expect(consumer.isSuspended)
        #expect(await stopCompletion.isCompleted == false)
        consumer.resume()
        await stopTask.value

        #expect(await stopCompletion.isCompleted)
        #expect(consumer.observations == [observation])
    }

    @Test("a failing consumer does not stop later observations")
    func failureIsolation() async {
        let consumer = FailOnceObservationConsumer()
        let runtime = WiFiObservationRuntime(store: WiFiObservationStore())
        runtime.addConsumer(consumer)
        runtime.accept(WiFiObservation(timestamp: Date(timeIntervalSince1970: 1)))
        runtime.accept(WiFiObservation(timestamp: Date(timeIntervalSince1970: 2)))

        await runtime.drainConsumers()
        #expect(consumer.attemptedTimestamps == [
            Date(timeIntervalSince1970: 1), Date(timeIntervalSince1970: 2),
        ])
    }

    @Test("OSS composition needs no consumer")
    func noConsumerComposition() async {
        let store = WiFiObservationStore()
        let runtime = WiFiObservationRuntime(store: store)
        let status = WiFiCurrentStatus(timestamp: Date(), isConnected: false, isWiFiPowerOn: true)
        runtime.accept(WiFiObservation(currentStatus: status))
        await runtime.drainConsumers()
        #expect(store.currentStatus == status)
    }

    @Test("start caches scanner capabilities once and publishes every network cycle")
    func scanStartCachesCapabilitiesAndPublishesCycles() async {
        let source = ScriptedScanSource()
        let pipeline = RecordingCyclePipeline()
        let store = WiFiObservationStore()
        let runtime = WiFiObservationRuntime(
            store: store,
            pipeline: pipeline,
            scanSource: source
        )
        var outputs: [WiFiObservationScanOutput] = []
        var publicationWasVisible: [Bool] = []
        let configuration = WiFiObservationRuntimeConfiguration(
            scanInterval: .seconds(4),
            userRegionOverride: .JP,
            userDefaultsRegionOverride: .US
        )

        await runtime.startScanning(configuration: configuration) { output in
            outputs.append(output)
            publicationWasVisible.append(store.currentStatus == output.cycle.observation.currentStatus)
        }
        let first = [runtimeNetwork(bssid: "AA:01", channel: 1)]
        let second = [runtimeNetwork(bssid: "AA:02", channel: 36)]
        await source.yield(.networks(first))
        await source.yield(.networks(second))
        await waitUntil { outputs.count == 2 }

        let snapshot = await source.snapshot()
        let calls = await pipeline.calls
        #expect(snapshot.requestedIntervals == [.seconds(4)])
        #expect(snapshot.interfaceNameCalls == 1)
        #expect(snapshot.supportedBandsCalls == 1)
        #expect(snapshot.supportedChannelsCalls == 1)
        #expect(snapshot.rawChannelsCalls == 1)
        #expect(snapshot.deviceCapabilitiesCalls == 1)
        #expect(calls.map(\.networks.count) == [1, 1])
        #expect(calls.allSatisfy { $0.context.interfaceName == "en7" })
        #expect(calls.allSatisfy { $0.context.supportedBands == [.band24GHz, .band5GHz] })
        #expect(calls.allSatisfy { $0.context.supportedChannelsRaw.count == 2 })
        #expect(calls.allSatisfy { $0.context.deviceSupportedChannels == ["1-1", "2-36"] })
        #expect(calls.allSatisfy { $0.context.userRegionOverride == .JP })
        #expect(calls.allSatisfy { $0.context.userDefaultsRegionOverride == .US })
        #expect(outputs.map(\.rawNetworks.count) == [1, 1])
        #expect(publicationWasVisible == [true, true])

        await runtime.stopScanning()
    }

    @Test("scan failure produces a partial cycle that preserves current status")
    func scanFailureProducesPartialCycle() async {
        let source = ScriptedScanSource()
        let preservedStatus = WiFiCurrentStatus(
            timestamp: Date(timeIntervalSince1970: 42),
            ssid: "Still connected",
            bssid: "AA:BB:CC:DD:EE:FF",
            isConnected: true,
            isWiFiPowerOn: true
        )
        let pipeline = RecordingCyclePipeline(currentStatus: preservedStatus)
        let store = WiFiObservationStore()
        let runtime = WiFiObservationRuntime(store: store, pipeline: pipeline, scanSource: source)
        var output: WiFiObservationScanOutput?

        await runtime.startScanning(configuration: .testDefault) { output = $0 }
        await source.yield(.failure("permission changed"))
        await waitUntil { output != nil }

        let call = await pipeline.calls.first
        let expectedError = WiFiObservationError.environmentScanFailed("permission changed")
        #expect(call?.networks.isEmpty == true)
        #expect(call?.context.environmentError == expectedError)
        #expect(output?.rawNetworks.isEmpty == true)
        #expect(output?.cycle.observation.currentStatus == preservedStatus)
        #expect(output?.cycle.observation.errors.contains(expectedError) == true)
        #expect(store.currentStatus == preservedStatus)

        await runtime.stopScanning()
    }

    @Test("publication gate rejects a cycle before store consumers and output")
    func publicationGateRejectsCycleAtomically() async {
        let source = ScriptedScanSource()
        let store = WiFiObservationStore()
        let consumer = CapturingObservationConsumer()
        let runtime = WiFiObservationRuntime(
            store: store,
            pipeline: RecordingCyclePipeline(),
            scanSource: source
        )
        runtime.addConsumer(consumer)
        var outputCount = 0

        await runtime.startScanning(
            configuration: .testDefault,
            isPublicationEligible: { false }
        ) { _ in
            outputCount += 1
        }
        await source.yield(.networks([runtimeNetwork(bssid: "AA:0F", channel: 36)]))
        await waitUntil { await source.snapshot().stopCalls == 1 }
        await runtime.drainConsumers()

        #expect(store.lastUpdated == nil)
        #expect(consumer.observations.isEmpty)
        #expect(outputCount == 0)
        #expect(await source.snapshot().activeStreamCount == 0)
    }

    @Test("publication rejection clears the restart request")
    func publicationRejectionRequiresFreshStart() async {
        let source = ScriptedScanSource()
        let runtime = WiFiObservationRuntime(
            store: WiFiObservationStore(),
            pipeline: RecordingCyclePipeline(),
            scanSource: source
        )

        await runtime.startScanning(
            configuration: .testDefault,
            isPublicationEligible: { false }
        ) { _ in }
        await source.yield(.networks([runtimeNetwork(bssid: "AA:10", channel: 36)]))
        await waitUntil { await source.snapshot().stopCalls == 1 }

        await runtime.restartScanning(configuration: .init(
            scanInterval: .seconds(9),
            userRegionOverride: nil,
            userDefaultsRegionOverride: nil
        ))

        let snapshot = await source.snapshot()
        #expect(snapshot.requestedIntervals == [.seconds(3)])
        #expect(snapshot.activeStreamCount == 0)
    }

    @Test("stop cancels the active stream and stops its source")
    func stopCancelsActiveStream() async {
        let source = ScriptedScanSource()
        let runtime = WiFiObservationRuntime(
            store: WiFiObservationStore(),
            pipeline: RecordingCyclePipeline(),
            scanSource: source
        )

        await runtime.startScanning(configuration: .testDefault) { _ in }
        await runtime.stopScanning()
        await waitUntil { await source.snapshot().activeStreamCount == 0 }

        let snapshot = await source.snapshot()
        #expect(snapshot.stopCalls == 1)
        #expect(snapshot.activeStreamCount == 0)
    }

    @Test("restart replaces the stream and uses the new interval")
    func restartReplacesStream() async {
        let source = ScriptedScanSource()
        let pipeline = RecordingCyclePipeline()
        let runtime = WiFiObservationRuntime(
            store: WiFiObservationStore(),
            pipeline: pipeline,
            scanSource: source
        )
        var outputCount = 0

        await runtime.startScanning(configuration: .testDefault) { _ in outputCount += 1 }
        await runtime.restartScanning(configuration: WiFiObservationRuntimeConfiguration(
            scanInterval: .seconds(9),
            userRegionOverride: nil,
            userDefaultsRegionOverride: nil
        ))
        await waitUntil { await source.snapshot().activeStreamCount == 1 }
        await source.yield(.networks([runtimeNetwork(bssid: "AA:09", channel: 9)]))
        await waitUntil { outputCount == 1 }

        let snapshot = await source.snapshot()
        #expect(snapshot.requestedIntervals == [.seconds(3), .seconds(9)])
        #expect(snapshot.stopCalls == 1)
        #expect(snapshot.activeStreamCount == 1)
        #expect(await pipeline.calls.count == 1)

        await runtime.stopScanning()
    }

    @Test("stop during capability lookup prevents stream creation")
    func stopDuringCapabilityLookupPreventsStreamCreation() async {
        let source = ScriptedScanSource()
        await source.suspendNextCapabilityLookup()
        let pipeline = RecordingCyclePipeline()
        let runtime = WiFiObservationRuntime(
            store: WiFiObservationStore(),
            pipeline: pipeline,
            scanSource: source
        )
        var outputCount = 0

        let startTask = Task { @MainActor in
            await runtime.startScanning(configuration: .testDefault) { _ in outputCount += 1 }
        }
        await source.waitUntilCapabilityLookupEntered()
        let stopTask = Task { @MainActor in
            await runtime.stopScanning()
        }
        await Task.yield()
        await source.releaseCapabilityLookup()
        await stopTask.value
        await startTask.value
        await source.yield(.networks([runtimeNetwork(bssid: "AA:10", channel: 10)]))
        await Task.yield()

        let snapshot = await source.snapshot()
        #expect(snapshot.requestedIntervals.isEmpty)
        #expect(snapshot.activeStreamCount == 0)
        #expect(await pipeline.calls.isEmpty)
        #expect(outputCount == 0)
    }

    @Test("restart replaces a startup suspended in capability lookup")
    func restartReplacesSuspendedStartup() async {
        let source = ScriptedScanSource()
        await source.suspendNextCapabilityLookup()
        let runtime = WiFiObservationRuntime(
            store: WiFiObservationStore(),
            pipeline: RecordingCyclePipeline(),
            scanSource: source
        )

        let firstStart = Task { @MainActor in
            await runtime.startScanning(configuration: .testDefault) { _ in }
        }
        await source.waitUntilCapabilityLookupEntered()
        let restart = Task { @MainActor in
            await runtime.restartScanning(configuration: WiFiObservationRuntimeConfiguration(
                scanInterval: .seconds(9),
                userRegionOverride: nil,
                userDefaultsRegionOverride: nil
            ))
        }
        await Task.yield()
        await source.releaseCapabilityLookup()
        await firstStart.value
        await restart.value
        await waitUntil { await source.snapshot().activeStreamCount > 0 }

        let snapshot = await source.snapshot()
        #expect(snapshot.requestedIntervals == [.seconds(9)])
        #expect(snapshot.stopCalls == 1)
        #expect(snapshot.activeStreamCount == 1)

        await runtime.stopScanning()
    }

    @Test("stop remains latest behind a queued restart during suspended startup")
    func stopWinsThreeCommandStartupRace() async {
        let source = ScriptedScanSource()
        await source.suspendNextCapabilityLookup()
        let runtime = WiFiObservationRuntime(
            store: WiFiObservationStore(),
            pipeline: RecordingCyclePipeline(),
            scanSource: source
        )
        var completed: Set<String> = []
        var restartEntered = false
        var stopEntered = false

        Task { @MainActor in
            await runtime.startScanning(configuration: .testDefault) { _ in }
            completed.insert("A")
        }
        await source.waitUntilCapabilityLookupEntered()
        Task { @MainActor in
            restartEntered = true
            await runtime.restartScanning(configuration: .init(
                scanInterval: .seconds(9),
                userRegionOverride: nil,
                userDefaultsRegionOverride: nil
            ))
            completed.insert("B")
        }
        await waitUntil { restartEntered }
        Task { @MainActor in
            stopEntered = true
            await runtime.stopScanning()
            completed.insert("C")
        }
        await waitUntil { stopEntered }

        await source.releaseCapabilityLookup()
        await waitUntil { completed == ["A", "B", "C"] }

        let snapshot = await source.snapshot()
        #expect(completed == ["A", "B", "C"])
        #expect(snapshot.requestedIntervals.isEmpty)
        #expect(snapshot.activeStreamCount == 0)
    }

    @Test("latest start wins behind a queued restart during suspended startup")
    func latestStartWinsThreeCommandStartupRace() async {
        let source = ScriptedScanSource()
        await source.suspendNextCapabilityLookup()
        let runtime = WiFiObservationRuntime(
            store: WiFiObservationStore(),
            pipeline: RecordingCyclePipeline(),
            scanSource: source
        )
        var completed: Set<String> = []
        var restartEntered = false
        var latestStartEntered = false

        Task { @MainActor in
            await runtime.startScanning(configuration: .testDefault) { _ in }
            completed.insert("A")
        }
        await source.waitUntilCapabilityLookupEntered()
        Task { @MainActor in
            restartEntered = true
            await runtime.restartScanning(configuration: .init(
                scanInterval: .seconds(9),
                userRegionOverride: nil,
                userDefaultsRegionOverride: nil
            ))
            completed.insert("B")
        }
        await waitUntil { restartEntered }
        Task { @MainActor in
            latestStartEntered = true
            await runtime.startScanning(configuration: .init(
                scanInterval: .seconds(11),
                userRegionOverride: nil,
                userDefaultsRegionOverride: nil
            )) { _ in }
            completed.insert("C")
        }
        await waitUntil { latestStartEntered }

        await source.releaseCapabilityLookup()
        await waitUntil { completed == ["A", "B", "C"] }
        await waitUntil { await source.snapshot().activeStreamCount == 1 }

        let snapshot = await source.snapshot()
        #expect(completed == ["A", "B", "C"])
        #expect(snapshot.requestedIntervals == [.seconds(11)])
        #expect(snapshot.activeStreamCount == 1)

        await runtime.stopScanning()
    }

    private func waitUntil(
        _ condition: @escaping @MainActor () async -> Bool
    ) async {
        for _ in 0..<1_000 {
            if await condition() { return }
            await Task.yield()
        }
        Issue.record("Timed out waiting for asynchronous runtime work")
    }
}

@Suite("Scanner runtime migration")
@MainActor
struct ScannerRuntimeMigrationTests {
    @Test("changing the settings region while scanning restarts with the new override")
    func settingsRegionChangeRestartsRuntime() async {
        let suiteName = "ScannerRuntimeMigrationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("auto", forKey: "regulatoryRegionOverride")

        let source = ScriptedScanSource()
        let pipeline = RecordingCyclePipeline()
        let runtime = WiFiObservationRuntime(
            store: WiFiObservationStore(),
            pipeline: pipeline,
            scanSource: source
        )
        let scanner = ScannerViewModel(
            observationRuntime: runtime,
            userDefaults: defaults,
            authorizationRefresh: { _ in }
        )
        scanner.locationManager.authorizationStatus = .authorized
        scanner.userRegionOverride = .US
        let network = runtimeNetwork(bssid: "AA:13", channel: 36)

        await scanner.debugStartScanLoopForTesting()
        scanner.handleRegulatoryRegionOverrideChange("JP")
        await scanner.debugDrainRuntimeLifecycleForTesting()
        await source.yield(.networks([network]))
        await waitUntil { await pipeline.calls.count == 1 }

        #expect(await source.snapshot().requestedIntervals == [.seconds(3), .seconds(3)])
        #expect(await pipeline.calls.last?.context.userRegionOverride == .US)
        #expect(await pipeline.calls.last?.context.userDefaultsRegionOverride == .JP)
        #expect(scanner.inferredRegion?.domain == .US)
        #expect(scanner.scanIntervalSeconds == 3)
        #expect(scanner.lastNetworks.map(\.id) == [network.id])

        scanner.handleRegulatoryRegionOverrideChange("auto")
        await scanner.debugDrainRuntimeLifecycleForTesting()
        await source.yield(.networks([network]))
        await waitUntil { await pipeline.calls.count == 2 }

        #expect(await pipeline.calls.last?.context.userDefaultsRegionOverride == nil)
        #expect(scanner.scanIntervalSeconds == 3)
        #expect(scanner.lastNetworks.map(\.id) == [network.id])
        scanner.stop()
    }

    @Test("changing the interval while scanning restarts the runtime")
    func intervalChangeRestartsRuntime() async {
        let source = ScriptedScanSource()
        let runtime = WiFiObservationRuntime(
            store: WiFiObservationStore(),
            pipeline: RecordingCyclePipeline(),
            scanSource: source
        )
        let scanner = ScannerViewModel(observationRuntime: runtime, authorizationRefresh: { _ in })

        await scanner.debugStartScanLoopForTesting()
        scanner.scanIntervalSeconds = 1
        await waitUntil { await source.snapshot().requestedIntervals.count == 2 }

        #expect(await source.snapshot().requestedIntervals == [.seconds(3), .seconds(1)])
        scanner.stop()
    }

    @Test("Wi-Fi power off stops runtime scanning")
    func powerOffStopsRuntime() async {
        let source = ScriptedScanSource()
        let store = WiFiObservationStore()
        let consumer = CapturingObservationConsumer()
        let runtime = WiFiObservationRuntime(
            store: store,
            pipeline: RecordingCyclePipeline(),
            scanSource: source
        )
        runtime.addConsumer(consumer)
        let scanner = ScannerViewModel(observationRuntime: runtime, authorizationRefresh: { _ in })

        await scanner.debugStartScanLoopForTesting()
        scanner.debugReconcileWiFiStateForTesting(.poweredOff)
        await waitUntil { await source.snapshot().stopCalls == 1 }
        await source.yield(.networks([runtimeNetwork(bssid: "AA:0D", channel: 36)]))
        await runtime.drainConsumers()

        #expect(scanner.isScanning == false)
        #expect(await source.snapshot().activeStreamCount == 0)
        #expect(store.lastUpdated == nil)
        #expect(consumer.observations.isEmpty)
    }

    @Test("authorization loss on a runtime output stops scanning")
    func authorizationLossStopsRuntime() async {
        let source = ScriptedScanSource()
        let store = WiFiObservationStore()
        let consumer = CapturingObservationConsumer()
        let runtime = WiFiObservationRuntime(
            store: store,
            pipeline: RecordingCyclePipeline(),
            scanSource: source
        )
        runtime.addConsumer(consumer)
        let scanner = ScannerViewModel(observationRuntime: runtime, authorizationRefresh: { _ in })
        scanner.locationManager.authorizationStatus = .authorized

        await scanner.debugStartScanLoopForTesting()
        scanner.locationManager.authorizationStatus = .denied
        await source.yield(.networks([runtimeNetwork(bssid: "AA:03", channel: 36)]))
        await waitUntil { await source.snapshot().stopCalls == 1 }

        #expect(scanner.isScanning == false)
        #expect(scanner.accessState == .denied)
        #expect(store.lastUpdated == nil)
        #expect(consumer.observations.isEmpty)
    }

    @Test("runtime output projects networks, analysis, region, and interface context")
    func outputProjection() async {
        let source = ScriptedScanSource()
        let quality = runtimeQuality(channel: 36)
        var recommendation = ChannelRecommendation(from: quality)
        recommendation.scoreSelected = true
        let pipeline = ProjectionCyclePipeline(
            channelQualities: [quality],
            recommendations: [recommendation],
            inferredRegion: RegionInferenceResult(
                domain: .JP,
                confidence: .high,
                contributions: [],
                conflicts: []
            )
        )
        let runtime = WiFiObservationRuntime(
            store: WiFiObservationStore(),
            pipeline: pipeline,
            scanSource: source
        )
        let scanner = ScannerViewModel(observationRuntime: runtime, authorizationRefresh: { _ in })
        scanner.locationManager.authorizationStatus = .authorized
        let network = runtimeNetwork(bssid: "AA:04", channel: 36)

        await scanner.debugStartScanLoopForTesting()
        await source.yield(.networks([network]))
        await waitUntil { scanner.lastNetworks.map(\.id) == [network.id] }

        #expect(scanner.signalHistory.allHistory[network.bssid] == [-50])
        #expect(scanner.channelQualities.map(\.qualityScore) == [quality.qualityScore])
        #expect(scanner.channelRecommendations.map(\.channel) == [recommendation.channel])
        #expect(scanner.inferredRegion?.domain == .JP)
        #expect(scanner.interfaceName == "en7")
        #expect(scanner.supportedBands == Set([ChannelBand.band24GHz, ChannelBand.band5GHz]))
        #expect(scanner.band5.allSeriesData.map { $0.id } == [network.id])
        scanner.stop()
    }

    @Test("runtime outputs preserve filters and locked AP visibility")
    func outputPreservesPresentationState() async {
        let source = ScriptedScanSource()
        let runtime = WiFiObservationRuntime(
            store: WiFiObservationStore(),
            pipeline: RecordingCyclePipeline(),
            scanSource: source
        )
        let scanner = ScannerViewModel(observationRuntime: runtime, authorizationRefresh: { _ in })
        scanner.locationManager.authorizationStatus = .authorized
        let office = runtimeNetwork(ssid: "Office", bssid: "AA:05", channel: 36)
        let guest = runtimeNetwork(ssid: "Guest", bssid: "AA:06", channel: 40)

        await scanner.debugStartScanLoopForTesting()
        await source.yield(.networks([office, guest]))
        await waitUntil { scanner.lastNetworks.count == 2 }
        scanner.toggleVisibility(seriesID: office.id)
        scanner.toggleVisibilityLocked(seriesID: office.id)
        scanner.setFilterQuery("Guest", for: .primary)

        await source.yield(.networks([office, guest]))
        await waitUntil { scanner.signalHistory.allHistory[office.bssid]?.count == 2 }

        #expect(scanner.filterQuery(for: .primary) == "Guest")
        #expect(scanner.combinedTableRows.first(where: { $0.id == office.id })?.isVisible == false)
        #expect(scanner.combinedTableRows.first(where: { $0.id == office.id })?.visibilityLocked == true)
        #expect(scanner.bandViewModel(for: .primary, selection: .band5).visibleSeriesData().map { $0.id } == [guest.id])
        scanner.stop()
    }

    @Test("failed scan preserves the last valid presentation projection")
    func failedScanPreservesLastValidProjection() async {
        let source = ScriptedScanSource()
        let quality = runtimeQuality(channel: 36)
        let recommendation = ChannelRecommendation(from: quality)
        let region = RegionInferenceResult(
            domain: .JP,
            confidence: .high,
            contributions: [],
            conflicts: []
        )
        let pipeline = ErrorAwareProjectionCyclePipeline(
            channelQualities: [quality],
            recommendations: [recommendation],
            inferredRegion: region
        )
        let runtime = WiFiObservationRuntime(
            store: WiFiObservationStore(),
            pipeline: pipeline,
            scanSource: source
        )
        let scanner = ScannerViewModel(observationRuntime: runtime, authorizationRefresh: { _ in })
        scanner.locationManager.authorizationStatus = .authorized
        let network = runtimeNetwork(bssid: "AA:0E", channel: 36)

        await scanner.debugStartScanLoopForTesting()
        await source.yield(.networks([network]))
        await waitUntil { scanner.lastNetworks.map(\.id) == [network.id] }
        await source.yield(.failure("temporary scan failure"))
        await waitUntil { await pipeline.callCount == 2 }

        #expect(scanner.lastNetworks.map(\.id) == [network.id])
        #expect(scanner.channelQualities.map(\.channel) == [36])
        #expect(scanner.channelRecommendations.map(\.channel) == [36])
        #expect(scanner.inferredRegion?.domain == .JP)
        scanner.stop()
    }

    @Test("scanner lifecycle forwarding is drained in call order")
    func lifecycleForwardingIsOrdered() async {
        let source = ScriptedScanSource()
        let runtime = WiFiObservationRuntime(
            store: WiFiObservationStore(),
            pipeline: RecordingCyclePipeline(),
            scanSource: source
        )
        let scanner = ScannerViewModel(observationRuntime: runtime, authorizationRefresh: { _ in })

        await scanner.debugStartScanLoopForTesting()
        scanner.scanIntervalSeconds = 5
        scanner.scanIntervalSeconds = 7
        scanner.stop()
        await scanner.debugStartScanLoopForTesting()
        await scanner.debugDrainRuntimeLifecycleForTesting()

        let snapshot = await source.snapshot()
        #expect(snapshot.requestedIntervals.last == .seconds(7))
        #expect(snapshot.activeStreamCount == 1)
        #expect(scanner.isScanning)
        scanner.stop()
    }

    @Test("a suspended old cycle cannot publish across scanner stop and start")
    func suspendedOldCycleIsRejectedAcrossStopStart() async {
        let source = ScriptedScanSource()
        let pipeline = SuspendingFirstCyclePipeline()
        let store = WiFiObservationStore()
        let consumer = CapturingObservationConsumer()
        let runtime = WiFiObservationRuntime(store: store, pipeline: pipeline, scanSource: source)
        runtime.addConsumer(consumer)
        let scanner = ScannerViewModel(observationRuntime: runtime, authorizationRefresh: { _ in })
        scanner.locationManager.authorizationStatus = .authorized
        let oldNetwork = runtimeNetwork(bssid: "AA:11", channel: 36)
        let newNetwork = runtimeNetwork(bssid: "AA:12", channel: 40)

        await scanner.debugStartScanLoopForTesting()
        await source.yield(.networks([oldNetwork]))
        await pipeline.waitUntilFirstCycleEntered()

        scanner.stop()
        let freshStart = Task { @MainActor in
            await scanner.debugStartScanLoopForTesting()
        }
        await waitUntil { await source.snapshot().stopCalls == 1 }
        await pipeline.releaseFirstCycle()
        await freshStart.value
        await source.yield(.networks([newNetwork]))
        await waitUntil { scanner.lastNetworks.map(\.id) == [newNetwork.id] }
        await runtime.drainConsumers()

        #expect(store.currentStatus?.bssid == newNetwork.bssid)
        #expect(consumer.observations.map { $0.currentStatus?.bssid } == [newNetwork.bssid])
        #expect(scanner.lastNetworks.map(\.id) == [newNetwork.id])
        #expect(scanner.signalHistory.allHistory[oldNetwork.bssid] == nil)
        #expect(scanner.signalHistory.allHistory[newNetwork.bssid] == [-50])
        #expect(await pipeline.completedBSSIDs == [oldNetwork.bssid, newNetwork.bssid])
        scanner.stop()
    }

    private func waitUntil(
        _ condition: @escaping @MainActor () async -> Bool
    ) async {
        for _ in 0..<1_000 {
            if await condition() { return }
            await Task.yield()
        }
        Issue.record("Timed out waiting for Scanner runtime work")
    }
}

private extension WiFiObservationRuntimeConfiguration {
    static let testDefault = WiFiObservationRuntimeConfiguration(
        scanInterval: .seconds(3),
        userRegionOverride: nil,
        userDefaultsRegionOverride: nil
    )
}

private func runtimeNetwork(
    ssid: String = "Runtime test",
    bssid: String,
    channel: Int
) -> WiFiNetwork {
    WiFiNetwork(
        ssid: ssid,
        bssid: bssid,
        rssi: -50,
        channel: WiFiChannel(
            band: channel <= 14 ? .band24GHz : .band5GHz,
            channelNumber: channel
        )
    )
}

private func runtimeQuality(channel: Int) -> ChannelQuality {
    ChannelQuality(
        channel: channel,
        band: "5",
        bandDisplay: "5 GHz",
        qualityScore: 88,
        qualityLevel: .excellent,
        apCount: 1,
        coChannelCount: 0,
        adjacentCount: 0,
        interferenceScore: 12,
        overlapLevel: .low,
        strongestNeighborRSSI: -90,
        isCurrentChannel: true
    )
}

private actor ScriptedScanSource: WiFiScanStreaming {
    struct Snapshot: Sendable {
        let requestedIntervals: [Duration]
        let stopCalls: Int
        let activeStreamCount: Int
        let interfaceNameCalls: Int
        let supportedBandsCalls: Int
        let supportedChannelsCalls: Int
        let rawChannelsCalls: Int
        let deviceCapabilitiesCalls: Int
    }

    private var requestedIntervals: [Duration] = []
    private var stopCalls = 0
    private var continuations: [UUID: AsyncStream<WiFiScanEvent>.Continuation] = [:]
    private var interfaceNameCalls = 0
    private var supportedBandsCalls = 0
    private var supportedChannelsCalls = 0
    private var rawChannelsCalls = 0
    private var deviceCapabilitiesCalls = 0
    private var shouldSuspendCapabilityLookup = false
    private var capabilityLookupEntered = false
    private var capabilityLookupEnteredContinuation: CheckedContinuation<Void, Never>?
    private var capabilityLookupReleaseContinuation: CheckedContinuation<Void, Never>?
    private var hasCompletedStop = false
    private var stopCompletedContinuation: CheckedContinuation<Void, Never>?

    func startScanning(interval: Duration) async -> AsyncStream<WiFiScanEvent> {
        requestedIntervals.append(interval)
        let id = UUID()
        let pair = AsyncStream<WiFiScanEvent>.makeStream()
        pair.continuation.onTermination = { [weak self] _ in
            Task { await self?.removeContinuation(id) }
        }
        continuations[id] = pair.continuation
        return pair.stream
    }

    func stopScanning() async {
        stopCalls += 1
        let active = continuations.values
        continuations.removeAll()
        for continuation in active { continuation.finish() }
        hasCompletedStop = true
        stopCompletedContinuation?.resume()
        stopCompletedContinuation = nil
    }

    func waitUntilStopCompleted() async {
        guard !hasCompletedStop else { return }
        await withCheckedContinuation { continuation in
            stopCompletedContinuation = continuation
        }
    }

    func interfaceName() async -> String? {
        interfaceNameCalls += 1
        if shouldSuspendCapabilityLookup {
            shouldSuspendCapabilityLookup = false
            capabilityLookupEntered = true
            capabilityLookupEnteredContinuation?.resume()
            capabilityLookupEnteredContinuation = nil
            await withCheckedContinuation { continuation in
                capabilityLookupReleaseContinuation = continuation
            }
        }
        return "en7"
    }

    func supportedBands() async -> Set<ChannelBand> {
        supportedBandsCalls += 1
        return [.band24GHz, .band5GHz]
    }

    func supportedChannels() async -> [(ChannelBand, Int)] {
        supportedChannelsCalls += 1
        return [(.band24GHz, 1), (.band5GHz, 36)]
    }

    func supportedWLANChannelsRaw() async -> [(Int, Int)] {
        rawChannelsCalls += 1
        return [(1, 1), (2, 36)]
    }

    func devicePHYCapabilities() async -> DevicePHYCapabilities {
        deviceCapabilitiesCalls += 1
        return .default
    }

    func yield(_ event: WiFiScanEvent) {
        for continuation in continuations.values { continuation.yield(event) }
    }

    func suspendNextCapabilityLookup() {
        shouldSuspendCapabilityLookup = true
        capabilityLookupEntered = false
    }

    func waitUntilCapabilityLookupEntered() async {
        guard !capabilityLookupEntered else { return }
        await withCheckedContinuation { continuation in
            capabilityLookupEnteredContinuation = continuation
        }
    }

    func releaseCapabilityLookup() {
        capabilityLookupReleaseContinuation?.resume()
        capabilityLookupReleaseContinuation = nil
    }

    func snapshot() -> Snapshot {
        Snapshot(
            requestedIntervals: requestedIntervals,
            stopCalls: stopCalls,
            activeStreamCount: continuations.count,
            interfaceNameCalls: interfaceNameCalls,
            supportedBandsCalls: supportedBandsCalls,
            supportedChannelsCalls: supportedChannelsCalls,
            rawChannelsCalls: rawChannelsCalls,
            deviceCapabilitiesCalls: deviceCapabilitiesCalls
        )
    }

    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
    }
}

private actor RecordingCyclePipeline: WiFiObservationPipelining {
    struct Call: Sendable {
        let networks: [WiFiNetwork]
        let context: WiFiObservationCycleContext
    }

    private(set) var calls: [Call] = []
    private let currentStatus: WiFiCurrentStatus

    init(currentStatus: WiFiCurrentStatus = WiFiCurrentStatus(
        timestamp: Date(timeIntervalSince1970: 1),
        isConnected: false,
        isWiFiPowerOn: true
    )) {
        self.currentStatus = currentStatus
    }

    func produceCycle(
        networks: [WiFiNetwork],
        context: WiFiObservationCycleContext
    ) async -> WiFiObservationCycleResult {
        calls.append(Call(networks: networks, context: context))
        let error = context.environmentError
        return WiFiObservationCycleResult(
            observation: WiFiObservation(
                timestamp: context.timestamp,
                currentStatus: currentStatus,
                environmentSnapshot: WiFiEnvironmentSnapshot(
                    timestamp: context.timestamp,
                    interfaceName: context.interfaceName,
                    networks: [],
                    error: error
                ),
                errors: [error].compactMap { $0 }
            ),
            inferredRegion: RegulatoryDomainResolver.resolve(
                userOverride: context.userRegionOverride,
                userDefaultsOverride: context.userDefaultsRegionOverride,
                supportedChannelsRaw: context.supportedChannelsRaw,
                apCountryCodes: []
            )
        )
    }

}

private actor ProjectionCyclePipeline: WiFiObservationPipelining {
    let channelQualities: [ChannelQuality]
    let recommendations: [ChannelRecommendation]
    let inferredRegion: RegionInferenceResult

    init(
        channelQualities: [ChannelQuality],
        recommendations: [ChannelRecommendation],
        inferredRegion: RegionInferenceResult
    ) {
        self.channelQualities = channelQualities
        self.recommendations = recommendations
        self.inferredRegion = inferredRegion
    }

    func produceCycle(
        networks: [WiFiNetwork],
        context: WiFiObservationCycleContext
    ) async -> WiFiObservationCycleResult {
        WiFiObservationCycleResult(
            observation: WiFiObservation(
                timestamp: context.timestamp,
                channelAnalysis: channelQualities,
                channelRecommendation: recommendations
            ),
            inferredRegion: inferredRegion
        )
    }

}

private actor ErrorAwareProjectionCyclePipeline: WiFiObservationPipelining {
    let channelQualities: [ChannelQuality]
    let recommendations: [ChannelRecommendation]
    let inferredRegion: RegionInferenceResult
    private(set) var callCount = 0

    init(
        channelQualities: [ChannelQuality],
        recommendations: [ChannelRecommendation],
        inferredRegion: RegionInferenceResult
    ) {
        self.channelQualities = channelQualities
        self.recommendations = recommendations
        self.inferredRegion = inferredRegion
    }

    func produceCycle(
        networks: [WiFiNetwork],
        context: WiFiObservationCycleContext
    ) async -> WiFiObservationCycleResult {
        callCount += 1
        let error = context.environmentError
        return WiFiObservationCycleResult(
            observation: WiFiObservation(
                timestamp: context.timestamp,
                environmentSnapshot: WiFiEnvironmentSnapshot(
                    timestamp: context.timestamp,
                    interfaceName: context.interfaceName,
                    networks: [],
                    error: error
                ),
                channelAnalysis: error == nil ? channelQualities : nil,
                channelRecommendation: error == nil ? recommendations : nil,
                errors: [error].compactMap { $0 }
            ),
            inferredRegion: inferredRegion
        )
    }

}

private actor SuspendingFirstCyclePipeline: WiFiObservationPipelining {
    private var callCount = 0
    private var firstCycleEntered = false
    private var enteredContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?
    private(set) var completedBSSIDs: [String] = []

    func produceCycle(
        networks: [WiFiNetwork],
        context: WiFiObservationCycleContext
    ) async -> WiFiObservationCycleResult {
        callCount += 1
        if callCount == 1 {
            firstCycleEntered = true
            enteredContinuation?.resume()
            enteredContinuation = nil
            await withCheckedContinuation { continuation in
                releaseContinuation = continuation
            }
        }

        let bssid = networks.first?.bssid
        if let bssid { completedBSSIDs.append(bssid) }
        return WiFiObservationCycleResult(
            observation: WiFiObservation(
                timestamp: context.timestamp,
                currentStatus: WiFiCurrentStatus(
                    timestamp: context.timestamp,
                    bssid: bssid,
                    isConnected: bssid != nil,
                    isWiFiPowerOn: true
                ),
                environmentSnapshot: WiFiEnvironmentSnapshot(
                    timestamp: context.timestamp,
                    interfaceName: context.interfaceName,
                    networks: []
                )
            ),
            inferredRegion: RegulatoryDomainResolver.resolve(
                userOverride: nil,
                userDefaultsOverride: nil,
                supportedChannelsRaw: context.supportedChannelsRaw,
                apCountryCodes: []
            )
        )
    }

    func waitUntilFirstCycleEntered() async {
        guard !firstCycleEntered else { return }
        await withCheckedContinuation { continuation in
            enteredContinuation = continuation
        }
    }

    func releaseFirstCycle() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }

}

@MainActor
private final class CapturingObservationConsumer: WiFiObservationConsuming {
    private(set) var observations: [WiFiObservation] = []

    func consume(_ observation: WiFiObservation) async throws {
        observations.append(observation)
    }
}

@MainActor
private final class SuspendedObservationConsumer: WiFiObservationConsuming {
    private var enteredContinuation: CheckedContinuation<Void, Never>?
    private var suspensionContinuation: CheckedContinuation<Void, Never>?
    private var hasEntered = false
    private(set) var isSuspended = false
    private(set) var observations: [WiFiObservation] = []

    func consume(_ observation: WiFiObservation) async throws {
        observations.append(observation)
        hasEntered = true
        enteredContinuation?.resume()
        enteredContinuation = nil
        isSuspended = true
        await withCheckedContinuation { continuation in
            suspensionContinuation = continuation
        }
        isSuspended = false
    }

    func waitUntilEntered() async {
        guard !hasEntered else { return }
        await withCheckedContinuation { continuation in
            enteredContinuation = continuation
        }
    }

    func resume() {
        suspensionContinuation?.resume()
        suspensionContinuation = nil
    }
}

private actor AsyncCompletionProbe {
    private(set) var isCompleted = false

    func markCompleted() {
        isCompleted = true
    }
}

@MainActor
private final class MainActorMilestone {
    private var isReached = false
    private var continuation: CheckedContinuation<Void, Never>?

    func reach() {
        isReached = true
        continuation?.resume()
        continuation = nil
    }

    func waitUntilReached() async {
        guard !isReached else { return }
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }
}

@MainActor
private final class FailOnceObservationConsumer: WiFiObservationConsuming {
    private enum TestError: Error {
        case expectedFailure
    }

    private(set) var attemptedTimestamps: [Date] = []
    private var shouldFail = true

    func consume(_ observation: WiFiObservation) async throws {
        attemptedTimestamps.append(observation.timestamp)
        if shouldFail {
            shouldFail = false
            throw TestError.expectedFailure
        }
    }
}
