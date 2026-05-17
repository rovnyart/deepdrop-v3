//
//  SettingsView.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            SettingsSectionView(
                title: "General",
                subtitle: "Appearance, editor behavior, and workspace preferences will live here.",
                systemImage: "gearshape"
            )
            .tabItem {
                Label("General", systemImage: "gearshape")
            }

            SettingsSectionView(
                title: "Connections",
                subtitle: "Saved sources, credential reset, and connection safety controls start in Phase 1.",
                systemImage: "server.rack"
            )
            .tabItem {
                Label("Connections", systemImage: "server.rack")
            }

            SettingsSectionView(
                title: "AI",
                subtitle: "OpenAI key storage, model selection, and context controls arrive after the core database flow.",
                systemImage: "sparkles"
            )
            .tabItem {
                Label("AI", systemImage: "sparkles")
            }

            SettingsSectionView(
                title: "Safety",
                subtitle: "Production markers, destructive query confirmations, and AI mutation policy will be configured here.",
                systemImage: "exclamationmark.shield"
            )
            .tabItem {
                Label("Safety", systemImage: "exclamationmark.shield")
            }
        }
        .frame(width: 560, height: 360)
    }
}

private struct SettingsSectionView: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: DeepDropSpacing.lg) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DeepDropSpacing.sm) {
                Text(title)
                    .font(.title2.weight(.semibold))
                Text(subtitle)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(DeepDropSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview {
    SettingsView()
}
