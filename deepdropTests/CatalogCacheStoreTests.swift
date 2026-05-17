//
//  CatalogCacheStoreTests.swift
//  deepdropTests
//
//  Created by Codex on 17.05.2026.
//

import Foundation
import Testing
@testable import deepdrop

struct CatalogCacheStoreTests {
    @Test func cacheRoundTripsCatalog() throws {
        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent("catalog-cache-\(UUID().uuidString)", isDirectory: true)
        let store = JSONCatalogCacheStore(directoryURL: directoryURL)
        let catalog = sampleCatalog(connectionID: UUID())

        try store.saveCatalog(catalog)
        let loadedCatalog = try store.loadCatalog(connectionID: catalog.connectionID)

        #expect(loadedCatalog == catalog)
        try? FileManager.default.removeItem(at: directoryURL)
    }

    @Test func deletingCatalogRemovesCachedFile() throws {
        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent("catalog-cache-\(UUID().uuidString)", isDirectory: true)
        let store = JSONCatalogCacheStore(directoryURL: directoryURL)
        let catalog = sampleCatalog(connectionID: UUID())

        try store.saveCatalog(catalog)
        try store.deleteCatalog(connectionID: catalog.connectionID)

        #expect(try store.loadCatalog(connectionID: catalog.connectionID) == nil)
        try? FileManager.default.removeItem(at: directoryURL)
    }
}

private func sampleCatalog(connectionID: UUID) -> DatabaseCatalog {
    DatabaseCatalog(
        connectionID: connectionID,
        databaseName: "deepdrop",
        loadedAt: Date(timeIntervalSince1970: 0),
        schemas: [
            DatabaseSchema(
                name: "public",
                owner: "postgres",
                tables: [],
                views: [],
                materializedViews: [],
                functions: []
            )
        ],
        extensions: [
            DatabaseExtension(name: "plpgsql", version: "1.0", schema: "pg_catalog")
        ]
    )
}
