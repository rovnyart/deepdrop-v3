//
//  SQLStatementClassifier.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import Foundation

enum SQLStatementClassification: String, Codable, Equatable {
    case readOnly
    case mutation
    case schemaChange
    case transactionControl
    case admin
    case unknown
}

enum SQLStatementClassifier {
    static func classify(_ sql: String) -> SQLStatementClassification {
        let firstWord = SQLLexer.tokenize(sql).compactMap { token -> String? in
            if case .word(let word) = token.kind {
                return word.lowercased()
            }
            return nil
        }.first

        guard let firstWord else {
            return .unknown
        }

        switch firstWord {
        case "select", "with", "values", "show", "explain":
            return .readOnly
        case "insert", "update", "delete", "merge":
            return .mutation
        case "create", "alter", "drop", "truncate":
            return .schemaChange
        case "begin", "start", "commit", "rollback", "savepoint", "release":
            return .transactionControl
        case "grant", "revoke", "vacuum", "analyze", "reindex", "copy", "cluster", "listen", "notify", "unlisten":
            return .admin
        default:
            return .unknown
        }
    }
}
