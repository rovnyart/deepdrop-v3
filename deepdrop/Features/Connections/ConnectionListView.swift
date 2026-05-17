//
//  ConnectionListView.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import SwiftUI

struct ConnectionListView: View {
    let connections: [ConnectionProfile]
    @Binding var selection: SidebarSelection?
    let onAddConnection: () -> Void
    let onEditConnection: (ConnectionProfile) -> Void
    let onDuplicateConnection: (ConnectionProfile) -> Void
    let onDeleteConnection: (ConnectionProfile) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("DeepDrop")
                    .font(.title3.weight(.semibold))
                Spacer()
            }
            .padding(.horizontal, DeepDropSpacing.lg)
            .padding(.vertical, DeepDropSpacing.md)

            List(selection: $selection) {
                Section("Connections") {
                    if connections.isEmpty {
                        emptyConnectionRow
                    } else {
                        ForEach(connections) { connection in
                            ConnectionRow(connection: connection)
                                .tag(SidebarSelection.connection(connection.id))
                                .contextMenu {
                                    Button("Edit") {
                                        onEditConnection(connection)
                                    }

                                    Button("Duplicate") {
                                        onDuplicateConnection(connection)
                                    }

                                    Button("Delete", role: .destructive) {
                                        onDeleteConnection(connection)
                                    }
                                }
                        }
                    }
                }

                Section("Database Objects") {
                    Label("Schemas", systemImage: "square.stack.3d.up")
                        .foregroundStyle(.secondary)
                    Label("Tables", systemImage: "tablecells")
                        .foregroundStyle(.secondary)
                    Label("Functions", systemImage: "function")
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.sidebar)

            VStack(spacing: DeepDropSpacing.sm) {
                Button(action: onAddConnection) {
                    Label("Add Database Source", systemImage: "plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .accessibilityIdentifier("add-database-source-button")

                HStack {
                    Label("Local only", systemImage: "lock")
                    Spacer()
                    Text("No secrets stored yet")
                }
                .font(DeepDropTypography.metadata)
                .foregroundStyle(.secondary)
            }
            .padding(DeepDropSpacing.md)
            .background(.bar)
        }
    }

    private var emptyConnectionRow: some View {
        VStack(alignment: .leading, spacing: DeepDropSpacing.xs) {
            Text("No sources")
                .font(DeepDropTypography.sectionTitle)
            Text("Add a PostgreSQL source to begin.")
                .font(DeepDropTypography.metadata)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, DeepDropSpacing.xs)
    }
}

private struct ConnectionRow: View {
    let connection: ConnectionProfile

    var body: some View {
        HStack(spacing: DeepDropSpacing.sm) {
            Circle()
                .fill(connection.colorTag.color)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(connection.displayName)
                    .lineLimit(1)
                Text("\(connection.username)@\(connection.host):\(connection.port)/\(connection.database)")
                    .font(DeepDropTypography.metadata)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if connection.isProduction {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help("Production connection")
            }
        }
        .accessibilityLabel(connection.displayName)
    }
}

#Preview {
    @Previewable @State var selection: SidebarSelection?

    ConnectionListView(
        connections: [],
        selection: $selection,
        onAddConnection: {},
        onEditConnection: { _ in },
        onDuplicateConnection: { _ in },
        onDeleteConnection: { _ in }
    )
}
