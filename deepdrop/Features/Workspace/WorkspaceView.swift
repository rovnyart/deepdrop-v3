//
//  WorkspaceView.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import SwiftUI

struct WorkspaceView: View {
    let appState: AppState
    let selectedCatalog: DatabaseCatalog?
    let onAddConnection: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            workspaceToolbar

            Divider()

            if appState.connections.isEmpty {
                ConnectionEmptyStateView(onAddConnection: onAddConnection)
            } else if let selectedCatalog {
                CatalogObjectDetailView(catalog: selectedCatalog, selection: appState.selectedCatalogItem)
            } else {
                WorkspacePlaceholderView(tab: appState.selectedTab)
            }

            Divider()

            ResultsPlaceholderView()
                .frame(height: 168)
        }
        .background(DeepDropColors.workspaceBackground)
    }

    private var workspaceToolbar: some View {
        HStack(spacing: DeepDropSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(toolbarTitle)
                    .font(DeepDropTypography.workspaceTitle)
                Text(toolbarSubtitle)
                    .font(DeepDropTypography.metadata)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: {}) {
                Label("New Query", systemImage: "plus.square.on.square")
            }
            .disabled(appState.connections.isEmpty)
            .help(appState.connections.isEmpty ? "Add a database source before creating queries" : "New query tab")
        }
        .padding(.horizontal, DeepDropSpacing.lg)
        .padding(.vertical, DeepDropSpacing.md)
        .background(.bar)
    }

    private var toolbarTitle: String {
        appState.selectedConnection?.displayName ?? "Workspace"
    }

    private var toolbarSubtitle: String {
        if let connection = appState.selectedConnection {
            return "\(connection.host) · PostgreSQL"
        }

        return "No database source selected"
    }
}

#Preview {
    WorkspaceView(appState: AppState(), selectedCatalog: nil, onAddConnection: {})
}
