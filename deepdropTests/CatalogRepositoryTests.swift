//
//  CatalogRepositoryTests.swift
//  deepdropTests
//
//  Created by Codex on 17.05.2026.
//

import Foundation
import Testing
@testable import deepdrop

@MainActor
struct CatalogRepositoryTests {
    @Test func freshCachedCatalogDoesNotRefresh() async throws {
        let connectionID = UUID()
        let catalog = sampleCatalog(connectionID: connectionID, loadedAt: .now)
        let cacheStore = InMemoryCatalogCacheStore(catalogs: [connectionID: catalog])
        let introspector = CountingCatalogIntrospector(catalog: catalog)
        let repository = CatalogRepository(cacheStore: cacheStore, introspectionService: introspector, staleInterval: 60)
        let profile = sampleProfile(id: connectionID)

        await repository.loadCatalog(for: profile, password: "secret")

        #expect(repository.catalog(for: connectionID) == catalog)
        #expect(introspector.loadCount == 0)
    }

    @Test func staleCachedCatalogRefreshes() async throws {
        let connectionID = UUID()
        let staleCatalog = sampleCatalog(connectionID: connectionID, loadedAt: Date(timeIntervalSinceNow: -120))
        let freshCatalog = sampleCatalog(connectionID: connectionID, loadedAt: .now)
        let cacheStore = InMemoryCatalogCacheStore(catalogs: [connectionID: staleCatalog])
        let introspector = CountingCatalogIntrospector(catalog: freshCatalog)
        let repository = CatalogRepository(cacheStore: cacheStore, introspectionService: introspector, staleInterval: 60)
        let profile = sampleProfile(id: connectionID)

        await repository.loadCatalog(for: profile, password: "secret")

        #expect(repository.catalog(for: connectionID) == freshCatalog)
        #expect(introspector.loadCount == 1)
    }

    @Test func forceRefreshIgnoresFreshCache() async throws {
        let connectionID = UUID()
        let cachedCatalog = sampleCatalog(connectionID: connectionID, loadedAt: .now)
        let refreshedCatalog = sampleCatalog(connectionID: connectionID, loadedAt: Date(timeIntervalSinceNow: 1))
        let cacheStore = InMemoryCatalogCacheStore(catalogs: [connectionID: cachedCatalog])
        let introspector = CountingCatalogIntrospector(catalog: refreshedCatalog)
        let repository = CatalogRepository(cacheStore: cacheStore, introspectionService: introspector, staleInterval: 60)
        let profile = sampleProfile(id: connectionID)

        await repository.loadCatalog(for: profile, password: "secret", forceRefresh: true)

        #expect(repository.catalog(for: connectionID) == refreshedCatalog)
        #expect(introspector.loadCount == 1)
    }
}

private func sampleProfile(id: UUID) -> ConnectionProfile {
    ConnectionProfile(
        id: id,
        displayName: "Local",
        host: "localhost",
        database: "deepdrop",
        username: "art"
    )
}

private func sampleCatalog(connectionID: UUID, loadedAt: Date) -> DatabaseCatalog {
    DatabaseCatalog(
        connectionID: connectionID,
        databaseName: "deepdrop",
        loadedAt: loadedAt,
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
        extensions: []
    )
}

private final class InMemoryCatalogCacheStore: CatalogCacheStore {
    var catalogs: [UUID: DatabaseCatalog]

    init(catalogs: [UUID: DatabaseCatalog]) {
        self.catalogs = catalogs
    }

    func loadCatalog(connectionID: UUID) throws -> DatabaseCatalog? {
        catalogs[connectionID]
    }

    func saveCatalog(_ catalog: DatabaseCatalog) throws {
        catalogs[catalog.connectionID] = catalog
    }

    func deleteCatalog(connectionID: UUID) throws {
        catalogs[connectionID] = nil
    }
}

private final class CountingCatalogIntrospector: CatalogIntrospecting {
    var loadCount = 0
    let catalog: DatabaseCatalog

    init(catalog: DatabaseCatalog) {
        self.catalog = catalog
    }

    func loadCatalog(for profile: ConnectionProfile, password: String) async throws -> DatabaseCatalog {
        loadCount += 1
        return catalog
    }
}
