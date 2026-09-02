import Foundation
import Testing
import SwiftUI
@testable import WiFi_Lens

@Suite @MainActor struct SpectrumHeatmapPanelTests {

    private func makeSnapshot(
        timestamp: Date,
        bssid: String,
        rssi: Int = -50,
        channel: Int = 6,
        band: String = "24",
        channelWidth: String = "20"
    ) -> NetworkSnapshot {
        NetworkSnapshot(
            timestamp: timestamp,
            bssid: bssid,
            ssid: "TestNet",
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

    private func recordCycle(
        _ vm: ScannerViewModel,
        timestamp: Date,
        snapshots: [NetworkSnapshot]
    ) {
        vm.signalHistory.recordScan(timestamp: timestamp)
        for snapshot in snapshots {
            vm.signalHistory.record(
                bssid: snapshot.bssid,
                rssi: snapshot.rssi,
                snapshot: snapshot
            )
        }
    }

    @Test func modelHasOneAnonymousFramePerSuccessfulScan() {
        let vm = ScannerViewModel()
        let t1 = Date(timeIntervalSince1970: 100)
        let t2 = Date(timeIntervalSince1970: 130)
        recordCycle(vm, timestamp: t1, snapshots: [
            makeSnapshot(timestamp: t1, bssid: "aa:bb:cc:dd:ee:01", rssi: -45, channel: 6)
        ])
        recordCycle(vm, timestamp: t2, snapshots: [
            makeSnapshot(timestamp: t2, bssid: "aa:bb:cc:dd:ee:01", rssi: -60, channel: 6),
            makeSnapshot(timestamp: t2, bssid: "aa:bb:cc:dd:ee:02", rssi: -75, channel: 11)
        ])

        let model = vm.heatmapModel(for: .band24GHz)

        #expect(model.frames.map(\.timestamp) == [t1, t2])
        #expect(model.frames[0].spans.count == 1)
        #expect(model.frames[1].spans.count == 2)
        #expect(model.frames[0].spans.allSatisfy { $0.lowerFrequencyMHz < $0.upperFrequencyMHz })
    }

    @Test func emptySuccessfulScanProducesZeroActivityFrame() {
        let vm = ScannerViewModel()
        let t1 = Date(timeIntervalSince1970: 100)
        let t2 = Date(timeIntervalSince1970: 130)
        recordCycle(vm, timestamp: t1, snapshots: [
            makeSnapshot(timestamp: t1, bssid: "aa:bb:cc:dd:ee:01")
        ])
        vm.debugApplyNetworksForTesting([], supportedBands: [.band24GHz], timestamp: t2)

        let model = vm.heatmapModel(for: .band24GHz)

        #expect(model.frames.map(\.timestamp) == [t1, t2])
        #expect(model.frames[1].spans.isEmpty)
    }

    @Test func bandFilteringKeepsFrameOwnershipButRemovesOtherBandSpans() {
        let vm = ScannerViewModel()
        let timestamp = Date(timeIntervalSince1970: 100)
        recordCycle(vm, timestamp: timestamp, snapshots: [
            makeSnapshot(timestamp: timestamp, bssid: "aa:bb:cc:dd:ee:01", channel: 36, band: "5")
        ])

        let model = vm.heatmapModel(for: .band24GHz)

        #expect(model.frames.count == 1)
        #expect(model.frames[0].spans.isEmpty)
    }

    @Test func strongerRSSIProducesGreaterSpanWeight() {
        let timestamp = Date(timeIntervalSince1970: 100)
        let weak = makeSnapshot(timestamp: timestamp, bssid: "aa:bb:cc:dd:ee:01", rssi: -85)
        let strong = makeSnapshot(timestamp: timestamp, bssid: "aa:bb:cc:dd:ee:02", rssi: -55)

        #expect(SpectrumHeatmapActivity.span(for: strong, band: .band24GHz)!.weight
            > SpectrumHeatmapActivity.span(for: weak, band: .band24GHz)!.weight)
    }

    @Test func staleSnapshotOutsideSuccessfulTimelineDoesNotCreateFrame() {
        let vm = ScannerViewModel()
        let stale = Date(timeIntervalSince1970: 100)
        vm.signalHistory.record(
            bssid: "aa:bb:cc:dd:ee:ff",
            rssi: -80,
            snapshot: makeSnapshot(timestamp: stale, bssid: "aa:bb:cc:dd:ee:ff")
        )
        let retainedTimeline = (1...3).map { Date(timeIntervalSince1970: Double(100 + $0)) }
        for timestamp in retainedTimeline {
            recordCycle(vm, timestamp: timestamp, snapshots: [
                makeSnapshot(timestamp: timestamp, bssid: "aa:bb:cc:dd:ee:01")
            ])
        }

        let model = vm.heatmapModel(for: .band24GHz)

        #expect(model.frames.map(\.timestamp) == retainedTimeline)
        #expect(model.frames.allSatisfy { $0.timestamp != stale })
    }

    @Test func debugIngestRecordsExactlyOneTimestampForOneCycle() {
        let vm = ScannerViewModel()
        let timestamp = Date(timeIntervalSince1970: 100)
        let networks = (1...3).map { channel in
            WiFiNetwork(
                ssid: "TestNet\(channel)",
                bssid: "aa:bb:cc:dd:ee:0\(channel)",
                rssi: -50,
                channel: WiFiChannel(band: .band24GHz, channelNumber: channel, channelWidthMHz: 20)
            )
        }

        vm.debugApplyNetworksForTesting(networks, supportedBands: [.band24GHz], timestamp: timestamp)

        #expect(vm.signalHistory.allScanTimestamps == [timestamp])
        #expect(vm.heatmapModel(for: .band24GHz).frames.count == 1)
    }

    @Test func emptyHistoryProducesNoFramesAndUsesLegalChannels() {
        let vm = ScannerViewModel()
        let model = vm.heatmapModel(for: .band5GHz)
        let expected = RegulatoryDatabase.rules[.US]?["5"]?.allowedChannels.sorted() ?? []

        #expect(model.frames.isEmpty)
        #expect(model.channels == expected)
        #expect(!model.channels.contains(1))
        #expect(!model.channels.contains(170))
    }

    @Test func fixedThermalIntensityScaleClampsAndCompresses() {
        #expect(SpectrumHeatmapActivity.normalizedIntensity(forActivity: 0) == 0)
        #expect(abs(SpectrumHeatmapActivity.normalizedIntensity(forActivity: 0.75) - 0.5) < 0.0001)
        #expect(SpectrumHeatmapActivity.normalizedIntensity(forActivity: 30) == 1)
    }

    @Test func thermalRampKeepsMaximumWarmRatherThanPureWhite() {
        let rgb = SpectrumHeatmapColor.components(forIntensity: 1)
        #expect(rgb.red == 1)
        #expect(rgb.green < 1)
        #expect(rgb.blue < 1)
    }

    @Test func panelConstructsWithBand() {
        let panel = SpectrumHeatmapPanel(viewModel: ScannerViewModel(), band: .band24GHz)
        #expect(panel.band == .band24GHz)
    }
}

@Suite struct SpectrumHeatmapRasterizerTests {
    private let domain = SpectrumHeatmapLayout.frequencyDomain(channels: [6], band: .band24GHz)

