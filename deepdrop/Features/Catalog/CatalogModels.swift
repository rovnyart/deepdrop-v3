//
//  CatalogModels.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import Foundation

struct DatabaseCatalog: Codable, Equatable {
    var connectionID: UUID
    var databaseName: String
    var loadedAt: Date
    var schemas: [DatabaseSchema]
    var extensions: [DatabaseExtension]
}

struct DatabaseSchema: Identifiable, Codable, Equatable {
    var id: String { name }
    var name: String
    var owner: String?
    var tables: [DatabaseTable]
    var views: [DatabaseView]
    var materializedViews: [DatabaseView]
    var functions: [DatabaseFunction]
}

struct DatabaseTable: Identifiable, Codable, Equatable {
    var id: String { "\(schema).\(name)" }
    var schema: String
    var name: String
    var kind: CatalogRelationKind
    var owner: String?
    var estimatedRowCount: Int64?
    var comment: String?
    var columns: [DatabaseColumn]
    var indexes: [DatabaseIndex]
    var constraints: [DatabaseConstraint]
}

struct DatabaseView: Identifiable, Codable, Equatable {
    var id: String { "\(schema).\(name)" }
    var schema: String
    var name: String
    var kind: CatalogRelationKind
    var owner: String?
    var comment: String?
    var columns: [DatabaseColumn]
}

struct DatabaseColumn: Identifiable, Codable, Equatable {
    var id: String { "\(schema).\(table).\(name)" }
    var schema: String
    var table: String
    var name: String
    var ordinal: Int
    var typeName: String
    var isNullable: Bool
    var defaultExpression: String?
    var isPrimaryKey: Bool
    var isForeignKey: Bool
    var comment: String?
}

enum CatalogRelationKind: String, Codable, Equatable {
    case table
    case view
    case materializedView
}

struct DatabaseIndex: Identifiable, Codable, Equatable {
    var id: String
    var schema: String
    var table: String
    var name: String
    var definition: String
    var isUnique: Bool
    var isPrimary: Bool
}

struct DatabaseConstraint: Identifiable, Codable, Equatable {
    var id: String
    var schema: String
    var table: String
    var name: String
    var type: DatabaseConstraintType
    var definition: String
}

enum DatabaseConstraintType: String, Codable, Equatable {
    case primaryKey
    case foreignKey
    case unique
    case check
    case exclusion
    case unknown
}

struct DatabaseFunction: Identifiable, Codable, Equatable {
    var id: String { "\(schema).\(name)(\(arguments))" }
    var schema: String
    var name: String
    var arguments: String
    var returnType: String
    var language: String?
}

struct DatabaseExtension: Identifiable, Codable, Equatable {
    var id: String { name }
    var name: String
    var version: String?
    var schema: String?
}

enum CatalogSelection: Hashable {
    case schema(connectionID: UUID, schema: String)
    case table(connectionID: UUID, schema: String, name: String)
    case view(connectionID: UUID, schema: String, name: String)
    case materializedView(connectionID: UUID, schema: String, name: String)
    case column(connectionID: UUID, schema: String, table: String, name: String)
    case function(connectionID: UUID, schema: String, name: String, arguments: String)
    case `extension`(connectionID: UUID, name: String)
}

enum CatalogLoadingState: Equatable {
    case idle
    case loading
    case loaded(Date)
    case failed(String)
}
