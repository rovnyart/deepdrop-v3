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

    init(
        connections: [ConnectionProfile] = [],
        selectedConnectionID: ConnectionProfile.ID? = nil,
        selectedCatalogItem: CatalogSelection? = nil,
        workspaceTabs: [WorkspaceTab] = [],
        selectedTabID: WorkspaceTab.ID? = nil
    ) {
        self.connections = connections
        self.selectedConnectionID = selectedConnectionID
        self.selectedCatalogItem = selectedCatalogItem
        self.workspaceTabs = workspaceTabs
        self.selectedTabID = selectedTabID
    }

    var selectedConnection: ConnectionProfile? {
        connections.first { $0.id == selectedConnectionID }
    }

    var selectedTab: WorkspaceTab? {
        workspaceTabs.first { $0.id == selectedTabID }
    }
}

enum SidebarSelection: Hashable {
    case connections
    case connection(ConnectionProfile.ID)
    case settings
}
