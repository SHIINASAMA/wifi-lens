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

    // MARK: - Settings

    private func navigateToSettings() throws {
        let sidebar = app.descendants(matching: .any)["sidebar-settings"]
        XCTAssertTrue(sidebar.waitForExistence(timeout: 5))
        sidebar.click()
        XCTAssertTrue(app.descendants(matching: .any)["page-settings"].waitForExistence(timeout: 5))
    }

    /// Scroll the settings scroll view to make lower sections visible.
    private func scrollSettings(byDeltaY deltaY: CGFloat) {
        let scrollView = app.scrollViews["settings-scroll-view"]
        if scrollView.exists {
            scrollView.scroll(byDeltaX: 0, deltaY: deltaY)
        }
    }

    func testSettingsAppearanceAndScan() throws {
        try navigateToSettings()

        // Theme picker — segmented control (RadioGroup in XCUI).
        let themeGroup = app.radioGroups["settings-theme-picker"]
        guard themeGroup.waitForExistence(timeout: 3) else {
            XCTFail("Theme picker not found.\n\(app.debugDescription)")
            return
        }
        let themeButtons = themeGroup.radioButtons
        XCTAssertEqual(themeButtons.count, 3, "Expected 3 theme options (system/light/dark)")

        // Click "Light" (second segment) and verify the selection changes.
        themeButtons.element(boundBy: 1).click()
        XCTAssertEqual(themeButtons.element(boundBy: 1).value as? Int, 1,
                       "Light segment should be selected after click")

        // Click "System" (first segment) to restore.
        themeButtons.element(boundBy: 0).click()

        // Scan interval picker — menu-style (PopUpButton in XCUI).
        let intervalPicker = app.popUpButtons["settings-scan-interval-picker"]
        XCTAssertTrue(intervalPicker.waitForExistence(timeout: 3),
                      "Scan interval picker not found")
        intervalPicker.click()
        // Select "5s" (4th item, tag 5).
        let intervalItem = intervalPicker.menuItems.element(boundBy: 3)
        if intervalItem.waitForExistence(timeout: 2) {
            intervalItem.click()
        }
        // Dismiss the menu by clicking elsewhere.
        intervalPicker.click()

        // Region picker — menu-style.
        let regionPicker = app.popUpButtons["settings-region-picker"]
        XCTAssertTrue(regionPicker.waitForExistence(timeout: 3),
                      "Region picker not found")
        regionPicker.click()
        let regionItem = regionPicker.menuItems.element(boundBy: 1) // "US"
        if regionItem.waitForExistence(timeout: 2) {
            regionItem.click()
        }
        regionPicker.click()
    }

    func testSettingsFeatureToggles() throws {
        try navigateToSettings()

        // BLE toggle — renders as CheckBox on macOS (default Toggle style in Form).
        let bleToggle = app.checkBoxes["settings-ble-toggle"]
        guard bleToggle.waitForExistence(timeout: 3) else {
            XCTFail("BLE toggle not found")
            return
        }
        let bleWasOn = (bleToggle.value as? Int) == 1
        bleToggle.click()
        sleep(1)
        let bleNowOn = (bleToggle.value as? Int) == 1
        XCTAssertNotEqual(bleWasOn, bleNowOn, "BLE toggle did not change state")
        // Restore.
        bleToggle.click()

        // MCP toggle and port field — verify they exist (may be below the
        // visible area; XCUI can find them by identifier regardless).
        let mcpToggle = app.switches["settings-mcp-toggle"]
        XCTAssertTrue(mcpToggle.waitForExistence(timeout: 3),
                      "MCP toggle not found")
        let portField = app.textFields["settings-mcp-port-field"]
        XCTAssertTrue(portField.exists,
                      "MCP port field not found")
    }

    func testSettingsDiagnosticsAndPermissions() throws {
        try navigateToSettings()
        scrollSettings(byDeltaY: 600)

        // Permission badges.
        let locationBadge = app.descendants(matching: .any)["permission-location-badge"]
        XCTAssertTrue(locationBadge.waitForExistence(timeout: 3),
                      "Location permission badge not found")

        let bluetoothBadge = app.descendants(matching: .any)["permission-bluetooth-badge"]
        XCTAssertTrue(bluetoothBadge.waitForExistence(timeout: 3),
                      "Bluetooth permission badge not found")

        // Reveal logs button.
        let revealLogs = app.buttons["settings-reveal-logs-button"]
        XCTAssertTrue(revealLogs.waitForExistence(timeout: 3),
                      "Reveal logs button not found")

        // Privacy policy button.
        let privacyBtn = app.buttons["settings-privacy-policy-button"]
        XCTAssertTrue(privacyBtn.waitForExistence(timeout: 3),
                      "Privacy policy button not found")

#if OSS
        // Auto-update toggle and check-now button (OSS only).
        scrollSettings(byDeltaY: 200)
        let autoCheckToggle = app.switches["settings-auto-check-toggle"]
        XCTAssertTrue(autoCheckToggle.waitForExistence(timeout: 3),
                      "Auto-check toggle not found")

        let checkNowBtn = app.buttons["settings-check-now-button"]
        XCTAssertTrue(checkNowBtn.waitForExistence(timeout: 3),
                      "Check now button not found")
#endif
    }
}
