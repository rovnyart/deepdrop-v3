//
//  CredentialStore.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import Foundation

protocol CredentialStore {
    func savePassword(_ password: String, account: String) throws
    func password(account: String) throws -> String?
    func deletePassword(account: String) throws
}

enum CredentialStoreError: Error, Equatable, LocalizedError {
    case unexpectedStatus(OSStatus)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            return "Keychain operation failed with status \(status)."
        case .invalidData:
            return "Keychain returned invalid password data."
        }
    }
}
