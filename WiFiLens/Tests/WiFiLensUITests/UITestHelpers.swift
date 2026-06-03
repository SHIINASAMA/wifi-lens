import XCTest

/// Shared helpers for WiFiLens UI tests.
/// Each page-specific test file's `XCTestCase` subclass can call these free functions
/// to avoid duplicating setup boilerplate.
extension XCTestCase {

    /// Standard UI test launch: purge saved state, set launch arguments, and launch.
    /// Call from `setUpWithError`.
    func launchAppForUITest(_ app: XCUIApplication, bundleID: String = "io.github.kaoru.wifi-lens") {
        let savedState = NSHomeDirectory() + "/Library/Saved Application State/\(bundleID).savedState"
        try? FileManager.default.removeItem(atPath: savedState)

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

    /// Click a sidebar item by its accessibility identifier and verify the target
    /// page or an acceptable fallback appeared.
    func navigateToPage(_ sidebarID: String, pageID: String, app: XCUIApplication,
                        file: StaticString = #filePath, line: UInt = #line) {
        let sidebar = app.descendants(matching: .any)[sidebarID]
        XCTAssertTrue(sidebar.waitForExistence(timeout: 5),
                      "Sidebar item '\(sidebarID)' not found", file: file, line: line)
        sidebar.click()

        let pageFound = app.descendants(matching: .any)[pageID].waitForExistence(timeout: 3)
        let locFound = app.descendants(matching: .any)["location-permission-view"].waitForExistence(timeout: 0)
        let wifiOff = app.descendants(matching: .any)["wifi-off-view"].waitForExistence(timeout: 0)
        XCTAssertTrue(pageFound || locFound || wifiOff,
                      "\(sidebarID) → expected \(pageID), location-permission-view, or wifi-off-view",
                      file: file, line: line)
    }

    /// Click the Settings sidebar item and wait for the settings page to appear.
    func navigateToSettings(_ app: XCUIApplication,
                            file: StaticString = #filePath, line: UInt = #line) {
        navigateToPage("sidebar-settings", pageID: "page-settings", app: app, file: file, line: line)
    }
}
