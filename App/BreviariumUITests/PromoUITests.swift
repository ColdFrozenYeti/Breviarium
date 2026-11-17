import UIKit
import XCTest

/// Promotional stills and screen-recorded tours (2026-10-11), for the App Store listing
/// and elsewhere. Run only by `.github/workflows/promo.yml`, which sets
/// `TEST_RUNNER_BREVIARIUM_PROMO=1` and records the simulator's screen; App CI skips
/// them. The stills are attachments like the snapshot tests'; each tour is paced for
/// video, and the workflow cuts the recording at the "Test Case ... started" lines.
/// The workflow runs them on an iPhone and on an iPad (1.4); the iPhone's stills and tours
/// skip on the iPad and the iPad's (landscape, the two-page spread) on the iPhone.
final class PromoUITests: BreviariumUITestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["BREVIARIUM_PROMO"] == "1", "promo captures run in promo.yml only")
        continueAfterFailure = false
    }

    private func pause(_ seconds: TimeInterval) { Thread.sleep(forTimeInterval: seconds) }

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    /// What promo.yml expects of the iPhone Duo in this pass (1.7): `open` (upright) or
    /// `side`, from `TEST_RUNNER_BREVIARIUM_DUO_EXPECT`; empty elsewhere.
    private var duoExpectation: String { ProcessInfo.processInfo.environment["BREVIARIUM_DUO_EXPECT"] ?? "" }

    /// The iPhone Duo open (1.7): an iPhone whose window is over 600 pt on its short side
    /// (669 x 951 upright). There a screen capture comes out black and swipes don't reach
    /// the inner screen, so its stills capture the window and open later pages at their
    /// section; promo.yml runs only the stills there (the tours are video made of swipes),
    /// and a failed check doesn't stop the stills after it. Folded, the Duo is an
    /// iPhone and takes the iPhone's path unchanged.
    private func isOpenDuo(_ app: XCUIApplication) -> Bool {
        let frame = app.windows.firstMatch.frame
        return !isPad && min(frame.width, frame.height) > 600
    }

    /// A still: the window on the open Duo, the screen elsewhere (as before 1.7).
    private func still(_ app: XCUIApplication, _ name: String) {
        if isOpenDuo(app) { captureWindow(app, name) } else { capture(app, name) }
    }

    /// A capture of the window, which in landscape keeps the screen's own orientation:
    /// `compose.py` turns it upright.
    private func captureWindow(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func turnLandscape() {
        XCUIDevice.shared.orientation = .landscapeLeft
        pause(1.5)
    }

    private func openSettingsRow(_ app: XCUIApplication, _ row: String, title: String) {
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        pause(0.8)
        // Swiped until the row is loaded: one swipe was not enough in an iPad's shorter
        // landscape sheet (1.4).
        let button = app.buttons[row]
        scrollSettings(to: button, in: app)
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        if !button.isHittable {
            app.collectionViews.firstMatch.swipeUp()
            pause(0.6)
        }
        button.tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5))
    }

    // MARK: Stills

    func testPromoStills() throws {
        try XCTSkipIf(isPad, "the iPad has its own stills")
        // Christmas Vespers, page 1 and the psalmody, in Nox.
        var app = launchApp(date: "2026-12-25", pageTurn: "curl")
        let openDuo = isOpenDuo(app)
        // promo.yml's open pass: stop at once if the Duo isn't open, rather than take the
        // folded screen's stills for the open one's.
        if duoExpectation == "open" {
            XCTAssertTrue(openDuo, "the iPhone Duo isn't open: \(app.windows.firstMatch.frame)")
        }
        // On the open Duo, one step that goes wrong mustn't lose every still after it.
        if openDuo { continueAfterFailure = true }
        pause(0.8)
        still(app, "promo-01-christmas-vespers")
        // The psalmody: on the open Duo it already starts on page 1, so no second still.
        if !openDuo {
            app.swipeLeft()
            pause(1.2)
            still(app, "promo-02-christmas-psalmody")
        }
        app.terminate()

        // Parallel English.
        app = launchApp(date: "2026-12-25", pageTurn: "curl", section: openDuo ? "hymnus" : nil, english: true)
        if !openDuo { app.swipeLeft() }
        pause(1.2)
        still(app, "promo-03-english")
        app.terminate()

        // The hour picker and the calendar.
        app = launchApp(date: "2026-12-25", pageTurn: "curl", hour: "Laudes")
        app.buttons["hourPickerButton"].tap()
        XCTAssertTrue(app.buttons["hour-Laudes"].waitForExistence(timeout: 5))
        pause(1.0)
        still(app, "promo-04-hours")
        app.terminate()

        app = launchApp(date: "2026-12-25", pageTurn: "curl")
        app.buttons["calendarButton"].tap()
        XCTAssertTrue(app.navigationBars["Kalendarium"].waitForExistence(timeout: 5))
        pause(2.0)
        still(app, "promo-05-calendar")
        app.terminate()

        // Matins of All Saints in Vellum and Gentium.
        app = launchApp(date: "2026-11-01", pageTurn: "curl", hour: "Matutinum", theme: "vellum", font: "gentium")
        pause(0.8)
        still(app, "promo-06-vellum-matins")
        app.terminate()

        // Lauds in Media nox.
        app = launchApp(date: "2027-03-28", pageTurn: "curl", hour: "Laudes", theme: "midnightBlue")
        pause(0.8)
        still(app, "promo-07-easter-lauds")
        app.terminate()

        // The theme gallery.
        app = launchApp(date: "2026-12-25", pageTurn: "curl", hour: "Completorium", theme: "sepia")
        openSettingsRow(app, "themePicker", title: "Theme")
        pause(1.0)
        still(app, "promo-08-themes")
        app.terminate()

        // The Dominican office on St Dominic's day, and Ambrosian Compline.
        app = launchApp(date: "2027-08-04", pageTurn: "curl", hour: "Vespera", rite: "dominicanus")
        pause(0.8)
        still(app, "promo-09-dominican")
        app.terminate()

        app = launchApp(date: "2026-12-25", pageTurn: "curl", hour: "Completorium", rite: "ambrosianus")
        pause(0.8)
        still(app, "promo-10-ambrosian")
        app.terminate()

        // Settings.
        app = launchApp(date: "2026-12-25", pageTurn: "curl")
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        pause(1.0)
        still(app, "promo-11-settings")
        app.terminate()
    }

    /// The open iPhone Duo on its side (1.7), turned by duoctl before this pass: the
    /// two-page spread and Latin and English on facing pages, for the inner screen's
    /// landscape screenshots (2853x2007, `compose.py --duo-side`). Window captures, which
    /// keep the screen's own orientation; compose.py turns them. Each still is checked to be
    /// a true spread, never one page in two columns.
    func testPromoStillsDuoSide() throws {
        try XCTSkipUnless(duoExpectation == "side", "the Duo on its side runs in promo.yml's own pass")
        var app = launchApp(date: "2026-12-25", pageTurn: "curl")
        let frame = app.windows.firstMatch.frame
        XCTAssertTrue(frame.width > frame.height && frame.height > 600, "the iPhone Duo isn't open on its side: \(frame)")
        continueAfterFailure = true

        func spread(_ app: XCUIApplication, _ name: String) {
            pause(1.2)
            let counter = app.staticTexts["pageCounter"]
            XCTAssertEqual(counter.value as? String, "spread", "\(name): \(counter.label)")
            captureWindow(app, name)
        }

        // Christmas Vespers on a spread.
        spread(app, "duo-side-01-spread")
        app.terminate()

        // Latin and English on facing pages.
        app = launchApp(date: "2026-12-25", pageTurn: "curl", english: true)
        spread(app, "duo-side-02-facing")
        app.terminate()

        // Matins of All Saints in Vellum and Gentium, facing pages.
        app = launchApp(date: "2026-11-01", pageTurn: "curl", english: true, hour: "Matutinum", theme: "vellum", font: "gentium")
        spread(app, "duo-side-03-vellum-matins")
        app.terminate()

        // The Dominican office on St Dominic's day, on a spread.
        app = launchApp(date: "2027-08-04", pageTurn: "curl", hour: "Vespera", rite: "dominicanus")
        spread(app, "duo-side-04-dominican")
        app.terminate()
    }

    // MARK: Tours, recorded as video

    /// Christmas Vespers, turning pages with the curl.
    func testTour1Pages() throws {
        try XCTSkipIf(isPad, "the iPad has its own tour")
        let app = launchApp(date: "2026-12-25", pageTurn: "curl")
        pause(2.5)
        for _ in 0..<3 {
            app.swipeLeft()
            pause(2.0)
        }
    }

    /// The hour picker, to Compline.
    func testTour2Hours() throws {
        try XCTSkipIf(isPad, "the iPad has its own tour")
        let app = launchApp(date: "2026-12-25", pageTurn: "curl")
        pause(1.5)
        app.buttons["hourPickerButton"].tap()
        XCTAssertTrue(app.buttons["hour-Completorium"].waitForExistence(timeout: 5))
        pause(2.0)
        app.buttons["hour-Completorium"].tap()
        XCTAssertTrue(app.buttons["Ad Completorium"].waitForExistence(timeout: 5))
        pause(2.0)
        app.swipeLeft()
        pause(2.0)
    }

    /// The calendar, with the colour of each day, to Easter.
    func testTour3Calendar() throws {
        try XCTSkipIf(isPad, "the iPad has its own tour")
        let app = launchApp(date: "2027-03-01", pageTurn: "curl", hour: "Laudes")
        pause(1.5)
        app.buttons["calendarButton"].tap()
        XCTAssertTrue(app.navigationBars["Kalendarium"].waitForExistence(timeout: 5))
        pause(2.5)
        // It opens on 1 March; Easter, the 28th, is further down.
        let easter = app.buttons["kalendariumDay-3-28"]
        for _ in 0..<8 where !(easter.exists && easter.isHittable) {
            app.swipeUp()
            pause(0.6)
        }
        easter.tap()
        pause(2.5)
        app.swipeLeft()
        pause(2.0)
    }

    /// Parallel English.
    func testTour4English() throws {
        try XCTSkipIf(isPad, "the iPad has its own tour")
        let app = launchApp(date: "2026-12-25", pageTurn: "curl", english: true)
        pause(2.0)
        for _ in 0..<2 {
            app.swipeLeft()
            pause(2.2)
        }
    }

    /// Settings -> Theme -> Vellum, and the office takes it.
    func testTour5Themes() throws {
        try XCTSkipIf(isPad, "the iPad has its own tour")
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

    // MARK: The iPad (1.4), in landscape

    /// The iPad's stills for its App Store screenshots: the two-page spread, Latin and
    /// English on facing pages, the Kalendarium, the hours, the themes and the rites.
    func testPromoStillsIPad() throws {
        try XCTSkipUnless(isPad, "iPad only")
        // Christmas Vespers on a spread.
        var app = launchApp(date: "2026-12-25", pageTurn: "curl")
        turnLandscape()
        captureWindow(app, "ipad-01-spread")
        app.terminate()

        // Facing pages.
        app = launchApp(date: "2026-12-25", pageTurn: "curl", english: true)
        turnLandscape()
        app.swipeLeft()
        pause(1.5)
        captureWindow(app, "ipad-02-facing")
        app.terminate()

        // The Kalendarium.
        app = launchApp(date: "2026-12-25", pageTurn: "curl")
        turnLandscape()
        app.buttons["calendarButton"].tap()
        XCTAssertTrue(app.navigationBars["Kalendarium"].waitForExistence(timeout: 5))
        pause(2.0)
        captureWindow(app, "ipad-03-calendar")
        app.terminate()

        // The hour picker.
        app = launchApp(date: "2026-12-25", pageTurn: "curl", hour: "Laudes")
        turnLandscape()
        app.buttons["hourPickerButton"].tap()
        XCTAssertTrue(app.buttons["hour-Laudes"].waitForExistence(timeout: 5))
        pause(1.0)
        captureWindow(app, "ipad-04-hours")
        app.terminate()

        // Matins of All Saints in Vellum and Gentium, facing pages.
        app = launchApp(date: "2026-11-01", pageTurn: "curl", english: true, hour: "Matutinum", theme: "vellum", font: "gentium")
        turnLandscape()
        captureWindow(app, "ipad-05-vellum-matins")
        app.terminate()

        // The theme gallery.
        app = launchApp(date: "2026-12-25", pageTurn: "curl", hour: "Completorium", theme: "sepia")
        turnLandscape()
        openSettingsRow(app, "themePicker", title: "Theme")
        pause(1.0)
        captureWindow(app, "ipad-06-themes")
        app.terminate()

        // The Dominican office on St Dominic's day, and Ambrosian Compline.
        app = launchApp(date: "2027-08-04", pageTurn: "curl", hour: "Vespera", rite: "dominicanus")
        turnLandscape()
        captureWindow(app, "ipad-07-dominican")
        app.terminate()

        app = launchApp(date: "2026-12-25", pageTurn: "curl", hour: "Completorium", rite: "ambrosianus")
        turnLandscape()
        captureWindow(app, "ipad-08-ambrosian")
        app.terminate()

        // Settings.
        app = launchApp(date: "2026-12-25", pageTurn: "curl")
        turnLandscape()
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        pause(1.0)
        captureWindow(app, "ipad-09-settings")
        app.terminate()
        XCUIDevice.shared.orientation = .portrait
    }

    /// Christmas Vespers on a spread, the curl turning a leaf about the spine.
    func testTourIPadSpread() throws {
        try XCTSkipUnless(isPad, "iPad only")
        let app = launchApp(date: "2026-12-25", pageTurn: "curl")
        turnLandscape()
        pause(1.5)
        for _ in 0..<3 {
            app.swipeLeft()
            pause(2.2)
        }
        XCUIDevice.shared.orientation = .portrait
    }
}
