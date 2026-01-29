import XCTest

final class IzmirDatasUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testLaunch() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.exists)
    }

    func testTabNavigationShowsTitles() {
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["Hatlar"].tap()
        XCTAssertTrue(app.navigationBars["Hatlar"].exists)

        app.tabBars.buttons["Duraklar"].tap()
        XCTAssertTrue(app.navigationBars["Duraklar"].exists)

        app.tabBars.buttons["Saatler"].tap()
        XCTAssertTrue(app.navigationBars["Saatler"].exists)

        app.tabBars.buttons["Harita"].tap()
        XCTAssertTrue(app.navigationBars["Canlı Konum"].exists)
    }
}
