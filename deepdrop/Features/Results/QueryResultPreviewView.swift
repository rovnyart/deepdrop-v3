//
//  QueryResultPreviewView.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import SwiftUI

struct QueryResultPreviewView: View {
    let state: QueryExecutionState

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { timeline in
            VStack(spacing: 0) {
                header(now: timeline.date)
                Divider()
                content(now: timeline.date)
            }
        }
        .accessibilityIdentifier("query-result-preview")
    }

    private func header(now: Date) -> some View {
        HStack(spacing: DeepDropSpacing.lg) {
            Label("Results", systemImage: "tablecells")
                .font(DeepDropTypography.sectionTitle)
            Label("Messages", systemImage: "text.bubble")
                .font(DeepDropTypography.sectionTitle)
                .foregroundStyle(.secondary)
            Spacer()
            Text(summary(now: now))
                .font(DeepDropTypography.metadata)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, DeepDropSpacing.lg)
        .padding(.vertical, DeepDropSpacing.sm)
        .background(DeepDropColors.panelBackground)
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        switch state {
        case .idle:
            VStack(spacing: DeepDropSpacing.sm) {
                Image(systemName: "play.rectangle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Run a query to see preview rows and messages here.")
                    .font(DeepDropTypography.metadata)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .running(let startedAt):
            VStack(spacing: DeepDropSpacing.sm) {
                ProgressView()
                Text("Running query... \(elapsedString(since: startedAt, now: now))")
                    .font(DeepDropTypography.metadata)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .succeeded(let response):
            resultTable(response)
        case .failed(let message):
            messageView(systemImage: "exclamationmark.triangle", message: message, color: DeepDropColors.dangerous)
        case .cancelled:
            messageView(systemImage: "stop.circle", message: "Query cancelled.", color: .secondary)
        }
    }

    private func resultTable(_ response: QueryExecutionResponse) -> some View {
        ScrollView([.horizontal, .vertical]) {
            Grid(alignment: .leading, horizontalSpacing: DeepDropSpacing.md, verticalSpacing: DeepDropSpacing.xs) {
                GridRow {
                    ForEach(response.columns, id: \.self) { column in
                        Text(column)
                            .font(DeepDropTypography.metadata.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(response.rows.indices, id: \.self) { rowIndex in
                    GridRow {
                        ForEach(response.rows[rowIndex].indices, id: \.self) { columnIndex in
                            Text(response.rows[rowIndex][columnIndex])
                                .font(DeepDropTypography.sql)
                                .lineLimit(1)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .padding(DeepDropSpacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func messageView(systemImage: String, message: String, color: Color) -> some View {
        VStack(spacing: DeepDropSpacing.sm) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(color)
            Text(message)
                .font(DeepDropTypography.metadata)
                .foregroundStyle(color)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func summary(now: Date) -> String {
        switch state {
        case .idle:
            return "No query has been run"
        case .running(let startedAt):
            return "Running · \(elapsedString(since: startedAt, now: now))"
        case .succeeded(let response):
            return "\(response.rowCount) rows · \(String(format: "%.2fs", response.duration))"
        case .failed:
            return "Failed"
        case .cancelled:
            return "Cancelled"
        }
    }

    private func elapsedString(since startedAt: Date, now: Date) -> String {
        let elapsed = max(0, now.timeIntervalSince(startedAt))
        if elapsed < 1 {
            return String(format: "%.2fs", elapsed)
        }

        return String(format: "%.1fs", elapsed)
    }
}
