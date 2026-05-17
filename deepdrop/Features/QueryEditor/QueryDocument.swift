//
//  QueryDocument.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import Foundation

struct QueryDocument: Identifiable, Hashable, Codable {
    var id: UUID
    var connectionID: UUID
    var title: String
    var sql: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        connectionID: UUID,
        title: String = "Untitled Query",
        sql: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.connectionID = connectionID
        self.title = title
        self.sql = sql
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
