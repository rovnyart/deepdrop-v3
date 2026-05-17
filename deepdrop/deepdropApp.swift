//
//  deepdropApp.swift
//  deepdrop
//
//  Created by art on 17.05.2026.
//

import SwiftUI
import CoreData

@main
struct deepdropApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
