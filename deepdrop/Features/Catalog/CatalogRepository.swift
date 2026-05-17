//
//  CatalogRepository.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class CatalogRepository {
    private(set) var catalogByConnectionID: [UUID: DatabaseCatalog] = [:]
    private(set) var loadingStateByConnectionID: [UUID: CatalogLoadingState] = [:]
    private(set) var cacheStatusByConnectionID: [UUID: String] = [:]

    private let cacheStore: CatalogCacheStore
    private let introspectionService: CatalogIntrospecting
    private let staleInterval: TimeInterval
    private var activeLoadConnectionIDs: Set<UUID> = []

    convenience init() {
        self.init(
            cacheStore: JSONCatalogCacheStore(),
            introspectionService: CatalogIntrospectionService()
        )
    }

    init(
        cacheStore: CatalogCacheStore,
        introspectionService: CatalogIntrospecting,
        staleInterval: TimeInterval = 15 * 60
    ) {
        self.cacheStore = cacheStore
        self.introspectionService = introspectionService
        self.staleInterval = staleInterval
    }

    func catalog(for connectionID: UUID) -> DatabaseCatalog? {
        catalogByConnectionID[connectionID]
    }

    func loadingState(for connectionID: UUID) -> CatalogLoadingState {
        loadingStateByConnectionID[connectionID] ?? .idle
    }

    func cacheStatus(for connectionID: UUID) -> String? {
        cacheStatusByConnectionID[connectionID]
    }

    func loadCatalog(for profile: ConnectionProfile, password: String, forceRefresh: Bool = false) async {
        guard !activeLoadConnectionIDs.contains(profile.id) else {
            return
        }

        if !forceRefresh {
            if let existingCatalog = catalogByConnectionID[profile.id] {
                loadingStateByConnectionID[profile.id] = .loaded(existingCatalog.loadedAt)
                cacheStatusByConnectionID[profile.id] = cacheStatus(for: existingCatalog)
                if !isStale(existingCatalog) {
                    return
                }
            } else {
                do {
                    if let cachedCatalog = try cacheStore.loadCatalog(connectionID: profile.id) {
                        catalogByConnectionID[profile.id] = cachedCatalog
                        loadingStateByConnectionID[profile.id] = .loaded(cachedCatalog.loadedAt)
                        cacheStatusByConnectionID[profile.id] = cacheStatus(for: cachedCatalog)
                        if !isStale(cachedCatalog) {
                            return
                        }
                    }
                } catch {
                    loadingStateByConnectionID[profile.id] = .failed("Could not load cached catalog: \(error.localizedDescription)")
                }
            }
        }

        activeLoadConnectionIDs.insert(profile.id)
        loadingStateByConnectionID[profile.id] = .loading
        cacheStatusByConnectionID[profile.id] = forceRefresh ? "Refreshing catalog..." : "Refreshing stale catalog..."

        do {
            let catalog = try await introspectionService.loadCatalog(for: profile, password: password)
            catalogByConnectionID[profile.id] = catalog
            loadingStateByConnectionID[profile.id] = .loaded(catalog.loadedAt)
            cacheStatusByConnectionID[profile.id] = cacheStatus(for: catalog)
            try cacheStore.saveCatalog(catalog)
        } catch is CancellationError {
            loadingStateByConnectionID[profile.id] = .idle
        } catch {
            loadingStateByConnectionID[profile.id] = .failed(error.localizedDescription)
        }

        activeLoadConnectionIDs.remove(profile.id)
    }

    func refreshCatalog(for profile: ConnectionProfile, password: String) async {
        await loadCatalog(for: profile, password: password, forceRefresh: true)
    }

    func clearCatalog(for connectionID: UUID) {
        catalogByConnectionID[connectionID] = nil
        loadingStateByConnectionID[connectionID] = .idle
        cacheStatusByConnectionID[connectionID] = nil
        try? cacheStore.deleteCatalog(connectionID: connectionID)
    }

    private func isStale(_ catalog: DatabaseCatalog) -> Bool {
        Date().timeIntervalSince(catalog.loadedAt) > staleInterval
    }

    private func cacheStatus(for catalog: DatabaseCatalog) -> String {
        if isStale(catalog) {
            return "Cached catalog is stale. Refresh when ready."
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "Catalog refreshed \(formatter.localizedString(for: catalog.loadedAt, relativeTo: .now))"
    }
}
