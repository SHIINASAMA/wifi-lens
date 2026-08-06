import Foundation
import Testing
@testable import WiFi_Lens

@MainActor
private final class FakeAudioPlayer: APRadarAudioPlaying {
    var prepareShouldThrow = false
    var playResult = true
    private(set) var prepareCallCount = 0
    private(set) var playCallCount = 0
    private(set) var stopCallCount = 0

    func prepare() throws {
        prepareCallCount += 1
        if prepareShouldThrow {
            throw APRadarAudioError.resourceNotFound
        }
    }

    @discardableResult
    func playPulse() -> Bool {
        playCallCount += 1
        return playResult
    }

    func stop() {
        stopCallCount += 1
    }
}

@MainActor
private final class FakePulseScheduler: APRadarPulseScheduling {
    private(set) var startCount = 0
    private(set) var cancelCount = 0
    private(set) var activeOverride = false

    var isActive: Bool { activeOverride }

    func start(
        shouldContinue: @escaping @MainActor () -> Bool,
        intervalProvider: @escaping @MainActor () -> Duration,
        playPulse: @escaping @MainActor () -> Void
    ) {
        startCount += 1
    }

    func cancel() {
        cancelCount += 1
        activeOverride = false
    }
}

@Suite("APRadarViewModel")
@MainActor
struct APRadarViewModelTests {

    // MARK: - Helpers

    private func makeDefaults() -> UserDefaults {
        let suite = "APRadarViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private func makeHarness(
        audio: FakeAudioPlayer = FakeAudioPlayer(),
        scheduler: FakePulseScheduler = FakePulseScheduler(),
        defaults: UserDefaults? = nil
    ) -> (viewModel: APRadarViewModel, runtime: WiFiObservationRuntime, audio: FakeAudioPlayer, scheduler: FakePulseScheduler) {
        let runtime = WiFiObservationRuntime(store: WiFiObservationStore())
        let vm = APRadarViewModel(
            observationRuntime: runtime,
            audioPlayer: audio,
            scheduler: scheduler,
            userDefaults: defaults ?? makeDefaults()
        )
        return (vm, runtime, audio, scheduler)
    }

    private func makeNetwork(
        ssid: String? = "Home Wi-Fi",
        bssid: String,
        rssi: Int,
        channel: Int = 36,
        band: ChannelBand = .band5GHz
    ) -> WiFiNetworkObservation {
        WiFiNetworkObservation(
            ssid: ssid,
            bssid: bssid,
            rssi: rssi,
            channel: WiFiChannel(band: band, channelNumber: channel, channelWidthMHz: 20)
        )
    }

    private func makeObservation(
        timestamp: Date,
        networks: [WiFiNetworkObservation] = [],
        error: WiFiObservationError? = nil
    ) -> WiFiObservation {
        WiFiObservation(
            timestamp: timestamp,
            environmentSnapshot: WiFiEnvironmentSnapshot(
                timestamp: timestamp,
                interfaceName: nil,
                networks: networks,
                scanDurationMs: nil,
                error: error
            ),
            errors: error.map { [$0] } ?? []
        )
    }

    private func activateAndSelect(
        _ vm: APRadarViewModel,
        bssid: String = "AA:BB:CC:DD:EE:FF",
        ssid: String? = "Home Wi-Fi",
        rssi: Int = -55
    ) {
        vm.setActive(true)
        let option = APRadarAPOption(observation: makeNetwork(ssid: ssid, bssid: bssid, rssi: rssi))
        vm.selectTarget(option)
    }

    private func trackingSnapshot(_ vm: APRadarViewModel) -> APRadarSnapshot? {
        guard case .tracking(let snapshot) = vm.state else { return nil }
        return snapshot
    }

    private func lostSnapshot(_ vm: APRadarViewModel) -> APRadarLostSnapshot? {
        guard case .signalLost(let snapshot) = vm.state else { return nil }
        return snapshot
    }

    // MARK: - Target selection

