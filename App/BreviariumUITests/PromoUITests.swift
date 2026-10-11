import XCTest

/// Promotional stills and screen-recorded tours (2026-10-11), for the App Store listing
/// and elsewhere. Run only by `.github/workflows/promo.yml`, which sets
/// `TEST_RUNNER_BREVIARIUM_PROMO=1` and records the simulator's screen; App CI skips
/// them. The stills are attachments like the snapshot tests'; each tour is paced for
/// video, and the workflow cuts the recording at the "Test Case ... started" lines.
final class PromoUITests: BreviariumUITestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["BREVIARIUM_PROMO"] == "1", "promo captures run in promo.yml only")
        continueAfterFailure = false
    }

    private func pause(_ seconds: TimeInterval) { Thread.sleep(forTimeInterval: seconds) }

    private func openSettingsRow(_ app: XCUIApplication, _ row: String, title: String) {
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        pause(0.8)
        app.swipeUp()
        let button = app.buttons[row]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5))
    }

    // MARK: Stills

    func testPromoStills() {
        // Christmas Vespers, page 1 and the psalmody, in Nox.
        var app = launchApp(date: "2026-12-25", pageTurn: "curl")
        pause(0.8)
        capture(app, "promo-01-christmas-vespers")
        app.swipeLeft()
        pause(1.2)
        capture(app, "promo-02-christmas-psalmody")
        app.terminate()

        // Parallel English.
        app = launchApp(date: "2026-12-25", pageTurn: "curl", english: true)
        app.swipeLeft()
        pause(1.2)
        capture(app, "promo-03-english")
        app.terminate()

        // The hour picker and the calendar.
        app = launchApp(date: "2026-12-25", pageTurn: "curl", hour: "Laudes")
        app.staticTexts["hourPickerButton"].tap()
        XCTAssertTrue(app.buttons["hour-Laudes"].waitForExistence(timeout: 5))
        pause(1.0)
        capture(app, "promo-04-hours")
        app.terminate()

        app = launchApp(date: "2026-12-25", pageTurn: "curl")
        app.buttons["jumpToDateButton"].tap()
        XCTAssertTrue(app.navigationBars["Jump to date"].waitForExistence(timeout: 5))
        pause(2.0)
        capture(app, "promo-05-calendar")
        app.terminate()

        // Matins of All Saints in Vellum and Gentium.
        app = launchApp(date: "2026-11-01", pageTurn: "curl", hour: "Matutinum", theme: "vellum", font: "gentium")
        pause(0.8)
        capture(app, "promo-06-vellum-matins")
        app.terminate()

        // Lauds in Media nox.
        app = launchApp(date: "2027-03-28", pageTurn: "curl", hour: "Laudes", theme: "midnightBlue")
        pause(0.8)
        capture(app, "promo-07-easter-lauds")
        app.terminate()

        // The theme gallery.
        app = launchApp(date: "2026-12-25", pageTurn: "curl", hour: "Completorium", theme: "sepia")
        openSettingsRow(app, "themePicker", title: "Theme")
        pause(1.0)
        capture(app, "promo-08-themes")
        app.terminate()

        // The Dominican office on St Dominic's day, and Ambrosian Compline.
        app = launchApp(date: "2027-08-04", pageTurn: "curl", hour: "Vespera", rite: "dominicanus")
        pause(0.8)
        capture(app, "promo-09-dominican")
        app.terminate()

        app = launchApp(date: "2026-12-25", pageTurn: "curl", hour: "Completorium", rite: "ambrosianus")
        pause(0.8)
        capture(app, "promo-10-ambrosian")
        app.terminate()

        // Settings.
        app = launchApp(date: "2026-12-25", pageTurn: "curl")
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        pause(1.0)
        capture(app, "promo-11-settings")
        app.terminate()
    }

    // MARK: Tours, recorded as video

    /// Christmas Vespers, turning pages with the curl.
    func testTour1Pages() {
        let app = launchApp(date: "2026-12-25", pageTurn: "curl")
        pause(2.5)
        for _ in 0..<3 {
            app.swipeLeft()
            pause(2.0)
        }
    }

    /// The hour picker, to Compline.
    func testTour2Hours() {
        let app = launchApp(date: "2026-12-25", pageTurn: "curl")
        pause(1.5)
        app.staticTexts["hourPickerButton"].tap()
        XCTAssertTrue(app.buttons["hour-Completorium"].waitForExistence(timeout: 5))
        pause(2.0)
        app.buttons["hour-Completorium"].tap()
        XCTAssertTrue(app.staticTexts["Ad Completorium"].waitForExistence(timeout: 5))
        pause(2.0)
        app.swipeLeft()
        pause(2.0)
    }

    /// The calendar, with the colour of each day, to Easter.
    func testTour3Calendar() {
        let app = launchApp(date: "2027-03-01", pageTurn: "curl", hour: "Laudes")
        pause(1.5)
        app.buttons["jumpToDateButton"].tap()
        XCTAssertTrue(app.navigationBars["Jump to date"].waitForExistence(timeout: 5))
        pause(2.5)
        app.buttons["calendarDay-28"].tap()
        pause(2.5)
        app.swipeLeft()
        pause(2.0)
    }

    /// Parallel English.
    func testTour4English() {
        let app = launchApp(date: "2026-12-25", pageTurn: "curl", english: true)
        pause(2.0)
        for _ in 0..<2 {
            app.swipeLeft()
            pause(2.2)
        }
    }

    /// Settings -> Theme -> Vellum, and the office takes it.
    func testTour5Themes() {
        let app = launchApp(date: "2026-11-01", pageTurn: "curl", hour: "Matutinum")
        pause(1.5)
        openSettingsRow(app, "themePicker", title: "Theme")
        pause(1.5)
        let vellum = app.buttons["theme-vellum"]
        XCTAssertTrue(vellum.waitForExistence(timeout: 5))
        if !vellum.isHittable { app.swipeUp(); pause(0.8) }
        vellum.tap()
        pause(1.2)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        pause(0.8)
        app.buttons["Done"].tap()
        pause(2.0)
        app.swipeLeft()
        pause(2.0)
    }
}
