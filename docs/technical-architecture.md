# DeepDrop Technical Architecture

## Architecture Goals

- Native macOS app with responsive UI.
- Clear separation between UI, database engine, AI orchestration, and persistence.
- Testable business logic outside views.
- Safe credential handling.
- Async/cancellable operations throughout.
- Replaceable components where mature native options evolve.

## Recommended Stack

Baseline:

- Swift 6+ where possible.
- SwiftUI for app shell, settings, dialogs, and ordinary views.
- AppKit/NSViewRepresentable bridges for high-performance editor/grid if SwiftUI alone is insufficient.
- Swift Concurrency for app-level async workflows.
- PostgreSQL driver: evaluate `postgres-nio` first because it is an actively maintained SwiftNIO PostgreSQL client.
- Keychain for secrets.
- SwiftData or Core Data for local metadata, connection profiles without secrets, query history, snippets, settings.

Editor options:

- MVP: native `NSTextView` with custom tokenizer/highlighter if scope must stay small.
- Better editor: Tree-sitter-backed native editor if PostgreSQL grammar integration is feasible.
- Pragmatic hybrid option: embedded web editor like Monaco/CodeMirror in `WKWebView`, but this trades native feel for mature SQL editing. Use only if native editor cost is too high.

Grid options:

- MVP: SwiftUI `Table` for small/medium datasets.
- Production: AppKit `NSTableView` or custom virtualized grid for large datasets and cell editors.

SQL parsing options:

- MVP: internal lexer for active statement boundaries and mutation detection.
- Stronger: bind to `libpg_query`, which uses PostgreSQL parser sources and returns PostgreSQL parse trees.
- Hybrid: lightweight lexer for editor responsiveness plus server `EXPLAIN`/parse validation when connected.

References checked while drafting:

- `postgres-nio`: https://github.com/vapor/postgres-nio
- `libpg_query`: https://github.com/pganalyze/libpg_query
- OpenAI Structured Outputs: https://platform.openai.com/docs/guides/structured-outputs

## Proposed Modules

### AppShell

Owns:

- Window structure.
- Navigation.
- Tabs.
- Sidebar state.
- Command palette.
- Global app commands.

Does not own:

- Database protocol details.
- AI prompts.
- Credential storage implementation.

### ConnectionManagement

Owns:

- Connection profiles.
- URL parsing.
- Validation.
- Test connection.
- Keychain credential references.
- Connection lifecycle.

Core types:

```swift
struct DatabaseConnectionProfile: Identifiable, Codable {
    var id: UUID
    var displayName: String
    var host: String
    var port: Int
    var database: String
    var username: String
    var sslMode: SSLMode
    var colorTag: ConnectionColorTag?
    var createdAt: Date
    var updatedAt: Date
}
```

Secrets live separately:

```swift
struct DatabaseCredentialRef: Codable {
    var profileID: UUID
    var keychainService: String
    var keychainAccount: String
}
```

### PostgresEngine

Owns:

- Connecting.
- Query execution.
- Transaction handling.
- Schema introspection.
- Type decoding.
- Result streaming/pagination.
- Cancellation.

Important interfaces:

```swift
protocol PostgresClient {
    func connect(profileID: UUID) async throws
    func disconnect(profileID: UUID) async
    func execute(_ request: SQLExecutionRequest) async throws -> SQLExecutionResponse
    func stream(_ request: SQLExecutionRequest) -> AsyncThrowingStream<RowBatch, Error>
    func introspect(_ request: IntrospectionRequest) async throws -> DatabaseCatalog
}
```

### SQLServices

Owns:

- SQL lexing.
- Active statement detection.
- Statement classification.
- Formatting hooks.
- Completion context extraction.
- Query templates.

Statement classification must be app-side and conservative. Unknown statements should be treated as potentially unsafe for AI auto-execution.

### CatalogStore

Owns:

- Cached database schemas.
- Table/column metadata.
- Index/constraint info.
- Cache invalidation.
- Search indexing.

Catalog data can be persisted locally but must be refreshable and scoped per connection.

### QueryWorkspace

Owns:

- Query tabs.
- Editor document state.
- Execution history.
- Result panes.
- Pending grid edits.
- Query cancellation.

### ResultGrid

Owns:

- Typed cell values.
- Virtualized grid model.
- Sorting/filtering state.
- Edit transactions.
- Copy/export formatting.

Core model:

```swift
enum PostgresCellValue: Equatable {
    case null
    case text(String)
    case integer(Int64)
    case decimal(String)
    case boolean(Bool)
    case date(DateOnlyValue)
    case time(TimeOnlyValue)
    case timestamp(Date, timeZone: TimeZone?)
    case json(String)
    case uuid(UUID)
    case bytes(Data)
    case array([PostgresCellValue])
    case raw(typeName: String, value: String)
}
```

### AIEngine

Owns:

- OpenAI client.
- Prompt construction.
- Tool definitions.
- Structured output schemas.
- AI policy enforcement.
- Request audit metadata.
- Context minimization.

AIEngine must not directly access a raw database connection. It should call a narrow tool interface that applies policy checks before executing anything.

### SettingsAndSecrets

Owns:

- User settings.
- AI key storage.
- Credential storage.
- Migration/versioning.
- Redaction utilities.

## Data Flow

### Query Execution

1. Query editor asks `SQLServices` for active statement.
2. `SQLServices` classifies statement.
3. UI asks for confirmation if multiline/destructive/production policy requires it.
4. `QueryWorkspace` creates `SQLExecutionRequest`.
5. `PostgresEngine` executes or streams rows.
6. `ResultGrid` receives typed batches.
7. Query history stores redacted metadata and SQL according to settings.

### Table Editing

1. Grid identifies table and primary key.
2. User edits cells.
3. Pending changes are represented as operations.
4. App previews SQL or operation summary.
5. Apply runs transaction.
6. On success, grid refreshes affected rows.

Generated mutations should use parameterized queries. Never build values into SQL strings for execution.

### AI Query Builder

1. User asks for query.
2. App gathers schema context, current editor selection, and optional constraints.
3. AI returns structured object: intent, SQL, explanation, risk classification.
4. App validates SQL with `SQLServices`.
5. SQL is inserted into editor or shown as draft.
6. User manually runs it.

## Persistence

Store locally:

- Connection profiles without secrets.
- Keychain references.
- UI layout preferences.
- Query history, configurable.
- Snippets.
- Catalog cache.
- AI audit metadata, configurable.

Never store in plain local database:

- Database passwords.
- OpenAI API keys.
- Full connection URLs containing passwords.

## Error Handling

Use typed errors with user-facing recovery suggestions.

Examples:

- Connection failed: host unreachable, auth failed, SSL mismatch, database missing.
- Query failed: syntax, permission, timeout, cancellation.
- Editing failed: row changed, no primary key, constraint violation.
- AI failed: missing API key, model error, policy blocked query, invalid structured output.

## Testing Strategy

Unit tests:

- Connection URL parser.
- SQL active statement detection.
- SQL mutation classifier.
- Keychain wrapper with injectable mock.
- AI policy enforcement.
- Result value decoding/formatting.

Integration tests:

- Local PostgreSQL test container or fixture database.
- Schema introspection.
- Query execution.
- CRUD transactions.
- JSON/date type roundtrips.

UI tests:

- Add connection flow.
- Open table.
- Run query.
- Edit cell and apply.
- AI disabled/enabled states.

Performance tests:

- Large catalog load.
- Large result grid scroll.
- Query cancellation responsiveness.

