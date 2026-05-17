//
//  QueryEditorView.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import SwiftUI

struct QueryEditorView: View {
    @Binding var document: QueryDocument
    @Binding var executionState: QueryExecutionState
    let connection: ConnectionProfile?
    let onExecute: (SQLStatement, ConnectionProfile) async throws -> QueryExecutionResponse
    let onRecordHistory: (QueryHistoryEntry) -> Void
    let historyEntries: [QueryHistoryEntry]
    let onUseHistoryEntry: (QueryHistoryEntry) -> Void
    @State private var selectedRange = NSRange(location: 0, length: 0)
    @State private var pendingStatement: SQLStatement?
    @State private var statusMessage = "Ready"
    @State private var executionTask: Task<Void, Never>?
    @State private var activeExecutionID: UUID?
    @State private var activeHistoryContext: QueryExecutionHistoryContext?

    var body: some View {
        VStack(spacing: 0) {
            editorHeader
            Divider()
            HStack(spacing: 0) {
                lineNumberGutter
                Divider()
                QueryTextViewRepresentable(text: $document.sql, selectedRange: $selectedRange)
                    .accessibilityIdentifier("query-editor-text-view")
                    .onChange(of: document.sql) { _, _ in
                        document.updatedAt = .now
                    }
            }
            Divider()
            statementStatusBar
        }
        .background(DeepDropColors.workspaceBackground)
        .sheet(
            isPresented: Binding(
                get: { pendingStatement != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingStatement = nil
                    }
                }
            )
        ) {
            if let pendingStatement {
                QueryExecutionConfirmationView(
                    statement: pendingStatement,
                    connection: connection,
                    onRun: {
                        run(pendingStatement)
                        self.pendingStatement = nil
                    },
                    onCancel: {
                        self.pendingStatement = nil
                    }
                )
            }
        }
    }

    private var editorHeader: some View {
        HStack(spacing: DeepDropSpacing.md) {
            Label(document.title, systemImage: "terminal")
                .font(DeepDropTypography.sectionTitle)

            if let connection {
                Text("\(connection.database)@\(connection.host)")
                    .font(DeepDropTypography.metadata)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            QueryHistoryMenu(entries: historyEntries, onUseEntry: onUseHistoryEntry)

            if case .running = executionState {
                Button(action: cancelRunningQuery) {
                    Label("Stop", systemImage: "stop.fill")
                }
                .keyboardShortcut(".", modifiers: .command)
                .help("Cancel running query")
            } else {
                Button(action: prepareRun) {
                    Label("Run", systemImage: "play.fill")
                }
                .disabled(document.sql.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
                .help("Run active statement")
            }
        }
        .padding(.horizontal, DeepDropSpacing.lg)
        .padding(.vertical, DeepDropSpacing.sm)
        .background(DeepDropColors.panelBackground)
    }

    private var statementStatusBar: some View {
        HStack(spacing: DeepDropSpacing.sm) {
            Image(systemName: "scope")
                .foregroundStyle(.secondary)
            Text(statusMessage)
                .font(DeepDropTypography.metadata)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, DeepDropSpacing.lg)
        .padding(.vertical, DeepDropSpacing.sm)
        .background(DeepDropColors.panelBackground)
    }

    private var lineNumberGutter: some View {
        ScrollView(.vertical) {
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(1...lineCount, id: \.self) { lineNumber in
                    Text("\(lineNumber)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .frame(height: 18, alignment: .topTrailing)
                }
            }
            .padding(.top, 13)
            .padding(.horizontal, DeepDropSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .scrollDisabled(true)
        .frame(width: 48)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.35))
    }

    private var lineCount: Int {
        max(document.sql.components(separatedBy: .newlines).count, 1)
    }

    private func prepareRun() {
        let statement = SQLStatementDetector.statement(
            in: document.sql,
            selectedRange: selectedRange,
            cursorLocation: selectedRange.location
        )

        guard let statement else {
            statusMessage = "No SQL statement at cursor."
            return
        }

        statusMessage = "Detected \(statement.classification.displayName) statement on lines \(statement.lineRange.lowerBound)-\(statement.lineRange.upperBound)."
        pendingStatement = statement
    }

    private func run(_ statement: SQLStatement) {
        guard let connection else {
            executionState = .failed(QueryExecutionError.missingConnection.localizedDescription)
            return
        }

        executionTask?.cancel()
        let executionID = UUID()
        let startedAt = Date()
        activeExecutionID = executionID
        activeHistoryContext = QueryExecutionHistoryContext(statement: statement, connection: connection, startedAt: startedAt)
        executionState = .running(startedAt: startedAt)
        statusMessage = "Running \(statement.classification.displayName) statement..."

        executionTask = Task {
            do {
                let response = try await onExecute(statement, connection)
                await MainActor.run {
                    guard activeExecutionID == executionID else {
                        return
                    }
                    executionState = .succeeded(response)
                    statusMessage = "Completed \(response.rowCount) rows in \(String(format: "%.2fs", response.duration))."
                    recordHistory(
                        statement: statement,
                        connection: connection,
                        startedAt: startedAt,
                        duration: response.duration,
                        rowCount: response.rowCount,
                        succeeded: true
                    )
                    activeExecutionID = nil
                    activeHistoryContext = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    guard activeExecutionID == executionID else {
                        return
                    }
                    executionState = .cancelled
                    statusMessage = "Query cancelled."
                    recordHistory(
                        statement: statement,
                        connection: connection,
                        startedAt: startedAt,
                        duration: Date().timeIntervalSince(startedAt),
                        rowCount: nil,
                        succeeded: false,
                        wasCancelled: true
                    )
                    activeExecutionID = nil
                    activeHistoryContext = nil
                }
            } catch {
                await MainActor.run {
                    guard activeExecutionID == executionID else {
                        return
                    }
                    executionState = .failed(error.localizedDescription)
                    statusMessage = "Query failed."
                    recordHistory(
                        statement: statement,
                        connection: connection,
                        startedAt: startedAt,
                        duration: Date().timeIntervalSince(startedAt),
                        rowCount: nil,
                        succeeded: false,
                        errorMessage: error.localizedDescription
                    )
                    activeExecutionID = nil
                    activeHistoryContext = nil
                }
            }
        }
    }

    private func cancelRunningQuery() {
        if let activeHistoryContext {
            recordHistory(
                statement: activeHistoryContext.statement,
                connection: activeHistoryContext.connection,
                startedAt: activeHistoryContext.startedAt,
                duration: Date().timeIntervalSince(activeHistoryContext.startedAt),
                rowCount: nil,
                succeeded: false,
                wasCancelled: true
            )
        }
        activeExecutionID = nil
        activeHistoryContext = nil
        executionTask?.cancel()
        executionTask = nil
        executionState = .cancelled
        statusMessage = "Query cancelled."
    }

    private func recordHistory(
        statement: SQLStatement,
        connection: ConnectionProfile,
        startedAt: Date,
        duration: TimeInterval?,
        rowCount: Int?,
        succeeded: Bool,
        wasCancelled: Bool = false,
        errorMessage: String? = nil
    ) {
        onRecordHistory(
            QueryHistoryEntry(
                connectionID: connection.id,
                sql: statement.text,
                classification: statement.classification,
                startedAt: startedAt,
                duration: duration,
                rowCount: rowCount,
                succeeded: succeeded,
                wasCancelled: wasCancelled,
                errorMessage: errorMessage
            )
        )
    }
}

private struct QueryExecutionHistoryContext {
    var statement: SQLStatement
    var connection: ConnectionProfile
    var startedAt: Date
}

private struct QueryExecutionConfirmationView: View {
    let statement: SQLStatement
    let connection: ConnectionProfile?
    let onRun: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DeepDropSpacing.lg) {
            VStack(alignment: .leading, spacing: DeepDropSpacing.xs) {
                Text(confirmationTitle)
                    .font(.headline)
                Text(confirmationSubtitle)
                    .font(DeepDropTypography.metadata)
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                Text(statement.text)
                    .font(DeepDropTypography.sql)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(DeepDropSpacing.md)
            }
            .frame(minHeight: 180)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            HStack {
                classificationBadge
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Run", action: onRun)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(DeepDropSpacing.xl)
        .frame(width: 620)
    }

    private var confirmationTitle: String {
        if statement.requiresStrongConfirmation {
            return "Confirm SQL Before Running"
        }

        return statement.isMultiline ? "Run Multiline Statement?" : "Run Statement?"
    }

    private var confirmationSubtitle: String {
        let target = connection.map { "\($0.displayName) (\($0.database)@\($0.host))" } ?? "selected connection"
        return "Target: \(target). Lines \(statement.lineRange.lowerBound)-\(statement.lineRange.upperBound)."
    }

    private var classificationBadge: some View {
        Text(statement.classification.displayName)
            .font(DeepDropTypography.metadata)
            .foregroundStyle(statement.requiresStrongConfirmation ? DeepDropColors.dangerous : .secondary)
            .padding(.horizontal, DeepDropSpacing.sm)
            .padding(.vertical, DeepDropSpacing.xs)
            .background(statement.requiresStrongConfirmation ? DeepDropColors.dangerous.opacity(0.12) : Color.secondary.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private extension SQLStatement {
    var requiresStrongConfirmation: Bool {
        switch classification {
        case .readOnly:
            return false
        case .mutation, .schemaChange, .transactionControl, .admin, .unknown:
            return true
        }
    }
}

#Preview {
    QueryEditorView(
        document: .constant(QueryDocument(connectionID: UUID(), sql: "select *\nfrom public.users\nlimit 100;")),
        executionState: .constant(.idle),
        connection: nil,
        onExecute: { _, _ in throw QueryExecutionError.missingConnection },
        onRecordHistory: { _ in },
        historyEntries: [],
        onUseHistoryEntry: { _ in }
    )
}
