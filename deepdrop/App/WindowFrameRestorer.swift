//
//  WindowFrameRestorer.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import AppKit
import SwiftUI

struct WindowFrameRestorer: NSViewRepresentable {
    let autosaveName: String
    let defaultSize: CGSize
    let minimumSize: CGSize

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.postsFrameChangedNotifications = false

        DispatchQueue.main.async {
            configureWindow(for: view)
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configureWindow(for: nsView)
        }
    }

    private func configureWindow(for view: NSView) {
        guard let window = view.window else {
            return
        }

        window.styleMask.insert(.resizable)
        window.minSize = minimumSize
        window.setFrameAutosaveName(autosaveName)

        let hasSavedFrame = UserDefaults.standard.string(forKey: "NSWindow Frame \(autosaveName)") != nil

        if !hasSavedFrame {
            let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
            let origin = NSPoint(
                x: visibleFrame.midX - defaultSize.width / 2,
                y: visibleFrame.midY - defaultSize.height / 2
            )
            window.setFrame(NSRect(origin: origin, size: defaultSize), display: true)
        }
    }
}

extension View {
    func deepDropWindowFrame(
        autosaveName: String,
        defaultSize: CGSize = CGSize(width: 1200, height: 780),
        minimumSize: CGSize = CGSize(width: 920, height: 560)
    ) -> some View {
        frame(
            minWidth: minimumSize.width,
            idealWidth: defaultSize.width,
            minHeight: minimumSize.height,
            idealHeight: defaultSize.height
        )
        .background(
            WindowFrameRestorer(
                autosaveName: autosaveName,
                defaultSize: defaultSize,
                minimumSize: minimumSize
            )
        )
    }
}
