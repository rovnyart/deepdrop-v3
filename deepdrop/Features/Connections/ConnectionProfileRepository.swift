//
//  ConnectionProfileRepository.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class ConnectionProfileRepository {
    private(set) var profiles: [ConnectionProfile]
    var lastErrorMessage: String?

    private let profileStore: ConnectionProfileStore
    private let credentialStore: CredentialStore

    convenience init() {
        self.init(
            profiles: [],
            profileStore: JSONConnectionProfileStore(),
            credentialStore: KeychainCredentialStore()
        )
    }

    init(
        profiles: [ConnectionProfile] = [],
        profileStore: ConnectionProfileStore,
        credentialStore: CredentialStore
    ) {
        self.profiles = profiles
        self.profileStore = profileStore
        self.credentialStore = credentialStore
    }

    func load() {
        do {
            profiles = try profileStore.loadProfiles().sortedByName()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func save(_ draft: ConnectionDraft) throws -> ConnectionProfile {
        let now = Date()
        let existingProfile = draft.id.flatMap { id in profiles.first { $0.id == id } }
        let profile = try makeProfile(from: draft, existingProfile: existingProfile, now: now)
        try validateNoExactDuplicate(profile)

        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }

        profiles = profiles.sortedByName()
        try persistProfilesAndPassword(profileID: profile.id, password: draft.password)
        lastErrorMessage = nil
        return profile
    }

    @discardableResult
    func duplicate(_ profile: ConnectionProfile) throws -> ConnectionProfile {
        let now = Date()
        let duplicate = ConnectionProfile(
            displayName: "\(profile.displayName) Copy",
            host: profile.host,
            port: profile.port,
            database: profile.database,
            username: profile.username,
            sslMode: profile.sslMode,
            colorTag: profile.colorTag,
            isProduction: profile.isProduction,
            createdAt: now,
            updatedAt: now
        )

        if let password = try credentialStore.password(account: profile.id.uuidString), !password.isEmpty {
            try credentialStore.savePassword(password, account: duplicate.id.uuidString)
        }

        profiles.append(duplicate)
        profiles = profiles.sortedByName()
        try profileStore.saveProfiles(profiles)
        lastErrorMessage = nil
        return duplicate
    }

    func delete(_ profile: ConnectionProfile) throws {
        profiles.removeAll { $0.id == profile.id }
        try profileStore.saveProfiles(profiles)
        try credentialStore.deletePassword(account: profile.id.uuidString)
        lastErrorMessage = nil
    }

    func password(for profile: ConnectionProfile) throws -> String? {
        try credentialStore.password(account: profile.id.uuidString)
    }

    private func makeProfile(from draft: ConnectionDraft, existingProfile: ConnectionProfile?, now: Date) throws -> ConnectionProfile {
        guard let port = draft.normalizedPort else {
            throw ConnectionRepositoryError.invalidPort
        }

        return ConnectionProfile(
            id: existingProfile?.id ?? draft.id ?? UUID(),
            displayName: draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            host: draft.host.trimmingCharacters(in: .whitespacesAndNewlines),
            port: port,
            database: draft.database.trimmingCharacters(in: .whitespacesAndNewlines),
            username: draft.username.trimmingCharacters(in: .whitespacesAndNewlines),
            sslMode: draft.sslMode,
            colorTag: draft.colorTag,
            isProduction: draft.isProduction,
            createdAt: existingProfile?.createdAt ?? now,
            updatedAt: now
        )
    }

    private func validateNoExactDuplicate(_ profile: ConnectionProfile) throws {
        let hasDuplicate = profiles.contains { existingProfile in
            existingProfile.id != profile.id
                && existingProfile.host.normalizedConnectionComponent == profile.host.normalizedConnectionComponent
                && existingProfile.port == profile.port
                && existingProfile.database.normalizedConnectionComponent == profile.database.normalizedConnectionComponent
                && existingProfile.username.normalizedConnectionComponent == profile.username.normalizedConnectionComponent
                && existingProfile.sslMode == profile.sslMode
        }

        if hasDuplicate {
            throw ConnectionRepositoryError.duplicateConnection
        }
    }

    private func persistProfilesAndPassword(profileID: UUID, password: String) throws {
        try profileStore.saveProfiles(profiles)

        if password.isEmpty {
            try credentialStore.deletePassword(account: profileID.uuidString)
        } else {
            try credentialStore.savePassword(password, account: profileID.uuidString)
        }
    }
}

enum ConnectionRepositoryError: Error, LocalizedError {
    case invalidPort
    case duplicateConnection

    var errorDescription: String? {
        switch self {
        case .invalidPort:
            return "Connection port is invalid."
        case .duplicateConnection:
            return "This exact connection already exists. Change the host, port, database, user, or SSL mode, or edit the existing saved source."
        }
    }
}

private extension String {
    var normalizedConnectionComponent: String {
        trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

private extension Array where Element == ConnectionProfile {
    func sortedByName() -> [ConnectionProfile] {
        sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }
}
