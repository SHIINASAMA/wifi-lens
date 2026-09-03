/// An anonymous spectrum envelope contributed by one network in the current
/// scan. It intentionally contains no access-point identity or time data.
struct SpectrumHeatmapEnvelope: Equatable, Sendable {
    let lowerFrequencyMHz: Double
    let upperFrequencyMHz: Double
    let peakRSSI: Double
    let sigmaMHz: Double
    let weight: Float
}

/// The current-scan aggregate view for one band. It deliberately contains no
/// scan history, timestamps, frames, or access-point identity.
struct SpectrumHeatmapModel: Equatable, Sendable {
    let band: ChannelBand
    let channels: [Int]
    let envelopes: [SpectrumHeatmapEnvelope]
}
