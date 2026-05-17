//
//  ConnectionEmptyStateView.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import SwiftUI

struct ConnectionEmptyStateView: View {
    let onAddConnection: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DeepDropSpacing.xl) {
            VStack(alignment: .leading, spacing: DeepDropSpacing.sm) {
                Text("Connect to PostgreSQL")
                    .font(.system(size: 28, weight: .semibold))
                Text("Create a database source to browse schemas, write SQL, inspect results, and add AI assistance later.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 520, alignment: .leading)
            }

            HStack(spacing: DeepDropSpacing.md) {
                Button(action: onAddConnection) {
                    Label("Add Database Source", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("empty-add-database-source-button")

                Button(action: {}) {
                    Label("Paste URL", systemImage: "doc.on.clipboard")
                }
                .controlSize(.large)
                .disabled(true)
                .help("Connection URL parsing starts in Phase 1")
            }

            VStack(alignment: .leading, spacing: DeepDropSpacing.md) {
                PhaseCapabilityRow(
                    icon: "sidebar.left",
                    title: "Connection sidebar",
                    detail: "Saved sources and schema objects will live on the left."
                )
                PhaseCapabilityRow(
                    icon: "text.cursor",
                    title: "SQL workspace",
                    detail: "Query tabs, execution, and history will fill the main area."
                )
                PhaseCapabilityRow(
                    icon: "tablecells",
                    title: "Results area",
                    detail: "Result grids, messages, and execution plans will appear below."
                )
            }
            .padding(.top, DeepDropSpacing.sm)
        }
        .padding(DeepDropSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
    }
}

private struct PhaseCapabilityRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: DeepDropSpacing.md) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DeepDropTypography.sectionTitle)
                Text(detail)
                    .font(DeepDropTypography.metadata)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ConnectionEmptyStateView(onAddConnection: {})
}
