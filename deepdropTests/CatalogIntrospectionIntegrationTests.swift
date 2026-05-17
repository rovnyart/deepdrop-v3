//
//  CatalogIntrospectionIntegrationTests.swift
//  deepdropTests
//
//  Created by Codex on 17.05.2026.
//

import Foundation
import Testing
@testable import deepdrop

struct CatalogIntrospectionIntegrationTests {
    @MainActor
    @Test func loadsCatalogFromConfiguredPostgresURL() async throws {
        guard let rawURL = ProcessInfo.processInfo.environment["DEEPDROP_INTEGRATION_POSTGRES_URL"], !rawURL.isEmpty else {
            return
        }

        let parsedURL = try ConnectionURLParser.parse(rawURL)
        let profile = ConnectionProfile(
            displayName: parsedURL.displayName,
            host: parsedURL.host,
            port: parsedURL.port,
            database: parsedURL.database,
            username: parsedURL.username,
            sslMode: parsedURL.sslMode
        )

        let catalog = try await CatalogIntrospectionService().loadCatalog(for: profile, password: parsedURL.password)

        #expect(catalog.connectionID == profile.id)
        #expect(catalog.databaseName == parsedURL.database)
        #expect(!catalog.schemas.isEmpty)
    }
}
