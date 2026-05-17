# DeepDrop Implementation Roadmap

## Phase 0: Foundation

Goal: turn the empty Xcode project into a maintainable macOS app skeleton.

Steps:

1. Confirm app target is macOS and set minimum macOS version.
2. Establish project structure: `App`, `Features`, `Core`, `Database`, `AI`, `DesignSystem`, `Tests`.
3. Add dependency management plan.
4. Add lint/format conventions.
5. Replace template view with app shell placeholder.
6. Add lightweight design tokens: spacing, typography, colors, connection color tags.
7. Add test targets for pure logic modules.

Acceptance criteria:

- App launches to a native shell with sidebar/main area/settings entry.
- Unit tests run from Xcode/CLI.
- No database or AI dependency is required to launch.

## Phase 1: Connection Management

Goal: users can add and test PostgreSQL sources quickly.

Steps:

1. Implement connection URL parser.
2. Add connection profile model without secrets.
3. Add Keychain wrapper for database passwords.
4. Build add/edit connection UI.
5. Support paste-to-parse behavior.
6. Add test connection using chosen PostgreSQL driver.
7. Save, edit, duplicate, delete connection profiles.
8. Add connection list/sidebar.

Acceptance criteria:

- Pasted PostgreSQL URLs parse correctly.
- Passwords are stored only in Keychain.
- Test connection reports success/failure clearly.
- Parser has unit tests for URL escaping, missing port, SSL params, and invalid URLs.

## Phase 2: Database Catalog Browser

Goal: users can inspect database structure.

Steps:

1. Implement catalog introspection queries.
2. Model schemas, tables, views, columns, indexes, constraints.
3. Add lazy sidebar loading.
4. Add refresh and search.
5. Add object context menu actions.
6. Cache catalog metadata per connection.

Acceptance criteria:

- Connected database shows schemas and tables.
- Search finds objects quickly.
- Refresh updates renamed/created/dropped objects.
- Large catalogs do not freeze UI.

## Phase 3: Query Editor MVP

Goal: users can write and execute SQL comfortably.

Steps:

1. Choose editor implementation for MVP.
2. Add SQL text editor with line numbers and highlighting.
3. Implement active statement detection.
4. Implement `Cmd+Enter` execution flow.
5. Add multiline statement confirmation sheet.
6. Add execution status, cancellation, errors, notices.
7. Add query history.

Acceptance criteria:

- User can run selected SQL or active statement.
- Multiline active statement confirmation shows exact SQL.
- Query cancellation works.
- SQL parser/lexer tests cover comments, strings, semicolons, dollar quotes.

## Phase 4: Result Grid Read-Only

Goal: query and table results are useful and fast.

Steps:

1. Create typed result model.
2. Decode common PostgreSQL types.
3. Render grid with virtualized or paginated data.
4. Add sort/filter UI.
5. Add copy/export CSV/JSON.
6. Add type-aware cell display for NULL, bool, numeric, date, JSON, UUID, bytea.

Acceptance criteria:

- `select * from table limit 1000` displays quickly.
- Copying cells/rows works.
- JSON and date cells render distinctly.
- Large result sets do not block app navigation.

## Phase 5: Table CRUD

Goal: users can edit table data safely.

Steps:

1. Detect editable table result sets.
2. Identify primary keys/unique row identity.
3. Add inline cell editing.
4. Add row insert, duplicate, delete.
5. Add pending changes model.
6. Add apply/discard review bar.
7. Execute changes in transaction with parameterized SQL.
8. Handle conflicts and constraint errors.

Acceptance criteria:

- Users can update a cell and apply changes.
- Users can insert, duplicate, and delete rows.
- Multi-row delete confirms affected count.
- Tables without stable identity are read-only with a clear reason.
- CRUD tests run against local PostgreSQL fixture.

## Phase 6: Rich Type Editors

Goal: editing feels polished for real PostgreSQL data.

Steps:

