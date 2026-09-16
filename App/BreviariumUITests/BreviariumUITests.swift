import XCTest

/// M0 placeholder, proving the simulator UI test lane works. Real snapshot tests
/// (rendering each key screen and uploading the PNGs as artifacts) land in M5.
final class BreviariumUITests: XCTestCase {
    func testAppLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Breviarium"].waitForExistence(timeout: 5))
    }
}
