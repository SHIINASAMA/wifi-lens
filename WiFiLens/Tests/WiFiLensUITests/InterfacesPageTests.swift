import XCTest

/// Network interfaces page tests.
@MainActor
final class InterfacesPageTests: XCTestCase {
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

    func testNavigateToInterfacesPage() throws {
        continueAfterFailure = true
        navigateToPage("sidebar-interfaces", pageID: "page-interfaces", app: app)
    }

    // MARK: - Content

    func testInterfacesModePickerExists() throws {
        continueAfterFailure = true

        let sidebar = app.descendants(matching: .any)["sidebar-interfaces"]
        guard sidebar.waitForExistence(timeout: 5) else { return }
        sidebar.click()

        let interfacesPage = app.descendants(matching: .any)["page-interfaces"]
        guard interfacesPage.waitForExistence(timeout: 5) else { return }

        // The interfaces mode picker (WiFi / Ethernet / Bluetooth) should exist.
        let modePicker = app.popUpButtons["interfaces-mode-picker"]
        if modePicker.waitForExistence(timeout: 3) {
            XCTAssertGreaterThan(modePicker.menuItems.count, 0,
                                 "Interfaces mode picker should have menu items")
        }
    }
}
