//
//  ResultsPlaceholderView.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import SwiftUI

struct ResultsPlaceholderView: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DeepDropSpacing.lg) {
                Label("Results", systemImage: "tablecells")
                    .font(DeepDropTypography.sectionTitle)
                Label("Messages", systemImage: "text.bubble")
                    .font(DeepDropTypography.sectionTitle)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("No query has been run")
                    .font(DeepDropTypography.metadata)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, DeepDropSpacing.lg)
            .padding(.vertical, DeepDropSpacing.sm)
            .background(DeepDropColors.panelBackground)

            VStack(spacing: DeepDropSpacing.sm) {
                Image(systemName: "play.rectangle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Run a query to see result sets, command tags, notices, and errors here.")
                    .font(DeepDropTypography.metadata)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    ResultsPlaceholderView()
}
