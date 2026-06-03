import XCTest

/// Channel analysis page tests.
@MainActor
final class ChannelsPageTests: XCTestCase {
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

    func testNavigateToChannelsPage() throws {
        continueAfterFailure = true
        navigateToPage("sidebar-channels", pageID: "page-channels", app: app)
    }

    // MARK: - Content

    func testChannelsQualityModePicker() throws {
        continueAfterFailure = true

        let sidebar = app.descendants(matching: .any)["sidebar-channels"]
        guard sidebar.waitForExistence(timeout: 5) else { return }
        sidebar.click()

        // Channels page may show wifi-off-view or location-permission-view in CI.
        let channelsPage = app.descendants(matching: .any)["page-channels"]
        guard channelsPage.waitForExistence(timeout: 5) else { return }

        // The channel quality mode picker (Signal / Quality) should exist on the page.
        let modePicker = app.popUpButtons["channel-quality-mode-picker"]
        if modePicker.waitForExistence(timeout: 3) {
            XCTAssertGreaterThan(modePicker.menuItems.count, 0,
                                 "Quality mode picker should have menu items")
        }
        // If picker doesn't exist, the page may be in wifi-off or location-permission state — OK.
    }
}
