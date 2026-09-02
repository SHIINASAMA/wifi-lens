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
        // Unknown region in a fresh view model → US 2.4 GHz fallback (channels 1...11).
        #expect(model.channels == Array(1...11))
    }

    @Test func fiveGHzChannelsUseLegalSet() {
        let vm = ScannerViewModel()
        let model = vm.heatmapModel(for: .band5GHz)
        // Unknown region → US fallback: the legal 5 GHz plan (36/40/44/…), not 1...170.
        let expected = RegulatoryDatabase.rules[.US]?["5"]?.allowedChannels.sorted() ?? []
        #expect(!expected.isEmpty)
        #expect(model.channels == expected)
        // Regression guards against the old continuous 1...maxChannel range:
        #expect(!model.channels.contains(1))
        #expect(!model.channels.contains(170))
    }

    @Test func sixGHzChannelsUseLegalSet() {
        let vm = ScannerViewModel()
        let model = vm.heatmapModel(for: .band6GHz)
        let expected = RegulatoryDatabase.rules[.US]?["6"]?.allowedChannels.sorted() ?? []
        #expect(!expected.isEmpty)
        #expect(model.channels == expected)
        // 6 GHz is a 20 MHz PSC grid (1, 5, 9, …, 233), not every integer:
        #expect(model.channels.first == 1)
        #expect(model.channels.contains(5))
        #expect(!model.channels.contains(2))
    }

    @Test func heatmapChannelsRespectRegionOverride() {
        let vm = ScannerViewModel()
        vm.userRegionOverride = .JP
        let model = vm.heatmapModel(for: .band5GHz)
        let expected = RegulatoryDatabase.rules[.JP]?["5"]?.allowedChannels.sorted() ?? []
        #expect(!expected.isEmpty)
        #expect(model.channels == expected)
        #expect(model.channels.last == 144)      // JP 5 GHz caps at 144
        #expect(!model.channels.contains(149))   // U-NII-3 not available in JP
    }

    @Test func bandFilteringExcludesOtherBandsButKeepsScanTimestamp() {
        let vm = ScannerViewModel()
        vm.signalHistory.record(
            bssid: "aa:bb:cc:dd:ee:01", rssi: -50,
            snapshot: makeSnapshot(timestamp: Date(timeIntervalSince1970: 100), bssid: "aa:bb:cc:dd:ee:01", channel: 36, band: "5")
        )

        let band24Model = vm.heatmapModel(for: .band24GHz)
        #expect(band24Model.rows.count == 1)
        #expect(band24Model.rows[0].cells.allSatisfy { $0.activity == 0 })
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

    @Test func selectedBandDisappearingMidWindowKeepsZeroActivityRow() {
        let vm = ScannerViewModel()
        let t1 = Date(timeIntervalSince1970: 100)
        let t2 = Date(timeIntervalSince1970: 130)
        // Scan 1 contains the selected band; scan 2 contains only another band.
        vm.signalHistory.record(
            bssid: "aa:bb:cc:dd:ee:01", rssi: -50,
            snapshot: makeSnapshot(timestamp: t1, bssid: "aa:bb:cc:dd:ee:01", channel: 6, band: "24")
        )
        vm.signalHistory.record(
            bssid: "aa:bb:cc:dd:ee:02", rssi: -60,
            snapshot: makeSnapshot(timestamp: t2, bssid: "aa:bb:cc:dd:ee:02", channel: 36, band: "5")
        )

        let model = vm.heatmapModel(for: .band24GHz)

        #expect(model.rows.map(\.timestamp) == [t1, t2])
        #expect(model.rows[1].cells.allSatisfy { $0.activity == 0 })
    }

    @Test func selectedBandDisappearanceProducesZeroRow() {
        let vm = ScannerViewModel()
        let first = Date(timeIntervalSince1970: 100)
        let second = Date(timeIntervalSince1970: 130)
        vm.signalHistory.recordScan(timestamp: first)
        vm.signalHistory.recordScan(timestamp: second)
        vm.signalHistory.record(
            bssid: "aa:bb:cc:dd:ee:01", rssi: -50,
            snapshot: makeSnapshot(timestamp: first, bssid: "aa:bb:cc:dd:ee:01", channel: 6, band: "24")
        )

        let model = vm.heatmapModel(for: .band24GHz)
        #expect(model.rows.map(\.timestamp) == [first, second])
        #expect(model.rows[1].cells.allSatisfy { $0.activity == 0 })
    }

    @Test func recordedScanTimelineIsRenderedOldestFirst() {
        let vm = ScannerViewModel()
        let first = Date(timeIntervalSince1970: 100)
        let second = Date(timeIntervalSince1970: 130)
        vm.signalHistory.recordScan(timestamp: second)
        vm.signalHistory.recordScan(timestamp: first)
        vm.signalHistory.record(
            bssid: "aa:bb:cc:dd:ee:01", rssi: -50,
            snapshot: makeSnapshot(timestamp: first, bssid: "aa:bb:cc:dd:ee:01", channel: 6, band: "24")
        )

        let model = vm.heatmapModel(for: .band24GHz)

        #expect(model.rows.map(\.timestamp) == [first, second])
    }

    @Test func staleSnapshotOutsideSuccessfulScanTimelineDoesNotCreateRow() {
        let vm = ScannerViewModel()
        let stale = Date(timeIntervalSince1970: 100)
        vm.signalHistory.record(
            bssid: "aa:bb:cc:dd:ee:ff", rssi: -80,
            snapshot: makeSnapshot(timestamp: stale, bssid: "aa:bb:cc:dd:ee:ff", channel: 1, band: "24")
        )
        let retainedTimeline = (1...20).map { Date(timeIntervalSince1970: Double(100 + $0)) }
        for (offset, timestamp) in retainedTimeline.enumerated() {
            vm.signalHistory.record(
                bssid: "aa:bb:cc:dd:ee:01", rssi: -50 - offset,
                snapshot: makeSnapshot(timestamp: timestamp, bssid: "aa:bb:cc:dd:ee:01", channel: 6, band: "24")
            )
        }

        let model = vm.heatmapModel(for: .band24GHz)

        #expect(vm.signalHistory.allSnapshots["aa:bb:cc:dd:ee:ff"]?.map(\.timestamp) == [stale])
        #expect(vm.signalHistory.allScanTimestamps == retainedTimeline)
        #expect(model.rows.map(\.timestamp) == retainedTimeline)
        #expect(model.rows.allSatisfy { $0.timestamp != stale })
    }

    @Test func emptyScanKeepsCurrentTimestampAsZeroActivityRow() {
        let vm = ScannerViewModel()
        let t1 = Date(timeIntervalSince1970: 100)
        let t2 = Date(timeIntervalSince1970: 130)
        vm.signalHistory.record(
            bssid: "aa:bb:cc:dd:ee:01", rssi: -50,
            snapshot: makeSnapshot(timestamp: t1, bssid: "aa:bb:cc:dd:ee:01", channel: 6, band: "24")
        )
        vm.debugApplyNetworksForTesting([], supportedBands: [.band24GHz], timestamp: t2)

        let model = vm.heatmapModel(for: .band24GHz)

        #expect(model.rows.map(\.timestamp) == [t1, t2])
        #expect(model.rows[1].cells.allSatisfy { $0.activity == 0 })
    }

    @Test func explicitScanRecordingAndSnapshotRecordingShareOneRow() {
        let vm = ScannerViewModel()
        let timestamp = Date(timeIntervalSince1970: 100)

        vm.debugApplyNetworksForTesting(
            [
                WiFiNetwork(
                    ssid: "TestNet",
                    bssid: "aa:bb:cc:dd:ee:01",
                    rssi: -50,
                    channel: WiFiChannel(band: .band24GHz, channelNumber: 6, channelWidthMHz: 20)
                )
            ],
            supportedBands: [.band24GHz],
            timestamp: timestamp
        )

        let model = vm.heatmapModel(for: .band24GHz)

        #expect(model.rows.map(\.timestamp) == [timestamp])
        #expect(model.rows.count == 1)
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
