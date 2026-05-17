//
//  DeepDropAppShell.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import SwiftUI

struct DeepDropAppShell: View {
    @State private var appState = AppState()
    @State private var sidebarSelection: SidebarSelection? = .connections
    @State private var isShowingAddConnectionPlaceholder = false

    var body: some View {
        NavigationSplitView {
            ConnectionListView(
                connections: appState.connections,
                selection: $sidebarSelection,
                onAddConnection: showAddConnectionPlaceholder
            )
            .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
        } detail: {
            WorkspaceView(
                appState: appState,
                onAddConnection: showAddConnectionPlaceholder
            )
        }
        .sheet(isPresented: $isShowingAddConnectionPlaceholder) {
            AddConnectionPlaceholderSheet()
        }
    }

    private func showAddConnectionPlaceholder() {
        isShowingAddConnectionPlaceholder = true
    }
}

private struct AddConnectionPlaceholderSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: DeepDropSpacing.xl) {
            VStack(alignment: .leading, spacing: DeepDropSpacing.sm) {
                Text("Add Database Source")
                    .font(.title2.weight(.semibold))
                Text("Phase 1 will turn this into the PostgreSQL connection form with URL parsing, testing, and Keychain-backed secrets.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: DeepDropSpacing.md) {
                LabeledContent("URL parsing", value: "Phase 1")
                LabeledContent("Credential storage", value: "Keychain")
                LabeledContent("Connection test", value: "PostgreSQL driver spike")
            }
            .font(DeepDropTypography.metadata)

            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(DeepDropSpacing.xl)
        .frame(width: 460)
    }
}

#Preview {
    DeepDropAppShell()
}
