//
//  WorkspaceTab.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import Foundation

enum WorkspaceTabKind: String, Codable, Hashable {
    case query
    case tableData
    case tableStructure
}

struct WorkspaceTab: Identifiable, Hashable, Codable {
    var id: UUID
    var title: String
    var kind: WorkspaceTabKind
    var connectionID: UUID?
    var queryDocumentID: UUID?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String = "Untitled Query",
        kind: WorkspaceTabKind = .query,
        connectionID: UUID? = nil,
        queryDocumentID: UUID? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.connectionID = connectionID
        self.queryDocumentID = queryDocumentID
        self.createdAt = createdAt
    }
}
