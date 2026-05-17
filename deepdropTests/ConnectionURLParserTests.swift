//
//  ConnectionURLParserTests.swift
//  deepdropTests
//
//  Created by Codex on 17.05.2026.
//

import Testing
@testable import deepdrop

struct ConnectionURLParserTests {
    @Test func parsesPostgresURL() throws {
        let parsed = try ConnectionURLParser.parse("postgres://art:secret@localhost:5433/deepdrop")

        #expect(parsed.displayName == "deepdrop localhost")
        #expect(parsed.host == "localhost")
        #expect(parsed.port == 5433)
        #expect(parsed.database == "deepdrop")
        #expect(parsed.username == "art")
        #expect(parsed.password == "secret")
        #expect(parsed.sslMode == .prefer)
    }

    @Test func parsesPostgresqlURLWithDefaultPort() throws {
        let parsed = try ConnectionURLParser.parse("postgresql://art:secret@db.example.com/analytics")

        #expect(parsed.host == "db.example.com")
        #expect(parsed.port == 5432)
        #expect(parsed.database == "analytics")
    }

    @Test func parsesEscapedCredentialsAndDatabase() throws {
        let parsed = try ConnectionURLParser.parse("postgres://art%40deepdrop:p%40ss%2Fword@localhost/my%20db")

        #expect(parsed.username == "art@deepdrop")
        #expect(parsed.password == "p@ss/word")
        #expect(parsed.database == "my db")
    }

    @Test func parsesSSLModeQueryItem() throws {
        let parsed = try ConnectionURLParser.parse("postgresql://art:secret@localhost/deepdrop?sslmode=require")

        #expect(parsed.sslMode == .require)
    }

    @Test func parsesVerifyFullSSLMode() throws {
        let parsed = try ConnectionURLParser.parse("postgresql://art:secret@localhost/deepdrop?sslmode=verify-full")

        #expect(parsed.sslMode == .verifyFull)
    }

    @Test func rejectsUnsupportedScheme() {
        #expect(throws: ConnectionURLParserError.unsupportedScheme("mysql")) {
            try ConnectionURLParser.parse("mysql://art:secret@localhost/deepdrop")
        }
    }

    @Test func rejectsMissingHost() {
        #expect(throws: ConnectionURLParserError.missingHost) {
            try ConnectionURLParser.parse("postgresql:///deepdrop")
        }
    }

    @Test func rejectsMissingDatabase() {
        #expect(throws: ConnectionURLParserError.missingDatabase) {
            try ConnectionURLParser.parse("postgresql://art:secret@localhost")
        }
    }

    @Test func rejectsInvalidPort() {
        #expect(throws: ConnectionURLParserError.invalidPort("abc")) {
            try ConnectionURLParser.parse("postgresql://art:secret@localhost:abc/deepdrop")
        }
    }
}
