import Foundation

/// An anonymous frequency interval contributed by one observed network.
struct SpectrumHeatmapSpan: Equatable, Sendable {
    let lowerFrequencyMHz: Double
    let upperFrequencyMHz: Double
    let weight: Double
}

/// One successful scan cycle, oldest first in the shared timeline.
struct SpectrumHeatmapFrame: Identifiable, Equatable, Sendable {
    let id: Date
    let timestamp: Date
    let spans: [SpectrumHeatmapSpan]
}

/// Aggregated shared-history view of one band. It is environment-level and
/// deliberately contains no AP identity.
struct SpectrumHeatmapModel: Equatable, Sendable {
    let band: ChannelBand
    let channels: [Int]
    let frames: [SpectrumHeatmapFrame]
}
