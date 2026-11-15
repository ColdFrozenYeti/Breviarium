import XCTest

/// The reminders (1.6, `docs/1.6_plan.md` §5): the *Notifications* page, through the
/// debug-only stand-in for the notification centre (`BREVIARIUM_NOTIFICATIONS`), which
/// lists what is scheduled in `remindersPending`; one test uses the real centre. Run on
/// the iPhone 17 and, in the iPad pass, on the iPad Air 11" (M3).
final class NotificationsUITests: BreviariumUITestCase {
    private var device: String { UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone" }

    /// Lauds 07:00, Vespers 18:00 and Compline 21:00 on.
    private static let someOn = #"{"Laudes":{"isOn":true,"hour":7,"minute":0},"Vespera":{"isOn":true,"hour":18,"minute":0},"Completorium":{"isOn":true,"hour":21,"minute":0}}"#

    /// Opens Settings, then the *Notifications* page.
    @discardableResult
    private func openPage(mode: String? = "granted", reminders: String = "{}", theme: String = "classicDark") -> XCUIApplication {
        var environment = ["BREVIARIUM_SNAPSHOT_REMINDERS": reminders]
        if let mode { environment["BREVIARIUM_NOTIFICATIONS"] = mode }
        let app = launchApp(date: "2026-09-16", theme: theme, environment: environment)
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        let row = app.buttons["notificationsRow"]
        scrollSettings(to: row, in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.navigationBars["Notifications"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        return app
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        snap(app.screenshot(), name)
    }

    private func snap(_ screenshot: XCUIScreenshot, _ name: String) {
        let shot = XCTAttachment(screenshot: screenshot)
        shot.name = "notifications-\(device)-\(name)"
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func reminderSwitch(_ app: XCUIApplication, _ key: String) -> XCUIElement { app.switches["reminder-\(key)"] }

    private func isOn(_ element: XCUIElement) -> Bool { (element.value as? String) == "1" }

    /// Flips a switch; a tap on a label-less switch's middle sometimes misses its knob,
    /// so it taps the right-hand side if the first tap did nothing.
    private func flip(_ element: XCUIElement) {
        let before = isOn(element)
        element.tap()
        Thread.sleep(forTimeInterval: 0.5)
        if isOn(element) == before {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)).tap()
        }
    }

    /// What is scheduled, `hour.Laudes 07:00, …`, waiting for `expected` if given.
    private func pending(_ app: XCUIApplication, waitingFor expected: String? = nil) -> String {
        let element = app.descendants(matching: .any)["remindersPending"]
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        if let expected {
            let predicate = NSPredicate(format: "value == %@", expected)
            _ = XCTWaiter().wait(for: [expectation(for: predicate, evaluatedWith: element)], timeout: 5)
        }
        return element.value as? String ?? ""
    }

    /// All off by default, nothing scheduled, and the Settings row says *Off*.
    func testAllOffByDefault() {
        let app = launchApp(date: "2026-09-16", environment: ["BREVIARIUM_NOTIFICATIONS": "granted"])
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        let row = app.buttons["notificationsRow"]
        scrollSettings(to: row, in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Off"), row.label)
        snap(app, "settings-row")
        row.tap()
        XCTAssertTrue(app.navigationBars["Notifications"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        // Nine rows, the Martyrology after Prime.
        for key in ["Matutinum", "Laudes", "Prima", "martyrologium", "Tertia", "Sexta", "Nona", "Vespera", "Completorium"] {
            XCTAssertTrue(reminderSwitch(app, key).exists, key)
            XCTAssertFalse(isOn(reminderSwitch(app, key)), key)
        }
        XCTAssertTrue(app.staticTexts["Martyrologium"].frame.minY > app.staticTexts["Ad Primam"].frame.minY)
        XCTAssertEqual(pending(app), "")
        XCTAssertFalse(app.staticTexts["notificationsRefused"].exists)
        snap(app, "all-off")
        app.terminate()
    }

    /// Some on, at their times; the Settings row counts them.
    func testSomeOn() {
        let app = openPage(mode: "allowed", reminders: Self.someOn)
        XCTAssertEqual(pending(app, waitingFor: "hour.Completorium 21:00, hour.Laudes 07:00, hour.Vespera 18:00"),
                       "hour.Completorium 21:00, hour.Laudes 07:00, hour.Vespera 18:00")
        XCTAssertTrue(isOn(reminderSwitch(app, "Vespera")))
        XCTAssertTrue(app.descendants(matching: .any)["reminderTime-Vespera"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["reminderTime-Prima"].exists)
        snap(app, "some-on")
        app.navigationBars["Notifications"].buttons.firstMatch.tap()
        let row = app.buttons["notificationsRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("3 hours"), row.label)
        app.terminate()
        // The same on a light theme.
        let light = openPage(mode: "allowed", reminders: Self.someOn, theme: "light")
        snap(light, "some-on-lux")
        light.terminate()
    }

    /// Turning an hour on asks, sets its suggested time and schedules just that one;
    /// turning it off removes it. The Martyrology's is 08:15.
    func testTurningOnSetsTheSuggestedTime() {
        let app = openPage(mode: "granted")
        flip(reminderSwitch(app, "Laudes"))
        XCTAssertTrue(isOn(reminderSwitch(app, "Laudes")))
        XCTAssertEqual(pending(app, waitingFor: "hour.Laudes 07:00"), "hour.Laudes 07:00")
        flip(reminderSwitch(app, "martyrologium"))
        XCTAssertEqual(pending(app, waitingFor: "hour.Laudes 07:00, hour.martyrologium 08:15"), "hour.Laudes 07:00, hour.martyrologium 08:15")
        flip(reminderSwitch(app, "Laudes"))
        XCTAssertFalse(isOn(reminderSwitch(app, "Laudes")))
        XCTAssertEqual(pending(app, waitingFor: "hour.martyrologium 08:15"), "hour.martyrologium 08:15")
        app.terminate()
    }

    /// Any time for any hour (decided 2026-11-14): Vespers at 07:00 is scheduled so.
    func testAnyTimeForAnyHour() {
        let app = openPage(mode: "allowed", reminders: #"{"Vespera":{"isOn":true,"hour":7,"minute":0}}"#)
        XCTAssertEqual(pending(app, waitingFor: "hour.Vespera 07:00"), "hour.Vespera 07:00")
        app.terminate()
    }

    /// A time being edited: the compact picker open on Vespers; a new hour is scheduled.
    func testEditingATime() {
        let app = openPage(mode: "allowed", reminders: Self.someOn)
        let time = app.descendants(matching: .any)["reminderTime-Vespera"].firstMatch
        XCTAssertTrue(time.waitForExistence(timeout: 5))
        time.tap()
        Thread.sleep(forTimeInterval: 1.0)
        snap(app, "editing-time")
        // Where the picker shows wheels, turn the hour and check the schedule follows.
        let wheels = app.pickerWheels
        if wheels.count >= 2 {
            let hourWheel = wheels.element(boundBy: 0)
            let current = hourWheel.value as? String ?? ""
            hourWheel.adjust(toPickerWheelValue: current.hasPrefix("7") ? "8" : "7")
            Thread.sleep(forTimeInterval: 0.8)
            snap(app, "editing-time-changed")
            XCTAssertFalse(pending(app).contains("hour.Vespera 18:00"), pending(app))
        }
        app.terminate()
    }

    /// Refused: the switch goes back off, nothing is scheduled, and the footer says how
    /// to allow notifications.
    func testRefusedPermission() {
        let app = openPage(mode: "denied")
        flip(reminderSwitch(app, "Vespera"))
        XCTAssertTrue(app.staticTexts["notificationsRefused"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertFalse(isOn(reminderSwitch(app, "Vespera")))
        XCTAssertEqual(pending(app), "")
        snap(app, "refused")
        app.terminate()
    }

    /// A tap on a reminder opens its hour on the day delivered (as a widget's link):
    /// Christmas Lauds, and the Martyrology of Christmas Eve (Christmas's entry).
    func testATapOpensTheHour() {
        let lauds = launchApp(
            date: "2026-09-16", expectedTitle: "Ad Laudes", environment: ["BREVIARIUM_SNAPSHOT_REMINDER": "Laudes@2026-12-25"]
        )
        snap(lauds, "tap-christmas-lauds")
        lauds.terminate()
        let martyrology = launchApp(
            date: "2026-09-16", expectedTitle: "Martyrologium", environment: ["BREVIARIUM_SNAPSHOT_REMINDER": "martyrologium@2026-12-24"]
        )
        snap(martyrology, "tap-martyrology-christmas-eve")
        martyrology.terminate()
    }

    /// The real notification centre, once: Vespers on, the system's alert allowed, one
    /// request pending; then off again, so nothing is left scheduled on the simulator.
    func testTheRealNotificationCentre() {
        let app = openPage(mode: nil)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        flip(reminderSwitch(app, "Vespera"))
        let allow = springboard.alerts.firstMatch.buttons["Allow"]
        if allow.waitForExistence(timeout: 5) {
            // The system's alert is SpringBoard's, over the app: the whole screen.
            snap(XCUIScreen.main.screenshot(), "system-alert")
            allow.tap()
        }
        XCTAssertEqual(pending(app, waitingFor: "hour.Vespera 18:00"), "hour.Vespera 18:00")
        flip(reminderSwitch(app, "Vespera"))
        XCTAssertEqual(pending(app, waitingFor: ""), "")
        app.terminate()
    }
}
