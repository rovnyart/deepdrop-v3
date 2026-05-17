# Phase 3 Implementation Plan: Query Editor MVP

## Goal

Let users write and execute PostgreSQL queries from DeepDrop.

Phase 3 turns DeepDrop from a connection/catalog browser into a usable database client. A user should be able to open a query tab for a saved connection, type SQL, run the selected text or active statement, cancel a running query, and inspect execution messages/errors. The result grid can stay deliberately simple in this phase; rich result rendering and table browsing belong to Phase 4.

## Product Outcome

At the end of Phase 3, DeepDrop should support:

- Opening a query tab for a selected saved connection.
- Editing SQL in a real query editor surface.
- Basic PostgreSQL syntax highlighting.
- Line numbers, current-line affordance, and monospace editor styling.
- Active statement detection at the cursor.
- Running selected SQL or active statement with `Cmd+Enter`.
- Showing a compact confirmation before running multiline active statements.
- Showing stronger confirmation for destructive or DDL/admin statements.
- Executing SQL against the selected PostgreSQL connection.
- Cancelling an in-flight query.
- Showing execution status, elapsed time, command tag, affected row count, notices, and errors.
- Persisting lightweight query history locally.
- Keeping the app responsive during execution.

## Non-Goals

Phase 3 does not include:

- Production-grade result grid virtualization.
- Large result set pagination or streaming UI.
- Table row browsing from sidebar double-click.
- CRUD/editing.
- CSV/JSON export.
- Full SQL autocomplete.
- AI query generation or explanation.
- Saved snippets.
- Query formatting.
- Full SQL parser bindings.
- Persistent connection pooling for many concurrent tabs.

These belong to later phases.

## Current Starting Point

Phase 0 provides:

- Native SwiftUI app shell.
- Workspace/results placeholder structure.
- Basic command/menu entry points.
- Window sizing/restoration.

Phase 1 provides:

- Saved `ConnectionProfile` metadata.
- Keychain-backed database passwords.
- PostgreSQL URL parsing and validation.
- Real `postgres-nio` connection testing.

Phase 2 provides:

- Real catalog introspection using `postgres-nio`.
- Sidebar schemas/tables/views/columns/functions/extensions.
- Per-connection catalog cache.
- Workspace object detail view.
- Catalog search and refresh.

Phase 3 should add query execution without destabilizing those foundations.

## Key Decisions

### Editor Implementation

Recommended MVP:

- Use an AppKit-backed `NSTextView` through `NSViewRepresentable`.
- Keep the bridge focused and replaceable.
- Implement lightweight highlighting ourselves.

Rationale:

- SwiftUI `TextEditor` is too limited for line numbers, selection APIs, current cursor statement detection, and future editor features.
- `NSTextView` is native, fast enough for MVP, and gives direct access to selected ranges, insertion point, undo, fonts, and text storage attributes.
- Monaco/CodeMirror in `WKWebView` is powerful but would compromise the native direction too early.
- Tree-sitter can be revisited after the core execution workflow is proven.

### Query Execution Lifecycle

Recommended MVP:

- Use short-lived `postgres-nio` clients for each execution.
- Do not introduce long-lived pooled sessions yet.
- Keep API shape compatible with a future `PostgresEngine` that can own sessions and streaming.

Rationale:

- Phase 3 needs correctness, cancellation, and UI flow more than pooling.
- Catalog loading already uses short-lived connections.
- Persistent sessions become more important once Phase 4 streams/paginates result rows and Phase 5 handles transactions/edits.

### Result Scope

Recommended MVP:

- Decode a small bounded result preview, not a production grid.
- Represent rows/columns in a typed-but-simple model.
- Show results in a placeholder table only if feasible without overbuilding.
- Prioritize execution workflow, error handling, and cancellation.

Hard limit:

- Default preview limit should be conservative, for example first 500 or 1000 rows.
- Phase 4 owns virtualized grids and large data behavior.

### SQL Parsing Scope

Recommended MVP:

- Build an internal lexer for statement boundaries and classification.
- Do not bind `libpg_query` in Phase 3.

The lexer must understand enough PostgreSQL syntax to avoid obvious wrong statement detection:

