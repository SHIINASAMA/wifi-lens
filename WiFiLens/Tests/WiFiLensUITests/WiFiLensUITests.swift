import XCTest

@MainActor
final class WiFiLensUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()

        // Dismiss crash log alert if present
        let dismissButton = app.dialogs.firstMatch.buttons["Ignore"]
        if dismissButton.waitForExistence(timeout: 3) {
            dismissButton.click()
        }
    }

    @MainActor
    func testAppLaunchAndWindowExists() throws {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertGreaterThan(app.windows.count, 0, "App should have at least one window")
    }

    @MainActor
    func testNavigateToSettings() throws {
        let settingsItem = app.descendants(matching: .any)["sidebar-settings"]
        XCTAssertTrue(settingsItem.waitForExistence(timeout: 5), "Settings sidebar item not found")
        settingsItem.click()

        let settingsScrollView = app.scrollViews["settings-scroll-view"]
        XCTAssertTrue(settingsScrollView.waitForExistence(timeout: 5), "Settings scroll view did not appear")
    }

    @MainActor
    func testPermissionStatusBadgesExist() throws {
        let settingsItem = app.descendants(matching: .any)["sidebar-settings"]
        XCTAssertTrue(settingsItem.waitForExistence(timeout: 5))
        settingsItem.click()

        let settingsScrollView = app.scrollViews["settings-scroll-view"]
        XCTAssertTrue(settingsScrollView.waitForExistence(timeout: 5))

        // Scroll to make permission section visible
        settingsScrollView.scroll(byDeltaX: 0, deltaY: 200)

        let locationBadge = app.descendants(matching: .any)["permission-location-badge"]
        XCTAssertTrue(locationBadge.waitForExistence(timeout: 3), "Location permission badge not found")

        let bluetoothBadge = app.descendants(matching: .any)["permission-bluetooth-badge"]
        XCTAssertTrue(bluetoothBadge.waitForExistence(timeout: 3), "Bluetooth permission badge not found")
    }

    @MainActor
    func testSidebarItemsPresent() throws {
        let expectedIdentifiers = [
            "sidebar-overview",
            "sidebar-spectrum",
            "sidebar-channels",
            "sidebar-interfaces",
            "sidebar-roaming",
            "sidebar-bleScanner",
            "sidebar-settings",
        ]

        for identifier in expectedIdentifiers {
            let element = app.descendants(matching: .any)[identifier]
            XCTAssertTrue(element.waitForExistence(timeout: 5), "Missing sidebar item: \(identifier)")
        }
    }
}
