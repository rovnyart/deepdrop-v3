//
//  deepdropUITestsLaunchTests.swift
//  deepdropUITests
//
//  Created by art on 17.05.2026.
//

import XCTest

final class deepdropUITestsLaunchTests: XCTestCase {
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Connect to PostgreSQL"].waitForExistence(timeout: 5))

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Phase 0 Shell"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
