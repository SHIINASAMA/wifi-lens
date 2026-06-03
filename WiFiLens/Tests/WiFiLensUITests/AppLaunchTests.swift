import XCTest

/// App launch, window existence, and sidebar structure tests.
/// These are foundational — all other page tests depend on a working sidebar.
@MainActor
final class AppLaunchTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        launchAppForUITest(app)
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    // MARK: - Launch

    func testAppLaunchAndWindowExists() throws {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10),
                      "Expected at least one window.\n\(app.debugDescription)")

        let sidebar = app.descendants(matching: .any)["sidebar-overview"]
        XCTAssertTrue(sidebar.waitForExistence(timeout: 5),
                      "Sidebar should be visible at launch.\n\(app.debugDescription)")
    }

    // MARK: - Sidebar items

    func testAllSidebarItemsPresent() throws {
        XCTAssertTrue(app.descendants(matching: .any)["sidebar-overview"].waitForExistence(timeout: 5))

        let toolPages = ["sidebar-spectrum", "sidebar-channels", "sidebar-interfaces", "sidebar-roaming"]
        for id in toolPages {
            XCTAssertTrue(app.descendants(matching: .any)[id].waitForExistence(timeout: 3),
                          "Missing sidebar item: \(id)")
        }

        XCTAssertTrue(app.descendants(matching: .any)["sidebar-bleScanner"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["sidebar-settings"].waitForExistence(timeout: 3))

#if DEBUG
        XCTAssertTrue(app.descendants(matching: .any)["sidebar-debugChart"].waitForExistence(timeout: 3))
#endif
    }
}
