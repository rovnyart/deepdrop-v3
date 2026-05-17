//
//  CatalogIntrospectionService.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import Foundation
import NIOSSL
import PostgresNIO

protocol CatalogIntrospecting {
    func loadCatalog(for profile: ConnectionProfile, password: String) async throws -> DatabaseCatalog
}

struct CatalogIntrospectionService: CatalogIntrospecting {
    func loadCatalog(for profile: ConnectionProfile, password: String) async throws -> DatabaseCatalog {
        let configuration = PostgresClient.Configuration(
            host: profile.host,
            port: profile.port,
            username: profile.username,
            password: password,
            database: profile.database,
            tls: tlsMode(for: profile.sslMode)
        )
        let client = PostgresClient(configuration: configuration)

        return try await withThrowingTaskGroup(of: DatabaseCatalog.self) { group in
            group.addTask {
                await client.run()
                throw CancellationError()
            }

            group.addTask {
                try await loadCatalog(profile: profile, client: client)
            }

            guard let catalog = try await group.next() else {
                throw CatalogIntrospectionError.emptyResult
            }

            group.cancelAll()
            return catalog
        }
    }

    private func loadCatalog(profile: ConnectionProfile, client: PostgresClient) async throws -> DatabaseCatalog {
        async let schemaRecords: [SchemaRecord] = fetchJSON(client: client, sql: Self.schemasSQL)
        async let relationRecords: [RelationRecord] = fetchJSON(client: client, sql: Self.relationsSQL)
        async let columnRecords: [ColumnRecord] = fetchJSON(client: client, sql: Self.columnsSQL)
        async let indexRecords: [IndexRecord] = fetchJSON(client: client, sql: Self.indexesSQL)
        async let constraintRecords: [ConstraintRecord] = fetchJSON(client: client, sql: Self.constraintsSQL)
        async let functionRecords: [FunctionRecord] = fetchJSON(client: client, sql: Self.functionsSQL)
        async let extensionRecords: [ExtensionRecord] = fetchJSON(client: client, sql: Self.extensionsSQL)

        return try await assembleCatalog(
            profile: profile,
            schemas: schemaRecords,
            relations: relationRecords,
            columns: columnRecords,
            indexes: indexRecords,
            constraints: constraintRecords,
            functions: functionRecords,
            extensions: extensionRecords
        )
    }

    private func fetchJSON<T: Decodable>(client: PostgresClient, sql: String) async throws -> [T] {
        let rows = try await client.query(PostgresQuery(unsafeSQL: sql))
        for try await json in rows.decode(String.self) {
            let data = Data(json.utf8)
            return try JSONDecoder().decode([T].self, from: data)
        }

        return []
    }

    private func assembleCatalog(
        profile: ConnectionProfile,
        schemas: [SchemaRecord],
        relations: [RelationRecord],
        columns: [ColumnRecord],
        indexes: [IndexRecord],
        constraints: [ConstraintRecord],
        functions: [FunctionRecord],
        extensions: [ExtensionRecord]
    ) -> DatabaseCatalog {
        let columnModels = columns.map { $0.model }
        let indexModels = indexes.map { $0.model }
        let constraintModels = constraints.map { $0.model }
        let functionModels = functions.map { $0.model }
        let extensionModels = extensions.map { $0.model }

        let columnsByRelation = Dictionary(grouping: columnModels, by: { "\($0.schema).\($0.table)" })
        let indexesByRelation = Dictionary(grouping: indexModels, by: { "\($0.schema).\($0.table)" })
        let constraintsByRelation = Dictionary(grouping: constraintModels, by: { "\($0.schema).\($0.table)" })
        let functionsBySchema = Dictionary(grouping: functionModels, by: { $0.schema })
        let relationsBySchema = Dictionary(grouping: relations, by: { $0.schemaName })

        let databaseSchemas: [DatabaseSchema] = schemas.map { schemaRecord in
            let schemaRelations = relationsBySchema[schemaRecord.schemaName] ?? []

            let tables = makeTables(
                from: schemaRelations,
                columnsByRelation: columnsByRelation,
                indexesByRelation: indexesByRelation,
                constraintsByRelation: constraintsByRelation
            )
            let views = makeViews(from: schemaRelations, kind: .view, columnsByRelation: columnsByRelation)
            let materializedViews = makeViews(from: schemaRelations, kind: .materializedView, columnsByRelation: columnsByRelation)

            return DatabaseSchema(
                name: schemaRecord.schemaName,
                owner: schemaRecord.owner,
                tables: tables,
                views: views,
                materializedViews: materializedViews,
                functions: sortedFunctions(functionsBySchema[schemaRecord.schemaName] ?? [])
            )
        }
        .sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        return DatabaseCatalog(
            connectionID: profile.id,
            databaseName: profile.database,
            loadedAt: .now,
            schemas: databaseSchemas,
            extensions: extensionModels.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        )
    }