    @Test("selecting an AP enters tracking with the chosen BSSID")
    func selectEntersTracking() async throws {
        let harness = makeHarness()
        activateAndSelect(harness.viewModel)

        let snapshot = trackingSnapshot(harness.viewModel)
        #expect(snapshot != nil)
        #expect(snapshot?.target.bssid == "AA:BB:CC:DD:EE:FF")
        #expect(snapshot?.target.currentSSID == "Home Wi-Fi")
        #expect(snapshot?.smoothedRSSI == nil)

        // First valid sample initializes the smoother.
        let t0 = Date(timeIntervalSince1970: 100)
        try await harness.viewModel.consume(
            makeObservation(timestamp: t0, networks: [makeNetwork(bssid: "aa:bb:cc:dd:ee:ff", rssi: -54)])
        )
        let updated = trackingSnapshot(harness.viewModel)
        #expect(updated?.rawRSSI == -54)
        #expect(updated?.smoothedRSSI == -54)
    }

    @Test("matching is BSSID-based and case/whitespace insensitive")
    func matchingNormalizesBSSID() async throws {
        let harness = makeHarness()
        activateAndSelect(harness.viewModel, bssid: "AA:BB:CC:DD:EE:FF")
        let t0 = Date(timeIntervalSince1970: 100)

        try await harness.viewModel.consume(
            makeObservation(timestamp: t0, networks: [makeNetwork(bssid: " aa:bb:cc:dd:ee:ff ", rssi: -48)])
        )
        #expect(trackingSnapshot(harness.viewModel)?.rawRSSI == -48)
    }

    @Test("invalid RSSI samples are ignored and do not update state")
    func invalidRSSIIsIgnored() async throws {
        let harness = makeHarness()
        activateAndSelect(harness.viewModel)
        let t0 = Date(timeIntervalSince1970: 100)

        try await harness.viewModel.consume(
            makeObservation(timestamp: t0, networks: [makeNetwork(bssid: "AA:BB:CC:DD:EE:FF", rssi: -60)])
        )
        try await harness.viewModel.consume(
            makeObservation(timestamp: t0.addingTimeInterval(1), networks: [makeNetwork(bssid: "AA:BB:CC:DD:EE:FF", rssi: 5)])
        )
        let snapshot = trackingSnapshot(harness.viewModel)
        #expect(snapshot?.rawRSSI == -60)
        #expect(snapshot?.smoothedRSSI == -60)
        #expect(snapshot?.lastSeenAt == t0)
    }

    // MARK: - Signal lost

    @Test("missing target past the timeout enters signal lost and stops sound")
    func signalLostStopsSound() async throws {
        let harness = makeHarness()
        activateAndSelect(harness.viewModel)
        let t0 = Date(timeIntervalSince1970: 100)

        try await harness.viewModel.consume(
            makeObservation(timestamp: t0, networks: [makeNetwork(bssid: "AA:BB:CC:DD:EE:FF", rssi: -60)])
        )
        let cancelsBefore = harness.scheduler.cancelCount

        // 9 seconds later with no target: 9 >= 8s default timeout.
        try await harness.viewModel.consume(makeObservation(timestamp: t0.addingTimeInterval(9)))
        #expect(lostSnapshot(harness.viewModel) != nil)
        #expect(harness.scheduler.cancelCount > cancelsBefore)
        #expect(harness.audio.stopCallCount >= 1)
        #expect(harness.viewModel.state.isTracking == false)
    }

    @Test("lifecycle scan interval extends the loss timeout to max(8s, 2.5x)")
    func lifecycleExtendsLossTimeout() async throws {
        let harness = makeHarness()
        activateAndSelect(harness.viewModel)
        let t0 = Date(timeIntervalSince1970: 100)

        try await harness.viewModel.consumeLifecycle(.started(at: t0, expectedInterval: .seconds(4)))
        try await harness.viewModel.consume(
            makeObservation(timestamp: t0, networks: [makeNetwork(bssid: "AA:BB:CC:DD:EE:FF", rssi: -60)])
        )

        // 9s < 10s timeout from a 4s scan interval: still tracking.
        try await harness.viewModel.consume(makeObservation(timestamp: t0.addingTimeInterval(9)))
        #expect(harness.viewModel.state.isTracking)
        #expect(lostSnapshot(harness.viewModel) == nil)

        try await harness.viewModel.consume(makeObservation(timestamp: t0.addingTimeInterval(10)))
        #expect(lostSnapshot(harness.viewModel) != nil)
    }

