//
//  QueryExecutionModels.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import Foundation

struct QueryExecutionResponse: Equatable {
    var columns: [String]
    var rows: [[String]]
    var rowCount: Int
    var duration: TimeInterval
    var completedAt: Date
    var wasTruncated: Bool
}

enum QueryExecutionState: Equatable {
    case idle
    case running(startedAt: Date)
    case succeeded(QueryExecutionResponse)
    case failed(String)
    case cancelled
}

enum QueryExecutionError: Error, LocalizedError {
    case missingConnection
    case missingPassword
    case unsupportedStatement(SQLStatementClassification)
    case timeout
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .missingConnection:
            return "Select a saved database source before running SQL."
        case .missingPassword:
            return "The selected database source does not have a saved password."
        case .unsupportedStatement(let classification):
            return "\(classification.displayName) execution starts in a later checkpoint. Read-only queries work now."
        case .timeout:
            return "Query timed out after 30 seconds."
        case .emptyResult:
            return "Query returned no preview data."
        }
    }
}

extension SQLStatementClassification {
    var displayName: String {
        switch self {
        case .readOnly:
            return "Read-only"
        case .mutation:
            return "Mutation"
        case .schemaChange:
            return "Schema change"
        case .transactionControl:
            return "Transaction"
        case .admin:
            return "Admin"
        case .unknown:
            return "Unknown"
        }
    }
}
