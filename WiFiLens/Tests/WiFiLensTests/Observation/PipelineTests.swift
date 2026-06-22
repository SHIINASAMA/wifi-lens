import Testing
@testable import WiFiLens

@Suite("WiFiObservationPipeline")
struct PipelineTests {
    @Test("refreshCurrentConnection returns currentStatus + quality, no environment")
    func currentConnectionOnly() async {
        let pipeline = WiFiObservationPipeline()
        let obs = await pipeline.refreshCurrentConnection()
        #expect(obs.currentStatus != nil)
        #expect(obs.quality != nil)
        #expect(obs.environmentSnapshot == nil)
    }

    @Test("refreshEnvironmentScan returns snapshot, no currentStatus")
    func environmentScanOnly() async {
        let pipeline = WiFiObservationPipeline()
        let obs = await pipeline.refreshEnvironmentScan()
        #expect(obs.environmentSnapshot != nil)
        #expect(obs.currentStatus == nil)
    }

    @Test("refreshFullObservation returns all fields")
    func fullObservation() async {
        let pipeline = WiFiObservationPipeline()
        let obs = await pipeline.refreshFullObservation()
        #expect(obs.currentStatus != nil)
        #expect(obs.environmentSnapshot != nil)
        #expect(obs.diagnosis != nil)
    }
}