    @Test("same BSSID reappearing restores tracking automatically")
    func sameBSSIDRestoresTracking() async throws {
        let harness = makeHarness()
        activateAndSelect(harness.viewModel)
        let t0 = Date(timeIntervalSince1970: 100)

        try await harness.viewModel.consume(
            makeObservation(timestamp: t0, networks: [makeNetwork(bssid: "AA:BB:CC:DD:EE:FF", rssi: -60)])
        )
        try await harness.viewModel.consume(makeObservation(timestamp: t0.addingTimeInterval(9)))
        #expect(lostSnapshot(harness.viewModel) != nil)

        let t1 = t0.addingTimeInterval(10)
        try await harness.viewModel.consume(
            makeObservation(timestamp: t1, networks: [makeNetwork(bssid: "AA:BB:CC:DD:EE:FF", rssi: -55)])
        )
        let snapshot = trackingSnapshot(harness.viewModel)
        #expect(snapshot != nil)
        #expect(snapshot?.rawRSSI == -55)
        #expect(snapshot?.lastSeenAt == t1)
    }

    @Test("a different BSSID with the same SSID cannot restore tracking")
    func differentBSSIDSameSSIDDoesNotRestore() async throws {
        let harness = makeHarness()
        activateAndSelect(harness.viewModel, bssid: "AA:BB:CC:DD:EE:FF", ssid: "Shared SSID")
        let t0 = Date(timeIntervalSince1970: 100)

        try await harness.viewModel.consume(
            makeObservation(timestamp: t0, networks: [makeNetwork(ssid: "Shared SSID", bssid: "AA:BB:CC:DD:EE:FF", rssi: -60)])
        )
        try await harness.viewModel.consume(makeObservation(timestamp: t0.addingTimeInterval(9)))
        #expect(lostSnapshot(harness.viewModel) != nil)

        // Another AP with the same SSID appears; the target BSSID is still absent.
        try await harness.viewModel.consume(
            makeObservation(timestamp: t0.addingTimeInterval(10), networks: [
                makeNetwork(ssid: "Shared SSID", bssid: "11:22:33:44:55:66", rssi: -40)
            ])
        )
        #expect(lostSnapshot(harness.viewModel) != nil)
    }

    @Test("recovery after a long loss resets the smoother")
    func longLossResetsSmoother() async throws {
        let harness = makeHarness()
        activateAndSelect(harness.viewModel)
        let t0 = Date(timeIntervalSince1970: 100)

        try await harness.viewModel.consume(
            makeObservation(timestamp: t0, networks: [makeNetwork(bssid: "AA:BB:CC:DD:EE:FF", rssi: -60)])
        )
        try await harness.viewModel.consume(
            makeObservation(timestamp: t0.addingTimeInterval(1), networks: [makeNetwork(bssid: "AA:BB:CC:DD:EE:FF", rssi: -50)])
        )
        try await harness.viewModel.consume(makeObservation(timestamp: t0.addingTimeInterval(9)))
        #expect(lostSnapshot(harness.viewModel) != nil)

        // 16 seconds after loss (> 15s): the first new sample is the baseline.
        try await harness.viewModel.consume(
            makeObservation(timestamp: t0.addingTimeInterval(25), networks: [makeNetwork(bssid: "AA:BB:CC:DD:EE:FF", rssi: -80)])
        )
        #expect(trackingSnapshot(harness.viewModel)?.smoothedRSSI == -80)
    }

