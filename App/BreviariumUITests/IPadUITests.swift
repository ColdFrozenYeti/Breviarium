import XCTest

/// The iPad (1.4, `docs/1.4_plan.md`, M3), run on an iPad Air 11" (M3) simulator, the
/// device App Review used: the two-page spread in landscape, Latin and English on facing
/// pages, one page in portrait, and the same settings as the iPhone (vertical scrolling,
/// the slide and the curl, *Menus: Hidden*, the Kalendarium).
final class IPadUITests: BreviariumUITestCase {
    /// A landscape capture, the window turned the right way up.
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

    /// English off in landscape: two pages at a time, page 1's header on the left page,
    /// the footer counting both (`Page 1–2 of N`); with the slide and with the curl.
    func testSpreadLandscape() {
        for turn in ["slide", "curl"] {
            let app = launchApp(date: "2026-09-16", pageTurn: turn)
            turnLandscape()
            XCTAssertTrue(counter(app).hasPrefix("Page 1–2 of"), counter(app))
            captureWindow(app, "ipad-spread-\(turn)-1")
            app.swipeLeft()
            Thread.sleep(forTimeInterval: 1.0)
            XCTAssertTrue(counter(app).hasPrefix("Page 3–4 of"), counter(app))
            captureWindow(app, "ipad-spread-\(turn)-2")
            // Back to portrait: one page, at the same place in the hour.
            XCUIDevice.shared.orientation = .portrait
            Thread.sleep(forTimeInterval: 1.5)
            XCTAssertFalse(counter(app).contains("–"), counter(app))
            captureWindow(app, "ipad-spread-\(turn)-portrait")
            app.terminate()
        }
    }

    /// English on in landscape: Latin on the left page, English on the right, each spread
    /// one page in the footer; and a Matins lesson on facing pages.
    func testFacingEnglish() {
        let app = launchApp(date: "2026-09-16", english: true)
        turnLandscape()
        XCTAssertTrue(counter(app).hasPrefix("Page 1 of"), counter(app))
        captureWindow(app, "ipad-facing-1")
        app.swipeLeft()
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertTrue(counter(app).hasPrefix("Page 2 of"), counter(app))
        captureWindow(app, "ipad-facing-2")
        app.terminate()

        let matins = launchApp(date: "2026-11-01", section: "nocturnusII", english: true, hour: "Matutinum")
        turnLandscape()
        captureWindow(matins, "ipad-facing-matins-nocturn2")
        matins.swipeLeft()
        Thread.sleep(forTimeInterval: 1.0)
        captureWindow(matins, "ipad-facing-matins-lesson")
        matins.terminate()
    }

    /// Portrait: one page, as on the iPhone, with the line held to about 34 em; English on
    /// side by side.
    func testPortrait() {
        for english in [false, true] {
            let app = launchApp(date: "2026-09-16", english: english)
            Thread.sleep(forTimeInterval: 1.0)
            XCTAssertTrue(counter(app).hasPrefix("Page 1 of"), counter(app))
            capture(app, "ipad-portrait-english\(english ? "On" : "Off")-1")
            app.swipeLeft()
            Thread.sleep(forTimeInterval: 1.0)
            capture(app, "ipad-portrait-english\(english ? "On" : "Off")-2")
            app.terminate()
        }
    }

    /// The same settings as the iPhone: vertical scrolling in landscape (one scroll, no
    /// spread), *Menus: Hidden* on a spread (`1–2`), and the Kalendarium.
    func testSettingsAsOnIPhone() {
        let vertical = launchApp(date: "2026-09-16", readingMode: "vertical")
        turnLandscape()
        captureWindow(vertical, "ipad-vertical-landscape")
        vertical.terminate()

        let hidden = launchApp(date: "2026-09-16", menus: "hidden")
        turnLandscape()
        XCTAssertTrue(waitForLabel(hidden.staticTexts["pageNumber"], "1–2"))
        captureWindow(hidden, "ipad-menus-hidden")
        hidden.terminate()

        let app = launchApp(date: "2026-11-02")
        turnLandscape()
        app.buttons["calendarButton"].tap()
        XCTAssertTrue(app.navigationBars["Kalendarium"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["kalendariumDay-11-2"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.5)
        captureWindow(app, "ipad-kalendarium")
        app.buttons["Close"].tap()
        app.buttons["settingsButton"].tap()
        Thread.sleep(forTimeInterval: 1.5)
        captureWindow(app, "ipad-settings")
        app.terminate()
    }
}
