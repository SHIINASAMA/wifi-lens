import Foundation
import Testing
@testable import WiFi_Lens

@Suite @MainActor struct SignalHistoryStoreTests {

    private func makeSnapshot(timestamp: Date) -> NetworkSnapshot {
        NetworkSnapshot(
            timestamp: timestamp,
            bssid: "aa:bb:cc:dd:ee:01",
            ssid: "TestNet",
            rssi: -50,
            channel: 6,
            band: "24",
            phyMode: "ax",
            channelWidth: "20",
            mcs: "",
            nss: "",
            security: "",
            country: "",
            supportsK: false,
            supportsR: false,
            supportsV: false,
            supportsWPA3: false,
            isHiddenSSID: false
        )
    }

    @Test func scanTimelineDeduplicatesSnapshotsFromOneCycle() {
        let store = SignalHistoryStore(maxCount: 20)
        let timestamp = Date(timeIntervalSince1970: 100)
        store.recordScan(timestamp: timestamp)
        store.recordScan(timestamp: timestamp)
        #expect(store.allScanTimestamps == [timestamp])
    }

    @Test func scanTimelineKeepsNewestTwentyCycles() {
        let store = SignalHistoryStore(maxCount: 20)
        for offset in 0..<21 {
            store.recordScan(timestamp: Date(timeIntervalSince1970: Double(offset)))
        }
        #expect(store.allScanTimestamps.count == 20)
        #expect(store.allScanTimestamps.first == Date(timeIntervalSince1970: 1))
    }

    @Test func scanTimelineRemovesFramesOutsideWallClockWindow() {
        let store = SignalHistoryStore(maxCount: 20, scanWindow: 60)
        let t100 = Date(timeIntervalSince1970: 100)
        let t140 = Date(timeIntervalSince1970: 140)
        let t161 = Date(timeIntervalSince1970: 161)

        store.recordScan(timestamp: t100)
        store.recordScan(timestamp: t140)
        store.recordScan(timestamp: t161)

        #expect(store.allScanTimestamps == [t140, t161])
    }

    @Test func recordingSnapshotDoesNotCreateAnotherScanCycle() {
        let store = SignalHistoryStore(maxCount: 20)
        let timestamp = Date(timeIntervalSince1970: 100)

        store.record(
            bssid: "aa:bb:cc:dd:ee:01",
            rssi: -50,
            snapshot: makeSnapshot(timestamp: timestamp)
        )

        #expect(store.allScanTimestamps.isEmpty)
    }
}
