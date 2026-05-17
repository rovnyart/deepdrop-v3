# DeepDrop PRD

## Summary

DeepDrop is a native macOS PostgreSQL client for developers, analysts, founders, and AI-assisted builders who want the power of tools like DataGrip, DBeaver, Postico, and TablePlus without their visual weight. It should feel fast, modern, and approachable while still supporting serious database work: connections, schema browsing, SQL editing, result exploration, CRUD, exports, and optional AI workflows.

The first version should prioritize excellent core database-client behavior. AI features should be useful but conservative: query explanation, query generation, autocomplete suggestions, and a separate database chat surface that can inspect schema and run read-only queries by default.

## Goals

- Provide a beautiful, minimal, high-performance PostgreSQL client for macOS.
- Make adding a database source as quick as pasting a connection string.
- Build a query editor that feels precise, smart, and safe.
- Support table browsing and result-grid CRUD for common PostgreSQL workflows.
- Add OpenAI-powered features that improve productivity without surprising the user.
- Treat credentials, API keys, query history, and database content as sensitive.

## Non-Goals For MVP

- Multi-database support beyond PostgreSQL.
- Full IDE parity with DataGrip on day one.
- Team collaboration, shared workspaces, cloud sync, or hosted accounts.
- Autonomous AI agents that modify production databases.
- Visual dashboard/report builder.
- Mobile or iPad support.

## Target Users

### Primary: Productive Developer

Works with local, staging, and production PostgreSQL databases. Wants fast query execution, keyboard shortcuts, schema navigation, result editing, and a clean UI that does not fight them.

### Secondary: AI-Assisted Builder

May not be a SQL expert. Wants to ask questions, generate queries, understand errors, and safely inspect data.

### Secondary: Analyst / Operator

Uses tables and filters more than raw SQL. Needs sorting, editing, exporting, JSON/date handling, and confidence around destructive operations.

## Product Positioning

DeepDrop should sit between:

- Postico: lightweight, native, delightful connection flow.
- TablePlus: polished, fast, friendly.
- DataGrip: powerful SQL editor, schema insight, keyboard workflow.
- DBeaver: broad CRUD/table utility.

The differentiator is a native, restrained, 2026-feeling macOS experience with integrated AI that is helpful but never reckless.

## Core User Journeys

### Add Database Source

1. User clicks `+` or uses `Cmd+N`.
2. User pastes a PostgreSQL connection string.
3. App parses host, port, database, user, password, SSL mode, and extras.
4. User can edit fields manually.
5. App offers `Test Connection`.
6. On success, app saves the source securely and opens the workspace.

Acceptance criteria:

- Supports `postgres://` and `postgresql://` URLs.
- Passwords with URL escaping parse correctly.
- Missing optional values get sensible defaults: port `5432`, SSL preference configurable.
- Credentials are stored in Keychain, not plain Core Data/UserDefaults.
- Failed connections produce useful, human-readable errors.

### Explore Database

1. User selects a saved source.
2. App connects and loads schemas.
3. Sidebar shows schemas, tables, views, materialized views, functions, and extensions progressively.
4. User opens a table to view rows.
5. User can inspect columns, types, indexes, constraints, foreign keys, and row counts.

Acceptance criteria:

- Schema loading is cancellable and does not block UI.
- Large databases remain usable through lazy loading and search.
- Sidebar search can find tables/columns quickly.

### Write And Run SQL

1. User opens query tab.
2. Editor provides syntax highlighting, line numbers, selection behavior, and PostgreSQL-aware completion.
3. `Cmd+Enter` executes the active statement.
4. If the active statement spans multiple lines, the app previews the statement and asks for confirmation before execution.
5. Results appear in a grid with duration, row count, and notices/errors.

Acceptance criteria:

- Active statement detection handles semicolons, comments, strings, dollar-quoted functions, and current cursor position.
- Query execution can be cancelled.
- Multiple result sets are represented clearly.
- Errors show line/column when PostgreSQL provides them.

### Browse And Edit Result Grid

1. User opens a table or runs an editable query.
2. Grid virtualizes rows/columns for performance.
3. User edits cells with type-aware editors.
4. User inserts, duplicates, deletes, or updates rows.
5. App previews pending changes and applies them in a transaction.

Acceptance criteria:

- Editing requires a stable row identity, preferably primary key.
- No silent destructive actions.
- Multi-row delete has confirmation and affected-row count.
- Unsupported editable queries are read-only with a clear reason.
- NULL, empty string, default value, and unchanged value are visually distinct enough.

### Use AI Features

1. User opens settings and enters an OpenAI API key.
2. App validates and stores the key securely.
3. AI actions become available: explain query, generate query, autocomplete, chat with database.
4. By default, AI can only propose SQL and run read-only inspection queries through app-controlled tools.
5. Mutation execution by AI is disabled unless user explicitly enables it.

