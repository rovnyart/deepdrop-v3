//
//  DeepDropCommands.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import SwiftUI

struct DeepDropCommands: Commands {
    var body: some Commands {
        CommandMenu("DeepDrop") {
            Button("New Connection") {}
                .keyboardShortcut("n", modifiers: .command)
                .disabled(true)

            Button("New Query Tab") {}
                .keyboardShortcut("t", modifiers: .command)
                .disabled(true)
        }
    }
}
