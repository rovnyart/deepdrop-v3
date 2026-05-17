//
//  deepdropUITestsLaunchTests.swift
//  deepdropUITests
//
//  Created by art on 17.05.2026.
//

import XCTest

final class deepdropUITestsLaunchTests: XCTestCase {
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        false
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        let baseDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("deepdrop-launch-ui-test-\(UUID().uuidString)", isDirectory: true)
        app.launchEnvironment["DEEPDROP_CONNECTIONS_FILE"] = baseDirectoryURL
            .appendingPathComponent("connections.json")
            .path
        app.launchEnvironment["DEEPDROP_CATALOG_CACHE_DIR"] = baseDirectoryURL
            .appendingPathComponent("CatalogCache", isDirectory: true)
            .path
        app.launchEnvironment["DEEPDROP_KEYCHAIN_SERVICE"] = "com.deepdrop.launch-ui-test.\(UUID().uuidString)"
        app.launch()

        XCTAssertTrue(app.staticTexts["Connect to PostgreSQL"].waitForExistence(timeout: 5))

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Phase 0 Shell"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
