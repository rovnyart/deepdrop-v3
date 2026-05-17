//
//  QueryHistoryMenu.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import SwiftUI

struct QueryHistoryMenu: View {
    let entries: [QueryHistoryEntry]
    let onUseEntry: (QueryHistoryEntry) -> Void

    var body: some View {
        Menu {
            if entries.isEmpty {
                Text("No query history")
            } else {
                ForEach(entries.prefix(12)) { entry in
                    Button {
                        onUseEntry(entry)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(entry.previewTitle)
                            Text(entry.previewSubtitle)
                        }
                    }
                }
            }
        } label: {
            Label("History", systemImage: "clock.arrow.circlepath")
        }
        .menuStyle(.button)
        .help("Recent query history")
    }
}

private extension QueryHistoryEntry {
    var previewTitle: String {
        let firstLine = sql
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Query"

        if firstLine.count > 64 {
            return "\(firstLine.prefix(61))..."
        }

        return firstLine
    }

    var previewSubtitle: String {
        let status: String
        if wasCancelled {
            status = "cancelled"
        } else if succeeded {
            status = rowCount.map { "\($0) rows" } ?? "succeeded"
        } else {
            status = "failed"
        }

        return "\(classification.displayName) · \(status) · \(startedAt.formatted(date: .abbreviated, time: .shortened))"
    }
}

#Preview {
    QueryHistoryMenu(
        entries: [
            QueryHistoryEntry(
                connectionID: UUID(),
                sql: "select *\nfrom users\nlimit 20",
                classification: .readOnly,
                startedAt: .now,
                duration: 0.2,
                rowCount: 20,
                succeeded: true
            )
        ],
        onUseEntry: { _ in }
    )
}
