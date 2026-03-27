import XCTest

@MainActor
final class KumaNotifyUITests: XCTestCase {
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

    func testSettingsWindowShowsServerManagementControls() {
        let app = XCUIApplication()
        let suiteName = "KumaNotifyUITests.settings.\(UUID().uuidString)"
        app.launchEnvironment["KUMA_SETTINGS_SUITE_NAME"] = suiteName
        app.launchEnvironment["KUMA_UI_TEST_SHOW_SETTINGS"] = "1"
        app.launch()

        let addServerButton = app.buttons["settings.addServerButton"]
        XCTAssertTrue(addServerButton.waitForExistence(timeout: 8))
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
}
