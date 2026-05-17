//
//  AppState.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import Foundation

struct AppState: Equatable {
    var connections: [ConnectionProfile]
    var selectedConnectionID: ConnectionProfile.ID?
    var selectedCatalogItem: CatalogSelection?
    var workspaceTabs: [WorkspaceTab]
    var selectedTabID: WorkspaceTab.ID?
    var queryDocuments: [QueryDocument]
    var queryExecutionStates: [UUID: QueryExecutionState]
    var queryHistoryEntries: [QueryHistoryEntry]

    init(
        connections: [ConnectionProfile] = [],
        selectedConnectionID: ConnectionProfile.ID? = nil,
        selectedCatalogItem: CatalogSelection? = nil,
        workspaceTabs: [WorkspaceTab] = [],
        selectedTabID: WorkspaceTab.ID? = nil,
        queryDocuments: [QueryDocument] = [],
        queryExecutionStates: [UUID: QueryExecutionState] = [:],
        queryHistoryEntries: [QueryHistoryEntry] = []
    ) {
        self.connections = connections
        self.selectedConnectionID = selectedConnectionID
        self.selectedCatalogItem = selectedCatalogItem
        self.workspaceTabs = workspaceTabs
        self.selectedTabID = selectedTabID
        self.queryDocuments = queryDocuments
        self.queryExecutionStates = queryExecutionStates
        self.queryHistoryEntries = queryHistoryEntries
    }

    var selectedConnection: ConnectionProfile? {
        connections.first { $0.id == selectedConnectionID }
    }

    var selectedTab: WorkspaceTab? {
        workspaceTabs.first { $0.id == selectedTabID }
    }

    var selectedQueryDocument: QueryDocument? {
        guard let selectedTab, let documentID = selectedTab.queryDocumentID else {
            return nil
        }

        return queryDocuments.first { $0.id == documentID }
    }

    mutating func openQueryTab(connectionID: UUID) {
        let documentIndex = queryDocuments.filter { $0.connectionID == connectionID }.count + 1
        let title = documentIndex == 1 ? "Untitled Query" : "Untitled Query \(documentIndex)"
        let document = QueryDocument(connectionID: connectionID, title: title)
        let tab = WorkspaceTab(
            title: title,
            kind: .query,
            connectionID: connectionID,
            queryDocumentID: document.id
        )

        queryDocuments.append(document)
        queryExecutionStates[document.id] = .idle
        workspaceTabs.append(tab)
        selectedConnectionID = connectionID
        selectedTabID = tab.id
        selectedCatalogItem = nil
    }

    mutating func replaceSelectedQuerySQL(_ sql: String) {
        guard let selectedQueryDocument,
              let index = queryDocuments.firstIndex(where: { $0.id == selectedQueryDocument.id }) else {
            return
        }

        queryDocuments[index].sql = sql
        queryDocuments[index].updatedAt = .now
    }
}

enum SidebarSelection: Hashable {
    case connections
    case connection(ConnectionProfile.ID)
    case settings
}
