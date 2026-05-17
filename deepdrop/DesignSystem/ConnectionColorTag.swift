//
//  ConnectionColorTag.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import SwiftUI

enum ConnectionColorTag: String, CaseIterable, Identifiable, Codable, Hashable {
    case blue
    case green
    case yellow
    case orange
    case red
    case purple
    case gray

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .blue:
            "Blue"
        case .green:
            "Green"
        case .yellow:
            "Yellow"
        case .orange:
            "Orange"
        case .red:
            "Red"
        case .purple:
            "Purple"
        case .gray:
            "Gray"
        }
    }

    var color: Color {
        switch self {
        case .blue:
            .blue
        case .green:
            .green
        case .yellow:
            .yellow
        case .orange:
            .orange
        case .red:
            .red
        case .purple:
            .purple
        case .gray:
            .gray
        }
    }
}