    @Test("recovery after a short loss keeps the smoother state")
    func shortLossKeepsSmoother() async throws {
        let harness = makeHarness()
        activateAndSelect(harness.viewModel)
        let t0 = Date(timeIntervalSince1970: 100)

        try await harness.viewModel.consume(
            makeObservation(timestamp: t0, networks: [makeNetwork(bssid: "AA:BB:CC:DD:EE:FF", rssi: -60)])
        )
        try await harness.viewModel.consume(
            makeObservation(timestamp: t0.addingTimeInterval(1), networks: [makeNetwork(bssid: "AA:BB:CC:DD:EE:FF", rssi: -50)])
        )
        try await harness.viewModel.consume(makeObservation(timestamp: t0.addingTimeInterval(9)))
        #expect(lostSnapshot(harness.viewModel) != nil)

        // 1 second after loss (< 15s): EMA continues from -57.
        try await harness.viewModel.consume(
            makeObservation(timestamp: t0.addingTimeInterval(10), networks: [makeNetwork(bssid: "AA:BB:CC:DD:EE:FF", rssi: -80)])
        )
        let smoothed = trackingSnapshot(harness.viewModel)?.smoothedRSSI ?? .nan
        #expect(abs(smoothed - (-63.9)) < 0.0001)
    }

    // MARK: - Sound

    @Test("sound off prevents all audio and scheduler activity")
    func soundOffPreventsAudio() async throws {
        let defaults = makeDefaults()
        defaults.set(false, forKey: APRadarViewModel.soundEnabledKey)
        let harness = makeHarness(defaults: defaults)
        #expect(harness.viewModel.soundEnabled == false)

        activateAndSelect(harness.viewModel)
        try await harness.viewModel.consume(
            makeObservation(timestamp: Date(timeIntervalSince1970: 100), networks: [makeNetwork(bssid: "AA:BB:CC:DD:EE:FF", rssi: -54)])
        )

        #expect(harness.viewModel.state.isTracking)
        #expect(harness.audio.playCallCount == 0)
        #expect(harness.audio.prepareCallCount == 0)
        #expect(harness.scheduler.startCount == 0)
    }

    @Test("re-enabling sound resumes audio after a valid sample")
    func reEnablingSoundResumes() async throws {
        let defaults = makeDefaults()
        defaults.set(false, forKey: APRadarViewModel.soundEnabledKey)
        let harness = makeHarness(defaults: defaults)

        activateAndSelect(harness.viewModel)
        try await harness.viewModel.consume(
            makeObservation(timestamp: Date(timeIntervalSince1970: 100), networks: [makeNetwork(bssid: "AA:BB:CC:DD:EE:FF", rssi: -54)])
        )
        #expect(harness.scheduler.startCount == 0)

        harness.viewModel.setSoundEnabled(true)
        #expect(harness.viewModel.soundEnabled == true)
        #expect(harness.audio.prepareCallCount >= 1)
        #expect(harness.scheduler.startCount == 1)
    }

    @Test("turning sound off cancels the active pulse scheduler")
    func turningSoundOffCancelsScheduler() async throws {
        let harness = makeHarness()
        activateAndSelect(harness.viewModel)
        try await harness.viewModel.consume(
            makeObservation(timestamp: Date(timeIntervalSince1970: 100), networks: [makeNetwork(bssid: "AA:BB:CC:DD:EE:FF", rssi: -54)])
        )
        #expect(harness.scheduler.startCount == 1)

        harness.viewModel.setSoundEnabled(false)
        #expect(harness.scheduler.cancelCount >= 1)
        #expect(harness.audio.stopCallCount >= 1)
    }

    @Test("audio initialization failure does not terminate RSSI tracking")
    func audioFailureKeepsTracking() async throws {
        let audio = FakeAudioPlayer()
        audio.prepareShouldThrow = true
        let harness = makeHarness(audio: audio)

        activateAndSelect(harness.viewModel)
        let t0 = Date(timeIntervalSince1970: 100)
        try await harness.viewModel.consume(
            makeObservation(timestamp: t0, networks: [makeNetwork(bssid: "AA:BB:CC:DD:EE:FF", rssi: -54)])
        )

        #expect(harness.viewModel.audioAvailable == false)
        #expect(harness.viewModel.audioErrorMessage != nil)
        #expect(harness.scheduler.startCount == 0)
        #expect(trackingSnapshot(harness.viewModel)?.smoothedRSSI == -54)

        // Tracking continues and updates with later samples.
        try await harness.viewModel.consume(
            makeObservation(timestamp: t0.addingTimeInterval(1), networks: [makeNetwork(bssid: "AA:BB:CC:DD:EE:FF", rssi: -60)])
        )
        let smoothed = trackingSnapshot(harness.viewModel)?.smoothedRSSI ?? .nan
        #expect(abs(smoothed - (-55.8)) < 0.0001)
        // The failure is reported only once.
        #expect(harness.audio.prepareCallCount >= 1)
    }

