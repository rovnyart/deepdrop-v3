//
//  ConnectionURLParser.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import Foundation

struct ParsedConnectionURL: Equatable {
    var displayName: String
    var host: String
    var port: Int
    var database: String
    var username: String
    var password: String
    var sslMode: SSLMode
}

enum ConnectionURLParserError: Error, Equatable, LocalizedError {
    case unsupportedScheme(String?)
    case missingHost
    case missingDatabase
    case invalidPort(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedScheme(let scheme):
            if let scheme, !scheme.isEmpty {
                return "Unsupported URL scheme '\(scheme)'. Use postgres:// or postgresql://."
            }
            return "Missing URL scheme. Use postgres:// or postgresql://."
        case .missingHost:
            return "Connection URL is missing a host."
        case .missingDatabase:
            return "Connection URL is missing a database name."
        case .invalidPort(let port):
            return "Connection URL has an invalid port: \(port)."
        }
    }
}

enum ConnectionURLParser {
    static func parse(_ rawValue: String) throws -> ParsedConnectionURL {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmedValue) else {
            let rawScheme = rawScheme(from: trimmedValue)
            if rawScheme == "postgres" || rawScheme == "postgresql",
               let rawPort = rawPort(from: trimmedValue),
               rawPort.isEmpty == false {
                throw ConnectionURLParserError.invalidPort(rawPort)
            }
            throw ConnectionURLParserError.unsupportedScheme(nil)
        }

        guard components.scheme == "postgres" || components.scheme == "postgresql" else {
            throw ConnectionURLParserError.unsupportedScheme(components.scheme)
        }

        guard let host = components.host?.removingPercentEncoding, !host.isEmpty else {
            throw ConnectionURLParserError.missingHost
        }

        let database = normalizedDatabaseName(from: components.path)
        guard !database.isEmpty else {
            throw ConnectionURLParserError.missingDatabase
        }

        let port = try normalizedPort(from: components)
        let username = components.percentEncodedUser?.removingPercentEncoding ?? ""
        let password = components.percentEncodedPassword?.removingPercentEncoding ?? ""
        let sslMode = normalizedSSLMode(from: components.queryItems) ?? .prefer

        return ParsedConnectionURL(
            displayName: defaultDisplayName(database: database, host: host),
            host: host,
            port: port,
            database: database,
            username: username,
            password: password,
            sslMode: sslMode
        )
    }

    private static func normalizedDatabaseName(from path: String) -> String {
        let trimmedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return trimmedPath.removingPercentEncoding ?? trimmedPath
    }

    private static func normalizedPort(from components: URLComponents) throws -> Int {
        if let port = components.port {
            return port
        }

        guard let rawPort = rawPort(from: components.string), rawPort.isEmpty == false else {
            return 5432
        }

        throw ConnectionURLParserError.invalidPort(rawPort)
    }

    private static func rawPort(from urlString: String?) -> String? {
        guard let urlString else {
            return nil
        }

        let authorityStart = urlString.range(of: "://")?.upperBound ?? urlString.startIndex
        let authorityEnd = urlString[authorityStart...].firstIndex(of: "/") ?? urlString.endIndex
        let authority = urlString[authorityStart..<authorityEnd]
        let hostPort = authority.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false).last ?? authority

        guard let colonIndex = hostPort.lastIndex(of: ":") else {
            return nil
        }

        return String(hostPort[hostPort.index(after: colonIndex)...])
    }

    private static func rawScheme(from urlString: String) -> String? {
        guard let schemeEnd = urlString.range(of: "://")?.lowerBound else {
            return nil
        }

        return String(urlString[..<schemeEnd]).lowercased()
    }

    private static func normalizedSSLMode(from queryItems: [URLQueryItem]?) -> SSLMode? {
        guard let value = queryItems?.first(where: { $0.name.lowercased() == "sslmode" })?.value?.lowercased() else {
            return nil
        }

        return SSLMode(rawValue: value)
    }

    private static func defaultDisplayName(database: String, host: String) -> String {
        "\(database) \(host)"
    }
}
