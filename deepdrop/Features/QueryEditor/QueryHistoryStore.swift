//
//  QueryHistoryStore.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import Foundation

struct QueryHistoryEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var connectionID: UUID
    var sql: String
    var classification: SQLStatementClassification
    var startedAt: Date
    var duration: TimeInterval?
    var rowCount: Int?
    var succeeded: Bool
    var wasCancelled: Bool
    var errorMessage: String?

    init(
        id: UUID = UUID(),
        connectionID: UUID,
        sql: String,
        classification: SQLStatementClassification,
        startedAt: Date,
        duration: TimeInterval?,
        rowCount: Int?,
        succeeded: Bool,
        wasCancelled: Bool = false,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.connectionID = connectionID
        self.sql = sql
        self.classification = classification
        self.startedAt = startedAt
        self.duration = duration
        self.rowCount = rowCount
        self.succeeded = succeeded
        self.wasCancelled = wasCancelled
        self.errorMessage = errorMessage
    }
}

protocol QueryHistoryStoring {
    func loadEntries() throws -> [QueryHistoryEntry]
    func append(_ entry: QueryHistoryEntry) throws
}

struct JSONQueryHistoryStore: QueryHistoryStoring {
    let fileURL: URL
    let maximumEntryCount: Int

    init(fileURL: URL = Self.defaultFileURL(), maximumEntryCount: Int = 1000) {
        self.fileURL = fileURL
        self.maximumEntryCount = maximumEntryCount
    }

    func loadEntries() throws -> [QueryHistoryEntry] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder.queryHistory.decode([QueryHistoryEntry].self, from: data)
    }

    func append(_ entry: QueryHistoryEntry) throws {
        var entries = try loadEntries()
        entries.insert(entry, at: 0)
        if entries.count > maximumEntryCount {
            entries = Array(entries.prefix(maximumEntryCount))
        }

        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try JSONEncoder.queryHistory.encode(entries)
        try data.write(to: fileURL, options: [.atomic])
    }

    static func defaultFileURL() -> URL {
        if let overridePath = ProcessInfo.processInfo.environment["DEEPDROP_QUERY_HISTORY_FILE"], !overridePath.isEmpty {
            return URL(fileURLWithPath: overridePath)
        }

        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")

        return baseURL
            .appendingPathComponent("DeepDrop", isDirectory: true)
            .appendingPathComponent("query-history.json", isDirectory: false)
    }
}

private extension JSONEncoder {
    static var queryHistory: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var queryHistory: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
