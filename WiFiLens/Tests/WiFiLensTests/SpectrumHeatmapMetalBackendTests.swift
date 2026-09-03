import Metal
import Testing
@testable import WiFi_Lens

@Suite struct SpectrumHeatmapMetalBackendTests {
    private let input = SpectrumHeatmapComputeInput(
        envelopes: [SpectrumHeatmapEnvelope(
            leftX: 3,
            rightX: 7,
            peakRSSI: -50,
            baselineRSSI: -100
        )],
        domain: SpectrumHeatmapChannelDomain(
            minChannelCoordinate: 1,
            maxChannelCoordinate: 9
        ),
        rssiRange: -100...(-30),
        resolution: SpectrumHeatmapResolution(width: 32, height: 16)
    )

    @Test func metalBackendMatchesCPUReferenceWhenAvailable() async throws {
        guard let backend = MetalHeatmapComputeBackend() else { return }

        let actual = try await backend.compute(input)
        let expected = try await CPUHeatmapComputeBackend().compute(input)
        let maximumError = zip(actual.values, expected.values)
            .map { abs(Double($0) - Double($1)) }
            .max() ?? 0

        #expect(actual.width == expected.width)
        #expect(actual.height == expected.height)
        #expect(actual.values.allSatisfy { $0.isFinite && (0...1).contains($0) })
        #expect(maximumError < 0.02)
    }

    @Test func concurrentMetalComputationsProduceIndependentResults() async throws {
        guard let backend = MetalHeatmapComputeBackend() else { return }

        async let first = backend.compute(input)
        async let second = backend.compute(input)
        let (firstRaster, secondRaster) = try await (first, second)

        #expect(firstRaster == secondRaster)
    }
}
