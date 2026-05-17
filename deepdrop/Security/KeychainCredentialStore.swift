//
//  KeychainCredentialStore.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import Foundation
import Security

struct KeychainCredentialStore: CredentialStore {
    let service: String

    init(service: String = ProcessInfo.processInfo.environment["DEEPDROP_KEYCHAIN_SERVICE"] ?? "com.deepdrop.database-password") {
        self.service = service
    }

    func savePassword(_ password: String, account: String) throws {
        let data = Data(password.utf8)
        var query = baseQuery(account: account)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(query as CFDictionary, nil)
        if addStatus == errSecSuccess {
            return
        }

        if addStatus == errSecDuplicateItem {
            let updateStatus = SecItemUpdate(
                baseQuery(account: account) as CFDictionary,
                [kSecValueData as String: data] as CFDictionary
            )
            guard updateStatus == errSecSuccess else {
                throw CredentialStoreError.unexpectedStatus(updateStatus)
            }
            return
        }

        throw CredentialStoreError.unexpectedStatus(addStatus)
    }

    func password(account: String) throws -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw CredentialStoreError.unexpectedStatus(status)
        }

        guard let data = item as? Data, let password = String(data: data, encoding: .utf8) else {
            throw CredentialStoreError.invalidData
        }

        return password
    }

    func deletePassword(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialStoreError.unexpectedStatus(status)
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