1. Build JSON/JSONB editor dialog.
2. Build date/time/timestamptz editor.
3. Build enum dropdown editor.
4. Improve arrays and bytea handling.
5. Add validation before applying edits.

Acceptance criteria:

- JSON editor formats, validates, and saves valid JSON.
- Date/time editor preserves time zone semantics.
- Invalid typed values cannot be applied silently.

## Phase 7: AI Settings And Query Assistance

Goal: optional AI features become available safely.

Steps:

1. Add OpenAI API key settings with Keychain storage.
2. Add AI feature flags and safety settings.
3. Implement OpenAI client abstraction.
4. Implement structured output validation.
5. Add explain query.
6. Add AI query builder.
7. Add generated SQL validation/classification.
8. Insert AI SQL as draft into editor.

Acceptance criteria:

- AI features are hidden/disabled until key is configured.
- API key is not logged or stored outside Keychain.
- Query builder returns structured draft SQL.
- Mutation SQL is flagged and not auto-executed.

## Phase 8: Chat With Database

Goal: users can ask questions about the database in a dedicated AI panel.

Steps:

1. Build AI chat panel.
2. Add schema context retrieval.
3. Add read-only tool interface.
4. Add app-side SQL policy enforcement.
5. Add result summarization.
6. Add audit log view.
7. Add user controls for sampled data sharing.

Acceptance criteria:

- Chat can answer schema questions.
- Chat can request app-approved read-only SQL execution.
- Blocked SQL explains why it was blocked.
- Tool calls are visible enough for user trust.

## Phase 9: Editor Intelligence

Goal: query editor becomes a daily-driver tool.

Steps:

1. Add catalog-aware autocomplete.
2. Add function/keyword completions.
3. Add context-aware column suggestions.
4. Add AI ghost suggestions when enabled.
5. Add error repair suggestions.
6. Add SQL formatting.
7. Add snippets.

Acceptance criteria:

- Completion works for schema/table/column names.
- AI suggestions are debounced and dismissible.
- Editor remains responsive during suggestions.

## Phase 10: Polish, Safety, And Release Prep

Goal: app is shippable as an early private beta.

Steps:

1. Add production connection marker and confirmations.
2. Add onboarding and empty states.
3. Add crash/error reporting policy, if desired.
4. Add preference migration.
5. Performance pass on catalog, editor, grid.
6. Accessibility pass.
7. Packaging/notarization.
8. Beta feedback loop.

Acceptance criteria:

- Private beta build can connect, browse, query, edit, and use basic AI safely.
- App has no known secret logging.
- Core flows have UI tests.
- Release checklist is repeatable.

## Suggested First AI Implementation Tickets

1. `Connection URL Parser`: implement pure Swift parser and tests.
2. `Keychain Secrets Wrapper`: create injectable credential store.
3. `App Shell`: replace template UI with sidebar/workspace/settings shell.
4. `Postgres Driver Spike`: connect to local PostgreSQL and run `select 1`.
5. `Catalog Introspection Spike`: load schemas/tables/columns into models.
6. `SQL Statement Lexer`: active statement detection and mutation classification.
7. `Query Execution MVP`: editor text box, run button, result table.
8. `Result Cell Value Model`: decode and format common PostgreSQL types.
9. `AI Settings`: OpenAI API key storage and feature gating.
10. `AI Query Builder Spike`: structured SQL draft generation with local validation.

## Dependency Decision Spikes

Run these before heavy implementation:

1. PostgreSQL driver spike: `postgres-nio` vs alternatives.
2. Editor spike: native `NSTextView` vs embedded Monaco/CodeMirror vs Tree-sitter-backed custom editor.
3. Grid spike: SwiftUI `Table` vs AppKit `NSTableView` vs custom grid.
4. SQL parser spike: internal lexer vs `libpg_query` binding.
5. Persistence spike: existing Core Data template vs SwiftData migration.

Each spike should produce:

- Minimal working code.
- Performance notes.
- API ergonomics notes.
- Risks.
- Recommendation.

