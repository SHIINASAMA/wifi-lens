import Foundation

/// One channel cell in the spectrum heatmap.
/// `activity` is the internal count of AP spans covering `channel` at `timestamp`;
/// the view maps it to a color via `SpectrumHeatmapColor`.
struct SpectrumHeatmapCell: Identifiable, Equatable, Sendable {
    let id: String          // "\(timestamp.timeIntervalSinceReferenceDate)-\(channel)"
    let timestamp: Date
    let channel: Int
    let activity: Int
}

/// One scan moment (one row in the waterfall).
struct SpectrumHeatmapRow: Identifiable, Equatable, Sendable {
    let id: Date            // snapshot timestamp
    let timestamp: Date     // snapshot timestamp
    let cells: [SpectrumHeatmapCell]
}

/// Aggregated shared-history view of a single band.
/// `channels` is the full column set; `rows` are oldest-first.
struct SpectrumHeatmapModel: Equatable, Sendable {
    let band: ChannelBand
    let channels: [Int]
    let rows: [SpectrumHeatmapRow]
}
