//
//  ConnectionProfileRepositoryTests.swift
//  deepdropTests
//
//  Created by Codex on 17.05.2026.
//

import Foundation
import Testing
@testable import deepdrop

@MainActor
struct ConnectionProfileRepositoryTests {
    @Test func savingProfileStoresMetadataAndPasswordSeparately() throws {
        let profileStore = InMemoryConnectionProfileStore()
        let credentialStore = InMemoryCredentialStore()
        let repository = ConnectionProfileRepository(profileStore: profileStore, credentialStore: credentialStore)
        let draft = ConnectionDraft(
            displayName: "Local",
            host: "localhost",
            portText: "5432",
            database: "deepdrop",
            username: "art",
            password: "super-secret"
        )

        let profile = try repository.save(draft)

        #expect(profileStore.savedProfiles.count == 1)
        #expect(profileStore.savedProfiles.first?.displayName == "Local")
        #expect(try credentialStore.password(account: profile.id.uuidString) == "super-secret")
    }

    @Test func serializedProfilesDoNotContainPassword() throws {
        let profile = ConnectionProfile(
            displayName: "Local",
            host: "localhost",
            database: "deepdrop",
            username: "art"
        )

        let data = try JSONEncoder().encode([profile])
        let json = String(decoding: data, as: UTF8.self)

        #expect(!json.contains("super-secret"))
        #expect(!json.contains("password"))
    }

    @Test func deletingProfileDeletesPassword() throws {
        let profileStore = InMemoryConnectionProfileStore()
        let credentialStore = InMemoryCredentialStore()
        let repository = ConnectionProfileRepository(profileStore: profileStore, credentialStore: credentialStore)
        let profile = try repository.save(ConnectionDraft(
            displayName: "Local",
            host: "localhost",
            portText: "5432",
            database: "deepdrop",
            username: "art",
            password: "super-secret"
        ))

        try repository.delete(profile)

        #expect(repository.profiles.isEmpty)
        #expect(try credentialStore.password(account: profile.id.uuidString) == nil)
    }

    @Test func duplicatingProfileCopiesPasswordToNewAccount() throws {
        let profileStore = InMemoryConnectionProfileStore()
        let credentialStore = InMemoryCredentialStore()
        let repository = ConnectionProfileRepository(profileStore: profileStore, credentialStore: credentialStore)
        let profile = try repository.save(ConnectionDraft(
            displayName: "Local",
            host: "localhost",
            portText: "5432",
            database: "deepdrop",
            username: "art",
            password: "super-secret"
        ))

        let duplicate = try repository.duplicate(profile)

        #expect(duplicate.id != profile.id)
        #expect(duplicate.displayName == "Local Copy")
        #expect(try credentialStore.password(account: duplicate.id.uuidString) == "super-secret")
    }

    @Test func savingExactDuplicateConnectionThrows() throws {
        let repository = ConnectionProfileRepository(
            profileStore: InMemoryConnectionProfileStore(),
            credentialStore: InMemoryCredentialStore()
        )
        let original = ConnectionDraft(
            displayName: "Local",
            host: "localhost",
            portText: "5432",
            database: "deepdrop",
            username: "art",
            password: "first",
            sslMode: .require
        )
        let duplicate = ConnectionDraft(
            displayName: "Local Copy",
            host: " LOCALHOST ",
            portText: "5432",
            database: "DeepDrop",
            username: "ART",
            password: "second",
            sslMode: .require
        )

        try repository.save(original)

        #expect(throws: ConnectionRepositoryError.duplicateConnection) {
            try repository.save(duplicate)
        }
    }

    @Test func editingExistingProfileDoesNotCountAsDuplicateOfItself() throws {
        let repository = ConnectionProfileRepository(
            profileStore: InMemoryConnectionProfileStore(),
            credentialStore: InMemoryCredentialStore()
        )
        let profile = try repository.save(ConnectionDraft(
            displayName: "Local",
            host: "localhost",
            portText: "5432",
            database: "deepdrop",
            username: "art",
            password: "first",
            sslMode: .require
        ))

        let editedProfile = try repository.save(ConnectionDraft(
            id: profile.id,
            displayName: "Local Renamed",
            host: "localhost",
            portText: "5432",
            database: "deepdrop",
            username: "art",
            password: "second",
            sslMode: .require
        ))

        #expect(editedProfile.id == profile.id)
        #expect(editedProfile.displayName == "Local Renamed")
        #expect(repository.profiles.count == 1)
    }
}

private final class InMemoryConnectionProfileStore: ConnectionProfileStore {
    var savedProfiles: [ConnectionProfile] = []

    func loadProfiles() throws -> [ConnectionProfile] {
        savedProfiles
    }

    func saveProfiles(_ profiles: [ConnectionProfile]) throws {
        savedProfiles = profiles
    }
}

private final class InMemoryCredentialStore: CredentialStore {
    private var passwords: [String: String] = [:]

    func savePassword(_ password: String, account: String) throws {
        passwords[account] = password
    }

    func password(account: String) throws -> String? {
        passwords[account]
    }

    func deletePassword(account: String) throws {
        passwords.removeValue(forKey: account)
    }
}
