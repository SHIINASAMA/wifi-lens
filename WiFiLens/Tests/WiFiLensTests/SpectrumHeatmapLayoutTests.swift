import Foundation
import Testing
@testable import WiFi_Lens

private func makeModel(channels: [Int], rows: Int) -> SpectrumHeatmapModel {
    let timestamps = (0..<rows).map { Date(timeIntervalSince1970: Double($0)) }
    let heatmapRows = timestamps.map { timestamp in
        SpectrumHeatmapRow(
            id: timestamp,
            timestamp: timestamp,
            cells: channels.map { channel in
                SpectrumHeatmapCell(
                    id: "\(timestamp.timeIntervalSinceReferenceDate)-\(channel)",
                    timestamp: timestamp,
                    channel: channel,
                    activity: 0
                )
            }
        )
    }
    return SpectrumHeatmapModel(band: .band5GHz, channels: channels, rows: heatmapRows)
}

@Suite struct SpectrumHeatmapLayoutTests {
    @Test func channelRectsPreserveNumericGaps() {
        let rects = SpectrumHeatmapLayout.columnRects(
            channels: [36, 40, 44, 48, 149],
            in: CGRect(x: 0, y: 0, width: 500, height: 200)
        )
        #expect(rects[0].channel == 36)
        #expect(rects[3].rect.maxX < rects[4].rect.minX)
    }

    @Test func sparseOnlyChannelRectsPreserveNumericGaps() {
        let rects = SpectrumHeatmapLayout.columnRects(
            channels: [36, 44, 149],
            in: CGRect(x: 0, y: 0, width: 500, height: 200)
        )

        #expect(rects[0].rect.maxX < rects[1].rect.minX)
        #expect(rects[1].rect.maxX < rects[2].rect.minX)
    }

    @Test func bandAwareRectsUseNominalFiveGHzSpacing() {
        let rects = SpectrumHeatmapLayout.columnRects(
            channels: [36, 40, 44, 48, 149],
            band: .band5GHz,
            in: CGRect(x: 0, y: 0, width: 500, height: 200)
        )

        #expect(abs(rects[0].rect.maxX - rects[1].rect.minX) < 0.001)
        #expect(rects[3].rect.maxX < rects[4].rect.minX)
    }

    @Test func cellHitTestingDoesNotInterpolateAcrossGap() {
        let result = SpectrumHeatmapLayout.cell(
            at: CGPoint(x: 250, y: 40),
            in: CGRect(x: 0, y: 0, width: 500, height: 200),
            model: makeModel(channels: [36, 40, 149], rows: 2)
        )
        #expect(result == nil)
    }

    @Test func emptyAndSingletonInputsAreHandled() {
        let rect = CGRect(x: 0, y: 0, width: 500, height: 200)
        #expect(SpectrumHeatmapLayout.columnRects(channels: [], in: rect).isEmpty)

        let singleton = SpectrumHeatmapLayout.columnRects(channels: [36], in: rect)
        #expect(singleton.count == 1)
        #expect(singleton[0].channel == 36)
        #expect(singleton[0].rect == rect)
    }

    @Test func rowBoundaryHitTestingUsesTheLowerRow() {
        let model = makeModel(channels: [36], rows: 2)
        let result = SpectrumHeatmapLayout.cell(
            at: CGPoint(x: 250, y: 100),
            in: CGRect(x: 0, y: 0, width: 500, height: 200),
            model: model
        )

        #expect(result?.row == 1)
        #expect(result?.channel == 36)
    }
}
