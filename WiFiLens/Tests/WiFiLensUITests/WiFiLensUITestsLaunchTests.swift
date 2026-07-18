import XCTest

@MainActor
final class WiFiLensUITestsLaunchTests: XCTestCase {
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchArguments = [
                "-ApplePersistenceIgnoreState", "YES",
                "-UITest",
            ]
            app.launch()
        }
    }
}
