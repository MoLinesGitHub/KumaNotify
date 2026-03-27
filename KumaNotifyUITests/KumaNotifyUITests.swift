import XCTest

@MainActor
final class KumaNotifyUITests: XCTestCase {
    private func waitForEnabled(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND enabled == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testFirstLaunchAutomaticallyShowsOnboarding() {
        let app = XCUIApplication()
        let suiteName = "KumaNotifyUITests.firstLaunch.\(UUID().uuidString)"
        app.launchEnvironment["KUMA_SETTINGS_SUITE_NAME"] = suiteName
        app.launch()

        let welcomeTitle = app.staticTexts["onboarding.welcomeTitle"]
        XCTAssertTrue(welcomeTitle.waitForExistence(timeout: 8))
    }

    func testOnboardingCanAdvanceToServerSetup() {
        let app = XCUIApplication()
        let suiteName = "KumaNotifyUITests.\(UUID().uuidString)"
        app.launchEnvironment["KUMA_SETTINGS_SUITE_NAME"] = suiteName
        app.launchEnvironment["KUMA_UI_TEST_SHOW_ONBOARDING"] = "1"
        app.launch()

        let welcomeTitle = app.staticTexts["onboarding.welcomeTitle"]
        XCTAssertTrue(welcomeTitle.waitForExistence(timeout: 5))

        let getStartedButton = app.buttons["onboarding.getStartedButton"]
        XCTAssertTrue(getStartedButton.waitForExistence(timeout: 5))
        getStartedButton.click()

        let serverURLField = app.descendants(matching: .any)["onboarding.serverURLField"]
        XCTAssertTrue(serverURLField.waitForExistence(timeout: 8))

        let nextButton = app.descendants(matching: .any)["onboarding.nextButton"]
        XCTAssertTrue(nextButton.exists)
        XCTAssertFalse(nextButton.isEnabled)
    }

    func testProductionFirstLaunchCanAdvanceToServerSetup() {
        let app = XCUIApplication()
        let suiteName = "KumaNotifyUITests.productionOnboarding.\(UUID().uuidString)"
        app.launchEnvironment["KUMA_SETTINGS_SUITE_NAME"] = suiteName
        app.launch()

        let welcomeTitle = app.staticTexts["onboarding.welcomeTitle"]
        XCTAssertTrue(welcomeTitle.waitForExistence(timeout: 8))

        let getStartedButton = app.buttons["onboarding.getStartedButton"]
        XCTAssertTrue(getStartedButton.waitForExistence(timeout: 5))
        getStartedButton.click()

        let serverURLField = app.descendants(matching: .any)["onboarding.serverURLField"]
        let slugField = app.descendants(matching: .any)["onboarding.statusPageSlugField"]
        XCTAssertTrue(serverURLField.waitForExistence(timeout: 8))
        XCTAssertTrue(slugField.exists)
    }

    func testSettingsWindowShowsServerManagementControls() {
        let app = XCUIApplication()
        let suiteName = "KumaNotifyUITests.settings.\(UUID().uuidString)"
        app.launchEnvironment["KUMA_SETTINGS_SUITE_NAME"] = suiteName
        app.launchEnvironment["KUMA_UI_TEST_SHOW_SETTINGS"] = "1"
        app.launch()

        let addServerButton = app.buttons["settings.addServerButton"]
        XCTAssertTrue(addServerButton.waitForExistence(timeout: 8))
    }

    func testSettingsAddServerFlowValidatesAndPersistsConnection() {
        let app = XCUIApplication()
        let suiteName = "KumaNotifyUITests.settingsAdd.\(UUID().uuidString)"
        app.launchEnvironment["KUMA_SETTINGS_SUITE_NAME"] = suiteName
        app.launchEnvironment["KUMA_UI_TEST_SHOW_SETTINGS"] = "1"
        app.launch()

        let addServerButton = app.buttons["settings.addServerButton"]
        XCTAssertTrue(addServerButton.waitForExistence(timeout: 8))
        addServerButton.click()

        let serverURLField = app.descendants(matching: .any)["settings.serverURLField"]
        let slugField = app.descendants(matching: .any)["settings.statusPageSlugField"]
        let saveButton = app.buttons["settings.saveButton"]

        XCTAssertTrue(serverURLField.waitForExistence(timeout: 8))
        XCTAssertTrue(slugField.exists)
        XCTAssertTrue(saveButton.exists)
        XCTAssertFalse(saveButton.isEnabled)

        serverURLField.click()
        serverURLField.typeText("https://status.example.com")
        slugField.click()
        slugField.typeText("production")

        XCTAssertTrue(waitForEnabled(saveButton, timeout: 5))
        saveButton.click()

        XCTAssertTrue(addServerButton.waitForExistence(timeout: 8))
        XCTAssertFalse(addServerButton.isEnabled)
    }

    func testProductionSettingsSceneShowsServerManagementControls() {
        let app = XCUIApplication()
        let suiteName = "KumaNotifyUITests.productionSettings.\(UUID().uuidString)"
        app.launchEnvironment["KUMA_SETTINGS_SUITE_NAME"] = suiteName
        app.launchEnvironment["KUMA_UI_TEST_SEED_SERVER"] = "1"
        app.launch()
        app.typeKey(",", modifierFlags: .command)

        let addServerButton = app.buttons["settings.addServerButton"]
        XCTAssertTrue(addServerButton.waitForExistence(timeout: 8))
    }

    func testProductionSettingsSceneCanAddSecondServerThroughRealFlow() {
        let app = XCUIApplication()
        let suiteName = "KumaNotifyUITests.productionSettingsAdd.\(UUID().uuidString)"
        app.launchEnvironment["KUMA_SETTINGS_SUITE_NAME"] = suiteName
        app.launchEnvironment["KUMA_UI_TEST_SEED_SERVER"] = "1"
        app.launchEnvironment["KUMA_UI_TEST_FORCE_PRO"] = "1"
        app.launch()
        app.typeKey(",", modifierFlags: .command)

        let addServerButton = app.buttons["settings.addServerButton"]
        XCTAssertTrue(addServerButton.waitForExistence(timeout: 8))
        addServerButton.click()

        let serverURLField = app.descendants(matching: .any)["settings.serverURLField"]
        let slugField = app.descendants(matching: .any)["settings.statusPageSlugField"]
        let displayNameField = app.descendants(matching: .any)["settings.displayNameField"]
        let saveButton = app.buttons["settings.saveButton"]

        XCTAssertTrue(serverURLField.waitForExistence(timeout: 8))
        serverURLField.click()
        serverURLField.typeText("https://secondary.example.com")
        slugField.click()
        slugField.typeText("secondary")
        displayNameField.click()
        displayNameField.typeText("Secondary")

        XCTAssertTrue(waitForEnabled(saveButton, timeout: 5))
        saveButton.click()

        XCTAssertTrue(app.staticTexts["Secondary"].waitForExistence(timeout: 8))
        XCTAssertTrue(addServerButton.waitForExistence(timeout: 8))
        XCTAssertTrue(addServerButton.isEnabled)
    }

    func testPaywallWindowShowsPurchaseActions() {
        let app = XCUIApplication()
        let suiteName = "KumaNotifyUITests.paywall.\(UUID().uuidString)"
        app.launchEnvironment["KUMA_SETTINGS_SUITE_NAME"] = suiteName
        app.launchEnvironment["KUMA_UI_TEST_SHOW_PAYWALL"] = "1"
        app.launch()

        let upgradeButton = app.buttons["paywall.upgradeButton"]
        let restoreButton = app.descendants(matching: .any)["paywall.restoreButton"]
        XCTAssertTrue(upgradeButton.waitForExistence(timeout: 8))
        XCTAssertTrue(restoreButton.exists)
    }

    func testProductionDashboardWindowShowsMonitorRowsThroughRestoredFlow() {
        let app = XCUIApplication()
        let suiteName = "KumaNotifyUITests.productionDashboard.\(UUID().uuidString)"
        app.launchEnvironment["KUMA_SETTINGS_SUITE_NAME"] = suiteName
        app.launchEnvironment["KUMA_UI_TEST_SEED_SERVER"] = "1"
        app.launchEnvironment["KUMA_UI_TEST_USE_STUB_MONITORING"] = "1"
        app.launchEnvironment["KUMA_UI_TEST_OPEN_RESTORED_DASHBOARD"] = "1"
        app.launch()

        let primaryMonitor = app.buttons["dashboard.monitor.primary-api"]
        XCTAssertTrue(primaryMonitor.waitForExistence(timeout: 8))
    }

    func testProductionDashboardCanPresentPaywallFromMoreOptions() {
        let app = XCUIApplication()
        let suiteName = "KumaNotifyUITests.productionDashboardPaywall.\(UUID().uuidString)"
        app.launchEnvironment["KUMA_SETTINGS_SUITE_NAME"] = suiteName
        app.launchEnvironment["KUMA_UI_TEST_SEED_SERVER"] = "1"
        app.launchEnvironment["KUMA_UI_TEST_USE_STUB_MONITORING"] = "1"
        app.launchEnvironment["KUMA_UI_TEST_OPEN_RESTORED_DASHBOARD"] = "1"
        app.launch()

        let moreOptionsButton = app.descendants(matching: .any)["dashboard.moreOptionsButton"]
        XCTAssertTrue(moreOptionsButton.waitForExistence(timeout: 8))
        moreOptionsButton.click()

        let upgradeMenuItem = app.menuItems["Upgrade to Pro..."]
        XCTAssertTrue(upgradeMenuItem.waitForExistence(timeout: 8))
        upgradeMenuItem.click()

        let upgradeButton = app.buttons["paywall.upgradeButton"]
        XCTAssertTrue(upgradeButton.waitForExistence(timeout: 8))
    }

    func testDashboardWindowCanSwitchBetweenServers() {
        let app = XCUIApplication()
        let suiteName = "KumaNotifyUITests.dashboard.\(UUID().uuidString)"
        app.launchEnvironment["KUMA_SETTINGS_SUITE_NAME"] = suiteName
        app.launchEnvironment["KUMA_UI_TEST_SHOW_DASHBOARD"] = "1"
        app.launch()

        let primaryMonitor = app.buttons["dashboard.monitor.primary-api"]
        XCTAssertTrue(primaryMonitor.waitForExistence(timeout: 8))

        let serverPicker = app.popUpButtons["dashboard.serverPicker"]
        XCTAssertTrue(serverPicker.waitForExistence(timeout: 8))
        serverPicker.click()
        app.menuItems["Secondary"].click()

        let secondaryMonitor = app.buttons["dashboard.monitor.secondary-api"]
        XCTAssertTrue(secondaryMonitor.waitForExistence(timeout: 8))
    }

    func testDashboardIncidentHistoryCanOpenAndDismiss() {
        let app = XCUIApplication()
        let suiteName = "KumaNotifyUITests.dashboardHistory.\(UUID().uuidString)"
        app.launchEnvironment["KUMA_SETTINGS_SUITE_NAME"] = suiteName
        app.launchEnvironment["KUMA_UI_TEST_SHOW_DASHBOARD"] = "1"
        app.launch()

        let incidentHistoryButton = app.buttons["dashboard.incidentHistoryButton"]
        XCTAssertTrue(incidentHistoryButton.waitForExistence(timeout: 8))
        incidentHistoryButton.click()

        let historyTitle = app.staticTexts["dashboard.incidentHistoryTitle"]
        let backButton = app.buttons["dashboard.incidentHistoryBackButton"]
        XCTAssertTrue(historyTitle.waitForExistence(timeout: 8))
        XCTAssertTrue(backButton.exists)

        backButton.click()

        let primaryMonitor = app.buttons["dashboard.monitor.primary-api"]
        XCTAssertTrue(primaryMonitor.waitForExistence(timeout: 8))
    }

    func testDashboardSearchCanFilterAndClearResults() {
        let app = XCUIApplication()
        let suiteName = "KumaNotifyUITests.dashboardSearch.\(UUID().uuidString)"
        app.launchEnvironment["KUMA_SETTINGS_SUITE_NAME"] = suiteName
        app.launchEnvironment["KUMA_UI_TEST_SHOW_DASHBOARD"] = "1"
        app.launch()

        let primaryAPI = app.buttons["dashboard.monitor.primary-api"]
        let primaryDB = app.buttons["dashboard.monitor.primary-db"]
        XCTAssertTrue(primaryAPI.waitForExistence(timeout: 8))
        XCTAssertTrue(primaryDB.exists)

        let searchField = app.textFields["dashboard.searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 8))
        searchField.click()
        searchField.typeText("db")

        XCTAssertTrue(primaryDB.waitForExistence(timeout: 8))
        XCTAssertFalse(primaryAPI.exists)

        let clearSearchButton = app.buttons["dashboard.clearSearchButton"]
        XCTAssertTrue(clearSearchButton.waitForExistence(timeout: 8))
        clearSearchButton.click()

        XCTAssertTrue(primaryAPI.waitForExistence(timeout: 8))
        XCTAssertTrue(primaryDB.exists)
    }
}
