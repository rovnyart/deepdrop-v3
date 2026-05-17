//
//  deepdropUITests.swift
//  deepdropUITests
//
//  Created by art on 17.05.2026.
//

import XCTest

final class deepdropUITests: XCTestCase {
    private var connectionsFileURL: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false
        connectionsFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("deepdrop-ui-tests-\(UUID().uuidString)")
            .appendingPathComponent("connections.json")
    }

    override func tearDownWithError() throws {
        if let connectionsFileURL {
            try? FileManager.default.removeItem(at: connectionsFileURL.deletingLastPathComponent())
        }
    }

    @MainActor
    func testLaunchShowsShell() throws {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["DeepDrop"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Connect to PostgreSQL"].exists)
        XCTAssertTrue(app.buttons["empty-add-database-source-button"].exists)
        XCTAssertTrue(app.staticTexts["No query has been run"].exists)
    }

    @MainActor
    func testAddConnectionFormParsesURLAndSaves() throws {
        let app = makeApp()
        app.launch()

        addConnection(
            in: app,
            url: "postgresql://art:secret@localhost:5433/deepdrop?sslmode=require"
        )

        XCTAssertTrue(app.staticTexts["deepdrop localhost"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testDuplicateConnectionShowsInlineError() throws {
        let app = makeApp()
        app.launch()

        let url = "postgresql://art:secret@localhost:5433/deepdrop?sslmode=require"
        addConnection(in: app, url: url)
        XCTAssertTrue(app.staticTexts["deepdrop localhost"].waitForExistence(timeout: 3))

        openAddConnectionForm(in: app)
        fillConnectionURL(url, in: app)

        let saveButton = app.buttons["connection-form-save-button"]
        XCTAssertTrue(saveButton.isEnabled)
        saveButton.click()

        XCTAssertTrue(app.staticTexts["This exact connection already exists. Change the host, port, database, user, or SSL mode, or edit the existing saved source."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Add Database Source"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            makeApp().launch()
        }
    }

    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["DEEPDROP_CONNECTIONS_FILE"] = connectionsFileURL.path
        app.launchEnvironment["DEEPDROP_KEYCHAIN_SERVICE"] = "com.deepdrop.ui-tests.\(UUID().uuidString)"
        return app
    }

    @MainActor
    private func addConnection(in app: XCUIApplication, url: String) {
        openAddConnectionForm(in: app)
        fillConnectionURL(url, in: app)

        XCTAssertEqual(app.textFields["connection-host-field"].value as? String, "localhost")
        XCTAssertEqual(app.textFields["connection-port-field"].value as? String, "5433")
        XCTAssertEqual(app.textFields["connection-database-field"].value as? String, "deepdrop")
        XCTAssertEqual(app.textFields["connection-username-field"].value as? String, "art")

        let saveButton = app.buttons["connection-form-save-button"]
        XCTAssertTrue(saveButton.isEnabled)
        saveButton.click()
    }

    @MainActor
    private func openAddConnectionForm(in app: XCUIApplication) {
        let addButton = app.buttons["empty-add-database-source-button"].exists
            ? app.buttons["empty-add-database-source-button"]
            : app.buttons["add-database-source-button"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.click()
        XCTAssertTrue(app.staticTexts["Add Database Source"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func fillConnectionURL(_ url: String, in app: XCUIApplication) {
        let urlField = app.textFields["connection-url-field"]
        XCTAssertTrue(urlField.exists)
        urlField.click()
        urlField.typeText(url)
    }
}
