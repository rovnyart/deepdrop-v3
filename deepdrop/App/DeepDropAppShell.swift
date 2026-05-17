//
//  DeepDropAppShell.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import SwiftUI

struct DeepDropAppShell: View {
    @State private var connectionRepository = ConnectionProfileRepository()
    @State private var catalogRepository = CatalogRepository()
    @State private var appState = AppState()
    @State private var sidebarSelection: SidebarSelection? = .connections
    @State private var connectionFormDraft: ConnectionDraft?
    @State private var connectionPendingDeletion: ConnectionProfile?

    var body: some View {
        HSplitView {
            ConnectionListView(
                connections: connectionRepository.profiles,
                selectedConnectionID: appState.selectedConnectionID,
                selectedCatalog: selectedCatalog,
                catalogLoadingState: selectedCatalogLoadingState,
                catalogCacheStatus: selectedCatalogCacheStatus,
                selectedCatalogItem: $appState.selectedCatalogItem,
                selection: $sidebarSelection,
                onAddConnection: showAddConnectionPlaceholder,
                onEditConnection: editConnection,
                onDuplicateConnection: duplicateConnection,
                onDeleteConnection: requestDeleteConnection,
                onRefreshCatalog: refreshCatalog
            )
            .frame(minWidth: 240, idealWidth: 280, maxWidth: 360)

            WorkspaceView(
                appState: appState,
                selectedCatalog: selectedCatalog,
                onAddConnection: showAddConnectionPlaceholder
            )
            .frame(minWidth: 680, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("deepdrop-app-shell")
        .onAppear {
            connectionRepository.load()
            syncConnectionsFromRepository()
        }
        .onChange(of: connectionRepository.profiles) { _, _ in
            syncConnectionsFromRepository()
        }
        .onChange(of: sidebarSelection) { _, newSelection in
            if case .connection(let connectionID) = newSelection {
                appState.selectedConnectionID = connectionID
                loadCatalogForSelectedConnection(forceRefresh: false)
            }
        }
        .sheet(
            isPresented: Binding(
                get: { connectionFormDraft != nil },
                set: { isPresented in
                    if !isPresented {
                        connectionFormDraft = nil
                    }
                }
            )
        ) {
            ConnectionFormView(
                draft: connectionFormDraft ?? ConnectionDraft(),
                onSave: saveConnection,
                onCancel: {
                    connectionFormDraft = nil
                }
            )
        }
        .confirmationDialog(
            "Delete Connection?",
            isPresented: Binding(
                get: { connectionPendingDeletion != nil },
                set: { isPresented in
                    if !isPresented {
                        connectionPendingDeletion = nil
                    }
                }
            ),
            presenting: connectionPendingDeletion
        ) { connection in
            Button("Delete \(connection.displayName)", role: .destructive) {
                deleteConnection(connection)
            }

            Button("Cancel", role: .cancel) {
                connectionPendingDeletion = nil
            }
        } message: { connection in
            Text("This removes the saved profile and its Keychain password.")
        }
    }

    private func showAddConnectionPlaceholder() {
        connectionFormDraft = ConnectionDraft()
    }

    private func saveConnection(_ draft: ConnectionDraft) throws {
        let profile = try connectionRepository.save(draft)
        appState.selectedConnectionID = profile.id
        sidebarSelection = .connection(profile.id)
        connectionFormDraft = nil
    }

    private func editConnection(_ profile: ConnectionProfile) {
        do {
            connectionFormDraft = ConnectionDraft(
                profile: profile,
                password: try connectionRepository.password(for: profile) ?? ""
            )
        } catch {
            connectionRepository.lastErrorMessage = error.localizedDescription
        }
    }

    private func duplicateConnection(_ profile: ConnectionProfile) {
        do {
            let duplicate = try connectionRepository.duplicate(profile)
            appState.selectedConnectionID = duplicate.id
            sidebarSelection = .connection(duplicate.id)
        } catch {
            connectionRepository.lastErrorMessage = error.localizedDescription
        }
    }

    private func requestDeleteConnection(_ profile: ConnectionProfile) {
        connectionPendingDeletion = profile
    }

    private func deleteConnection(_ profile: ConnectionProfile) {
        do {
            try connectionRepository.delete(profile)
            catalogRepository.clearCatalog(for: profile.id)
            if appState.selectedConnectionID == profile.id {
                appState.selectedConnectionID = nil
                appState.selectedCatalogItem = nil
                sidebarSelection = .connections
            }
            connectionPendingDeletion = nil
        } catch {
            connectionRepository.lastErrorMessage = error.localizedDescription
        }
    }

    private func syncConnectionsFromRepository() {
        appState.connections = connectionRepository.profiles
    }

    private var selectedCatalog: DatabaseCatalog? {
        guard let selectedConnectionID = appState.selectedConnectionID else {
            return nil
        }

        return catalogRepository.catalog(for: selectedConnectionID)
    }

    private var selectedCatalogLoadingState: CatalogLoadingState {
        guard let selectedConnectionID = appState.selectedConnectionID else {
            return .idle
        }

        return catalogRepository.loadingState(for: selectedConnectionID)
    }

    private var selectedCatalogCacheStatus: String? {
        guard let selectedConnectionID = appState.selectedConnectionID else {
            return nil
        }

        return catalogRepository.cacheStatus(for: selectedConnectionID)
    }

    private func refreshCatalog(_ profile: ConnectionProfile) {
        appState.selectedConnectionID = profile.id
        sidebarSelection = .connection(profile.id)
        loadCatalog(for: profile, forceRefresh: true)
    }

    private func loadCatalogForSelectedConnection(forceRefresh: Bool) {
        guard let selectedConnectionID = appState.selectedConnectionID,
              let profile = connectionRepository.profiles.first(where: { $0.id == selectedConnectionID }) else {
            return
        }

        loadCatalog(for: profile, forceRefresh: forceRefresh)
    }

    private func loadCatalog(for profile: ConnectionProfile, forceRefresh: Bool) {
        Task {
            let password = (try? connectionRepository.password(for: profile)) ?? ""
            await catalogRepository.loadCatalog(for: profile, password: password, forceRefresh: forceRefresh)
        }
    }
}

#Preview {
    DeepDropAppShell()
}