    private func makeTables(
        from relations: [RelationRecord],
        columnsByRelation: [String: [DatabaseColumn]],
        indexesByRelation: [String: [DatabaseIndex]],
        constraintsByRelation: [String: [DatabaseConstraint]]
    ) -> [DatabaseTable] {
        let tables = relations
            .filter { $0.kind == .table }
            .map { relation in
                makeTable(
                    from: relation,
                    columnsByRelation: columnsByRelation,
                    indexesByRelation: indexesByRelation,
                    constraintsByRelation: constraintsByRelation
                )
            }

        return tables.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func sortedFunctions(_ functions: [DatabaseFunction]) -> [DatabaseFunction] {
        functions.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private func makeViews(
        from relations: [RelationRecord],
        kind: CatalogRelationKind,
        columnsByRelation: [String: [DatabaseColumn]]
    ) -> [DatabaseView] {
        let views = relations
            .filter { $0.kind == kind }
            .map { relation in
                makeView(from: relation, kind: kind, columnsByRelation: columnsByRelation)
            }

        return views.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func makeTable(
        from relation: RelationRecord,
        columnsByRelation: [String: [DatabaseColumn]],
        indexesByRelation: [String: [DatabaseIndex]],
        constraintsByRelation: [String: [DatabaseConstraint]]
    ) -> DatabaseTable {
        let key = "\(relation.schemaName).\(relation.relationName)"
        return DatabaseTable(
            schema: relation.schemaName,
            name: relation.relationName,
            kind: .table,
            owner: relation.owner,
            estimatedRowCount: relation.estimatedRowCount,
            comment: relation.comment,
            columns: columnsByRelation[key] ?? [],
            indexes: indexesByRelation[key] ?? [],
            constraints: constraintsByRelation[key] ?? []
        )
    }

    private func makeView(
        from relation: RelationRecord,
        kind: CatalogRelationKind,
        columnsByRelation: [String: [DatabaseColumn]]
    ) -> DatabaseView {
        let key = "\(relation.schemaName).\(relation.relationName)"
        return DatabaseView(
            schema: relation.schemaName,
            name: relation.relationName,
            kind: kind,
            owner: relation.owner,
            comment: relation.comment,
            columns: columnsByRelation[key] ?? []
        )
    }

    private func tlsMode(for sslMode: SSLMode) -> PostgresClient.Configuration.TLS {
        var tlsConfiguration = TLSConfiguration.makeClientConfiguration()
        tlsConfiguration.certificateVerification = .none

        switch sslMode {
        case .disable, .allow:
            return .disable
        case .prefer:
            return .prefer(tlsConfiguration)
        case .require, .verifyCA, .verifyFull:
            return .require(tlsConfiguration)
        }
    }
}

enum CatalogIntrospectionError: Error, LocalizedError {
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .emptyResult:
            return "Catalog introspection returned no data."
        }
    }
}

nonisolated private struct SchemaRecord: Decodable {
    var schemaName: String
    var owner: String?
}

nonisolated private struct RelationRecord: Decodable {
    var schemaName: String
    var relationName: String
    var relkind: String
    var owner: String?
    var estimatedRowCount: Int64?
    var comment: String?

    var kind: CatalogRelationKind {
        switch relkind {
        case "v": .view
        case "m": .materializedView
        default: .table
        }
    }
}

nonisolated private struct ColumnRecord: Decodable {
    var schemaName: String
    var tableName: String
    var columnName: String
    var ordinal: Int
    var typeName: String
    var isNullable: Bool
    var defaultExpression: String?
    var isPrimaryKey: Bool
    var isForeignKey: Bool
    var comment: String?

    var model: DatabaseColumn {
        DatabaseColumn(
            schema: schemaName,
            table: tableName,
            name: columnName,
            ordinal: ordinal,
            typeName: typeName,
            isNullable: isNullable,
            defaultExpression: defaultExpression,
            isPrimaryKey: isPrimaryKey,
            isForeignKey: isForeignKey,
            comment: comment
        )
    }
}

nonisolated private struct IndexRecord: Decodable {
    var schemaName: String
    var tableName: String
    var indexName: String
    var definition: String
    var isUnique: Bool
    var isPrimary: Bool

    var model: DatabaseIndex {
        DatabaseIndex(
            id: "\(schemaName).\(tableName).\(indexName)",
            schema: schemaName,
            table: tableName,
            name: indexName,
            definition: definition,
            isUnique: isUnique,
            isPrimary: isPrimary
        )
    }
}

nonisolated private struct ConstraintRecord: Decodable {
    var schemaName: String
    var tableName: String
    var constraintName: String
    var contype: String
    var definition: String

    var model: DatabaseConstraint {
        DatabaseConstraint(
            id: "\(schemaName).\(tableName).\(constraintName)",
            schema: schemaName,
            table: tableName,
            name: constraintName,
            type: constraintType,
            definition: definition
        )
    }

    private var constraintType: DatabaseConstraintType {
        switch contype {
        case "p": .primaryKey
        case "f": .foreignKey
        case "u": .unique
        case "c": .check
        case "x": .exclusion
        default: .unknown
        }
    }
}

nonisolated private struct FunctionRecord: Decodable {
    var schemaName: String
    var functionName: String
    var arguments: String
    var returnType: String
    var language: String?

    var model: DatabaseFunction {
        DatabaseFunction(
            schema: schemaName,
            name: functionName,
            arguments: arguments,
            returnType: returnType,
            language: language
        )
    }
}

nonisolated private struct ExtensionRecord: Decodable {
    var name: String
    var version: String?
    var schemaName: String?

    var model: DatabaseExtension {
        DatabaseExtension(name: name, version: version, schema: schemaName)
    }
}

private extension CatalogIntrospectionService {
    static let schemasSQL = """
    select coalesce(json_agg(row_to_json(t)), '[]'::json)::text
    from (
      select n.nspname as "schemaName", pg_catalog.pg_get_userbyid(n.nspowner) as "owner"
      from pg_catalog.pg_namespace n
      where n.nspname not like 'pg_%' and n.nspname <> 'information_schema'
      order by n.nspname
    ) t;
    """

