//
//  ConnectionProfileStore.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import Foundation

protocol ConnectionProfileStore {
    func loadProfiles() throws -> [ConnectionProfile]
    func saveProfiles(_ profiles: [ConnectionProfile]) throws
}

struct JSONConnectionProfileStore: ConnectionProfileStore {
    let fileURL: URL

    init(fileURL: URL = Self.defaultFileURL()) {
        self.fileURL = fileURL
    }

    func loadProfiles() throws -> [ConnectionProfile] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder.deepDrop.decode([ConnectionProfile].self, from: data)
    }

    func saveProfiles(_ profiles: [ConnectionProfile]) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let data = try JSONEncoder.deepDrop.encode(profiles)
        try data.write(to: fileURL, options: [.atomic])
    }

    static func defaultFileURL() -> URL {
        if let overridePath = ProcessInfo.processInfo.environment["DEEPDROP_CONNECTIONS_FILE"], !overridePath.isEmpty {
            return URL(fileURLWithPath: overridePath)
        }

        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")

        return baseURL
            .appendingPathComponent("DeepDrop", isDirectory: true)
            .appendingPathComponent("connections.json", isDirectory: false)
    }
}

private extension JSONEncoder {
    static var deepDrop: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var deepDrop: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
