import Foundation

@MainActor
final class WiFiObservationController {
    let pipeline: WiFiObservationPipelining
    let store: WiFiObservationStore

    init(
        pipeline: WiFiObservationPipelining = WiFiObservationPipeline(),
        store: WiFiObservationStore = WiFiObservationStore()
    ) {
        self.pipeline = pipeline
        self.store = store
    }

    func refreshCurrentConnection() async {
        store.isRefreshingCurrent = true
        defer { store.isRefreshingCurrent = false }
        let observation = await pipeline.refreshCurrentConnection()
        store.apply(observation)
    }

    func refreshEnvironmentScan() async {
        store.isScanningEnvironment = true
        defer { store.isScanningEnvironment = false }
        let observation = await pipeline.refreshEnvironmentScan()
        store.apply(observation)
    }

    func refreshFullObservation() async {
        store.isRefreshingCurrent = true
        store.isScanningEnvironment = true
        defer {
            store.isRefreshingCurrent = false
            store.isScanningEnvironment = false
        }
        let observation = await pipeline.refreshFullObservation()
        store.apply(observation)
    }
}
