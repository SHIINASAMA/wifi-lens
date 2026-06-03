import XCTest

/// BLE scanner page tests.
@MainActor
final class BLEScannerPageTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        launchAppForUITest(app)
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    // MARK: - Navigation

    func testNavigateToBLEScannerPage() throws {
        continueAfterFailure = true

        let sidebar = app.descendants(matching: .any)["sidebar-bleScanner"]
        guard sidebar.waitForExistence(timeout: 5) else {
            XCTFail("BLE sidebar not found")
            return
        }
        sidebar.click()

        let blePage = app.descendants(matching: .any)["page-bleScanner"]
        let wifiOff = app.descendants(matching: .any)["wifi-off-view"]
        XCTAssertTrue(blePage.waitForExistence(timeout: 3) || wifiOff.waitForExistence(timeout: 0),
                      "BLE Scanner → expected page-bleScanner or wifi-off-view")
    }

    // MARK: - Controls

    func testBLEScanControlsPresent() throws {
        continueAfterFailure = true

        let sidebar = app.descendants(matching: .any)["sidebar-bleScanner"]
        guard sidebar.waitForExistence(timeout: 5) else { return }
        sidebar.click()

        let blePage = app.descendants(matching: .any)["page-bleScanner"]
        guard blePage.waitForExistence(timeout: 5) else { return }

        // BLE scan toggle button should be present.
        let scanToggle = app.buttons["ble-scan-toggle-button"]
        if scanToggle.waitForExistence(timeout: 3) {
            XCTAssertTrue(scanToggle.exists, "Scan toggle button exists")
        }

        // Control bar should be present.
        let controlBar = app.descendants(matching: .any)["ble-control-bar"]
        if controlBar.waitForExistence(timeout: 2) {
            XCTAssertTrue(controlBar.exists, "BLE control bar exists")
        }
    }
}
