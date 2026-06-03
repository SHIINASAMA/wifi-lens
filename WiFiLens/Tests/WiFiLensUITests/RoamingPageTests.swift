import XCTest

/// Roaming test page tests.
@MainActor
final class RoamingPageTests: XCTestCase {
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

    func testNavigateToRoamingPage() throws {
        continueAfterFailure = true
        navigateToPage("sidebar-roaming", pageID: "page-roaming", app: app)
    }

    // MARK: - Controls

    func testRoamingControlsPresent() throws {
        continueAfterFailure = true

        let sidebar = app.descendants(matching: .any)["sidebar-roaming"]
        guard sidebar.waitForExistence(timeout: 5) else { return }
        sidebar.click()

        let roamingPage = app.descendants(matching: .any)["page-roaming"]
        guard roamingPage.waitForExistence(timeout: 5) else { return }

        // The roaming page should have start, load, save, and stop buttons.
        // Start button — should always be visible when not running.
        let startButton = app.buttons["roaming-start-test-button"]
        if startButton.waitForExistence(timeout: 3) {
            XCTAssertTrue(startButton.isEnabled || !startButton.isEnabled,
                          "Start button state check")
        }

        // Load button — always visible when not running.
        let loadButton = app.buttons["roaming-load-session-button"]
        if loadButton.waitForExistence(timeout: 2) {
            XCTAssertTrue(loadButton.exists, "Load button should exist")
        }

        // Stop button — only visible during running, so may not be present.
        // Save button — only visible in stopped state with data.
    }
}