    static let relationsSQL = """
    select coalesce(json_agg(row_to_json(t)), '[]'::json)::text
    from (
      select n.nspname as "schemaName", c.relname as "relationName", c.relkind::text as "relkind",
             pg_catalog.pg_get_userbyid(c.relowner) as "owner", c.reltuples::bigint as "estimatedRowCount",
             obj_description(c.oid, 'pg_class') as "comment"
      from pg_catalog.pg_class c
      join pg_catalog.pg_namespace n on n.oid = c.relnamespace
      where n.nspname not like 'pg_%' and n.nspname <> 'information_schema' and c.relkind in ('r', 'p', 'v', 'm')
      order by n.nspname, c.relkind, c.relname
    ) t;
    """

    static let columnsSQL = """
    select coalesce(json_agg(row_to_json(t)), '[]'::json)::text
    from (
      select n.nspname as "schemaName", c.relname as "tableName", a.attname as "columnName", a.attnum::int as "ordinal",
             pg_catalog.format_type(a.atttypid, a.atttypmod) as "typeName", (not a.attnotnull) as "isNullable",
             pg_get_expr(ad.adbin, ad.adrelid) as "defaultExpression",
             exists (select 1 from pg_catalog.pg_constraint con where con.conrelid = c.oid and con.contype = 'p' and a.attnum = any(con.conkey)) as "isPrimaryKey",
             exists (select 1 from pg_catalog.pg_constraint con where con.conrelid = c.oid and con.contype = 'f' and a.attnum = any(con.conkey)) as "isForeignKey",
             col_description(a.attrelid, a.attnum) as "comment"
      from pg_catalog.pg_attribute a
      join pg_catalog.pg_class c on c.oid = a.attrelid
      join pg_catalog.pg_namespace n on n.oid = c.relnamespace
      left join pg_catalog.pg_attrdef ad on ad.adrelid = a.attrelid and ad.adnum = a.attnum
      where a.attnum > 0 and not a.attisdropped and n.nspname not like 'pg_%' and n.nspname <> 'information_schema' and c.relkind in ('r', 'p', 'v', 'm')
      order by n.nspname, c.relname, a.attnum
    ) t;
    """

    static let indexesSQL = """
    select coalesce(json_agg(row_to_json(t)), '[]'::json)::text
    from (
      select schemaname as "schemaName", tablename as "tableName", indexname as "indexName", indexdef as "definition",
             indexdef ilike 'create unique index%' as "isUnique", indexdef ilike '% using %' and indexname ilike '%pkey%' as "isPrimary"
      from pg_catalog.pg_indexes
      where schemaname not like 'pg_%' and schemaname <> 'information_schema'
      order by schemaname, tablename, indexname
    ) t;
    """

    static let constraintsSQL = """
    select coalesce(json_agg(row_to_json(t)), '[]'::json)::text
    from (
      select n.nspname as "schemaName", c.relname as "tableName", con.conname as "constraintName", con.contype::text as "contype",
             pg_get_constraintdef(con.oid) as "definition"
      from pg_catalog.pg_constraint con
      join pg_catalog.pg_class c on c.oid = con.conrelid
      join pg_catalog.pg_namespace n on n.oid = c.relnamespace
      where n.nspname not like 'pg_%' and n.nspname <> 'information_schema'
      order by n.nspname, c.relname, con.conname
    ) t;
    """

    static let functionsSQL = """
    select coalesce(json_agg(row_to_json(t)), '[]'::json)::text
    from (
      select n.nspname as "schemaName", p.proname as "functionName", pg_get_function_arguments(p.oid) as "arguments",
             pg_get_function_result(p.oid) as "returnType", l.lanname as "language"
      from pg_catalog.pg_proc p
      join pg_catalog.pg_namespace n on n.oid = p.pronamespace
      left join pg_catalog.pg_language l on l.oid = p.prolang
      where n.nspname not like 'pg_%' and n.nspname <> 'information_schema'
      order by n.nspname, p.proname, arguments
    ) t;
    """

    static let extensionsSQL = """
    select coalesce(json_agg(row_to_json(t)), '[]'::json)::text
    from (
      select e.extname as "name", e.extversion as "version", n.nspname as "schemaName"
      from pg_catalog.pg_extension e
      left join pg_catalog.pg_namespace n on n.oid = e.extnamespace
      order by e.extname
    ) t;
    """
}