- Semicolons.
- Single-line comments.
- Block comments.
- Single-quoted strings.
- Double-quoted identifiers.
- Dollar-quoted strings, including tagged dollar quotes.
- Cursor position.

Statement classification should be conservative. Unknown statements should be treated as potentially unsafe when confirmations matter.

## Proposed File Structure

Add files under the app target:

```text
deepdrop/
  Database/
    QueryExecutionModels.swift
    QueryExecutionService.swift
    PostgresQueryExecutor.swift
  Features/
    QueryEditor/
      QueryDocument.swift
      QueryEditorView.swift
      QueryTextViewRepresentable.swift
      QueryEditorCoordinator.swift
      SQLSyntaxHighlighter.swift
      SQLLexer.swift
      SQLStatementDetector.swift
      SQLStatementClassifier.swift
      QueryExecutionViewModel.swift
      QueryExecutionConfirmation.swift
      QueryHistoryStore.swift
      QueryHistoryView.swift
  Features/
    Results/
      QueryResultPreviewView.swift
      QueryMessagesView.swift
      QueryExecutionStatusView.swift
```

Tests:

```text
deepdropTests/
  SQLLexerTests.swift
  SQLStatementDetectorTests.swift
  SQLStatementClassifierTests.swift
  QueryHistoryStoreTests.swift
  QueryExecutionServiceTests.swift
```

Optional integration tests:

```text
deepdropTests/
  QueryExecutionIntegrationTests.swift
```

## Domain Models

### QueryDocument

```swift
struct QueryDocument: Identifiable, Codable, Equatable {
    var id: UUID
    var connectionID: UUID
    var title: String
    var sql: String
    var selectedRange: NSRange?
    var createdAt: Date
    var updatedAt: Date
}
```

Notes:

- `selectedRange` does not need to be persisted initially.
- `title` can default to `Untitled Query`.
- Document persistence can be skipped in Phase 3 if query history is enough, but the tab/editor should be modeled as a document-like object from the start.

### SQLStatement

```swift
struct SQLStatement: Equatable {
    var text: String
    var range: Range<String.Index>
    var lineRange: ClosedRange<Int>
    var isMultiline: Bool
    var classification: SQLStatementClassification
}
```

### SQLStatementClassification

```swift
enum SQLStatementClassification: String, Codable, Equatable {
    case readOnly
    case mutation
    case schemaChange
    case transactionControl
    case admin
    case unknown
}
```

Initial examples:

- `select`, `with`, `values`, `show`, `explain`: `readOnly`
- `insert`, `update`, `delete`, `merge`: `mutation`
- `create`, `alter`, `drop`, `truncate`: `schemaChange`
- `begin`, `commit`, `rollback`, `savepoint`: `transactionControl`
- `grant`, `revoke`, `vacuum`, `analyze`, `reindex`, `copy`: `admin`

Unknown should require confirmation when there is any safety concern.

### QueryExecutionRequest

```swift
struct QueryExecutionRequest: Sendable, Equatable {
    var id: UUID
    var connectionID: UUID
    var sql: String
    var startedAt: Date
    var previewRowLimit: Int
}
```

### QueryExecutionResponse

```swift
struct QueryExecutionResponse: Equatable {
    var requestID: UUID
    var commandTag: String?
    var columns: [QueryResultColumn]
    var rows: [QueryResultRow]
    var rowCount: Int
    var affectedRows: Int?
    var notices: [QueryNotice]
    var duration: TimeInterval
    var completedAt: Date
    var wasTruncated: Bool
}
```

### QueryResultColumn

```swift
struct QueryResultColumn: Identifiable, Equatable {
    var id: Int
    var name: String
    var dataTypeID: Int?
    var typeName: String?
}
```

### QueryResultValue

```swift
enum QueryResultValue: Equatable {
    case null
    case text(String)
    case bool(Bool)
    case int(Int64)
    case double(Double)
    case decimal(String)
    case date(String)
    case timestamp(String)
    case json(String)
    case uuid(String)
    case bytes(String)
    case raw(typeName: String?, value: String)
}
```

Phase 3 can decode many values as text/raw if `postgres-nio` type metadata is inconvenient. Phase 4 should replace this with a stronger `PostgresCellValue` model.

