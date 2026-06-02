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

    // MARK: - Window & Launch

    func testAppLaunchAndWindowExists() throws {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10),
                      "Expected at least one window to exist. UI tree:\n\(app.debugDescription)")

        let sidebar = app.descendants(matching: .any)["sidebar-overview"]
        XCTAssertTrue(sidebar.waitForExistence(timeout: 5),
                      "Expected sidebar-overview to exist. UI tree:\n\(app.debugDescription)")
    }

    // MARK: - Sidebar

    func testSidebarItemsPresent() throws {
        // Overview is already visible from launch
        XCTAssertTrue(app.descendants(matching: .any)["sidebar-overview"].waitForExistence(timeout: 5))

        // Tool pages
        let toolPages = ["sidebar-spectrum", "sidebar-channels", "sidebar-interfaces", "sidebar-roaming"]
        for id in toolPages {
            XCTAssertTrue(app.descendants(matching: .any)[id].waitForExistence(timeout: 3),
                          "Missing sidebar item: \(id)")
        }

        // BLE scanner
        XCTAssertTrue(app.descendants(matching: .any)["sidebar-bleScanner"].waitForExistence(timeout: 3))

        // Settings
        XCTAssertTrue(app.descendants(matching: .any)["sidebar-settings"].waitForExistence(timeout: 3))

#if DEBUG
        XCTAssertTrue(app.descendants(matching: .any)["sidebar-debugChart"].waitForExistence(timeout: 3))
#endif
    }

    // MARK: - Page Navigation

    /// Navigate to a sidebar item and verify the result — either the expected page,
    /// a location-permission placeholder, or a WiFi-off placeholder (both are valid
    /// outcomes in a CI / no-permission environment).
    func testNavigateToAllPages() throws {
        continueAfterFailure = true

        // --- Overview (default page on launch) ---
        XCTAssertTrue(app.descendants(matching: .any)["page-overview"].waitForExistence(timeout: 5),
                      "Overview page did not appear")

        // --- Pages that require location + WiFi ---
        let permissionGatedPages: [(sidebar: String, page: String)] = [
            ("sidebar-spectrum", "page-spectrum"),
            ("sidebar-channels", "page-channels"),
            ("sidebar-interfaces", "page-interfaces"),
            ("sidebar-roaming", "page-roaming"),
        ]
        for (sidebarID, pageID) in permissionGatedPages {
            let sidebar = app.descendants(matching: .any)[sidebarID]
            guard sidebar.waitForExistence(timeout: 3) else {
                XCTFail("\(sidebarID) not found")
                continue
            }
            sidebar.click()

            // In test environment we may see the actual page, the location permission
            // view, or a WiFi-off view — all are acceptable.
            let pageFound = app.descendants(matching: .any)[pageID].waitForExistence(timeout: 3)
            let locationViewFound = app.descendants(matching: .any)["location-permission-view"].waitForExistence(timeout: 0)
            let wifiOffFound = app.descendants(matching: .any)["wifi-off-view"].waitForExistence(timeout: 0)
            XCTAssertTrue(pageFound || locationViewFound || wifiOffFound,
                          "\(sidebarID) → neither \(pageID), location-permission-view, nor wifi-off-view appeared")
        }

#if DEBUG
        // Debug chart (requires location + WiFi, same gating)
        let debugSidebar = app.descendants(matching: .any)["sidebar-debugChart"]
        if debugSidebar.waitForExistence(timeout: 3) {
            debugSidebar.click()
            let debugFound = app.descendants(matching: .any)["page-debugChart"].waitForExistence(timeout: 3)
            let debugLocFound = app.descendants(matching: .any)["location-permission-view"].exists
            let debugWifiOff = app.descendants(matching: .any)["wifi-off-view"].exists
            XCTAssertTrue(debugFound || debugLocFound || debugWifiOff,
                          "debugChart → neither page-debugChart, location-permission-view, nor wifi-off-view appeared")
        }
#endif

        // --- Pages that do NOT require location ---

        // BLE Scanner
        let bleSidebar = app.descendants(matching: .any)["sidebar-bleScanner"]
        if bleSidebar.waitForExistence(timeout: 3) {
            bleSidebar.click()
            let blePage = app.descendants(matching: .any)["page-bleScanner"].waitForExistence(timeout: 3)
            let bleOff = app.descendants(matching: .any)["wifi-off-view"].exists
            XCTAssertTrue(blePage || bleOff,
                          "BLE Scanner → neither page-bleScanner nor wifi-off-view appeared")
        }

        // Help — sidebar item is currently disabled (commented out in SidebarView), skip.
        // Settings
        let settingsSidebar = app.descendants(matching: .any)["sidebar-settings"]
        if settingsSidebar.waitForExistence(timeout: 3) {
            settingsSidebar.click()
            XCTAssertTrue(app.descendants(matching: .any)["page-settings"].waitForExistence(timeout: 5),
                          "Settings page did not appear after clicking sidebar-settings")
        }
    }

    // MARK: - Settings Controls

    func testSettingsControls() throws {
        // Navigate to settings
        let settingsSidebar = app.descendants(matching: .any)["sidebar-settings"]
        XCTAssertTrue(settingsSidebar.waitForExistence(timeout: 5))
        settingsSidebar.click()

        let settingsPage = app.descendants(matching: .any)["page-settings"]
        XCTAssertTrue(settingsPage.waitForExistence(timeout: 5))

        // Scroll down to make all controls visible
        let scrollView = app.scrollViews["settings-scroll-view"]
        if scrollView.exists {
            scrollView.scroll(byDeltaX: 0, deltaY: 400)
        }

        // Theme picker
        let themePicker = app.popUpButtons["settings-theme-picker"]
        if themePicker.waitForExistence(timeout: 3) {
            XCTAssertTrue(themePicker.isEnabled)
        }

        // Scan interval picker
        let intervalPicker = app.popUpButtons["settings-scan-interval-picker"]
        if intervalPicker.waitForExistence(timeout: 3) {
            XCTAssertTrue(intervalPicker.isEnabled)
        }

        // Region picker
        let regionPicker = app.popUpButtons["settings-region-picker"]
        if regionPicker.waitForExistence(timeout: 3) {
            XCTAssertTrue(regionPicker.isEnabled)
        }

        // BLE toggle
        let bleToggle = app.switches["settings-ble-toggle"]
        if bleToggle.waitForExistence(timeout: 3) {
            XCTAssertTrue(bleToggle.isEnabled)
        }

        // MCP toggle
        let mcpToggle = app.switches["settings-mcp-toggle"]
        if mcpToggle.waitForExistence(timeout: 3) {
            XCTAssertTrue(mcpToggle.isEnabled)
        }
    }
}
