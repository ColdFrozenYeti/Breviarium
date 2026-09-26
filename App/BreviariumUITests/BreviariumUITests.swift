import XCTest

final class BreviariumUITests: XCTestCase {
    /// Scrolls the Settings form until `element` is loaded: its lower rows (text size,
    /// About) exist only once scrolled into view, and the form outgrew the screen when
    /// Psalterium was added.
    private func scrollSettings(to element: XCUIElement, in app: XCUIApplication) {
        var swipes = 0
        while !element.exists, swipes < 5 {
            app.collectionViews.firstMatch.swipeUp()
            swipes += 1
        }
    }

    /// Launches on a fixed date with an explicit reading mode and the default text size,
    /// passed through the `UserDefaults` argument domain (`-key value`) so no test inherits
    /// another's Settings choice from the same simulator (a snapshot once came out at XXL
    /// because an earlier test had chosen it). A test can still change the text size
    /// through Settings; the choice holds for that launch.
    @discardableResult
    private func launchApp(
        date: String, readingMode: String = "horizontal", pageTurn: String = "slide", textSize: String = "standard",
        section: String? = nil, english: Bool = false, psalter: String = "vulgate", hour: String = "Vespera",
        officium: String = "diei", rubrics: Bool = true, expectedTitle: String? = nil
    ) -> XCUIApplication {
        // Every launch starts in portrait: a failed step ends a test at once, so a rotation
        // undone at the end of a test could leak into the next ones (it did, B1-M5: a
        // landscape capture failed and every later Settings tap missed).
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["BREVIARIUM_SNAPSHOT_DATE"] = date
        if let section { app.launchEnvironment["BREVIARIUM_SNAPSHOT_SECTION"] = section }
        // Pinned, as the app otherwise opens the hour for the time of day (Beta 2).
        app.launchEnvironment["BREVIARIUM_SNAPSHOT_HOUR"] = hour
        app.launchArguments += [
            "-settings.readingMode", readingMode, "-settings.pageTurn", pageTurn, "-settings.textSize", textSize,
            "-settings.showEnglish", english ? "YES" : "NO", "-settings.psalter", psalter,
            "-settings.officium", officium, "-settings.showRubrics", rubrics ? "YES" : "NO",
        ]
        app.launch()
        XCTAssertTrue(app.staticTexts[expectedTitle ?? Self.titles[hour] ?? "Ad Vesperas"].waitForExistence(timeout: 5))
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
        XCTAssertTrue(app.staticTexts["Dominicanus"].exists)
        XCTAssertTrue(app.switches["Sacerdos vel diaconus adest"].exists)
        XCTAssertTrue(app.switches["Rubricæ"].exists)
        XCTAssertTrue(app.switches["English translation"].exists)
        XCTAssertTrue(app.buttons["psalterPicker"].exists || app.otherElements["psalterPicker"].exists || app.staticTexts["Psalterium"].exists)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "settings-screen"
        attachment.lifetime = .keepAlways
        add(attachment)

        // Release notes, beside About at the foot of the list.
        app.swipeUp()
        let releaseNotes = app.buttons["Release notes"]
        XCTAssertTrue(releaseNotes.waitForExistence(timeout: 5))
        releaseNotes.tap()
        XCTAssertTrue(app.navigationBars["Release notes"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Beta 2"].exists || app.staticTexts["BETA 2"].exists)
        let notes = XCTAttachment(screenshot: app.screenshot())
        notes.name = "settings-release-notes"
        notes.lifetime = .keepAlways
        add(notes)
    }

    /// Beta 3's icon on the simulator's Home Screen: the app is installed and launched
    /// once, then the Home button shows SpringBoard. A freshly installed app lands on the
    /// last Home Screen page, so the capture swipes left until it shows.
    func testHomeScreenIcon() {
        _ = launchApp(date: "2026-09-16")
        XCUIDevice.shared.press(.home)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let icon = springboard.icons["Breviarium"]
        for _ in 0..<4 where !(icon.exists && icon.isHittable) {
            springboard.swipeLeft()
        }
        let attachment = XCTAttachment(screenshot: springboard.screenshot())
        attachment.name = "home-screen-icon"
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
        scrollSettings(to: app.staticTexts["About"], in: app)
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
        scrollSettings(to: app.buttons[sizeLabel], in: app)
        app.buttons[sizeLabel].tap()
        app.buttons["Done"].tap()
    }

    /// `CLAUDE.md`'s own snapshot matrix. "Page 1" is the first page and "a psalmody
    /// page" the second, in the default horizontal reading mode. One fresh launch per
    /// text size, so each starts on page 1. English off by default; the English-on
    /// captures are `captureEnglishMatrix`'s (Beta 1, B1-M5).
    private func captureSnapshotMatrix(
        dateString: String, namePrefix: String, sizeLabel: String, sizeName: String, english: Bool = false,
        psalter: String = "vulgate", landscape: Bool = false
    ) {
        let app = launchApp(date: dateString, english: english, psalter: psalter)
        // The text size is set in portrait, where Settings has room; then the phone turns.
        setTextSize(sizeLabel, in: app)
        if landscape { XCUIDevice.shared.orientation = .landscapeLeft }
        Thread.sleep(forTimeInterval: landscape ? 1.0 : 0.4)

        // In landscape the screen's own capture came back in the portrait buffer, cropped
        // (B1-M5); the window's capture follows the app's orientation.
        func capture() -> XCUIScreenshot { landscape ? app.windows.firstMatch.screenshot() : app.screenshot() }
        let page1 = XCTAttachment(screenshot: capture())
        page1.name = "\(namePrefix)-\(sizeName)-page1"
        page1.lifetime = .keepAlways
        add(page1)

        app.swipeLeft()
        Thread.sleep(forTimeInterval: 0.4)
        let psalmodyPage = XCTAttachment(screenshot: capture())
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

    /// B1-M0: hymns must show as stanzas (normal pitch within a stanza, a gap between
    /// stanzas), not as evenly spaced single lines. 19 November 2026's hymn, "Fortem virili
    /// pectore", opened at the HYMNUS section, in both reading modes at M and XXL.
    /// Measured with `scripts/measure-snapshot.py --pitch`.
    func testHymnStanzasSnapshots() {
        for readingMode in ["horizontal", "vertical"] {
            for (textSize, sizeName) in [("standard", "default"), ("largest", "largest")] {
                let app = launchApp(date: "2026-11-19", readingMode: readingMode, textSize: textSize, section: "hymnus")
                Thread.sleep(forTimeInterval: 0.6)
                let attachment = XCTAttachment(screenshot: app.screenshot())
                attachment.name = "hymn-\(readingMode)-\(sizeName)"
                attachment.lifetime = .keepAlways
                add(attachment)
                app.terminate()
            }
        }
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

    // MARK: Beta 1, B1-M5: English on

    /// `CLAUDE.md`'s matrix with English on: each day in portrait at both sizes, plus
    /// landscape at the default size, and the ferial day in the Pius XII psalter too
    /// (its psalms are paired whole, `docs/psalters-and-english.md`).
    private func captureEnglishMatrix(dateString: String, namePrefix: String) {
        captureSnapshotMatrix(dateString: dateString, namePrefix: "\(namePrefix)-en", sizeLabel: "M", sizeName: "default", english: true)
        captureSnapshotMatrix(dateString: dateString, namePrefix: "\(namePrefix)-en", sizeLabel: "XXL", sizeName: "largest", english: true)
        captureSnapshotMatrix(
            dateString: dateString, namePrefix: "\(namePrefix)-en-landscape", sizeLabel: "M", sizeName: "default", english: true, landscape: true
        )
    }

    func testEnglishSnapshotMatrixFerialDay() {
        captureEnglishMatrix(dateString: "2027-04-09", namePrefix: "matrix-ferial")
        captureSnapshotMatrix(
            dateString: "2027-04-09", namePrefix: "matrix-ferial-en-pius12", sizeLabel: "M", sizeName: "default", english: true, psalter: "pius12"
        )
        captureSnapshotMatrix(dateString: "2027-04-09", namePrefix: "matrix-ferial-pius12", sizeLabel: "M", sizeName: "default", psalter: "pius12")
    }

    func testEnglishSnapshotMatrixCommemorationDay() {
        captureEnglishMatrix(dateString: "2026-02-24", namePrefix: "matrix-commemoration")
    }

    func testEnglishSnapshotMatrixIClassFeast() {
        captureEnglishMatrix(dateString: "2026-11-01", namePrefix: "matrix-feast")
    }

    func testEnglishSnapshotMatrixHolyWeekDay() {
        captureEnglishMatrix(dateString: "2026-03-29", namePrefix: "matrix-holyweek")
    }

    /// English on, horizontal and vertical: the pages flow (the counter counts up on a
    /// swipe) and the table of contents jumps to a later page.
    func testEnglishPagesFlowAndTableOfContentsJumps() {
        let app = launchApp(date: "2026-09-16", english: true)
        Thread.sleep(forTimeInterval: 0.5)
        guard let first = pageCounter(app) else { return XCTFail("no page counter") }
        XCTAssertEqual(first.page, 1)
        XCTAssertGreaterThan(first.count, 3)
        app.swipeLeft()
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertEqual(pageCounter(app)?.page, 2)
        app.terminate()

        let hymn = launchApp(date: "2026-11-19", section: "hymnus", english: true)
        Thread.sleep(forTimeInterval: 0.6)
        XCTAssertGreaterThan(pageCounter(hymn)?.page ?? 0, 1)
        let attachment = XCTAttachment(screenshot: hymn.screenshot())
        attachment.name = "hymn-en-horizontal-default"
        attachment.lifetime = .keepAlways
        add(attachment)
        hymn.terminate()

        let vertical = launchApp(date: "2026-11-19", readingMode: "vertical", section: "hymnus", english: true)
        Thread.sleep(forTimeInterval: 0.6)
        let verticalShot = XCTAttachment(screenshot: vertical.screenshot())
        verticalShot.name = "hymn-en-vertical-default"
        verticalShot.lifetime = .keepAlways
        add(verticalShot)
    }

    // MARK: Beta 2: the day hours

    private static let titles = [
        "Matutinum": "Ad Matutinum", "Laudes": "Ad Laudes", "Prima": "Ad Primam", "Tertia": "Ad Tertiam", "Sexta": "Ad Sextam", "Nona": "Ad Nonam",
        "Vespera": "Ad Vesperas", "Completorium": "Ad Completorium", "martyrologium": "Martyrologium",
    ]

    /// The hour picker opens from the title and switches the hour.
    func testHourPickerSwitchesTheHour() {
        let app = launchApp(date: "2026-09-16")
        app.staticTexts["hourPickerButton"].tap()
        let lauds = app.buttons["hour-Laudes"]
        XCTAssertTrue(lauds.waitForExistence(timeout: 5))
        let picker = XCTAttachment(screenshot: app.screenshot())
        picker.name = "hour-picker"
        picker.lifetime = .keepAlways
        add(picker)
        lauds.tap()
        XCTAssertTrue(app.staticTexts["Ad Laudes"].waitForExistence(timeout: 5))
    }

    /// Page 1 and page 2 of every day hour, for a ferial day and a I class feast, plus
    /// Lauds of 16 September 2026 (the title block's commemoration example) and Compline
    /// of Holy Saturday.
    func testDayHoursSnapshots() {
        for (date, name) in [("2027-04-09", "ferial"), ("2026-11-01", "feast")] {
            for hour in ["Laudes", "Prima", "Tertia", "Sexta", "Nona", "Completorium"] {
                captureTwoPages(date: date, hour: hour, name: "hours-\(name)-\(hour)")
            }
        }
        captureTwoPages(date: "2026-09-16", hour: "Laudes", name: "hours-0916-Laudes")
        captureTwoPages(date: "2026-04-04", hour: "Completorium", name: "hours-holysaturday-Completorium")
    }

    /// 25 September 2026, as reported from the phone: each little hour's chapter page and
    /// last page (None's end was cut off), Compline's Marian antiphon, and None with
    /// English on.
    func testDayHoursChapterAndLastPages() {
        for hour in ["Prima", "Tertia", "Sexta", "Nona", "Completorium"] {
            captureChapterAndLastPage(date: "2026-09-25", hour: hour, english: false, name: "0925-\(hour)")
        }
        captureChapterAndLastPage(date: "2026-09-25", hour: "Nona", english: true, name: "0925-Nona-en")
    }

    /// Matins (Beta 3): page 1 and 2, the first lesson, the second nocturn and the last
    /// page, for a three-lesson feria, a nine-lesson feast and Maundy Thursday; the lesson
    /// page with English on in portrait and landscape; the hour picker's first row.
    func testMatinsSnapshots() {
        for (date, name) in [("2027-04-12", "feria"), ("2026-11-01", "feast"), ("2026-04-02", "holythursday")] {
            captureTwoPages(date: date, hour: "Matutinum", name: "matins-\(name)")
            for section in ["adNocturnum", "nocturnusI", "nocturnusII"] {
                let app = launchApp(date: date, section: section, hour: "Matutinum")
                Thread.sleep(forTimeInterval: 0.6)
                // The section's first page, then the one after (the first lesson).
                for step in 0..<2 {
                    let shot = XCTAttachment(screenshot: app.screenshot())
                    shot.name = "matins-\(name)-\(section)-\(step)"
                    shot.lifetime = .keepAlways
                    add(shot)
                    app.swipeLeft()
                    Thread.sleep(forTimeInterval: 0.4)
                }
                app.terminate()
            }
            captureChapterAndLastPage(date: date, hour: "Matutinum", english: false, name: "matins-\(name)")
        }
        let app = launchApp(date: "2026-11-01", section: "nocturnusII", english: true, hour: "Matutinum")
        Thread.sleep(forTimeInterval: 0.6)
        app.swipeLeft()
        Thread.sleep(forTimeInterval: 0.4)
        let portrait = XCTAttachment(screenshot: app.screenshot())
        portrait.name = "matins-feast-english-portrait"
        portrait.lifetime = .keepAlways
        add(portrait)
        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 1.0)
        let landscape = XCTAttachment(screenshot: app.screenshot())
        landscape.name = "matins-feast-english-landscape"
        landscape.lifetime = .keepAlways
        add(landscape)
        XCUIDevice.shared.orientation = .portrait
        app.terminate()
    }

    private func captureChapterAndLastPage(date: String, hour: String, english: Bool, name: String) {
        let chapterSection = hour == "Completorium" ? "lectioBrevis" : hour == "Matutinum" ? "teDeum" : "capitulum"
        var app = launchApp(date: date, section: chapterSection, english: english, hour: hour)
        Thread.sleep(forTimeInterval: 0.6)
        let chapter = XCTAttachment(screenshot: app.screenshot())
        chapter.name = "\(name)-chapter"
        chapter.lifetime = .keepAlways
        add(chapter)
        app.terminate()

        app = launchApp(date: date, english: english, hour: hour)
        Thread.sleep(forTimeInterval: 0.4)
        var swipes = 0
        while let counter = pageCounter(app), counter.page < counter.count, swipes < 40 {
            app.swipeLeft()
            Thread.sleep(forTimeInterval: 0.4)
            swipes += 1
        }
        let last = XCTAttachment(screenshot: app.screenshot())
        last.name = "\(name)-last"
        last.lifetime = .keepAlways
        add(last)
        app.terminate()
    }

    private func captureTwoPages(date: String, hour: String, name: String) {
        let app = launchApp(date: date, hour: hour)
        Thread.sleep(forTimeInterval: 0.4)
        let page1 = XCTAttachment(screenshot: app.screenshot())
        page1.name = "\(name)-page1"
        page1.lifetime = .keepAlways
        add(page1)
        app.swipeLeft()
        Thread.sleep(forTimeInterval: 0.4)
        let page2 = XCTAttachment(screenshot: app.screenshot())
        page2.name = "\(name)-page2"
        page2.lifetime = .keepAlways
        add(page2)
        app.terminate()
    }

    // MARK: Beta 4

    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Settings -> Romanus chooses the office; the hour picker then lists that office's
    /// hours and the Martyrology (decided 2026-09-26).
    func testOfficiumSettingAndHourPicker() {
        let app = launchApp(date: "2026-09-16", hour: "Laudes")
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        app.buttons["ritusRomanus"].tap()
        let dead = app.buttons["officium-defunctorum"]
        XCTAssertTrue(dead.waitForExistence(timeout: 5))
        capture(app, "b4-officium-setting")
        dead.tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Done"].tap()

        app.staticTexts["hourPickerButton"].tap()
        XCTAssertTrue(app.buttons["hour-Matutinum"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["hour-Laudes"].exists)
        XCTAssertTrue(app.buttons["hour-Vespera"].exists)
        XCTAssertTrue(app.buttons["hour-martyrologium"].exists)
        XCTAssertFalse(app.buttons["hour-Tertia"].exists)
        capture(app, "b4-hour-picker-defunctorum")
        app.buttons["hour-martyrologium"].tap()
        XCTAssertTrue(app.staticTexts["Martyrologium"].waitForExistence(timeout: 5))
    }

    /// The Little Office: page 1 of every hour (16 September 2026), and Lauds in Advent.
    func testLittleOfficeSnapshots() {
        for hour in ["Matutinum", "Laudes", "Prima", "Tertia", "Sexta", "Nona", "Vespera", "Completorium"] {
            let app = launchApp(date: "2026-09-16", hour: hour, officium: "parvumBMV")
            Thread.sleep(forTimeInterval: 0.4)
            capture(app, "b4-parvum-\(hour)-page1")
            app.terminate()
        }
        captureTwoPages(date: "2026-12-02", hour: "Laudes", name: "b4-parvum-advent-Laudes")
    }

    /// The Office of the Dead: its three hours, and Terce opening Lauds (decided 2026-09-26).
    func testOfficeOfTheDeadSnapshots() {
        for hour in ["Matutinum", "Laudes", "Vespera"] {
            let app = launchApp(date: "2026-09-16", hour: hour, officium: "defunctorum")
            Thread.sleep(forTimeInterval: 0.4)
            capture(app, "b4-defunctorum-\(hour)-page1")
            app.swipeLeft()
            Thread.sleep(forTimeInterval: 0.4)
            capture(app, "b4-defunctorum-\(hour)-page2")
            app.terminate()
        }
        let app = launchApp(date: "2026-09-16", hour: "Tertia", officium: "defunctorum", expectedTitle: "Ad Laudes")
        app.terminate()
    }

    /// The Martyrology: an ordinary day, Easter Sunday, Christmas Eve (its inline rubric,
    /// on and off) and Holy Saturday (omitted).
    func testMartyrologySnapshots() {
        for (date, name) in [("2026-09-16", "ordinary"), ("2026-04-05", "easter"), ("2026-04-04", "holysaturday")] {
            let app = launchApp(date: date, hour: "martyrologium")
            Thread.sleep(forTimeInterval: 0.4)
            capture(app, "b4-martyrology-\(name)")
            app.terminate()
        }
        for rubrics in [true, false] {
            let app = launchApp(date: "2026-12-24", hour: "martyrologium", rubrics: rubrics)
            Thread.sleep(forTimeInterval: 0.4)
            capture(app, "b4-martyrology-christmas-page1-rubrics\(rubrics ? "On" : "Off")")
            app.swipeLeft()
            Thread.sleep(forTimeInterval: 0.4)
            capture(app, "b4-martyrology-christmas-page2-rubrics\(rubrics ? "On" : "Off")")
            app.terminate()
        }
    }

    /// The Jump to date calendar's colour dots: November 2026 (black, green, red, white,
    /// violet), December (rose, violet, white, red) and March (rose, violet, white, red).
    func testCalendarColourDots() {
        let app = launchApp(date: "2026-11-02")
        app.buttons["jumpToDateButton"].tap()
        XCTAssertTrue(app.navigationBars["Jump to date"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["calendarDay-2"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 2.0)
        XCTAssertEqual(app.buttons["calendarDay-2"].value as? String, "black")
        capture(app, "b4-calendar-2026-11")
        app.buttons["nextMonthButton"].tap()
        Thread.sleep(forTimeInterval: 2.0)
        XCTAssertEqual(app.buttons["calendarDay-13"].value as? String, "rose")
        capture(app, "b4-calendar-2026-12")
        for _ in 0..<9 { app.buttons["previousMonthButton"].tap() }
        Thread.sleep(forTimeInterval: 2.0)
        capture(app, "b4-calendar-2026-03")
        app.buttons["calendarDay-15"].tap()
        XCTAssertTrue(waitForLabel(app.buttons["jumpToDateButton"], "15-Mar-26"))
    }

    /// The Te Deum's inline directions, red with rubrics on and gone with them off.
    func testTeDeumInlineRubrics() {
        for rubrics in [true, false] {
            let app = launchApp(date: "2026-11-01", section: "teDeum", hour: "Matutinum", rubrics: rubrics)
            Thread.sleep(forTimeInterval: 0.6)
            capture(app, "b4-tedeum-rubrics\(rubrics ? "On" : "Off")")
            app.swipeLeft()
            Thread.sleep(forTimeInterval: 0.4)
            capture(app, "b4-tedeum-rubrics\(rubrics ? "On" : "Off")-page2")
            app.terminate()
        }
    }
}
