import Foundation
import Testing
@testable import WiFi_Lens

@Suite @MainActor struct SignalHistoryStoreTests {

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
}
