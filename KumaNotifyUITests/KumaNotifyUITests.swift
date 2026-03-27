import XCTest

@MainActor
final class KumaNotifyUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
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
}
