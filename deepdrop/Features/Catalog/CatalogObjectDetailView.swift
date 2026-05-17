//
//  CatalogObjectDetailView.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import SwiftUI

struct CatalogObjectDetailView: View {
    let catalog: DatabaseCatalog
    let selection: CatalogSelection?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DeepDropSpacing.xl) {
                content
            }
            .padding(DeepDropSpacing.xl)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(DeepDropColors.workspaceBackground)
    }

    @ViewBuilder
    private var content: some View {
        if let selection {
            switch selection {
            case .schema(_, let schema):
                if let schema = catalog.schema(named: schema) {
                    schemaDetail(schema)
                }
            case .table(_, let schema, let name):
                if let table = catalog.table(schema: schema, name: name) {
                    tableDetail(table)
                }
            case .view(_, let schema, let name):
                if let view = catalog.view(schema: schema, name: name) {
                    viewDetail(view)
                }
            case .materializedView(_, let schema, let name):
                if let view = catalog.materializedView(schema: schema, name: name) {
                    viewDetail(view)
                }
            case .column(_, let schema, let table, let name):
                if let column = catalog.column(schema: schema, table: table, name: name) {
                    columnDetail(column)
                }
            case .function(_, let schema, let name, let arguments):
                if let function = catalog.function(schema: schema, name: name, arguments: arguments) {
                    functionDetail(function)
                }
            case .extension(_, let name):
                if let databaseExtension = catalog.extensions.first(where: { $0.name == name }) {
                    extensionDetail(databaseExtension)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: DeepDropSpacing.sm) {
                Text("Catalog")
                    .font(.title2.weight(.semibold))
                Text("Select a schema, table, column, function, or extension to inspect its structure.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func schemaDetail(_ schema: DatabaseSchema) -> some View {
        VStack(alignment: .leading, spacing: DeepDropSpacing.lg) {
            header(title: schema.name, subtitle: "Schema", systemImage: "folder")
            metricGrid([
                ("Tables", "\(schema.tables.count)"),
                ("Views", "\(schema.views.count)"),
                ("Materialized Views", "\(schema.materializedViews.count)"),
                ("Functions", "\(schema.functions.count)")
            ])
        }
    }

    private func tableDetail(_ table: DatabaseTable) -> some View {
        VStack(alignment: .leading, spacing: DeepDropSpacing.lg) {
            header(title: table.name, subtitle: "\(table.schema) · Table", systemImage: "tablecells")
            metricGrid([
                ("Columns", "\(table.columns.count)"),
                ("Indexes", "\(table.indexes.count)"),
                ("Constraints", "\(table.constraints.count)"),
                ("Estimated Rows", table.estimatedRowCount.map(String.init) ?? "Unknown")
            ])
            if let comment = table.comment, !comment.isEmpty {
                metadataSection(title: "Comment", rows: [("", comment)])
            }
            columnsSection(table.columns)
            indexesSection(table.indexes)
            constraintsSection(table.constraints)
        }
    }

    private func viewDetail(_ view: DatabaseView) -> some View {
        VStack(alignment: .leading, spacing: DeepDropSpacing.lg) {
            header(title: view.name, subtitle: "\(view.schema) · \(view.kind == .materializedView ? "Materialized View" : "View")", systemImage: view.kind == .materializedView ? "rectangle.stack" : "rectangle.on.rectangle")
            metricGrid([("Columns", "\(view.columns.count)")])
            if let comment = view.comment, !comment.isEmpty {
                metadataSection(title: "Comment", rows: [("", comment)])
            }
            columnsSection(view.columns)
        }
    }

    private func columnDetail(_ column: DatabaseColumn) -> some View {
        VStack(alignment: .leading, spacing: DeepDropSpacing.lg) {
            header(title: column.name, subtitle: "\(column.schema).\(column.table) · Column", systemImage: column.isPrimaryKey ? "key" : "list.bullet.rectangle")
            metadataSection(title: "Column", rows: [
                ("Type", column.typeName),
                ("Nullable", column.isNullable ? "Yes" : "No"),
                ("Primary Key", column.isPrimaryKey ? "Yes" : "No"),
                ("Foreign Key", column.isForeignKey ? "Yes" : "No"),
                ("Default", column.defaultExpression ?? "None")
            ])
        }
    }

    private func functionDetail(_ function: DatabaseFunction) -> some View {
        VStack(alignment: .leading, spacing: DeepDropSpacing.lg) {
            header(title: function.name, subtitle: "\(function.schema) · Function", systemImage: "function")
            metadataSection(title: "Signature", rows: [
                ("Arguments", function.arguments.isEmpty ? "None" : function.arguments),
                ("Returns", function.returnType),
                ("Language", function.language ?? "Unknown")
            ])
        }
    }

    private func extensionDetail(_ databaseExtension: DatabaseExtension) -> some View {
        VStack(alignment: .leading, spacing: DeepDropSpacing.lg) {
            header(title: databaseExtension.name, subtitle: "Extension", systemImage: "shippingbox")
            metadataSection(title: "Extension", rows: [
                ("Version", databaseExtension.version ?? "Unknown"),
                ("Schema", databaseExtension.schema ?? "Unknown")
            ])
        }
    }

    private func header(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: DeepDropSpacing.md) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2.weight(.semibold))
                Text(subtitle)
                    .font(DeepDropTypography.metadata)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func metricGrid(_ metrics: [(String, String)]) -> some View {
        Grid(alignment: .leading, horizontalSpacing: DeepDropSpacing.xl, verticalSpacing: DeepDropSpacing.sm) {
            GridRow {
                ForEach(metrics, id: \.0) { metric in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(metric.1)
                            .font(.title3.weight(.semibold))
                        Text(metric.0)
                            .font(DeepDropTypography.metadata)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func columnsSection(_ columns: [DatabaseColumn]) -> some View {
        metadataSection(
            title: "Columns",
            rows: columns.map { column in
                let key = column.isPrimaryKey ? "key.fill" : ""
                let flags = [column.isPrimaryKey ? "PK" : nil, column.isForeignKey ? "FK" : nil, column.isNullable ? nil : "not null"].compactMap { $0 }.joined(separator: ", ")
                return ("\(key) \(column.name)", "\(column.typeName)\(flags.isEmpty ? "" : " · \(flags)")")
            }
        )
    }

    private func indexesSection(_ indexes: [DatabaseIndex]) -> some View {
        metadataSection(title: "Indexes", rows: indexes.map { ($0.name, $0.definition) })
    }

    private func constraintsSection(_ constraints: [DatabaseConstraint]) -> some View {
        metadataSection(title: "Constraints", rows: constraints.map { ($0.name, $0.definition) })
    }

    private func metadataSection(title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: DeepDropSpacing.sm) {
            Text(title)
                .font(DeepDropTypography.sectionTitle)
            if rows.isEmpty {
                Text("None")
                    .font(DeepDropTypography.metadata)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .top, spacing: DeepDropSpacing.md) {
                        if !row.0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(row.0)
                                .font(DeepDropTypography.metadata)
                                .foregroundStyle(.secondary)
                                .frame(width: 160, alignment: .leading)
                        }
                        Text(row.1)
                            .font(DeepDropTypography.metadata)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

private extension DatabaseCatalog {
    func schema(named name: String) -> DatabaseSchema? {
        schemas.first { $0.name == name }
    }

    func table(schema: String, name: String) -> DatabaseTable? {
        self.schema(named: schema)?.tables.first { $0.name == name }
    }

    func view(schema: String, name: String) -> DatabaseView? {
        self.schema(named: schema)?.views.first { $0.name == name }
    }

    func materializedView(schema: String, name: String) -> DatabaseView? {
        self.schema(named: schema)?.materializedViews.first { $0.name == name }
    }

    func column(schema: String, table: String, name: String) -> DatabaseColumn? {
        let relationColumns = self.table(schema: schema, name: table)?.columns
            ?? self.view(schema: schema, name: table)?.columns
            ?? self.materializedView(schema: schema, name: table)?.columns
        return relationColumns?.first { $0.name == name }
    }

    func function(schema: String, name: String, arguments: String) -> DatabaseFunction? {
        self.schema(named: schema)?.functions.first { $0.name == name && $0.arguments == arguments }
    }
}
