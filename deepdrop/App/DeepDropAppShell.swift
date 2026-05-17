//
//  DeepDropAppShell.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import SwiftUI

struct DeepDropAppShell: View {
    @State private var connectionRepository = ConnectionProfileRepository()
    @State private var appState = AppState()
    @State private var sidebarSelection: SidebarSelection? = .connections
    @State private var connectionFormDraft: ConnectionDraft?
    @State private var connectionPendingDeletion: ConnectionProfile?

    var body: some View {
        HSplitView {
            ConnectionListView(
                connections: connectionRepository.profiles,
                selection: $sidebarSelection,
                onAddConnection: showAddConnectionPlaceholder,
                onEditConnection: editConnection,
                onDuplicateConnection: duplicateConnection,
                onDeleteConnection: requestDeleteConnection
            )
            .frame(minWidth: 240, idealWidth: 280, maxWidth: 360)

            WorkspaceView(
                appState: appState,
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
            if appState.selectedConnectionID == profile.id {
                appState.selectedConnectionID = nil
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
}

#Preview {
    DeepDropAppShell()
}