### QueryExecutionState

```swift
enum QueryExecutionState: Equatable {
    case idle
    case preparing
    case confirming(QueryExecutionConfirmation)
    case running(startedAt: Date)
    case succeeded(QueryExecutionResponse)
    case failed(QueryExecutionError)
    case cancelled
}
```

### QueryHistoryEntry

```swift
struct QueryHistoryEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var connectionID: UUID
    var sql: String
    var classification: SQLStatementClassification
    var startedAt: Date
    var duration: TimeInterval?
    var rowCount: Int?
    var affectedRows: Int?
    var succeeded: Bool
    var errorMessage: String?
}
```

## SQL Lexer And Active Statement Detection

### SQLLexer

The lexer should produce tokens that preserve ranges:

```swift
enum SQLTokenKind: Equatable {
    case word(String)
    case semicolon
    case whitespace
    case lineComment
    case blockComment
    case singleQuotedString
    case doubleQuotedIdentifier
    case dollarQuotedString(tag: String?)
    case symbol(Character)
    case unknown
}
```

Requirements:

- Preserve source ranges for all tokens.
- Treat semicolons inside strings/comments/dollar quotes as non-boundaries.
- Support unterminated tokens gracefully.
- Avoid throwing for ordinary malformed SQL typed in an editor.

### Active Statement Rules

When user presses `Cmd+Enter`:

1. If there is a non-empty selection, execute selection exactly.
2. Otherwise find statement containing the insertion point.
3. Statement boundaries are nearest real semicolons before/after cursor.
4. Trim leading/trailing whitespace.
5. If no statement exists, do nothing and show a subtle status message.
6. If active statement spans multiple non-empty lines, show confirmation with exact SQL.
7. If classification is mutation/schema/admin/unknown, show stronger confirmation.

### Confirmation Behavior

Confirmation should show:

- Connection display name.
- Database name.
- Classification.
- Exact SQL in monospace text.
- Primary action: `Run`
- Secondary action: `Cancel`

Stronger confirmations should be required for:

- `mutation`
- `schemaChange`
- `admin`
- `unknown`
- Any statement on a connection marked `isProduction`

Production confirmation can be basic in Phase 3, then improved during the safety/polish phase.

## Query Editor UI

### Editor Surface

`QueryEditorView` should include:

- Query tab title/header.
- Connection context.
- `Run` button with keyboard shortcut.
- `Cancel` button while running.
- Editor body.
- Bottom status/results region.

Editor requirements:

- Monospace font.
- Line numbers.
- Current line highlight.
- Syntax coloring for keywords, comments, strings, identifiers, numbers.
- Selection read/write support.
- Undo/redo should work via `NSTextView`.
- Text should not lag for normal query sizes.

### Syntax Highlighting

MVP highlighting should cover:

- Keywords.
- Comments.
- Strings.
- Dollar-quoted strings.
- Numeric literals.
- Quoted identifiers.

Avoid semantic/catalog-aware highlighting in Phase 3. Catalog-aware completion/highlighting belongs to Phase 9.

### Keyboard Commands

Initial shortcuts:

- `Cmd+T`: new query tab for selected connection.
- `Cmd+Enter`: run selection or active statement.
- `Esc`: cancel confirmation sheet; later maybe dismiss completions.

Possible later shortcuts:

- `Shift+Cmd+Enter`: run all statements.
- `Cmd+S`: save query/snippet.

Phase 3 should not overload these before UX is proven.

## Query Execution Service

### Protocol

```swift
protocol QueryExecuting {
    func execute(_ request: QueryExecutionRequest, profile: ConnectionProfile, password: String) async throws -> QueryExecutionResponse
}
```

### PostgresQueryExecutor

Responsibilities:

- Build `PostgresClient.Configuration` from `ConnectionProfile`.
- Open connection.
- Execute SQL.
- Decode columns and bounded rows.
- Capture command tag/affected count where available.
- Capture notices if `postgres-nio` exposes them cleanly.
- Close/cancel cleanly.
- Respect task cancellation.

### Cancellation

Phase 3 cancellation should:

- Cancel the Swift task.
- Stop waiting for results.
- Close the underlying client connection.
- Update UI to `cancelled`.