Acceptance criteria:

- AI key is stored in Keychain.
- User can see and control what schema/query/data context is sent.
- AI-generated SQL is shown before execution.
- Default policy blocks `INSERT`, `UPDATE`, `DELETE`, `MERGE`, `TRUNCATE`, `DROP`, `ALTER`, `CREATE`, `GRANT`, `REVOKE`, `VACUUM`, and other mutation/DDL/admin operations.
- Mutation setting is per profile or global with explicit warning copy.

## Functional Requirements

### Connections

- Create, edit, duplicate, delete saved connections.
- Parse connection URLs.
- Manual connection form.
- Test connection.
- SSL mode support.
- Optional SSH tunnel support after MVP.
- Favorites, groups, recent connections.
- Per-connection color/accent marker to avoid production mistakes.

### Schema Browser

- Schemas, tables, views, materialized views, functions, indexes, triggers, extensions.
- Fast search.
- Context menus: open data, open structure, copy name, copy qualified name, generate select, generate insert/update/delete template.
- Metadata cache with refresh.

### Query Editor

- PostgreSQL syntax highlighting.
- Line numbers and current-line highlight.
- Multi-tab query workspace.
- Active statement detection.
- `Cmd+Enter`: run active statement.
- `Shift+Cmd+Enter`: run selection or all statements.
- Autocomplete for schemas, tables, columns, functions, keywords.
- AI suggestions when enabled.
- Query history.
- Saved snippets.
- Explain/analyze helpers.
- Cancellation.
- Error annotations.

### Result Grid

- Virtualized rendering.
- Sort and filter.
- Column resize/reorder/hide.
- Copy cells/rows as TSV, CSV, JSON, SQL inserts.
- Export CSV/JSON.
- Inline editing.
- Type-aware rendering and editing:
  - Text/varchar: text editor with expansion.
  - Numeric: numeric validation.
  - Boolean: checkbox/segmented toggle.
  - Date/time/timestamptz: calendar/time editor.
  - JSON/JSONB: formatted editor with syntax highlighting and validation.
  - Arrays: structured text editor initially, richer editor later.
  - UUID: monospace, copy affordance.
  - Bytea: hex preview and save/open affordance.
  - Enum: dropdown.
  - Geometric/network/range types: readable text initially, specialized later.

### AI

- Settings for OpenAI API key.
- Model selector with sensible default and explicit advanced section.
- Explain selected query/result/error.
- Generate SQL from natural language using schema context.
- Chat with database in a dedicated panel.
- AI autocomplete/suggestions in editor.
- Read-only default tool policy.
- Mutation opt-in.
- Prompt and tool-call audit log.
- Per-request context preview.

### Settings

- General: appearance, font, editor behavior.
- Connections: saved sources and credential reset.
- AI: API key, model, context sharing, mutation policy.
- Safety: production connection confirmations, destructive query confirmations.
- Keyboard shortcuts, eventually.

## UX Requirements

- Native macOS feel with modern polish.
- Minimal chrome; avoid giant toolbars.
- Fast keyboard-first workflow.
- Clear empty states.
- No marketing-style landing page inside the app.
- Smooth transitions, not flashy animation.
- Strong visual distinction for production or dangerous contexts.
- Friendly copy without being cutesy.

## Performance Requirements

- App launch to usable shell under 1 second on modern Apple Silicon after cold start target is optimized.
- Connection list renders instantly for hundreds of saved sources.
- Schema browser handles thousands of tables via lazy loading/search.
- Result grid handles 100k+ fetched rows through pagination/streaming/virtualization.
- Query execution and schema loading must be cancellable.
- AI requests must never block query execution or UI navigation.

## Security And Privacy Requirements

- Store database passwords and OpenAI API keys in Keychain.
- Never log secrets.
- Avoid sending raw table data to AI unless user explicitly requests an operation requiring it.
- Default AI context should prefer schema metadata, query text, and small sampled/result summaries.
- Provide user-visible controls for data sharing.
- Mutation and destructive operations require app-side validation, not only prompt instructions.

## Success Metrics

- Time to first successful connection under 60 seconds for a new user with a connection URL.
- Query editor perceived latency below noticeable threshold for common editing.
- Result grid scrolling remains smooth for large tables.
- AI-generated SQL acceptance rate improves over time without safety incidents.
- Zero known credential leakage in logs, crashes, or analytics.

## Open Questions

- Should DeepDrop ship via Mac App Store, direct download, or both?
- Should the first app architecture be pure SwiftUI, SwiftUI plus AppKit bridges, or AppKit-heavy for editor/grid?
- Should SQL parsing use embedded PostgreSQL parser bindings, an incremental editor parser, or a hybrid?
- Which license/commercial model is desired?
- How soon should SSH tunnels and cloud secret integrations arrive?

