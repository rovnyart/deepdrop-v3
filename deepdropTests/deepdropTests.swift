//
//  deepdropTests.swift
//  deepdropTests
//
//  Created by art on 17.05.2026.
//

import Testing
@testable import deepdrop

struct deepdropTests {
    @Test func connectionColorTagsHaveStableDisplayNames() {
        #expect(ConnectionColorTag.blue.displayName == "Blue")
        #expect(ConnectionColorTag.green.displayName == "Green")
        #expect(ConnectionColorTag.yellow.displayName == "Yellow")
        #expect(ConnectionColorTag.orange.displayName == "Orange")
        #expect(ConnectionColorTag.red.displayName == "Red")
        #expect(ConnectionColorTag.purple.displayName == "Purple")
        #expect(ConnectionColorTag.gray.displayName == "Gray")
    }

    @Test func workspaceTabDefaultsToUntitledQuery() {
        let tab = WorkspaceTab()

        #expect(tab.title == "Untitled Query")
        #expect(tab.kind == .query)
        #expect(tab.connectionID == nil)
    }

    @Test func appStateStartsEmpty() {
        let state = AppState()

        #expect(state.connections.isEmpty)
        #expect(state.workspaceTabs.isEmpty)
        #expect(state.selectedConnection == nil)
        #expect(state.selectedTab == nil)
    }
}