Server-side `pg_cancel_backend` can be deferred unless `postgres-nio` gives us a clean connection handle and backend PID cheaply. The UI must still stop waiting and release local resources.

### Execution Limits

Default MVP safeguards:

- Preview row limit: 500 or 1000.
- Query timeout: reuse or introduce a configurable default, for example 30 seconds.
- No automatic execution on tab open.
- No automatic execution of generated SQL from context menus.

## Results And Messages UI

Phase 3 result UI should be simple but honest.

### QueryExecutionStatusView

Show:

- Running spinner.
- Elapsed time.
- Connection/database.
- Cancel button.
- Success/failure state.
- Row count.
- Affected rows.

### QueryResultPreviewView

Show:

- Column headers.
- First bounded rows.
- `NULL` visibly distinct.
- Truncation notice when row limit is reached.

Implementation can use SwiftUI `Table` or simple grid/list for MVP. Do not chase full grid behavior in Phase 3.

### QueryMessagesView

Show:

- Command tag.
- Notices/warnings.
- PostgreSQL error message.
- SQLSTATE if available.
- Error position/line if available.
- Duration.

Error copy should be useful and compact.

## Query History

### QueryHistoryStore

Recommended persistence:

```text
~/Library/Application Support/DeepDrop/query-history.json
```

Phase 3 history should store:

- SQL text.
- Connection ID.
- Timestamp.
- Duration.
- Row count/affected count.
- Success/failure.
- Error message.

Do not store:

- Result row data.
- Passwords.
- Full connection URLs.

History controls:

- Append on completion/failure/cancel.
- Keep a bounded number of entries initially, for example 500 or 1000.
- Delete history on explicit future setting; not required in Phase 3.

UI:

- A simple history list or popover is optional for Phase 3 if storage is complete.
- At minimum, history should be test-covered and ready for a UI in a follow-up.

## Integration With Existing App

### AppState

Evolve app state from placeholder tabs to real query tabs:

```swift
@Observable
final class AppState {
    var selectedConnectionID: ConnectionProfile.ID?
    var selectedCatalogItem: CatalogSelection?
    var workspaceTabs: [WorkspaceTab]
    var selectedTabID: WorkspaceTab.ID?
}
```

`WorkspaceTab` should evolve to represent:

- Query tab.
- Catalog detail tab or current catalog selection.
- Future table-data tab.

Possible shape:

```swift
enum WorkspaceTabContent: Hashable, Codable {
    case query(connectionID: UUID, documentID: UUID)
    case catalogDetail(connectionID: UUID, selection: CatalogSelection)
}
```

Keep changes minimal if the current workspace can host one query editor without full tab refactor.

### ConnectionListView

Add actions:

- New Query.
- Generate `select * ... limit 100` should insert into a new query tab, not execute.

For Phase 3, context-generated SQL should be draft-only.

### DeepDropCommands

Add commands:

- New Query Tab.
- Run Query.
- Cancel Query.

Commands should route to selected workspace/editor state.

## Safety And Privacy

Never log:

- Passwords.
- Full connection URLs with credentials.
- Result row values in debug output.

History stores SQL. This is sensitive but required for a useful database client. Later settings should let users disable or clear it.

Confirmation requirements:

- Multiline active statement confirmation.
- Strong confirmation for destructive/DDL/admin/unknown statements.
- Production connection confirmation when `isProduction` is true.

No AI is involved in Phase 3.

## Testing Plan

### Unit Tests

Add tests for SQL lexing:

- Semicolons split ordinary statements.
- Semicolons inside single-quoted strings do not split.
- Semicolons inside double-quoted identifiers do not split.
- Semicolons inside line comments do not split.
- Semicolons inside block comments do not split.
- Semicolons inside dollar-quoted strings do not split.
- Tagged dollar quotes work.
- Unterminated strings/comments do not crash.

Add tests for active statement detection:

- Selection takes precedence.
- Cursor inside first/second/last statement.
- Cursor on semicolon.
- Leading/trailing whitespace trimmed.
- Empty editor returns nil.
- Multiline statement is marked multiline.

Add tests for classification:

- `select`, `with`, `show`, `explain` are read-only.
- `insert`, `update`, `delete`, `merge` are mutation.
- `create`, `alter`, `drop`, `truncate` are schema changes.
- `grant`, `revoke`, `vacuum`, `copy` are admin.
- Leading comments do not break classification.
- Unknown statements classify as unknown.

Add tests for history:

- Save/load roundtrip.
- Bounded retention.
- No result rows persisted.
- Corrupt file handling.

### UI Tests

Avoid live database dependency in normal UI tests.

Recommended UI tests:

- New query tab opens for saved connection.
- Editor accepts SQL text.
- Multiline active statement confirmation appears.
- Destructive statement confirmation appears.

Execution UI tests should use an injectable fake executor if practical. Do not require external PostgreSQL in standard UI tests.

### Integration Tests

Add opt-in tests gated by:

```text
DEEPDROP_INTEGRATION_POSTGRES_URL
```

Test:

- `select 1` succeeds.
- Syntax error surfaces a user-facing error.
- `select generate_series(1, 5)` returns rows.
- Cancellation of a long query returns cancelled state.

Do not run these by default during normal local validation unless explicitly needed.

## Build And Validation

Default validation during implementation:

- Xcode diagnostics on changed files.
- `BuildProject`.
- Targeted unit tests for SQL lexer/detector/classifier when changed.

Avoid full UI test suite unless:

- Phase completion validation.
- User explicitly asks.
- UI test files are changed in a risky way.

Manual validation against a real database:

1. Select saved connection.
2. Open new query tab.
3. Run `select 1;`.
4. Run a multiline `select` and confirm exact SQL.
5. Run selected SQL inside a larger editor buffer.
6. Run invalid SQL and inspect error.
7. Run `select pg_sleep(10);` and cancel.
8. Run `create table` or `drop table` only against a disposable database to verify confirmation.

## Meaningful Review Checkpoints

Stop for review only when the user can actually test a behavior.

### Checkpoint 1: Editor Tab And Text Editing

Deliver:

- New query tab action for selected connection.
- Native editor surface.
- Monospace styling.
- Line numbers.
- Basic syntax highlighting.

User can test:

- Open query tab.
- Type/edit SQL.
- Use undo/redo.
- Confirm editor feels acceptable for MVP.

### Checkpoint 2: Active Statement Detection

Deliver:

- SQL lexer.
- Active statement detection.
- Selection precedence.
- Multiline confirmation sheet.
- Destructive/DDL confirmation sheet.

User can test:

- Put cursor in multi-statement SQL and see exact statement selected.
- Select text and run only selected SQL.
- Confirm multiline/destructive prompts are not annoying or missing.

### Checkpoint 3: Real Query Execution

Deliver:

- `QueryExecuting` protocol.
- `PostgresQueryExecutor`.
- Run selected/active SQL with `Cmd+Enter`.
- Status and errors.

User can test:

- Run `select 1`.
- Run invalid SQL and see useful error.
- Run query against existing tables.

### Checkpoint 4: Cancellation And Messages

Deliver:

- Cancel running query.
- Elapsed time.
- Command tag/affected rows where available.
- Notices/errors/messages pane.

User can test:

- Run `select pg_sleep(10);`.
- Cancel it.
- Confirm UI returns to usable state quickly.

### Checkpoint 5: Query History And Phase 3 Validation

Deliver:

- Query history persistence.
- History tests.
- Phase 3 completion notes.
- Build validation.

User can test:

- Run several queries.
- Relaunch app.
- Confirm history is available or persisted for future UI.

## Acceptance Criteria

Phase 3 is complete when:

- User can open a query tab for a saved connection.
- User can type/edit SQL in a native editor.
- Editor has line numbers and basic syntax highlighting.
- `Cmd+Enter` runs selected SQL or active statement.
- Active statement detection handles comments, strings, semicolons, and dollar quotes.
- Multiline active statement confirmation shows exact SQL.
- Destructive/schema/admin/unknown statements require stronger confirmation.
- Real PostgreSQL execution works through saved credentials.
- Query cancellation works from the UI.
- Errors show useful PostgreSQL message details.
- Basic result preview or messages appear after execution.
- Query history is persisted without row data or secrets.
- App builds without requiring a database.
- Standard tests do not require a live database.
- Integration tests are opt-in through `DEEPDROP_INTEGRATION_POSTGRES_URL`.

