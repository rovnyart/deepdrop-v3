//
//  CatalogCacheStore.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import Foundation

protocol CatalogCacheStore {
    func loadCatalog(connectionID: UUID) throws -> DatabaseCatalog?
    func saveCatalog(_ catalog: DatabaseCatalog) throws
    func deleteCatalog(connectionID: UUID) throws
}

struct JSONCatalogCacheStore: CatalogCacheStore {
    let directoryURL: URL

    init(directoryURL: URL = Self.defaultDirectoryURL()) {
        self.directoryURL = directoryURL
    }

    func loadCatalog(connectionID: UUID) throws -> DatabaseCatalog? {
        let fileURL = fileURL(for: connectionID)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder.catalogCache.decode(DatabaseCatalog.self, from: data)
    }

    func saveCatalog(_ catalog: DatabaseCatalog) throws {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try JSONEncoder.catalogCache.encode(catalog)
        try data.write(to: fileURL(for: catalog.connectionID), options: [.atomic])
    }

    func deleteCatalog(connectionID: UUID) throws {
        let fileURL = fileURL(for: connectionID)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    private func fileURL(for connectionID: UUID) -> URL {
        directoryURL.appendingPathComponent("\(connectionID.uuidString).json", isDirectory: false)
    }

    static func defaultDirectoryURL() -> URL {
        if let overridePath = ProcessInfo.processInfo.environment["DEEPDROP_CATALOG_CACHE_DIR"], !overridePath.isEmpty {
            return URL(fileURLWithPath: overridePath, isDirectory: true)
        }

        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")

        return baseURL
            .appendingPathComponent("DeepDrop", isDirectory: true)
            .appendingPathComponent("CatalogCache", isDirectory: true)
    }
}

private extension JSONEncoder {
    static var catalogCache: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var catalogCache: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
