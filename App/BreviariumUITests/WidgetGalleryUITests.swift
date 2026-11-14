import XCTest

/// The widgets (1.5, `docs/1.5_plan.md` §4), photographed from the app's debug-only
/// gallery (`WidgetGalleryView`), which draws each widget's own face at the device's
/// widget sizes from the widget's data file. Run on the iPhone 17 and, in the iPad pass,
/// on the iPad Air 11" (M3); the captures' names say which.
final class WidgetGalleryUITests: BreviariumUITestCase {
    private var device: String { UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone" }

    /// Opens the gallery's `page` on `date` at `clock` o'clock, configured as given, and
    /// captures it.
    private func capture(
        _ page: String, date: String, clock: Int, name: String, rite: String = "romanus", officium: String = "diei",
        psalter: String = "vulgate", theme: String = "classicDark", font: String = "serif"
    ) {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["BREVIARIUM_WIDGET_GALLERY"] = page
        app.launchEnvironment["BREVIARIUM_SNAPSHOT_DATE"] = date
        app.launchEnvironment["BREVIARIUM_WIDGET_CLOCK"] = String(clock)
        app.launchArguments += [
            "-settings.rite", rite, "-settings.officium", officium, "-settings.psalter", psalter,
            "-settings.theme", theme, "-settings.font", font,
        ]
        app.launch()
        XCTAssertTrue(app.otherElements["widgetGallery"].waitForExistence(timeout: 10) || app.staticTexts.firstMatch.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.5)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "widget-\(device)-\(name)"
        shot.lifetime = .keepAlways
        add(shot)
        app.terminate()
    }

    /// 16 September 2026, the spec's title block, with its commemoration: every page, at
    /// Lauds (06:00).
    func testEveryWidgetOnTheSpecsDay() {
        for page in ["day", "hour", "lock", "tinted"] {
            capture(page, date: "2026-09-16", clock: 6, name: "2026-09-16-lauds-\(page)")
        }
    }

    /// Long texts are cut off at the line limit, never shrunk (decided 2026-11-14): the
    /// long *Magnificat* antiphon of 14 November 2026, and the Little Office's long
    /// *Benedictus* antiphon.
    func testLongAntiphonsAreCutOff() {
        capture("hour", date: "2026-11-14", clock: 18, name: "2026-11-14-vespers-hour")
        capture("hour", date: "2026-11-14", clock: 6, name: "2026-11-14-lauds-bmv-hour", officium: "parvumBMV")
    }

    /// An hour without an antiphon shows the day's title (decided 2026-11-14): Terce of
    /// Good Friday.
    func testTheDaysTitleWhereThereIsNoAntiphon() {
        capture("hour", date: "2026-04-03", clock: 10, name: "2026-04-03-terce-hour")
        capture("day", date: "2026-04-03", clock: 10, name: "2026-04-03-terce-day")
    }

    /// The options under Edit Widget: the Pius XII psalter, the Ambrosian rite, a light
    /// theme and another font.
    func testTheWidgetsOwnSettings() {
        capture("hour", date: "2026-11-16", clock: 10, name: "2026-11-16-terce-pius12-hour", psalter: "pius12")
        capture("hour", date: "2026-11-14", clock: 21, name: "2026-11-14-ambrosian-hour", rite: "ambrosianus")
        capture("day", date: "2026-12-24", clock: 18, name: "2026-12-24-vespers-lux-day", theme: "light", font: "gentium")
        capture("hour", date: "2026-12-24", clock: 18, name: "2026-12-24-vespers-sepia-comic-hour", theme: "sepia", font: "comic")
    }

    /// A tap on a widget opens its hour and date (`breviarium://open?…`), whatever the
    /// app was showing.
    func testAWidgetsLinkOpensItsHourAndDate() {
        let app = launchApp(date: "2026-09-16", hour: "Vespera")
        app.open(URL(string: "breviarium://open?hour=Laudes&date=2026-12-25")!)
        XCTAssertTrue(app.buttons["Ad Laudes"].waitForExistence(timeout: 10))
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "widget-\(device)-link-christmas-lauds"
        shot.lifetime = .keepAlways
        add(shot)
        app.terminate()
    }
}
