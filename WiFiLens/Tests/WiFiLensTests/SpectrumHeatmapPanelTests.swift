import Testing
import SwiftUI
@testable import WiFi_Lens

@Suite @MainActor struct SpectrumHeatmapPanelTests {

    private func makeSnapshot(
        timestamp: Date,
        bssid: String,
        ssid: String = "TestNet",
        rssi: Int = -50,
        channel: Int = 6,
        band: String = "24",
        channelWidth: String = "20"
    ) -> NetworkSnapshot {
        NetworkSnapshot(
            timestamp: timestamp,
            bssid: bssid,
            ssid: ssid,
            rssi: rssi,
            channel: channel,
            band: band,
            phyMode: "ax",
            channelWidth: channelWidth,
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

    @Test func oneRowPerDistinctTimestampOldestFirst() {
        let vm = ScannerViewModel()
        let t1 = Date(timeIntervalSince1970: 100)
        let t2 = Date(timeIntervalSince1970: 130)
        vm.signalHistory.record(
            bssid: "aa:bb:cc:dd:ee:01", rssi: -50,
            snapshot: makeSnapshot(timestamp: t1, bssid: "aa:bb:cc:dd:ee:01", channel: 6)
        )
        vm.signalHistory.record(
            bssid: "aa:bb:cc:dd:ee:01", rssi: -55,
            snapshot: makeSnapshot(timestamp: t2, bssid: "aa:bb:cc:dd:ee:01", channel: 6)
        )

        let model = vm.heatmapModel(for: .band24GHz)

        #expect(model.rows.count == 2)
        #expect(model.rows[0].timestamp == t1)  // oldest first
        #expect(model.rows[1].timestamp == t2)
    }

    @Test func spanCountingMatchesChannelSpanCalculator() {
        let vm = ScannerViewModel()
        vm.signalHistory.record(
            bssid: "aa:bb:cc:dd:ee:01", rssi: -50,
            snapshot: makeSnapshot(timestamp: Date(timeIntervalSince1970: 100), bssid: "aa:bb:cc:dd:ee:01", channel: 6)
        )

        let model = vm.heatmapModel(for: .band24GHz)
        #expect(model.rows.count == 1)
        let span = ChannelSpanCalculator.channelBlock(
            primaryChannel: 6, widthMHz: 20, band: .band24GHz, spanDirection: nil
        )
        for cell in model.rows[0].cells {
            let inSpan = (span.left...span.right).contains(cell.channel)
            #expect(cell.activity == (inSpan ? 1 : 0))
        }
        #expect(model.rows[0].cells.first { $0.channel == 6 }?.activity == 1)
    }

    @Test func wideChannelSpanCounted() {
        let vm = ScannerViewModel()
        vm.signalHistory.record(
            bssid: "aa:bb:cc:dd:ee:01", rssi: -50,
            snapshot: makeSnapshot(timestamp: Date(timeIntervalSince1970: 100), bssid: "aa:bb:cc:dd:ee:01", channel: 36, band: "5", channelWidth: "80")
        )

        let model = vm.heatmapModel(for: .band5GHz)
        #expect(model.rows.count == 1)
        let span = ChannelSpanCalculator.channelBlock(
            primaryChannel: 36, widthMHz: 80, band: .band5GHz, spanDirection: nil
        )
        // 80 MHz on ch36 → block (34, 50)
        #expect(span.left == 34 && span.right == 50)
        for cell in model.rows[0].cells {
            let inSpan = (span.left...span.right).contains(cell.channel)
            #expect(cell.activity == (inSpan ? 1 : 0))
        }
    }

    @Test func emptyHistoryProducesNoRows() {
        let vm = ScannerViewModel()
        let model = vm.heatmapModel(for: .band24GHz)
        #expect(model.rows.isEmpty)
        #expect(model.channels == Array(1...14))
    }

    @Test func bandFilteringExcludesOtherBands() {
        let vm = ScannerViewModel()
        vm.signalHistory.record(
            bssid: "aa:bb:cc:dd:ee:01", rssi: -50,
            snapshot: makeSnapshot(timestamp: Date(timeIntervalSince1970: 100), bssid: "aa:bb:cc:dd:ee:01", channel: 36, band: "5")
        )

        #expect(vm.heatmapModel(for: .band24GHz).rows.isEmpty)
        #expect(vm.heatmapModel(for: .band5GHz).rows.count == 1)
    }

    @Test func bssidAppearingMidWindowAddsRow() {
        let vm = ScannerViewModel()
        let t1 = Date(timeIntervalSince1970: 100)
        let t2 = Date(timeIntervalSince1970: 130)
        // Scan 1: only A. Scan 2: A and B.
        vm.signalHistory.record(
            bssid: "aa:bb:cc:dd:ee:01", rssi: -50,
            snapshot: makeSnapshot(timestamp: t1, bssid: "aa:bb:cc:dd:ee:01", channel: 6)
        )
        vm.signalHistory.record(
            bssid: "aa:bb:cc:dd:ee:01", rssi: -55,
            snapshot: makeSnapshot(timestamp: t2, bssid: "aa:bb:cc:dd:ee:01", channel: 6)
        )
        vm.signalHistory.record(
            bssid: "aa:bb:cc:dd:ee:02", rssi: -60,
            snapshot: makeSnapshot(timestamp: t2, bssid: "aa:bb:cc:dd:ee:02", channel: 11)
        )

        let model = vm.heatmapModel(for: .band24GHz)
        #expect(model.rows.count == 2)
        #expect(model.rows[1].cells.first { $0.channel == 11 }?.activity == 1)
        #expect(model.rows[0].cells.first { $0.channel == 11 }?.activity == 0)  // B absent at t1
    }

    @Test func cellIDIsDeterministic() {
        let vm = ScannerViewModel()
        let t1 = Date(timeIntervalSince1970: 100)
        vm.signalHistory.record(
            bssid: "aa:bb:cc:dd:ee:01", rssi: -50,
            snapshot: makeSnapshot(timestamp: t1, bssid: "aa:bb:cc:dd:ee:01", channel: 6)
        )
        let model = vm.heatmapModel(for: .band24GHz)
        let cell = model.rows[0].cells.first { $0.channel == 6 }
        #expect(cell?.id == "\(t1.timeIntervalSinceReferenceDate)-6")
    }

    @Test func fixedColorScaleClampsAtFive() {
        #expect(SpectrumHeatmapColor.intensity(forActivity: 0) == 0.0)
        #expect(SpectrumHeatmapColor.intensity(forActivity: 1) == 0.2)
        #expect(SpectrumHeatmapColor.intensity(forActivity: 5) == 1.0)
        #expect(SpectrumHeatmapColor.intensity(forActivity: 9) == 1.0)   // clamped high
        #expect(SpectrumHeatmapColor.intensity(forActivity: -3) == 0.0)  // clamped low
    }

    @Test func panelConstructsWithBand() {
        let vm = ScannerViewModel()
        let panel = SpectrumHeatmapPanel(viewModel: vm, band: .band24GHz)
        #expect(panel.band == .band24GHz)
    }
}
