//
//  deepdropApp.swift
//  deepdrop
//
//  Created by art on 17.05.2026.
//

import SwiftUI

@main
struct deepdropApp: App {
    var body: some Scene {
        WindowGroup("DeepDrop") {
            ContentView()
                .deepDropWindowFrame(autosaveName: "DeepDropMainWindow")
        }
        .defaultSize(width: 1200, height: 780)
        .windowResizability(.contentMinSize)
        .commands {
            DeepDropCommands()
        }

        Settings {
            SettingsView()
        }
    }
}
