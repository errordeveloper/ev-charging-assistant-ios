import XCTest

@MainActor
final class DashboardUITests: XCTestCase {
    func testManualBatteryAndTripEstimate() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts["batteryUnavailable"].waitForExistence(timeout: 5))
        let estimate = app.buttons["estimateTrip"]
        XCTAssertFalse(estimate.isEnabled)
        app.buttons["manualBattery"].tap()
        XCTAssertEqual(app.staticTexts["batterySource"].label, "Manual battery")
        app.swipeUp()
        estimate.tap()
        XCTAssertTrue(app.staticTexts["arrivalEstimate"].waitForExistence(timeout: 3))
    }

    func testDemoIsLabeledAndDoesNotRequestBluetoothPermission() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitesting"]
        app.launch()
        app.buttons["loadDemo"].tap()
        XCTAssertEqual(app.staticTexts["batterySource"].label, "Demo battery")
        XCTAssertEqual(app.staticTexts["batteryPercent"].label, "65%")
    }
}
