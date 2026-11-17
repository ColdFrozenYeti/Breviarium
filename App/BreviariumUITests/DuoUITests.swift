import XCTest

/// The iPhone Duo (1.7, `docs/1.7_plan.md`, M2), run on the iPhone Duo simulator open.
/// Its inner screen there is 466 x 678 pt, with a strip of about 86 pt down the right
/// edge kept for the vertical status bar, and it doesn't turn with the device (run
/// 44083214618): the app gets one page about 380 pt wide. The spread is decided by the
/// window's size alone (`VespersView.isSpread`), so these tests follow what the window
/// is: a spread where it is at least 900 pt wide and wider than tall, one page otherwise.
/// Folded, the Duo is a standard iPhone, which the iPhone passes cover; the fold and a
/// real Duo's screen are checked on the device.
final class DuoUITests: BreviariumUITestCase {
    private func captureWindow(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func turnLandscape() {
        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 1.5)
    }

    private func counter(_ app: XCUIApplication) -> String { app.staticTexts["pageCounter"].label }

    /// A page turn, swiped once more if the first swipe didn't take.
    private func turnPage(_ app: XCUIApplication) {
        let before = counter(app)
        app.swipeLeft()
        Thread.sleep(forTimeInterval: 1.0)
        if counter(app) == before {
            app.swipeLeft()
            Thread.sleep(forTimeInterval: 1.0)
        }
    }

    /// Whether this window shows a spread: horizontal pages, at least 900 pt wide and
    /// wider than tall (the inner screen is of regular height when open).
    private func spreads(_ app: XCUIApplication) -> Bool {
        let frame = app.windows.firstMatch.frame
        return frame.width >= 900 && frame.width > frame.height
    }

    /// The window's size, kept with the captures.
    private func recordWindow(_ app: XCUIApplication, _ name: String) {
        let note = XCTAttachment(string: "\(app.windows.firstMatch.frame)")
        note.name = "duo-window-\(name)"
        note.lifetime = .keepAlways
        add(note)
    }

    /// Upright: one page, English off and on.
    func testUpright() {
        for english in [false, true] {
            let app = launchApp(date: "2026-09-16", english: english)
            recordWindow(app, "upright")
            Thread.sleep(forTimeInterval: 1.0)
            XCTAssertTrue(counter(app).hasPrefix("Page 1 of"), counter(app))
            capture(app, "duo-upright-english\(english ? "On" : "Off")-1")
            turnPage(app)
            XCTAssertTrue(counter(app).hasPrefix("Page 2 of"), counter(app))
            capture(app, "duo-upright-english\(english ? "On" : "Off")-2")
            app.terminate()
        }
    }

    /// On its side: the spread (`Page 1–2 of N`) where the window is wide enough, then
    /// English on facing pages (each spread one page), and back upright at the same
    /// place; one page where it isn't.
    func testOnItsSide() {
        let app = launchApp(date: "2026-09-16", pageTurn: "curl")
        turnLandscape()
        recordWindow(app, "side")
        let spread = spreads(app)
        XCTAssertTrue(counter(app).hasPrefix(spread ? "Page 1–2 of" : "Page 1 of"), counter(app))
        captureWindow(app, "duo-side-1")
        turnPage(app)
        XCTAssertTrue(counter(app).hasPrefix(spread ? "Page 3–4 of" : "Page 2 of"), counter(app))
        captureWindow(app, "duo-side-2")
        XCUIDevice.shared.orientation = .portrait
        Thread.sleep(forTimeInterval: 1.5)
        capture(app, "duo-side-back-upright")
        app.terminate()

        let english = launchApp(date: "2026-09-16", english: true)
        turnLandscape()
        XCTAssertTrue(counter(english).hasPrefix("Page 1 of"), counter(english))
        captureWindow(english, "duo-side-english-1")
        turnPage(english)
        XCTAssertTrue(counter(english).hasPrefix("Page 2 of"), counter(english))
        captureWindow(english, "duo-side-english-2")
        english.terminate()
    }

    /// The other settings: vertical scrolling on its side (no spread), *Menus: Hidden* on
    /// a spread, the Kalendarium, and the Notifications page.
    func testSettings() {
        let vertical = launchApp(date: "2026-09-16", readingMode: "vertical")
        turnLandscape()
        captureWindow(vertical, "duo-vertical-landscape")
        vertical.terminate()

        let hidden = launchApp(date: "2026-09-16", menus: "hidden")
        turnLandscape()
        XCTAssertTrue(waitForLabel(hidden.staticTexts["pageNumber"], spreads(hidden) ? "1–2" : "1"))
        captureWindow(hidden, "duo-menus-hidden")
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
