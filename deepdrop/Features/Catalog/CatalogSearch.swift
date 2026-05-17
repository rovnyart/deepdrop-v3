//
//  CatalogSearch.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import Foundation

struct CatalogSearchResult: Identifiable, Equatable {
    var id: String
    var title: String
    var subtitle: String
    var kind: String
    var selection: CatalogSelection
}

struct CatalogSearch {
    func results(in catalog: DatabaseCatalog, matching query: String) -> [CatalogSearchResult] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else {
            return []
        }

        var results: [CatalogSearchResult] = []

        for schema in catalog.schemas {
            appendIfMatches(
                title: schema.name,
                subtitle: "Schema",
                kind: "schema",
                selection: .schema(connectionID: catalog.connectionID, schema: schema.name),
                query: normalizedQuery,
                results: &results
            )

            for table in schema.tables {
                appendIfMatches(
                    title: table.name,
                    subtitle: "\(table.schema).\(table.name)",
                    kind: "table",
                    selection: .table(connectionID: catalog.connectionID, schema: table.schema, name: table.name),
                    query: normalizedQuery,
                    results: &results
                )

                appendColumnResults(table.columns, connectionID: catalog.connectionID, kind: "column", query: normalizedQuery, results: &results)
            }

            for view in schema.views {
                appendIfMatches(
                    title: view.name,
                    subtitle: "\(view.schema).\(view.name)",
                    kind: "view",
                    selection: .view(connectionID: catalog.connectionID, schema: view.schema, name: view.name),
                    query: normalizedQuery,
                    results: &results
                )
                appendColumnResults(view.columns, connectionID: catalog.connectionID, kind: "column", query: normalizedQuery, results: &results)
            }

            for view in schema.materializedViews {
                appendIfMatches(
                    title: view.name,
                    subtitle: "\(view.schema).\(view.name)",
                    kind: "materialized view",
                    selection: .materializedView(connectionID: catalog.connectionID, schema: view.schema, name: view.name),
                    query: normalizedQuery,
                    results: &results
                )
                appendColumnResults(view.columns, connectionID: catalog.connectionID, kind: "column", query: normalizedQuery, results: &results)
            }

            for function in schema.functions {
                appendIfMatches(
                    title: function.name,
                    subtitle: "\(function.schema).\(function.name)(\(function.arguments)) -> \(function.returnType)",
                    kind: "function",
                    selection: .function(connectionID: catalog.connectionID, schema: function.schema, name: function.name, arguments: function.arguments),
                    query: normalizedQuery,
                    results: &results
                )
            }
        }

        for databaseExtension in catalog.extensions {
            appendIfMatches(
                title: databaseExtension.name,
                subtitle: databaseExtension.version ?? "Extension",
                kind: "extension",
                selection: .extension(connectionID: catalog.connectionID, name: databaseExtension.name),
                query: normalizedQuery,
                results: &results
            )
        }

        return results
    }

    private func appendColumnResults(
        _ columns: [DatabaseColumn],
        connectionID: UUID,
        kind: String,
        query: String,
        results: inout [CatalogSearchResult]
    ) {
        for column in columns {
            appendIfMatches(
                title: column.name,
                subtitle: "\(column.schema).\(column.table).\(column.name) · \(column.typeName)",
                kind: kind,
                selection: .column(connectionID: connectionID, schema: column.schema, table: column.table, name: column.name),
                query: query,
                results: &results
            )
        }
    }

    private func appendIfMatches(
        title: String,
        subtitle: String,
        kind: String,
        selection: CatalogSelection,
        query: String,
        results: inout [CatalogSearchResult]
    ) {
        let searchableText = "\(title) \(subtitle) \(kind)".lowercased()
        guard searchableText.contains(query) else {
            return
        }

        results.append(CatalogSearchResult(
            id: "\(kind):\(subtitle):\(title)",
            title: title,
            subtitle: subtitle,
            kind: kind,
            selection: selection
        ))
    }
}
