import Testing
@testable import WiFiLens

@Suite("WiFiObservationController")
struct ControllerTests {
    @Test("refreshCurrentConnection updates store")
    func controllerUpdatesStore() async {
        let store = WiFiObservationStore()
        let controller = WiFiObservationController(store: store)
        await controller.refreshCurrentConnection()
        #expect(store.lastUpdated != nil)
        #expect(store.isRefreshingCurrent == false)
    }

    @Test("refreshEnvironmentScan updates store snapshot")
    func controllerUpdatesSnapshot() async {
        let store = WiFiObservationStore()
        let controller = WiFiObservationController(store: store)
        await controller.refreshEnvironmentScan()
        #expect(store.latestEnvironmentSnapshot != nil)
        #expect(store.isScanningEnvironment == false)
    }
}
