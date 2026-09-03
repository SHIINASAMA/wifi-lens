import ChartLens
import Foundation

/// Converts current-scan networks into anonymous frequency envelopes.
enum SpectrumHeatmapActivity {
    static func envelope(
        for network: WiFiNetwork,
        band: ChannelBand
    ) -> SpectrumHeatmapEnvelope? {
        envelope(for: network, rssi: Double(network.rssi), band: band)
    }

    static func envelope(
        for network: WiFiNetwork,
        rssi: Double,
        band: ChannelBand
    ) -> SpectrumHeatmapEnvelope? {
        guard network.channel.band == band,
              rssi.isFinite,
              SpectrumHeatmapLayout.fixedRSSIRange.contains(rssi),
              network.channel.channelWidthMHz > 0 else { return nil }

        let block = ChannelSpanCalculator.channelBlock(
            primaryChannel: network.channel.channelNumber,
            widthMHz: network.channel.channelWidthMHz,
            band: band,
            spanDirection: network.channel.spanDirection
        )
        guard let bounds = SpectrumHeatmapLayout.channelBlockFrequencyBounds(
            leftChannel: block.left,
            rightChannel: block.right,
            band: band
        ) else { return nil }

        let lowerFrequencyMHz = bounds.lowerBound
        let upperFrequencyMHz = bounds.upperBound
        let halfWidthMHz = (upperFrequencyMHz - lowerFrequencyMHz) / 2.0
        guard
            lowerFrequencyMHz.isFinite,
            upperFrequencyMHz.isFinite,
            upperFrequencyMHz > lowerFrequencyMHz,
            halfWidthMHz.isFinite,
            halfWidthMHz > 0
        else { return nil }

        return SpectrumHeatmapEnvelope(
            lowerFrequencyMHz: lowerFrequencyMHz,
            upperFrequencyMHz: upperFrequencyMHz,
            peakRSSI: rssi,
            sigmaMHz: halfWidthMHz / 4.0,
            weight: Float(signalWeight(forRSSI: rssi))
        )
    }

    /// Returns the shared ChartLens sampler for a current-scan envelope.
    /// This preserves the same Gaussian mathematics as the Spectrum chart.
    static func gaussianEnvelope(for envelope: SpectrumHeatmapEnvelope) -> GaussianEnvelope {
        GaussianEnvelope(
            leftX: envelope.lowerFrequencyMHz,
            rightX: envelope.upperFrequencyMHz,
            peakY: envelope.peakRSSI,
            baselineY: Double(Constants.rssiNoiseFloor),
            sigma: envelope.sigmaMHz
        )
    }

    private static func signalWeight(forRSSI rssi: Double) -> Double {
        if rssi <= -90 { return 0.15 }
        if rssi >= -45 { return 1.0 }
        return 0.15 + Double(rssi + 90) / 45.0 * 0.85
    }
}
