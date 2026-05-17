//
//  ConnectionValidation.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import Foundation

enum ConnectionDraftField: Hashable {
    case displayName
    case host
    case port
    case database
    case username
}

struct ConnectionValidationIssue: Equatable, Identifiable {
    var field: ConnectionDraftField
    var message: String

    var id: ConnectionDraftField { field }
}

struct ConnectionValidationResult: Equatable {
    var issues: [ConnectionValidationIssue]

    var isValid: Bool {
        issues.isEmpty
    }

    func message(for field: ConnectionDraftField) -> String? {
        issues.first { $0.field == field }?.message
    }
}

enum ConnectionValidation {
    static func validate(_ draft: ConnectionDraft) -> ConnectionValidationResult {
        var issues: [ConnectionValidationIssue] = []

        if draft.displayName.trimmedForValidation.isEmpty {
            issues.append(ConnectionValidationIssue(field: .displayName, message: "Name is required."))
        }

        if draft.host.trimmedForValidation.isEmpty {
            issues.append(ConnectionValidationIssue(field: .host, message: "Host is required."))
        }

        if draft.database.trimmedForValidation.isEmpty {
            issues.append(ConnectionValidationIssue(field: .database, message: "Database is required."))
        }

        if draft.username.trimmedForValidation.isEmpty {
            issues.append(ConnectionValidationIssue(field: .username, message: "User is required."))
        }

        let portText = draft.portText.trimmedForValidation
        if portText.isEmpty {
            issues.append(ConnectionValidationIssue(field: .port, message: "Port is required."))
        } else if let port = Int(portText) {
            if !(1...65535).contains(port) {
                issues.append(ConnectionValidationIssue(field: .port, message: "Port must be between 1 and 65535."))
            }
        } else {
            issues.append(ConnectionValidationIssue(field: .port, message: "Port must be a number."))
        }

        return ConnectionValidationResult(issues: issues)
    }
}

private extension String {
    var trimmedForValidation: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
