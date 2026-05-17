//
//  ConnectionListView.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import SwiftUI

struct ConnectionListView: View {
    let connections: [ConnectionProfile]
    let selectedConnectionID: ConnectionProfile.ID?
    let selectedCatalog: DatabaseCatalog?
    let catalogLoadingState: CatalogLoadingState
    let catalogCacheStatus: String?
    @Binding var selectedCatalogItem: CatalogSelection?
    @Binding var selection: SidebarSelection?
    let onAddConnection: () -> Void
    let onEditConnection: (ConnectionProfile) -> Void
    let onDuplicateConnection: (ConnectionProfile) -> Void
    let onDeleteConnection: (ConnectionProfile) -> Void
    let onRefreshCatalog: (ConnectionProfile) -> Void
    @State private var catalogSearchQuery = ""

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

                catalogSection
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

    @ViewBuilder
    private var catalogSection: some View {
        Section("Database Objects") {
            if let selectedConnection = connections.first(where: { $0.id == selectedConnectionID }) {
                if selectedCatalog != nil {
                    TextField("Search catalog", text: $catalogSearchQuery)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("catalog-search-field")
                }

                Button {
                    onRefreshCatalog(selectedConnection)
                } label: {
                    Label("Refresh Catalog", systemImage: "arrow.clockwise")
                }
                .contextMenu {
                    Button("Copy Connection Name") {
                        copyToPasteboard(selectedConnection.displayName)
                    }
                }

                if let catalogCacheStatus {
                    Text(catalogCacheStatus)
                        .font(DeepDropTypography.metadata)
                        .foregroundStyle(.secondary)
                }

                switch catalogLoadingState {
                case .idle:
                    Label("Select refresh to load catalog", systemImage: "square.stack.3d.up")
                        .foregroundStyle(.secondary)
                case .loading:
                    Label("Loading catalog...", systemImage: "progress.indicator")
                        .foregroundStyle(.secondary)
                case .failed(let message):
                    VStack(alignment: .leading, spacing: DeepDropSpacing.xs) {
                        Label("Catalog failed", systemImage: "xmark.octagon")
                            .foregroundStyle(.red)
                        Text(message)
                            .font(DeepDropTypography.metadata)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                case .loaded:
                    if let selectedCatalog {
                        let query = catalogSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                        if query.isEmpty {
                            CatalogTreeView(catalog: selectedCatalog, selectedCatalogItem: $selectedCatalogItem)
                        } else {
                            let results = CatalogSearch().results(in: selectedCatalog, matching: query)
                            if results.isEmpty {
                                Label("No matches", systemImage: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(results) { result in
                    Button {
                        selectedCatalogItem = result.selection
                    } label: {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(result.title)
                                            Text("\(result.kind) · \(result.subtitle)")
                                                .font(DeepDropTypography.metadata)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    } else {
                        Label("No cached catalog", systemImage: "square.stack.3d.up")
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Label("Select a connection", systemImage: "square.stack.3d.up")
                    .foregroundStyle(.secondary)
            }
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

private struct CatalogTreeView: View {
    let catalog: DatabaseCatalog
    @Binding var selectedCatalogItem: CatalogSelection?

    var body: some View {
        ForEach(catalog.schemas) { schema in
            DisclosureGroup {
                relationGroup("Tables", systemImage: "tablecells", relations: schema.tables)
                viewGroup("Views", systemImage: "rectangle.on.rectangle", views: schema.views, selectionKind: .view)
                viewGroup("Materialized Views", systemImage: "rectangle.stack", views: schema.materializedViews, selectionKind: .materializedView)
                functionGroup(schema.functions)
            } label: {
                Button {
                    selectedCatalogItem = .schema(connectionID: catalog.connectionID, schema: schema.name)
                } label: {
                    Label(schema.name, systemImage: "folder")
                }
                .buttonStyle(.plain)
            }
        }

        if !catalog.extensions.isEmpty {
            DisclosureGroup {
                ForEach(catalog.extensions) { databaseExtension in
                    Button {
                        selectedCatalogItem = .extension(connectionID: catalog.connectionID, name: databaseExtension.name)
                    } label: {
                        Label(databaseExtension.name, systemImage: "shippingbox")
                    }
                    .buttonStyle(.plain)
                }
            } label: {
                Label("Extensions", systemImage: "shippingbox")
            }
        }
    }

    private func relationGroup(_ title: String, systemImage: String, relations: [DatabaseTable]) -> some View {
        DisclosureGroup {
            ForEach(relations) { relation in
                DisclosureGroup {
                    ForEach(relation.columns) { column in
                                    Button {
                                        selectedCatalogItem = .column(connectionID: catalog.connectionID, schema: column.schema, table: column.table, name: column.name)
                                    } label: {
                                        Label(column.name, systemImage: column.isPrimaryKey ? "key" : "list.bullet.rectangle")
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        catalogObjectContextMenu(name: column.name, qualifiedName: "\(column.schema).\(column.table).\(column.name)")
                                    }
                                }
                            } label: {
                    Button {
                        selectedCatalogItem = .table(connectionID: catalog.connectionID, schema: relation.schema, name: relation.name)
                    } label: {
                        Label(relation.name, systemImage: systemImage)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        catalogObjectContextMenu(
                            name: relation.name,
                            qualifiedName: "\(relation.schema).\(relation.name)",
                            selectSQL: "select * from \(quotedIdentifier(relation.schema)).\(quotedIdentifier(relation.name)) limit 100;"
                        )
                    }
                }
            }
        } label: {
            Label(title, systemImage: systemImage)
        }
    }

    private enum ViewSelectionKind {
        case view
        case materializedView
    }

    private func viewGroup(_ title: String, systemImage: String, views: [DatabaseView], selectionKind: ViewSelectionKind) -> some View {
        DisclosureGroup {
            ForEach(views) { view in
                DisclosureGroup {
                    ForEach(view.columns) { column in
                        Button {
                            selectedCatalogItem = .column(connectionID: catalog.connectionID, schema: column.schema, table: column.table, name: column.name)
                        } label: {
                            Label(column.name, systemImage: "list.bullet.rectangle")
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            catalogObjectContextMenu(name: column.name, qualifiedName: "\(column.schema).\(column.table).\(column.name)")
                        }
                    }
                } label: {
                    Button {
                        switch selectionKind {
                        case .view:
                            selectedCatalogItem = .view(connectionID: catalog.connectionID, schema: view.schema, name: view.name)
                        case .materializedView:
                            selectedCatalogItem = .materializedView(connectionID: catalog.connectionID, schema: view.schema, name: view.name)
                        }
                    } label: {
                        Label(view.name, systemImage: systemImage)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        catalogObjectContextMenu(
                            name: view.name,
                            qualifiedName: "\(view.schema).\(view.name)",
                            selectSQL: "select * from \(quotedIdentifier(view.schema)).\(quotedIdentifier(view.name)) limit 100;"
                        )
                    }
                }
            }
        } label: {
            Label(title, systemImage: systemImage)
        }
    }

    private func functionGroup(_ functions: [DatabaseFunction]) -> some View {
        DisclosureGroup {
            ForEach(functions) { function in
                Button {
                    selectedCatalogItem = .function(connectionID: catalog.connectionID, schema: function.schema, name: function.name, arguments: function.arguments)
                } label: {
                    Label(function.name, systemImage: "function")
                }
                .buttonStyle(.plain)
                .contextMenu {
                    catalogObjectContextMenu(name: function.name, qualifiedName: "\(function.schema).\(function.name)(\(function.arguments))")
                }
            }
        } label: {
            Label("Functions", systemImage: "function")
        }
    }
}

private func catalogObjectContextMenu(name: String, qualifiedName: String, selectSQL: String? = nil) -> some View {
    Group {
        Button("Copy Name") {
            copyToPasteboard(name)
        }

        Button("Copy Qualified Name") {
            copyToPasteboard(qualifiedName)
        }

        if let selectSQL {
            Button("Copy SELECT") {
                copyToPasteboard(selectSQL)
            }
        }
    }
}

private func copyToPasteboard(_ value: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(value, forType: .string)
}

private func quotedIdentifier(_ identifier: String) -> String {
    "\"\(identifier.replacingOccurrences(of: "\"", with: "\"\""))\""
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
        selectedConnectionID: nil,
        selectedCatalog: nil,
        catalogLoadingState: .idle,
        catalogCacheStatus: nil,
        selectedCatalogItem: .constant(nil),
        selection: $selection,
        onAddConnection: {},
        onEditConnection: { _ in },
        onDuplicateConnection: { _ in },
        onDeleteConnection: { _ in },
        onRefreshCatalog: { _ in }
    )
}
