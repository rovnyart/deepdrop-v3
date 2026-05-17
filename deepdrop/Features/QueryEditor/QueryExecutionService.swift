//
//  QueryExecutionService.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import Foundation
import NIOSSL
import PostgresNIO

protocol QueryExecuting {
    func executeReadOnlyPreview(sql: String, profile: ConnectionProfile, password: String) async throws -> QueryExecutionResponse
}

struct PostgresQueryExecutionService: QueryExecuting {
    private let previewLimit = 500

    func executeReadOnlyPreview(sql: String, profile: ConnectionProfile, password: String) async throws -> QueryExecutionResponse {
        let startedAt = Date()
        let configuration = PostgresClient.Configuration(
            host: profile.host,
            port: profile.port,
            username: profile.username,
            password: password,
            database: profile.database,
            tls: tlsMode(for: profile.sslMode)
        )
        let client = PostgresClient(configuration: configuration)

        return try await withThrowingTaskGroup(of: QueryExecutionResponse.self) { group in
            group.addTask {
                await client.run()
                throw CancellationError()
            }

            group.addTask {
                try await Task.sleep(for: .seconds(30))
                throw QueryExecutionError.timeout
            }

            group.addTask {
                try await executePreviewQuery(sql: sql, client: client, startedAt: startedAt, previewLimit: previewLimit)
            }

            guard let response = try await group.next() else {
                throw QueryExecutionError.emptyResult
            }

            group.cancelAll()
            return response
        }
    }

    private func executePreviewQuery(
        sql: String,
        client: PostgresClient,
        startedAt: Date,
        previewLimit: Int
    ) async throws -> QueryExecutionResponse {
        try Task.checkCancellation()
        let query = previewSQL(for: sql, limit: previewLimit)
        let rows = try await client.query(PostgresQuery(unsafeSQL: query))

        for try await json in rows.decode(String.self) {
            try Task.checkCancellation()
            let decodedRows = try decodeRows(json)
            let columns = orderedColumns(from: decodedRows)
            return QueryExecutionResponse(
                columns: columns,
                rows: decodedRows.map { row in columns.map { row[$0, default: ""] } },
                rowCount: decodedRows.count,
                duration: Date().timeIntervalSince(startedAt),
                completedAt: .now,
                wasTruncated: decodedRows.count >= previewLimit
            )
        }

        throw QueryExecutionError.emptyResult
    }

    private func previewSQL(for sql: String, limit: Int) -> String {
        let trimmedSQL = sql.trimmingCharacters(in: .whitespacesAndNewlinesAndSemicolons)
        return """
        select coalesce(json_agg(row_to_json(deepdrop_preview_row)), '[]'::json)::text
        from (
          select *
          from (
            \(trimmedSQL)
          ) deepdrop_user_query
          limit \(limit)
        ) deepdrop_preview_row;
        """
    }

    private func decodeRows(_ json: String) throws -> [[String: String]] {
        let data = Data(json.utf8)
        let rawRows = try JSONSerialization.jsonObject(with: data) as? [[String: Any?]] ?? []
        return rawRows.map { row in
            row.reduce(into: [:]) { result, pair in
                result[pair.key] = displayValue(pair.value)
            }
        }
    }

    private func displayValue(_ value: Any?) -> String {
        guard let value, !(value is NSNull) else {
            return "NULL"
        }

        if let string = value as? String {
            return string
        }

        if let number = value as? NSNumber {
            return number.stringValue
        }

        if let object = value as? [String: Any],
           let string = jsonString(from: object) {
            return string
        }

        if let array = value as? [Any],
           let string = jsonString(from: array) {
            return string
        }

        return String(describing: value)
    }

    private func jsonString(from value: Any) -> String? {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    private func orderedColumns(from rows: [[String: String]]) -> [String] {
        var seen = Set<String>()
        var columns: [String] = []

        for row in rows {
            for key in row.keys.sorted() where !seen.contains(key) {
                seen.insert(key)
                columns.append(key)
            }
        }

        return columns
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

private extension CharacterSet {
    static let whitespacesAndNewlinesAndSemicolons = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ";"))
}
