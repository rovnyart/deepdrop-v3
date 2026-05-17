//
//  WorkspaceView.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import SwiftUI

struct WorkspaceView: View {
    @Binding var appState: AppState
    let selectedCatalog: DatabaseCatalog?
    let onAddConnection: () -> Void
    let onNewQuery: () -> Void
    let onExecuteQuery: (SQLStatement, ConnectionProfile) async throws -> QueryExecutionResponse
    let onRecordQueryHistory: (QueryHistoryEntry) -> Void

    var body: some View {
        VStack(spacing: 0) {
            workspaceToolbar

            Divider()

            if !appState.workspaceTabs.isEmpty {
                workspaceTabBar
                Divider()
            }

            if appState.connections.isEmpty {
                ConnectionEmptyStateView(onAddConnection: onAddConnection)
            } else if let selectedQueryDocumentBinding {
                QueryEditorView(
                    document: selectedQueryDocumentBinding,
                    executionState: selectedQueryExecutionStateBinding ?? .constant(.idle),
                    connection: appState.selectedConnection,
                    onExecute: onExecuteQuery,
                    onRecordHistory: onRecordQueryHistory,
                    historyEntries: historyEntriesForSelectedConnection,
                    onUseHistoryEntry: useHistoryEntry
                )
            } else if let selectedCatalog {
                CatalogObjectDetailView(catalog: selectedCatalog, selection: appState.selectedCatalogItem)
            } else {
                WorkspacePlaceholderView(tab: appState.selectedTab)
            }

            Divider()

            resultsPane
        }
        .background(DeepDropColors.workspaceBackground)
    }

    @ViewBuilder
    private var resultsPane: some View {
        if selectedQueryDocumentBinding == nil {
            ResultsPlaceholderView()
                .frame(height: 168)
        } else {
            QueryResultPreviewView(state: selectedQueryExecutionStateBinding?.wrappedValue ?? .idle)
                .frame(height: 168)
        }
    }

    private var selectedQueryExecutionStateBinding: Binding<QueryExecutionState>? {
        guard let selectedTab = appState.selectedTab,
              let queryDocumentID = selectedTab.queryDocumentID else {
            return nil
        }

        return Binding(
            get: { appState.queryExecutionStates[queryDocumentID] ?? .idle },
            set: { appState.queryExecutionStates[queryDocumentID] = $0 }
        )
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

            Button(action: onNewQuery) {
                Label("New Query", systemImage: "plus.square.on.square")
            }
            .disabled(appState.selectedConnectionID == nil)
            .keyboardShortcut("t", modifiers: .command)
            .help(appState.selectedConnectionID == nil ? "Select a database source before creating queries" : "New query tab")
        }
        .padding(.horizontal, DeepDropSpacing.lg)
        .padding(.vertical, DeepDropSpacing.md)
        .background(.bar)
    }

    private var workspaceTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DeepDropSpacing.xs) {
                ForEach(appState.workspaceTabs) { tab in
                    Button {
                        appState.selectedTabID = tab.id
                        appState.selectedConnectionID = tab.connectionID ?? appState.selectedConnectionID
                        appState.selectedCatalogItem = nil
                    } label: {
                        Label(tab.title, systemImage: tab.kind == .query ? "terminal" : "tablecells")
                            .lineLimit(1)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(appState.selectedTabID == tab.id ? .accentColor : .secondary)
                }
            }
            .padding(.horizontal, DeepDropSpacing.lg)
            .padding(.vertical, DeepDropSpacing.sm)
        }
        .background(DeepDropColors.panelBackground)
    }

    private var selectedQueryDocumentBinding: Binding<QueryDocument>? {
        guard let selectedTab = appState.selectedTab,
              selectedTab.kind == .query,
              let queryDocumentID = selectedTab.queryDocumentID,
              let index = appState.queryDocuments.firstIndex(where: { $0.id == queryDocumentID }) else {
            return nil
        }

        return $appState.queryDocuments[index]
    }

    private var historyEntriesForSelectedConnection: [QueryHistoryEntry] {
        guard let selectedConnectionID = appState.selectedConnectionID else {
            return []
        }

        return appState.queryHistoryEntries.filter { $0.connectionID == selectedConnectionID }
    }

    private func useHistoryEntry(_ entry: QueryHistoryEntry) {
        Task { @MainActor in
            appState.replaceSelectedQuerySQL(entry.sql)
        }
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
    WorkspaceView(
        appState: .constant(AppState()),
        selectedCatalog: nil,
        onAddConnection: {},
        onNewQuery: {},
        onExecuteQuery: { _, _ in throw QueryExecutionError.missingConnection },
        onRecordQueryHistory: { _ in }
    )
}
