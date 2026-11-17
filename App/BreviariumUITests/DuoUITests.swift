import XCTest

/// The iPhone Duo (1.7, `docs/1.7_plan.md`, M2), run on the iPhone Duo simulator open:
/// its inner screen (about 669 x 951 pt) is of regular width and height. Upright, one
/// page with widened margins; on its side, the two-page spread, with Latin and English
/// on facing pages, as on the iPad. Folded, the Duo is a standard iPhone, which the
/// iPhone passes cover; the fold itself is checked on the device.
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

    /// The simulator is the Duo open: a window wider than any iPhone's (at most 440 pt).
    private func assertOpen(_ app: XCUIApplication) {
        let frame = app.windows.firstMatch.frame
        XCTAssertGreaterThan(min(frame.width, frame.height), 600, "the iPhone Duo should be open: \(frame)")
    }

    /// Upright: one page, English off and on.
    func testUpright() {
        for english in [false, true] {
            let app = launchApp(date: "2026-09-16", english: english)
            assertOpen(app)
            Thread.sleep(forTimeInterval: 1.0)
            XCTAssertTrue(counter(app).hasPrefix("Page 1 of"), counter(app))
            capture(app, "duo-upright-english\(english ? "On" : "Off")-1")
            turnPage(app)
            XCTAssertTrue(counter(app).hasPrefix("Page 2 of"), counter(app))
            capture(app, "duo-upright-english\(english ? "On" : "Off")-2")
            app.terminate()
        }
    }

    /// On its side: the spread (`Page 1–2 of N`), then English on facing pages (each
    /// spread one page), and back upright at the same place.
    func testSpreadOnItsSide() {
        let app = launchApp(date: "2026-09-16", pageTurn: "curl")
        turnLandscape()
        XCTAssertTrue(counter(app).hasPrefix("Page 1–2 of"), counter(app))
        captureWindow(app, "duo-spread-1")
        turnPage(app)
        XCTAssertTrue(counter(app).hasPrefix("Page 3–4 of"), counter(app))
        captureWindow(app, "duo-spread-2")
        XCUIDevice.shared.orientation = .portrait
        Thread.sleep(forTimeInterval: 1.5)
        XCTAssertFalse(counter(app).contains("–"), counter(app))
        capture(app, "duo-spread-back-upright")
        app.terminate()

        let english = launchApp(date: "2026-09-16", english: true)
        turnLandscape()
        XCTAssertTrue(counter(english).hasPrefix("Page 1 of"), counter(english))
        captureWindow(english, "duo-facing-1")
        turnPage(english)
        XCTAssertTrue(counter(english).hasPrefix("Page 2 of"), counter(english))
        captureWindow(english, "duo-facing-2")
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
        XCTAssertTrue(waitForLabel(hidden.staticTexts["pageNumber"], "1–2"))
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
