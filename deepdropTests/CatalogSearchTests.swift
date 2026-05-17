//
//  CatalogSearchTests.swift
//  deepdropTests
//
//  Created by Codex on 17.05.2026.
//

import Foundation
import Testing
@testable import deepdrop

struct CatalogSearchTests {
    @Test func findsTableByName() {
        let results = CatalogSearch().results(in: sampleCatalog, matching: "users")

        #expect(results.contains { $0.kind == "table" && $0.title == "users" })
    }

    @Test func findsTableByQualifiedName() {
        let results = CatalogSearch().results(in: sampleCatalog, matching: "public.users")

        #expect(results.contains { $0.kind == "table" && $0.title == "users" })
    }

    @Test func findsColumnByName() {
        let results = CatalogSearch().results(in: sampleCatalog, matching: "email")

        #expect(results.contains { $0.kind == "column" && $0.title == "email" })
    }

    @Test func searchIsCaseInsensitive() {
        let results = CatalogSearch().results(in: sampleCatalog, matching: "USERS")

        #expect(results.contains { $0.kind == "table" && $0.title == "users" })
    }

    @Test func emptyQueryReturnsNoResults() {
        let results = CatalogSearch().results(in: sampleCatalog, matching: "   ")

        #expect(results.isEmpty)
    }
}

private let sampleCatalog = DatabaseCatalog(
    connectionID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
    databaseName: "deepdrop",
    loadedAt: Date(timeIntervalSince1970: 0),
    schemas: [
        DatabaseSchema(
            name: "public",
            owner: "postgres",
            tables: [
                DatabaseTable(
                    schema: "public",
                    name: "users",
                    kind: .table,
                    owner: "postgres",
                    estimatedRowCount: 42,
                    comment: nil,
                    columns: [
                        DatabaseColumn(
                            schema: "public",
                            table: "users",
                            name: "id",
                            ordinal: 1,
                            typeName: "uuid",
                            isNullable: false,
                            defaultExpression: nil,
                            isPrimaryKey: true,
                            isForeignKey: false,
                            comment: nil
                        ),
                        DatabaseColumn(
                            schema: "public",
                            table: "users",
                            name: "email",
                            ordinal: 2,
                            typeName: "text",
                            isNullable: false,
                            defaultExpression: nil,
                            isPrimaryKey: false,
                            isForeignKey: false,
                            comment: nil
                        )
                    ],
                    indexes: [],
                    constraints: []
                )
            ],
            views: [],
            materializedViews: [],
            functions: []
        )
    ],
    extensions: []
)
