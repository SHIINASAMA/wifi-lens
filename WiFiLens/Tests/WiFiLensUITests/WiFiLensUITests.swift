import XCTest

@MainActor
final class WiFiLensUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        // Clear any stale window restoration state from previous runs so
        // WindowGroup always creates a fresh window during UI tests.
        let bundleID = "io.github.kaoru.wifi-lens"
        let savedState = NSHomeDirectory() + "/Library/Saved Application State/\(bundleID).savedState"
        try? FileManager.default.removeItem(atPath: savedState)

        app = XCUIApplication()
        app.launchArguments = [
            "-ApplePersistenceIgnoreState", "YES",
            "-UITest",
        ]
        app.launch()

        let dismissButton = app.dialogs.firstMatch.buttons["Ignore"]
        if dismissButton.waitForExistence(timeout: 3) {
            dismissButton.click()
        }
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    func testAppLaunchAndWindowExists() throws {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))

        // Wait for the window to appear (it should always appear for a fresh launch).
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10),
                      "Expected at least one window to exist. UI tree:\n\(app.debugDescription)")

        // Verify the sidebar — our most stable early UI element.
        let sidebar = app.descendants(matching: .any)["sidebar-overview"]
        XCTAssertTrue(sidebar.waitForExistence(timeout: 5),
                      "Expected sidebar-overview to exist. UI tree:\n\(app.debugDescription)")
    }

    func testNavigateToSettings() throws {
        let sidebar = app.descendants(matching: .any)["sidebar-overview"]
        guard sidebar.waitForExistence(timeout: 15) else {
            XCTFail("Sidebar did not appear. UI tree:\n\(app.debugDescription)")
            return
        }

        let settingsButton = app.descendants(matching: .any)["sidebar-settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.click()

        let settingsPage = app.descendants(matching: .any)["page-settings"]
        XCTAssertTrue(settingsPage.waitForExistence(timeout: 5))
    }
}
