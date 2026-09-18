import XCTest

final class BreviariumUITests: XCTestCase {
    func testAppLaunches() {
        let app = XCUIApplication()
        // Pinned rather than "today": occurrence/precedence resolution across arbitrary
        // real dates isn't exhaustively oracle-tested yet, so a real-time "now" here
        // would risk this test flaking on some future CI run date that happens to hit
        // an unexercised edge case, unrelated to whatever change triggered that run.
        app.launchEnvironment["BREVIARIUM_SNAPSHOT_DATE"] = "2026-09-16"
        app.launch()
        XCTAssertTrue(app.staticTexts["Ad Vesperas"].waitForExistence(timeout: 5))
    }

    /// Captures the Vespers screen for 16 September 2026 -- the martyrs'-feast date this
    /// session's oracle tests already verify in full (`docs/PLAN.md`), and the exact
    /// date `CLAUDE.md`'s visual spec gives worked title-block text for. English off,
    /// default text size, portrait -- the first snapshot in `CLAUDE.md`'s matrix; the
    /// rest (commemoration day, I class feast, Holy Week day; English on; landscape;
    /// largest text size) land once this one is confirmed against
    /// `design/reference/Format.png`.
    func testVespersSnapshot16September2026() {
        let app = XCUIApplication()
        app.launchEnvironment["BREVIARIUM_SNAPSHOT_DATE"] = "2026-09-16"
        app.launch()
        XCTAssertTrue(app.staticTexts["Ad Vesperas"].waitForExistence(timeout: 5))

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "vespers-2026-09-16-latin-off-portrait-default"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Captures a full walkthrough of Vespers for a given date by scrolling down the
    /// screen's whole continuous document (`VespersView`'s own doc comment covers why
    /// it's one scroll rather than swiped pages for now) and screenshotting after each
    /// scroll, stopping once a scroll produces the exact same screenshot as the last one
    /// -- i.e. the bottom of the content has been reached and there's nothing further to
    /// capture.
    private func captureWholeScroll(dateString: String, namePrefix: String) {
        let app = XCUIApplication()
        app.launchEnvironment["BREVIARIUM_SNAPSHOT_DATE"] = dateString
        app.launch()
        XCTAssertTrue(app.staticTexts["Ad Vesperas"].waitForExistence(timeout: 5))

        var previousImageData: Data?
        let maxScreens = 20
        for index in 1...maxScreens {
            // Let the scroll's own momentum/animation settle before capturing --
            // screenshotting immediately after swipeUp() can catch the view mid-scroll.
            Thread.sleep(forTimeInterval: 0.3)
            let screenshot = app.screenshot()
            let imageData = screenshot.pngRepresentation
            if let previousImageData, previousImageData == imageData {
                break
            }
            previousImageData = imageData

            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "\(namePrefix)-screen-\(index)"
            attachment.lifetime = .keepAlways
            add(attachment)

            app.swipeUp()
        }
    }

    func testVespersAllPages19November2026() {
        captureWholeScroll(dateString: "2026-11-19", namePrefix: "vespers-2026-11-19")
    }

    /// Requested test date: 14 August 2028 -- the Vigil of the Assumption.
    func testVespersAllPages14August2028() {
        captureWholeScroll(dateString: "2028-08-14", namePrefix: "vespers-2028-08-14")
    }
}
