import Testing
import SwiftUI
@testable import WiFiLens

struct NetworkTableRowTests {

    private let defaultRow = NetworkTableRow(
        id: "aa:bb:cc:dd:ee:ff-6-1",
        bandLabel: "5 GHz",
        channel: 44,
        rssi: -50,
        ssid: "TestWiFi",
        bssid: "aa:bb:cc:dd:ee:ff",
        color: .blue,
        isFilteredOut: false,
        phyMode: "ax",
        channelWidth: "80",
        supportsK: true,
        supportsR: false,
        supportsV: true,
        isHiddenSSID: false,
        security: "WPA3",
        mcs: "9",
        nss: "2",
        country: "US",
        trendArrow: "▲",
        trendDelta: 3,
        isVisible: true,
        qualityScore: 80
    )

    private func row(_ update: (inout NetworkTableRow) -> Void) -> NetworkTableRow {
        var row = defaultRow
        update(&row)
        return row
    }

    // MARK: - Equality

    @Test func identicalRowsAreEqual() async throws {
        let a = defaultRow
        let b = defaultRow
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test func differentRSSINotEqual() async throws {
        let a = row { $0.rssi = -50 }
        let b = row { $0.rssi = -60 }
        #expect(a != b)
    }

    @Test func differentSSIDNotEqual() async throws {
        let a = row { $0.ssid = "WiFi-A" }
        let b = row { $0.ssid = "WiFi-B" }
        #expect(a != b)
    }

    @Test func differentQualityScoreNotEqual() async throws {
        let a = row { $0.qualityScore = 80 }
        let b = row { $0.qualityScore = 60 }
        #expect(a != b)
    }

    @Test func differentPhyModeNotEqual() async throws {
        let a = row { $0.phyMode = "ax" }
        let b = row { $0.phyMode = "ac" }
        #expect(a != b)
    }

    @Test func differentVisibilityNotEqual() async throws {
        let a = row { $0.isVisible = true }
        let b = row { $0.isVisible = false }
        #expect(a != b)
    }

    @Test func differentFilterNotEqual() async throws {
        let a = row { $0.isFilteredOut = false }
        let b = row { $0.isFilteredOut = true }
        #expect(a != b)
    }

    @Test func differentChannelWidthNotEqual() async throws {
        let a = row { $0.channelWidth = "80" }
        let b = row { $0.channelWidth = "160" }
        #expect(a != b)
    }

    @Test func differentSecurityNotEqual() async throws {
        let a = row { $0.security = "WPA3" }
        let b = row { $0.security = "WPA2" }
        #expect(a != b)
    }

    @Test func differentMCSNotEqual() async throws {
        let a = row { $0.mcs = "9" }
        let b = row { $0.mcs = "7" }
        #expect(a != b)
    }

    @Test func differentHiddenSSIDNotEqual() async throws {
        let a = row { $0.isHiddenSSID = false }
        let b = row { $0.isHiddenSSID = true }
        #expect(a != b)
    }

    // MARK: - Array comparison (the pattern used in NativeTableView)

    @Test func arrayOfRowsDetectsSingleChange() async throws {
        let rows1 = [row {
            $0.id = "id1"
            $0.rssi = -50
        }, row {
            $0.id = "id2"
            $0.rssi = -60
        }]
        let rows2 = [row {
            $0.id = "id1"
            $0.rssi = -50
        }, row {
            $0.id = "id2"
            $0.rssi = -55
        }] // rssi changed
        #expect(rows1 != rows2)
    }

    @Test func arrayOfRowsDetectsNoChange() async throws {
        let rows1 = [defaultRow, defaultRow]
        let rows2 = [defaultRow, defaultRow]
        #expect(rows1 == rows2)
    }
}
