//
//  deepdropUITests.swift
//  deepdropUITests
//
//  Created by art on 17.05.2026.
//

import XCTest

final class deepdropUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsPhaseZeroShell() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["DeepDrop"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Connect to PostgreSQL"].exists)
        XCTAssertTrue(app.buttons["empty-add-database-source-button"].exists)
        XCTAssertTrue(app.staticTexts["No query has been run"].exists)
    }

    @MainActor
    func testAddConnectionPlaceholderCanOpenAndClose() throws {
        let app = XCUIApplication()
        app.launch()

        let addButton = app.buttons["empty-add-database-source-button"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.click()

        XCTAssertTrue(app.staticTexts["Add Database Source"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["URL parsing"].exists)

        let closeButton = app.buttons["add-connection-placeholder-close-button"]
        XCTAssertTrue(closeButton.exists)
        closeButton.click()

        XCTAssertFalse(app.staticTexts["Add Database Source"].waitForExistence(timeout: 1))
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
