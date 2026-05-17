//
//  WorkspacePlaceholderView.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import SwiftUI

struct WorkspacePlaceholderView: View {
    let tab: WorkspaceTab?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DeepDropSpacing.sm) {
                Label(tab?.title ?? "Untitled Query", systemImage: "terminal")
                    .font(DeepDropTypography.sectionTitle)
                Spacer()
                Text("Editor arrives in Phase 3")
                    .font(DeepDropTypography.metadata)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, DeepDropSpacing.lg)
            .padding(.vertical, DeepDropSpacing.sm)
            .background(DeepDropColors.panelBackground)

            Text("select *\nfrom public.example\nlimit 100;")
                .font(DeepDropTypography.sql)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(DeepDropSpacing.lg)
        }
    }
}

#Preview {
    WorkspacePlaceholderView(tab: WorkspaceTab())
}
