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
            // Wait for the footer to actually show this page number before capturing --
            // swiping triggers the TabView's own transition animation asynchronously,
            // so screenshotting immediately after swipeLeft() can catch the previous
            // page mid-transition or not yet transitioned at all (confirmed real: an
            // earlier export had two consecutive identical "Page 1 of 7" screenshots).
            // 15s, not 5s: a heavier office (more blocks to lay out per page, e.g. the
            // Vigil of the Assumption's longer Psalmodia) can make a single TabView page
            // transition take longer than 5s to settle under CI's simulator load --
            // confirmed real from a run where every page after the first showed up
            // exactly one swipe late, each individual wait having timed out by seconds.
            let expectedLabel = "Page \(page) of \(totalPages)"
            XCTAssertTrue(
                app.staticTexts[expectedLabel].waitForExistence(timeout: 15),
                "Footer never showed \"\(expectedLabel)\""
            )
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

    /// Requested test date: 14 August 2028 -- the Vigil of the Assumption.
    func testVespersAllPages14August2028() {
        captureAllPages(dateString: "2028-08-14", namePrefix: "vespers-2028-08-14")
    }
}
