//
//  ConnectionValidationTests.swift
//  deepdropTests
//
//  Created by Codex on 17.05.2026.
//

import Testing
@testable import deepdrop

struct ConnectionValidationTests {
    @Test func validDraftPassesValidation() {
        let draft = ConnectionDraft(
            displayName: "Local DeepDrop",
            host: "localhost",
            portText: "5432",
            database: "deepdrop",
            username: "art",
            password: ""
        )

        #expect(ConnectionValidation.validate(draft).isValid)
    }

    @Test func requiredFieldsAreValidated() {
        let result = ConnectionValidation.validate(ConnectionDraft(portText: "5432"))

        #expect(result.message(for: .displayName) == "Name is required.")
        #expect(result.message(for: .host) == "Host is required.")
        #expect(result.message(for: .database) == "Database is required.")
        #expect(result.message(for: .username) == "User is required.")
    }

    @Test func portMustBeNumeric() {
        let draft = ConnectionDraft(
            displayName: "Local",
            host: "localhost",
            portText: "abc",
            database: "deepdrop",
            username: "art"
        )

        let result = ConnectionValidation.validate(draft)

        #expect(result.message(for: .port) == "Port must be a number.")
    }

    @Test func portMustBeInRange() {
        let draft = ConnectionDraft(
            displayName: "Local",
            host: "localhost",
            portText: "70000",
            database: "deepdrop",
            username: "art"
        )

        let result = ConnectionValidation.validate(draft)

        #expect(result.message(for: .port) == "Port must be between 1 and 65535.")
    }

    @Test func draftCanBeInitializedFromParsedURL() throws {
        let parsed = try ConnectionURLParser.parse("postgresql://art:secret@localhost/deepdrop?sslmode=require")
        let draft = ConnectionDraft(parsedURL: parsed)

        #expect(draft.displayName == "deepdrop localhost")
        #expect(draft.host == "localhost")
        #expect(draft.portText == "5432")
        #expect(draft.database == "deepdrop")
        #expect(draft.username == "art")
        #expect(draft.password == "secret")
        #expect(draft.sslMode == .require)
    }
}
