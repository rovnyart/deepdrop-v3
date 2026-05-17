//
//  QueryHistoryStoreTests.swift
//  deepdropTests
//
//  Created by Codex on 17.05.2026.
//

import Foundation
import Testing
@testable import deepdrop

struct QueryHistoryStoreTests {
    @Test func historyRoundTripsEntries() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("query-history-\(UUID().uuidString).json")
        let store = JSONQueryHistoryStore(fileURL: fileURL)
        let entry = QueryHistoryEntry(
            connectionID: UUID(),
            sql: "select 1",
            classification: .readOnly,
            startedAt: Date(timeIntervalSince1970: 0),
            duration: 0.05,
            rowCount: 1,
            succeeded: true
        )

        try store.append(entry)

        #expect(try store.loadEntries() == [entry])
        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test func historyKeepsNewestEntriesWhenBounded() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("query-history-\(UUID().uuidString).json")
        let store = JSONQueryHistoryStore(fileURL: fileURL, maximumEntryCount: 2)
        let first = entry(sql: "select 1")
        let second = entry(sql: "select 2")
        let third = entry(sql: "select 3")

        try store.append(first)
        try store.append(second)
        try store.append(third)

        #expect(try store.loadEntries().map(\.sql) == ["select 3", "select 2"])
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func entry(sql: String) -> QueryHistoryEntry {
        QueryHistoryEntry(
            connectionID: UUID(),
            sql: sql,
            classification: .readOnly,
            startedAt: Date(timeIntervalSince1970: 0),
            duration: nil,
            rowCount: nil,
            succeeded: true
        )
    }
}