    @Test func rasterResolutionIsBoundedByDisplaySizeAndCap() {
        let large = SpectrumHeatmapRasterizer.resolution(for: CGSize(width: 1_000, height: 400))
        let small = SpectrumHeatmapRasterizer.resolution(for: CGSize(width: 80, height: 40))

        #expect(large.width == 320)
        #expect(large.height == 96)
        #expect(small.width == 80)
        #expect(small.height == 40)
    }

    @Test func rasterUsesWallClockTimeInsteadOfFrameOrdinal() {
        let start = Date(timeIntervalSince1970: 0)
        let frames = [
            SpectrumHeatmapFrame(
                id: start,
                timestamp: start,
                spans: [SpectrumHeatmapSpan(lowerFrequencyMHz: 2427, upperFrequencyMHz: 2447, weight: 1)]
            ),
            SpectrumHeatmapFrame(
                id: start.addingTimeInterval(30),
                timestamp: start.addingTimeInterval(30),
                spans: []
            ),
            SpectrumHeatmapFrame(
                id: start.addingTimeInterval(60),
                timestamp: start.addingTimeInterval(60),
                spans: [SpectrumHeatmapSpan(lowerFrequencyMHz: 2427, upperFrequencyMHz: 2447, weight: 1)]
            )
        ]

        let raster = SpectrumHeatmapRasterizer.rasterize(
            frames: frames,
            domain: domain,
            timeDomain: SpectrumHeatmapTimeDomain(start: start, end: start.addingTimeInterval(60)),
            size: CGSize(width: 1, height: 5)
        )

        #expect(raster.value(x: 0, y: 0) > 0.5)
        #expect(raster.value(x: 0, y: 1) > 0.4)
        #expect(raster.value(x: 0, y: 2) == 0)
        #expect(raster.value(x: 0, y: 3) > 0.4)
        #expect(raster.value(x: 0, y: 4) > 0.5)
    }

    @Test func smoothingDoesNotBridgeDiscontinuousRegions() {
        let domain = SpectrumHeatmapFrequencyDomain(
            minFrequencyMHz: 0,
            maxFrequencyMHz: 100,
            regions: [0...20, 80...100]
        )
        let raster = SpectrumHeatmapRaster(width: 5, height: 1, values: [1, 0, 0, 0, 0])

        let smoothed = SpectrumHeatmapRasterizer.smooth(raster, domain: domain)

        #expect(smoothed.value(x: 0, y: 0) > 0)
        #expect(smoothed.value(x: 4, y: 0) == 0)
    }
}
