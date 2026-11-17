import XCTest

/// The iPhone Duo (1.7, `docs/1.7_plan.md`, M2 and M5a), run on the iPhone Duo simulator
/// open flat: `scripts/ci-simulator.sh` opens it with duoctl, as the simulator boots
/// folded (its outer screen, 1398 x 2034 px, is what App CI's first Duo runs tested). Open,
/// the inner screen is 669 x 951 pt. XCUITest's swipes don't reach the inner screen and
/// `XCUIDevice` can't turn it, so these tests reach a later page by opening the hour at a
/// section (`BREVIARIUM_SNAPSHOT_SECTION`), and the Duo on its side is a pass of its own,
/// turned by duoctl (`DuoSideUITests`). Taps work. Folded, the Duo is a standard iPhone,
/// which the iPhone passes cover; the fold itself is checked on the device.
class DuoTestCase: BreviariumUITestCase {
    func captureWindow(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    func counter(_ app: XCUIApplication) -> String { app.staticTexts["pageCounter"].label }

    /// The window's size, kept with the captures.
    func recordWindow(_ app: XCUIApplication, _ name: String) {
        let note = XCTAttachment(string: "\(app.windows.firstMatch.frame)")
        note.name = "duo-window-\(name)"
        note.lifetime = .keepAlways
        add(note)
    }

    /// The Duo is open: a window wider than any iPhone's (at most 440 pt) on its short side.
    /// If duoctl couldn't open it (`ci-simulator.sh` then warns), the test is skipped rather
    /// than run on the folded screen.
    func requireOpen(_ app: XCUIApplication) throws {
        let frame = app.windows.firstMatch.frame
        try XCTSkipUnless(min(frame.width, frame.height) > 600, "the iPhone Duo isn't open: \(frame)")
    }
}

/// The open Duo, upright (669 x 951 pt), turned by duoctl: one page with widened margins.
/// It opens on its side, so if duoctl couldn't turn it these skip.
final class DuoUITests: DuoTestCase {
    private func requireUpright(_ app: XCUIApplication) throws {
        let frame = app.windows.firstMatch.frame
        try XCTSkipUnless(frame.height > frame.width, "the open Duo isn't upright: \(frame)")
    }

    /// Page 1 and the psalmody, English off and on.
    func testUpright() throws {
        for english in [false, true] {
            let app = launchApp(date: "2026-09-16", english: english)
            recordWindow(app, "upright")
            try requireOpen(app)
            try requireUpright(app)
            Thread.sleep(forTimeInterval: 1.0)
            XCTAssertTrue(counter(app).hasPrefix("Page 1 of"), counter(app))
            capture(app, "duo-upright-english\(english ? "On" : "Off")-1")
            app.terminate()

            let later = launchApp(date: "2026-09-16", section: "psalmodia", english: english)
            Thread.sleep(forTimeInterval: 1.0)
            XCTAssertFalse(counter(later).hasPrefix("Page 1 of"), counter(later))
            capture(later, "duo-upright-english\(english ? "On" : "Off")-psalmody")
            later.terminate()
        }
    }

    /// Vertical scrolling, *Menus: Hidden*, the Kalendarium, Settings and Notifications.
    func testSettings() throws {
        let vertical = launchApp(date: "2026-09-16", readingMode: "vertical")
        try requireOpen(vertical)
        try requireUpright(vertical)
        capture(vertical, "duo-vertical")
        vertical.terminate()

        let hidden = launchApp(date: "2026-09-16", menus: "hidden")
        XCTAssertTrue(waitForLabel(hidden.staticTexts["pageNumber"], "1"))
        capture(hidden, "duo-menus-hidden")
        hidden.terminate()

        let app = launchApp(date: "2026-11-19")
        app.buttons["calendarButton"].tap()
        XCTAssertTrue(app.navigationBars["Kalendarium"].waitForExistence(timeout: 5))
        let day = app.buttons["kalendariumDay-11-19"]
        XCTAssertTrue(day.exists && day.isHittable, "the first frame should show 19 November")
        Thread.sleep(forTimeInterval: 1.5)
        capture(app, "duo-kalendarium")
        app.buttons["Close"].tap()
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.0)
        capture(app, "duo-settings")
        let row = app.buttons["notificationsRow"]
        scrollSettings(to: row, in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.navigationBars["Notifications"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        capture(app, "duo-notifications")
        app.terminate()
    }
}

/// The open Duo on its side (951 x 669 pt), turned by duoctl before this pass: the
/// two-page spread, as on the iPad, and the Latin and English on facing pages.
final class DuoSideUITests: DuoTestCase {
    /// Whether this window shows a spread: horizontal pages, at least 900 pt wide and
    /// wider than tall (`VespersView.isSpread`).
    private func spreads(_ app: XCUIApplication) -> Bool {
        let frame = app.windows.firstMatch.frame
        return frame.width >= 900 && frame.width > frame.height
    }

    func testSpread() throws {
        let app = launchApp(date: "2026-09-16", pageTurn: "curl")
        recordWindow(app, "side")
        try requireOpen(app)
        try XCTSkipUnless(spreads(app), "duoctl didn't turn the Duo: \(app.windows.firstMatch.frame)")
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertTrue(counter(app).hasPrefix("Page 1–2 of"), counter(app))
        captureWindow(app, "duo-side-spread-1")
        app.terminate()

        let later = launchApp(date: "2026-09-16", pageTurn: "curl", section: "psalmodia")
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertTrue(counter(later).contains("–"), counter(later))
        captureWindow(later, "duo-side-spread-psalmody")
        later.terminate()

        let hidden = launchApp(date: "2026-09-16", menus: "hidden")
        XCTAssertTrue(waitForLabel(hidden.staticTexts["pageNumber"], "1–2"))
        captureWindow(hidden, "duo-side-menus-hidden")
        hidden.terminate()
    }

    /// English on: Latin on the left page and English on the right, each spread one page.
    func testFacingEnglish() throws {
        let app = launchApp(date: "2026-09-16", english: true)
        try requireOpen(app)
        try XCTSkipUnless(spreads(app), "duoctl didn't turn the Duo: \(app.windows.firstMatch.frame)")
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertTrue(counter(app).hasPrefix("Page 1 of"), counter(app))
        captureWindow(app, "duo-side-facing-1")
        app.terminate()

        let later = launchApp(date: "2026-09-16", section: "psalmodia", english: true)
        Thread.sleep(forTimeInterval: 1.0)
        captureWindow(later, "duo-side-facing-psalmody")
        later.terminate()

        let vertical = launchApp(date: "2026-09-16", readingMode: "vertical")
        captureWindow(vertical, "duo-side-vertical")
        vertical.terminate()
    }
}
