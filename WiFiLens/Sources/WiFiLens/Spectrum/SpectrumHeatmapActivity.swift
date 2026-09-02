import Foundation

/// Converts observed networks into anonymous, frequency-based heatmap spans.
/// The heatmap intentionally carries no SSID or BSSID identity.
enum SpectrumHeatmapActivity {
    /// Keep weak but real observations visible while giving nearby APs more
    /// influence. This is a fixed scale so colors remain comparable over time.
    static func signalWeight(forRSSI rssi: Int) -> Double {
        let clamped = min(-45, max(-90, rssi))
        return 0.15 + Double(clamped + 90) / 45.0 * 0.85
    }

    static func span(
        for snapshot: NetworkSnapshot,
        band: ChannelBand
    ) -> SpectrumHeatmapSpan? {
        guard ChannelBand(id: snapshot.band) == band else { return nil }

        let widthMHz = SnapshotToChartAdapter.channelWidthMHz(from: snapshot.channelWidth)
        let block = ChannelSpanCalculator.channelBlock(
            primaryChannel: snapshot.channel,
            widthMHz: widthMHz,
            band: band,
            spanDirection: nil
        )
        guard
            let lower = SpectrumHeatmapLayout.channelEdgeFrequencyMHz(
                channel: block.left,
                band: band
            ),
            let upper = SpectrumHeatmapLayout.channelEdgeFrequencyMHz(
                channel: block.right,
                band: band
            )
        else { return nil }

        return SpectrumHeatmapSpan(
            lowerFrequencyMHz: min(lower, upper),
            upperFrequencyMHz: max(lower, upper),
            weight: signalWeight(forRSSI: snapshot.rssi)
        )
    }

    /// Compress activity into the fixed [0, 1] display range. Square-root
    /// compression makes a single weak AP visible without allowing crowded
    /// areas to wash out the whole field.
    static func normalizedIntensity(forActivity activity: Double) -> Double {
        let clamped = min(1, max(0, activity / 3.0))
        return sqrt(clamped)
    }
}
