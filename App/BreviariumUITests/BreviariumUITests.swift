import XCTest

final class BreviariumUITests: XCTestCase {
    /// Launches on a fixed date with an explicit reading mode and the default text size,
    /// passed through the `UserDefaults` argument domain (`-key value`) so no test inherits
    /// another's Settings choice from the same simulator (a snapshot once came out at XXL
    /// because an earlier test had chosen it). A test can still change the text size
    /// through Settings; the choice holds for that launch.
    @discardableResult
    private func launchApp(date: String, readingMode: String = "horizontal", pageTurn: String = "slide") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["BREVIARIUM_SNAPSHOT_DATE"] = date
        app.launchArguments += [
            "-settings.readingMode", readingMode, "-settings.pageTurn", pageTurn, "-settings.textSize", "standard",
        ]
        app.launch()
        XCTAssertTrue(app.staticTexts["Ad Vesperas"].waitForExistence(timeout: 5))
        return app
    }

    private func waitForLabel(_ element: XCUIElement, _ label: String, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "label == %@", label)
        return XCTWaiter().wait(for: [expectation(for: predicate, evaluatedWith: element)], timeout: timeout) == .completed
    }

    /// The footer's "Page N of M", parsed.
    private func pageCounter(_ app: XCUIApplication) -> (page: Int, count: Int)? {
        let parts = app.staticTexts["pageCounter"].label.split(separator: " ")
        guard parts.count == 4, let page = Int(parts[1]), let count = Int(parts[3]) else { return nil }
        return (page, count)
    }

    func testAppLaunches() {
        // Pinned rather than "today", so a CI run's date never changes what is tested.
        let app = launchApp(date: "2026-09-16")
        XCTAssertTrue(app.textViews["officeText"].firstMatch.waitForExistence(timeout: 5))
    }

    /// Captures the Vespers screen for 16 September 2026 -- the martyrs'-feast date this
    /// session's oracle tests already verify in full (`docs/PLAN.md`), and the exact
    /// date `CLAUDE.md`'s visual spec gives worked title-block text for. English off,
    /// default text size, portrait -- the first snapshot in `CLAUDE.md`'s matrix; the
    /// rest (commemoration day, I class feast, Holy Week day; English on; landscape;
    /// largest text size) land once this one is confirmed against
    /// `design/reference/Format.png`.
    func testVespersSnapshot16September2026() {
        let app = launchApp(date: "2026-09-16")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "vespers-2026-09-16-latin-off-portrait-default"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Captures a full walkthrough of Vespers for a given date, turning page after page
    /// (horizontal mode, the default) or scrolling screen after screen (vertical), and
    /// screenshotting each, stopping once a turn produces the exact same screenshot as the
    /// last one -- i.e. the end of the office has been reached.
    private func captureWholeScroll(dateString: String, namePrefix: String, readingMode: String = "horizontal") {
        let app = launchApp(date: dateString, readingMode: readingMode)

        var previousImageData: Data?
        let maxScreens = 40
        for index in 1...maxScreens {
            // Let the turn's own animation settle before capturing.
            Thread.sleep(forTimeInterval: 0.4)
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

            if readingMode == "vertical" { app.swipeUp() } else { app.swipeLeft() }
        }
    }

    func testVespersAllPages19November2026() {
        captureWholeScroll(dateString: "2026-11-19", namePrefix: "vespers-2026-11-19")
    }

    /// Requested test date: 14 August 2028 -- the Vigil of the Assumption.
    func testVespersAllPages14August2028() {
        captureWholeScroll(dateString: "2028-08-14", namePrefix: "vespers-2028-08-14")
    }

    /// 24 February 2026 -- S. Matthiae Apostoli commemorating the Lenten feria at
    /// Vespers. A full walkthrough to see `assembleCommemorations`'s own rendered
    /// output directly in the real app UI, not just via the oracle-fixture unit test
    /// it was built and verified against.
    func testVespersAllPages24February2026() {
        captureWholeScroll(dateString: "2026-02-24", namePrefix: "vespers-2026-02-24")
    }

    // A handful of otherwise-unremarkable, arbitrarily-chosen dates (not edge cases --
    // those already have their own named tests and fixtures) spread across different
    // years and seasons, for a final visual spot-check of ordinary-looking days
    // alongside `OracleTests`' own full-range structural sweep, before moving past this
    // milestone's aesthetic pass.
    func testVespersAllPagesRandomSample1() {
        captureWholeScroll(dateString: "2027-04-09", namePrefix: "vespers-2027-04-09")
    }

    func testVespersAllPagesRandomSample2() {
        captureWholeScroll(dateString: "2032-10-22", namePrefix: "vespers-2032-10-22")
    }

    func testVespersAllPagesRandomSample3() {
        captureWholeScroll(dateString: "2038-07-05", namePrefix: "vespers-2038-07-05")
    }

    /// Confirms the Settings sheet actually opens from the gear icon and shows every
    /// `CLAUDE.md`-required toggle -- M5's own Settings screen.
    func testSettingsSheetOpensAndShowsEveryToggle() {
        let app = launchApp(date: "2026-09-16")

        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Romanus"].exists)
        XCTAssertTrue(app.staticTexts["Ambrosianus"].exists)
        XCTAssertTrue(app.switches["Sacerdos vel diaconus adest"].exists)
        XCTAssertTrue(app.switches["Rubricæ"].exists)
        XCTAssertTrue(app.staticTexts["English translation"].exists)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "settings-screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// M6's own manual checklist names "previous/next day" -- confirms the nav header's
    /// chevrons actually move the displayed date, checking the footer's short date.
    func testPreviousAndNextDayNavigationChangeTheDate() {
        let app = launchApp(date: "2026-09-16")
        let date = app.buttons["jumpToDateButton"]
        XCTAssertTrue(waitForLabel(date, "16-Sep-26"))

        app.buttons["nextDayButton"].tap()
        XCTAssertTrue(waitForLabel(date, "17-Sep-26"))

        app.buttons["previousDayButton"].tap()
        app.buttons["previousDayButton"].tap()
        XCTAssertTrue(waitForLabel(date, "15-Sep-26"))
    }

    /// M6's own manual checklist also names "jump-to-date": the footer date opens it.
    func testFooterDateOpensJumpToDateSheet() {
        let app = launchApp(date: "2026-09-16")
        app.buttons["jumpToDateButton"].tap()
        XCTAssertTrue(app.navigationBars["Jump to date"].waitForExistence(timeout: 5))
    }

    /// The date line on page 1 is an in-text link to the same sheet. Skipped, not failed,
    /// if the system doesn't expose UITextView links to UI tests.
    func testPageOneDateLineLinkOpensJumpToDate() throws {
        let app = launchApp(date: "2026-09-16")
        let dateLink = app.links["Dies 16 septembris 2026"]
        try XCTSkipUnless(dateLink.waitForExistence(timeout: 5), "UITextView link not exposed to accessibility")
        dateLink.tap()
        XCTAssertTrue(app.navigationBars["Jump to date"].waitForExistence(timeout: 5))
    }

    /// Book-style pagination: several pages at the default size, the counter advancing on
    /// a swipe, and more pages at the largest text size (the text re-flows; nothing is
    /// cut off, it moves to later pages).
    func testHorizontalPagesFlowAndCountUp() {
        let app = launchApp(date: "2026-09-16")
        Thread.sleep(forTimeInterval: 0.5)
        guard let first = pageCounter(app) else { return XCTFail("no page counter: \(app.staticTexts["pageCounter"].label)") }
        XCTAssertEqual(first.page, 1)
        XCTAssertGreaterThan(first.count, 3)

        app.swipeLeft()
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertEqual(pageCounter(app)?.page, 2)

        setTextSize("XXL", in: app)
        Thread.sleep(forTimeInterval: 0.5)
        let largest = pageCounter(app)
        XCTAssertGreaterThan(largest?.count ?? 0, first.count)
        setTextSize("M", in: app)
    }

    /// Confirms the About screen (CLAUDE.md: "Include the MIT notice on the About
    /// screen") is reachable from Settings and actually shows the licence text.
    func testAboutScreenShowsTheDivinumOfficiumLicense() {
        let app = launchApp(date: "2026-09-16")

        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        app.staticTexts["About"].tap()
        XCTAssertTrue(app.navigationBars["About"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Breviarium"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'MIT License'")).firstMatch.exists)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "about-screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Sets text size via the real Settings UI (not a launch-environment shortcut) --
    /// `sizeLabel` is one of the segmented control's own visible labels ("M", "XXL").
    /// Explicit every time rather than relying on whatever's already selected: the
    /// setting persists in UserDefaults across app launches on the same simulator, so a
    /// later test in the same CI run could otherwise inherit an earlier test's choice.
    private func setTextSize(_ sizeLabel: String, in app: XCUIApplication) {
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        app.buttons[sizeLabel].tap()
        app.buttons["Done"].tap()
    }

    /// `CLAUDE.md`'s own snapshot matrix, adapted for what's built: English is deferred
    /// to beta (so every capture is English off). "Page 1" is the first page and "a
    /// psalmody page" the second, in the default horizontal reading mode. One fresh
    /// launch per text size, so each starts on page 1.
    private func captureSnapshotMatrix(dateString: String, namePrefix: String, sizeLabel: String, sizeName: String) {
        let app = launchApp(date: dateString)

        setTextSize(sizeLabel, in: app)
        Thread.sleep(forTimeInterval: 0.4)

        let page1 = XCTAttachment(screenshot: app.screenshot())
        page1.name = "\(namePrefix)-\(sizeName)-page1"
        page1.lifetime = .keepAlways
        add(page1)

        app.swipeLeft()
        Thread.sleep(forTimeInterval: 0.4)
        let psalmodyPage = XCTAttachment(screenshot: app.screenshot())
        psalmodyPage.name = "\(namePrefix)-\(sizeName)-psalmody"
        psalmodyPage.lifetime = .keepAlways
        add(psalmodyPage)
    }

    /// The other two reading modes, for comparison: vertical scroll and the page curl
    /// (captured mid-turn is not reliable, so after the turn completes).
    func testReadingModesSnapshots() {
        let vertical = launchApp(date: "2026-09-16", readingMode: "vertical")
        let verticalTop = XCTAttachment(screenshot: vertical.screenshot())
        verticalTop.name = "mode-vertical-top"
        verticalTop.lifetime = .keepAlways
        add(verticalTop)
        vertical.swipeUp()
        Thread.sleep(forTimeInterval: 0.4)
        let verticalNext = XCTAttachment(screenshot: vertical.screenshot())
        verticalNext.name = "mode-vertical-scrolled"
        verticalNext.lifetime = .keepAlways
        add(verticalNext)
        vertical.terminate()

        let curl = launchApp(date: "2026-09-16", pageTurn: "curl")
        curl.swipeLeft()
        Thread.sleep(forTimeInterval: 0.8)
        let curlPage = XCTAttachment(screenshot: curl.screenshot())
        curlPage.name = "mode-curl-page2"
        curlPage.lifetime = .keepAlways
        add(curlPage)
    }

    func testSnapshotMatrixFerialDay() {
        captureSnapshotMatrix(dateString: "2027-04-09", namePrefix: "matrix-ferial", sizeLabel: "M", sizeName: "default")
        captureSnapshotMatrix(dateString: "2027-04-09", namePrefix: "matrix-ferial", sizeLabel: "XXL", sizeName: "largest")
    }

    /// 24 February 2026: S. Matthiæ Apostoli (II. classis) commemorating the Lenten
    /// feria at Vespers -- the exact date `HourAssembler.assembleCommemorations` was
    /// built and verified against this session.
    func testSnapshotMatrixCommemorationDay() {
        captureSnapshotMatrix(dateString: "2026-02-24", namePrefix: "matrix-commemoration", sizeLabel: "M", sizeName: "default")
        captureSnapshotMatrix(dateString: "2026-02-24", namePrefix: "matrix-commemoration", sizeLabel: "XXL", sizeName: "largest")
    }

    /// 1 November 2026: All Saints, I. classis.
    func testSnapshotMatrixIClassFeast() {
        captureSnapshotMatrix(dateString: "2026-11-01", namePrefix: "matrix-feast", sizeLabel: "M", sizeName: "default")
        captureSnapshotMatrix(dateString: "2026-11-01", namePrefix: "matrix-feast", sizeLabel: "XXL", sizeName: "largest")
    }

    /// 29 March 2026: Palm Sunday (Easter 2026 falls on 5 April).
    func testSnapshotMatrixHolyWeekDay() {
        captureSnapshotMatrix(dateString: "2026-03-29", namePrefix: "matrix-holyweek", sizeLabel: "M", sizeName: "default")
        captureSnapshotMatrix(dateString: "2026-03-29", namePrefix: "matrix-holyweek", sizeLabel: "XXL", sizeName: "largest")
    }
}
