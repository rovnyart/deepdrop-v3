//
//  ConnectionProfile.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import Foundation

struct ConnectionProfile: Identifiable, Hashable, Codable {
    var id: UUID
    var displayName: String
    var host: String
    var port: Int
    var database: String
    var username: String
    var sslMode: SSLMode
    var colorTag: ConnectionColorTag
    var isProduction: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        displayName: String,
        host: String,
        port: Int = 5432,
        database: String,
        username: String,
        sslMode: SSLMode = .prefer,
        colorTag: ConnectionColorTag = .blue,
        isProduction: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.displayName = displayName
        self.host = host
        self.port = port
        self.database = database
        self.username = username
        self.sslMode = sslMode
        self.colorTag = colorTag
        self.isProduction = isProduction
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum SSLMode: String, CaseIterable, Identifiable, Codable, Hashable {
    case disable
    case allow
    case prefer
    case require
    case verifyCA = "verify-ca"
    case verifyFull = "verify-full"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .disable:
            "Disable"
        case .allow:
            "Allow"
        case .prefer:
            "Prefer"
        case .require:
            "Require"
        case .verifyCA:
            "Verify CA"
        case .verifyFull:
            "Verify Full"
        }
    }
}