    // MARK: - Lifecycle

    @Test("stop tracking cancels the scheduler and returns to idle")
    func stopTrackingCancelsScheduler() async throws {
        let harness = makeHarness()
        activateAndSelect(harness.viewModel)
        try await harness.viewModel.consume(
            makeObservation(timestamp: Date(timeIntervalSince1970: 100), networks: [makeNetwork(bssid: "AA:BB:CC:DD:EE:FF", rssi: -54)])
        )
        #expect(harness.scheduler.startCount == 1)

        harness.viewModel.stopTracking()

        #expect(harness.viewModel.state == .idle)
        #expect(harness.scheduler.cancelCount >= 1)
        #expect(harness.audio.stopCallCount >= 1)
        #expect(trackingSnapshot(harness.viewModel) == nil)
    }

    @Test("leaving the page cancels scheduling and releases the scan subscription")
    func leavingPageReleasesSubscription() async throws {
        let harness = makeHarness()
        activateAndSelect(harness.viewModel)
        try await harness.viewModel.consume(
            makeObservation(timestamp: Date(timeIntervalSince1970: 100), networks: [makeNetwork(bssid: "AA:BB:CC:DD:EE:FF", rssi: -54)])
        )

        #expect(harness.runtime.diagnostics().count == 1)
        let cancelsAfterStart = harness.scheduler.cancelCount

        harness.viewModel.setActive(false)
        #expect(harness.runtime.diagnostics().count == 0)
        #expect(harness.scheduler.cancelCount > cancelsAfterStart)
        #expect(harness.audio.stopCallCount >= 1)
    }

    @Test("repeated page visits do not stack scan subscriptions")
    func repeatedVisitsDoNotStackSubscriptions() {
        let harness = makeHarness()
        for _ in 0..<10 {
            harness.viewModel.setActive(true)
            #expect(harness.runtime.diagnostics().count == 1)
            harness.viewModel.setActive(false)
            #expect(harness.runtime.diagnostics().count == 0)
        }
    }

    @Test("returning to the page starts from the idle state")
    func returningStartsIdle() async throws {
        let harness = makeHarness()
        activateAndSelect(harness.viewModel)
        try await harness.viewModel.consume(
            makeObservation(timestamp: Date(timeIntervalSince1970: 100), networks: [makeNetwork(bssid: "AA:BB:CC:DD:EE:FF", rssi: -54)])
        )

        harness.viewModel.setActive(false)
        harness.viewModel.setActive(true)

        #expect(harness.viewModel.state == .idle)
        #expect(trackingSnapshot(harness.viewModel) == nil)
    }

    @Test("suspend stops sound and scheduling while preserving the target")
    func suspendPreservesTarget() async throws {
        let harness = makeHarness()
        activateAndSelect(harness.viewModel)
        try await harness.viewModel.consume(
            makeObservation(timestamp: Date(timeIntervalSince1970: 100), networks: [makeNetwork(bssid: "AA:BB:CC:DD:EE:FF", rssi: -54)])
        )

        harness.viewModel.handleAppInactive()

        #expect(harness.scheduler.cancelCount >= 1)
        #expect(harness.audio.stopCallCount >= 1)
        // Target is preserved, so a fresh sample resumes the session.
        try await harness.viewModel.consume(
            makeObservation(timestamp: Date(timeIntervalSince1970: 101), networks: [makeNetwork(bssid: "AA:BB:CC:DD:EE:FF", rssi: -50)])
        )
        #expect(trackingSnapshot(harness.viewModel) != nil)
    }
}
