import Testing
import AppKit
@testable import WiFi_Lens

@MainActor
struct NetworkTableRowSorterTests {
    private func row(_ id: String, rssi: Int, ssid: String) -> NetworkTableRow {
        NetworkTableRow(
            id: id,
            bandID: "5",
            bandLabel: "5 GHz",
            channel: 44,
            rssi: rssi,
            ssid: ssid,
            vendor: "",
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
            trendArrow: "",
            trendDelta: 0,
            isVisible: true,
            visibilityLocked: false,
            qualityScore: 80,
            lastSeen: ""
        )
    }

    @Test func emptySortOrderPreservesRows() {
        let rows = [row("b", rssi: -60, ssid: "B"), row("a", rssi: -50, ssid: "A")]
        #expect(NetworkTableRowSorter.sort(rows, by: []) == rows)
    }

    @Test func sortsBySSID() {
        let rows = [row("b", rssi: -60, ssid: "B"), row("a", rssi: -50, ssid: "A")]
        let sorted = NetworkTableRowSorter.sort(
            rows,
            by: [NSSortDescriptor(key: "ssid", ascending: true)]
        )
        #expect(sorted.map(\.ssid) == ["A", "B"])
    }

    @Test func sortsByRSSIUsingExistingInvertedSemantics() {
        let rows = [row("weak", rssi: -60, ssid: "A"), row("strong", rssi: -50, ssid: "B")]
        let sorted = NetworkTableRowSorter.sort(
            rows,
            by: [NSSortDescriptor(key: "rssi", ascending: false)]
        )
        // The pre-existing comparator treats a larger RSSI as "ascending", so
        // descending flips the order: weaker signal comes first.
        #expect(sorted.map(\.id) == ["weak", "strong"])

        let ascendingSorted = NetworkTableRowSorter.sort(
            rows,
            by: [NSSortDescriptor(key: "rssi", ascending: true)]
        )
        #expect(ascendingSorted.map(\.id) == ["strong", "weak"])
    }
}
