//
//  ConnectionDraft.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import Foundation

struct ConnectionDraft: Equatable {
    var id: UUID?
    var displayName: String
    var host: String
    var portText: String
    var database: String
    var username: String
    var password: String
    var sslMode: SSLMode
    var colorTag: ConnectionColorTag
    var isProduction: Bool

    init(
        id: UUID? = nil,
        displayName: String = "",
        host: String = "",
        portText: String = "5432",
        database: String = "",
        username: String = "",
        password: String = "",
        sslMode: SSLMode = .prefer,
        colorTag: ConnectionColorTag = .blue,
        isProduction: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.host = host
        self.portText = portText
        self.database = database
        self.username = username
        self.password = password
        self.sslMode = sslMode
        self.colorTag = colorTag
        self.isProduction = isProduction
    }

    init(parsedURL: ParsedConnectionURL) {
        self.init(
            displayName: parsedURL.displayName,
            host: parsedURL.host,
            portText: String(parsedURL.port),
            database: parsedURL.database,
            username: parsedURL.username,
            password: parsedURL.password,
            sslMode: parsedURL.sslMode
        )
    }

    init(profile: ConnectionProfile, password: String = "") {
        self.init(
            id: profile.id,
            displayName: profile.displayName,
            host: profile.host,
            portText: String(profile.port),
            database: profile.database,
            username: profile.username,
            password: password,
            sslMode: profile.sslMode,
            colorTag: profile.colorTag,
            isProduction: profile.isProduction
        )
    }

    var normalizedPort: Int? {
        Int(portText.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