## Risks And Mitigations

### Risk: Native Editor Scope Expands Too Quickly

Mitigation: keep Phase 3 editor to text, selection, line numbers, highlighting, and execution. Defer autocomplete, formatting, snippets, minimap, and advanced diagnostics.

### Risk: Active Statement Detection Is Wrong

Mitigation: invest in lexer tests early. This is core safety behavior and cheaper to test now than to debug later in UI.

### Risk: Result Grid Work Takes Over Phase 3

Mitigation: use a bounded preview and messages pane only. Phase 4 owns the real grid.

### Risk: Query Cancellation Is Not Server-Side Complete

Mitigation: Phase 3 cancellation can close the local client and stop UI waiting. Add server-side cancellation later if needed.

### Risk: Query History Stores Sensitive SQL

Mitigation: do not store result rows or secrets. Add future settings to disable/clear history. Avoid logging SQL unless the user explicitly exports it.

### Risk: `postgres-nio` Row Decoding Is Awkward For Arbitrary Queries

Mitigation: decode initial values conservatively as strings/raw values and keep the result model replaceable for Phase 4 typed decoding.

## Open Questions Before Implementation

- Should Phase 3 persist query documents, or only query history?
- Should `Cmd+Enter` always confirm multiline statements, or only multiline statements without selected text?
- Should destructive confirmation apply on non-production connections too? Recommended: yes, but lighter.
- Should generated sidebar SQL open in a new tab or append to the active tab?
- Should query timeout be global, per connection, or hardcoded for MVP?
- Should result preview limit be 500 or 1000 rows?
- Should history be visible in Phase 3 UI or only persisted for Phase 4/9?
- Should `EXPLAIN` be classified as read-only even when wrapping mutation statements? Recommended: classify plain leading `explain` as read-only for MVP, revisit later.

## Completion Notes

Implemented:

- Multiple query tabs for the same saved connection.
- Native AppKit-backed `NSTextView` editor embedded in SwiftUI.
- Monospace editing, line numbers, undo/redo, and basic PostgreSQL highlighting.
- SQL lexer for semicolons, whitespace, comments, single-quoted strings, double-quoted identifiers, and dollar-quoted strings.
- Relaxed active statement detection:
  - Selection takes precedence.
  - Semicolons split statements.
  - Blank lines split statements when semicolons are missing.
  - Cursor after a trailing semicolon falls back to the nearest real previous statement.
  - Semicolons inside strings/comments/dollar quotes do not split statements.
- Statement classification for read-only, mutation, schema, transaction, admin, and unknown statements.
- Confirmation sheet showing exact SQL before running.
- Stronger confirmation styling for mutation/schema/admin/unknown statements.
- Real read-only PostgreSQL execution through saved `ConnectionProfile` and Keychain password.
- Bounded JSON preview execution for read-only statements with a 500-row preview limit.
- Basic result preview and error display.
- Running status with elapsed time.
- Local cancellation UI with `Stop` and `Cmd+.`.
- Query history persistence in Application Support.
- Query history menu scoped to the selected connection.
- Unit tests for SQL statement classification, active statement detection, and query history storage.

Current tradeoffs:

- The editor/result/history UI is functional foundation UI, not final product design.
- Execution is intentionally limited to read-only preview queries in this phase.
- Mutation/DDL/admin execution is blocked with a clear message for now.
- Result rendering is a simple bounded preview, not a production result grid.
- Query cancellation stops the local task and ignores late responses; deeper server-side cancellation can be improved later.
- Query documents are session-only; executed SQL history persists, but open draft tabs are not restored after relaunch.
- Query history stores SQL text as expected for a database client, but stores no result rows or credentials.

Deferred:

- Full result grid with virtualization, type-aware cells, copy/export, sort/filter, and row browsing.
- Non-read-only execution with command tags/affected rows.
- Server-side cancellation using backend PID / cancel request if the driver flow supports it cleanly.
- Query document autosave and tab restoration.
- Catalog-aware autocomplete.
- SQL formatting and snippets.
- Final editor/results/history UX pass.
