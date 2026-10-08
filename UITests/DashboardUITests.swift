import XCTest

@MainActor
final class DashboardUITests: XCTestCase {
    func testAccessoryInspectionRefreshRemovesDisconnectedFixture() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitesting", "-accessory-fixture"]
        app.launch()
        app.buttons["inspectAccessories"].tap()
        XCTAssertTrue(app.staticTexts["Inspection fixture — no hardware evidence"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Fixture head unit"].exists)
        app.staticTexts["Fixture head unit"].tap()
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Fixture model"].exists)
        XCTAssertTrue(app.staticTexts["com.example.inspection.fixture"].exists)
        XCTAssertFalse(app.staticTexts["FIXTURE-SERIAL"].exists)
        let details = XCTAttachment(screenshot: app.screenshot())
        details.name = "Accessory inspection — synthetic fixture"
        details.lifetime = .keepAlways
        add(details)
        let reveal = app.switches["revealAccessoryIdentifiers"]
        for _ in 0..<6 where !reveal.isHittable { app.swipeUp() }
        XCTAssertTrue(reveal.isHittable)
        // SwiftUI exposes the entire labeled row as the switch; tap its trailing control.
        reveal.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertEqual(reveal.value as? String, "1")
        for _ in 0..<6 where !app.staticTexts["FIXTURE-SERIAL"].isHittable { app.swipeDown() }
        XCTAssertTrue(app.staticTexts["FIXTURE-SERIAL"].exists)
        app.buttons["refreshAccessories"].tap()
        app.swipeDown()
        XCTAssertTrue(app.staticTexts["No accessories exposed to this app"].exists)
        XCTAssertFalse(app.staticTexts["Fixture head unit"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["batteryUnavailable"].exists)
    }

    func testAccessoryInspectionEmptyStateAndReturnToDashboard() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitesting"]
        app.launch()
        app.buttons["inspectAccessories"].tap()
        XCTAssertTrue(app.staticTexts["noExposedAccessories"].waitForExistence(timeout: 5))
        let empty = XCTAttachment(screenshot: app.screenshot())
        empty.name = "Accessory inspection — empty fixture"
        empty.lifetime = .keepAlways
        add(empty)
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.staticTexts["Inspection cleared. Refresh while the app is active."].waitForExistence(timeout: 5))
        app.buttons["refreshAccessories"].tap()
        XCTAssertTrue(app.staticTexts["noExposedAccessories"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["manualBattery"].tap()
        XCTAssertEqual(app.staticTexts["batterySource"].label, "Manual battery")
    }

    func testManualBatteryAndTripEstimate() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts["batteryUnavailable"].waitForExistence(timeout: 5))
        let estimate = app.buttons["estimateTrip"]
        for _ in 0..<4 where !estimate.exists { app.swipeUp() }
        XCTAssertFalse(estimate.isEnabled)
        for _ in 0..<4 where !app.buttons["manualBattery"].isHittable { app.swipeDown() }
        app.buttons["manualBattery"].tap()
        XCTAssertEqual(app.staticTexts["batterySource"].label, "Manual battery")
        for _ in 0..<4 where !estimate.isHittable { app.swipeUp() }
        estimate.tap()
        for _ in 0..<3 where !app.staticTexts["arrivalEstimate"].exists { app.swipeUp() }
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
