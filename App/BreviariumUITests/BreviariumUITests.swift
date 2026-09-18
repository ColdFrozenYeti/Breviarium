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

    /// Captures every page of Vespers for a given date by reading "Page 1 of M" off the
    /// footer, then swiping through -- a full walkthrough rather than just page 1, for
    /// visual review.
    private func captureAllPages(dateString: String, namePrefix: String) {
        let app = XCUIApplication()
        app.launchEnvironment["BREVIARIUM_SNAPSHOT_DATE"] = dateString
        app.launch()
        XCTAssertTrue(app.staticTexts["Ad Vesperas"].waitForExistence(timeout: 5))

        let footerPredicate = NSPredicate(format: "label BEGINSWITH 'Page 1 of '")
        let footerText = app.staticTexts.element(matching: footerPredicate).firstMatch
        XCTAssertTrue(footerText.waitForExistence(timeout: 5))
        let totalPages = Int(footerText.label.replacingOccurrences(of: "Page 1 of ", with: "")) ?? 1

        for page in 1...totalPages {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "\(namePrefix)-page-\(page)-of-\(totalPages)"
            attachment.lifetime = .keepAlways
            add(attachment)
            if page < totalPages {
                app.swipeLeft()
            }
        }
    }

    func testVespersAllPages19November2026() {
        captureAllPages(dateString: "2026-11-19", namePrefix: "vespers-2026-11-19")
    }
}
