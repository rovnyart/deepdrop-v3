//
//  ConnectionTestService.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import Foundation
#if canImport(PostgresNIO)
import NIOSSL
import PostgresNIO
#endif

protocol ConnectionTesting {
    func testConnection(_ request: ConnectionTestRequest) async -> ConnectionTestResult
}

struct ConnectionTestRequest: Equatable {
    var host: String
    var port: Int
    var database: String
    var username: String
    var password: String
    var sslMode: SSLMode
}

struct ConnectionTestResult: Equatable {
    var status: ConnectionTestStatus
    var duration: Duration?
    var serverVersion: String?
    var message: String

    static let notTested = ConnectionTestResult(
        status: .notTested,
        duration: nil,
        serverVersion: nil,
        message: "Not tested"
    )
}

enum ConnectionTestStatus: Equatable {
    case notTested
    case testing
    case succeeded
    case failed
}

struct PostgresConnectionTestService: ConnectionTesting {
    func testConnection(_ request: ConnectionTestRequest) async -> ConnectionTestResult {
#if canImport(PostgresNIO)
        let startedAt = ContinuousClock.now

        do {
            return try await withThrowingTaskGroup(of: ConnectionTestResult.self) { group in
                group.addTask {
                    try await runConnectionTest(request, startedAt: startedAt)
                }

                group.addTask {
                    try await Task.sleep(for: .seconds(8))
                    throw ConnectionTestError.timeout
                }

                guard let result = try await group.next() else {
                    throw ConnectionTestError.unknown
                }

                group.cancelAll()
                return result
            }
        } catch {
            return ConnectionTestResult(
                status: .failed,
                duration: startedAt.duration(to: .now),
                serverVersion: nil,
                message: friendlyMessage(for: error)
            )
        }
#else
        ConnectionTestResult(
            status: .failed,
            duration: nil,
            serverVersion: nil,
            message: "PostgresNIO is not linked to the app target."
        )
#endif
    }

#if canImport(PostgresNIO)
    private func runConnectionTest(_ request: ConnectionTestRequest, startedAt: ContinuousClock.Instant) async throws -> ConnectionTestResult {
        let configuration = PostgresClient.Configuration(
            host: request.host,
            port: request.port,
            username: request.username,
            password: request.password,
            database: request.database,
            tls: tlsMode(for: request.sslMode)
        )
        let client = PostgresClient(configuration: configuration)

        return try await withThrowingTaskGroup(of: String?.self) { group in
            group.addTask {
                await client.run()
                return nil
            }

            group.addTask {
                let rows = try await client.query("select version()")
                for try await row in rows.decode((String).self) {
                    return row
                }
                return nil
            }

            let version = try await group.next() ?? nil
            group.cancelAll()

            return ConnectionTestResult(
                status: .succeeded,
                duration: startedAt.duration(to: .now),
                serverVersion: version,
                message: "Connected"
            )
        }
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

    private func friendlyMessage(for error: Error) -> String {
        if error is CancellationError {
            return "Connection test was cancelled."
        }

        if let testError = error as? ConnectionTestError {
            switch testError {
            case .timeout:
                return "Connection timed out after 8 seconds."
            case .unknown:
                return "Connection test failed."
            }
        }

        let rawMessage = String(describing: error)
        let lowercased = rawMessage.lowercased()

        if lowercased.contains("authentication") || lowercased.contains("password") {
            return "Authentication failed. Check the user and password."
        }

        if lowercased.contains("connection refused") || lowercased.contains("connect") {
            return "Host unreachable or refused the connection."
        }

        if lowercased.contains("database") && lowercased.contains("does not exist") {
            return "Database does not exist."
        }

        if lowercased.contains("ssl") || lowercased.contains("tls") {
            return "SSL mode was rejected by the server."
        }

        return rawMessage
    }
#endif
}

enum ConnectionTestError: Error {
    case timeout
    case unknown
}

extension ConnectionDraft {
    var connectionTestRequest: ConnectionTestRequest? {
        guard let port = normalizedPort else {
            return nil
        }

        return ConnectionTestRequest(
            host: host.trimmingCharacters(in: .whitespacesAndNewlines),
            port: port,
            database: database.trimmingCharacters(in: .whitespacesAndNewlines),
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password,
            sslMode: sslMode
        )
    }
}
