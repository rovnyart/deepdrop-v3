# Phase 2 Implementation Plan: Database Catalog Browser

## Goal

Let users select a saved PostgreSQL connection and inspect database structure without writing SQL manually.

Phase 2 turns saved connection rows into useful database workspaces. A user should be able to select a connection, load schemas and database objects, search the catalog, refresh metadata, and inspect basic structure for tables/views/functions.

## Product Outcome

At the end of Phase 2, DeepDrop should support:

- Selecting a saved connection.
- Loading catalog metadata from PostgreSQL.
- Showing schemas in the sidebar.
- Showing tables, views, materialized views, functions, indexes, constraints, and extensions.
- Expanding tables/views to see columns.
- Showing object metadata in the main workspace.
- Refreshing catalog metadata.
- Searching catalog objects quickly.
- Caching catalog metadata per connection.
- Keeping the UI responsive while loading large catalogs.

## Non-Goals

Phase 2 does not include:

- Query editor execution.
- Opening table data rows.
- Result grid rendering.
- CRUD/editing.
- Full SQL autocomplete.
- AI schema chat.
- SSH tunnels.
- Cross-database support.
- Deep function/procedure source editing.
- Full dependency graph visualization.

These belong to later phases.

## Current Starting Point

Phase 1 provides:

- Saved connection profiles.
- Keychain-backed passwords.
- Real PostgreSQL test connection using `postgres-nio`.
- Sidebar list of saved connections.
- In-memory selected connection state.
- Placeholder database object rows.

Phase 2 should replace the placeholder database object section with real, lazy catalog data scoped to the selected connection.

## Key Decisions

### Connection Lifecycle

Recommended for Phase 2:

- Do not keep long-lived pooled sessions yet.
- Use short-lived `postgres-nio` connections for catalog loading and refresh.
- Keep the API compatible with a future `PostgresEngine` that can own persistent sessions.

Rationale:

- Catalog loading is read-only and bursty.
- Query execution and live session lifecycle start in Phase 3.
- Short-lived connections keep cancellation and error handling simpler.

### Catalog Cache

Recommended for Phase 2:

- Persist catalog snapshots as JSON in Application Support.
- Scope cache files by connection profile ID.
- Treat cache as best-effort and refreshable.
- Never store row data in catalog cache.

Recommended location:

```text
~/Library/Application Support/DeepDrop/CatalogCache/<connection-id>.json
```

### UI Shape

Keep the current foundation UI functional, but avoid investing in final visual polish yet.

Recommended sidebar hierarchy:

```text
Connections
  Local Database
    public
      Tables
        users
          id uuid primary key
          email text
      Views
      Materialized Views
      Functions
      Extensions
```

The main workspace should show a structure placeholder/detail view when an object is selected.

## Proposed File Structure

Add files under the app target:

```text
deepdrop/
  Database/
    PostgresConnectionFactory.swift
    PostgresConnectionSettings.swift
  Features/
    Catalog/
      CatalogModels.swift
      CatalogIntrospectionService.swift
      CatalogRepository.swift
      CatalogCacheStore.swift
      CatalogSidebarView.swift
      CatalogSearch.swift
      CatalogObjectDetailView.swift
      CatalogLoadingState.swift
      CatalogObjectActions.swift
```

Tests:

```text
deepdropTests/
  CatalogModelTests.swift
  CatalogSearchTests.swift
  CatalogCacheStoreTests.swift
  CatalogRepositoryTests.swift
```

Optional integration tests:

```text
deepdropTests/
  CatalogIntrospectionIntegrationTests.swift
```

## Catalog Domain Model

### DatabaseCatalog

```swift
struct DatabaseCatalog: Codable, Equatable {
    var connectionID: UUID
    var databaseName: String
    var loadedAt: Date
    var schemas: [DatabaseSchema]
    var extensions: [DatabaseExtension]
}
```

### DatabaseSchema

```swift
struct DatabaseSchema: Identifiable, Codable, Equatable {
    var id: String { name }
    var name: String
    var owner: String?
    var tables: [DatabaseTable]
    var views: [DatabaseView]
    var materializedViews: [DatabaseView]
    var functions: [DatabaseFunction]
}
```

### DatabaseTable

```swift
struct DatabaseTable: Identifiable, Codable, Equatable {
    var id: String { "\(schema).\(name)" }
    var schema: String
    var name: String
    var kind: CatalogRelationKind
    var owner: String?
    var estimatedRowCount: Int64?
    var comment: String?
    var columns: [DatabaseColumn]
    var indexes: [DatabaseIndex]
    var constraints: [DatabaseConstraint]
}
```

### DatabaseColumn

```swift
struct DatabaseColumn: Identifiable, Codable, Equatable {
    var id: String { "\(schema).\(table).\(name)" }
    var schema: String
    var table: String
    var name: String
    var ordinal: Int
    var typeName: String
    var isNullable: Bool
    var defaultExpression: String?
    var isPrimaryKey: Bool
    var isForeignKey: Bool
    var comment: String?
}
```

### Other Models

```swift
enum CatalogRelationKind: String, Codable {
    case table
    case view
    case materializedView
}

struct DatabaseIndex: Identifiable, Codable, Equatable {
    var id: String
    var schema: String
    var table: String
    var name: String
    var definition: String
    var isUnique: Bool
    var isPrimary: Bool
}

struct DatabaseConstraint: Identifiable, Codable, Equatable {
    var id: String
    var schema: String
    var table: String
    var name: String
    var type: DatabaseConstraintType
    var definition: String
}

enum DatabaseConstraintType: String, Codable {
    case primaryKey
    case foreignKey
    case unique
    case check
    case exclusion
    case unknown
}

struct DatabaseFunction: Identifiable, Codable, Equatable {
    var id: String
    var schema: String
    var name: String
    var arguments: String
    var returnType: String
    var language: String?
}

struct DatabaseExtension: Identifiable, Codable, Equatable {
    var id: String { name }
    var name: String
    var version: String?
    var schema: String?
}
```

## Introspection Queries

Use PostgreSQL catalog views rather than information schema where PostgreSQL-specific metadata is needed.

### Schemas

Load non-system schemas by default:

```sql
select
  n.nspname as schema_name,
  pg_catalog.pg_get_userbyid(n.nspowner) as owner
from pg_catalog.pg_namespace n
where n.nspname not like 'pg_%'
  and n.nspname <> 'information_schema'
order by n.nspname;
```

System schemas can be hidden by default and exposed later by a setting.

### Relations

Load tables, views, and materialized views:

```sql
select
  n.nspname as schema_name,
  c.relname as relation_name,
  c.relkind,
  pg_catalog.pg_get_userbyid(c.relowner) as owner,
  c.reltuples::bigint as estimated_row_count,
  obj_description(c.oid, 'pg_class') as comment
from pg_catalog.pg_class c
join pg_catalog.pg_namespace n on n.oid = c.relnamespace
where n.nspname not like 'pg_%'
  and n.nspname <> 'information_schema'
  and c.relkind in ('r', 'p', 'v', 'm')
order by n.nspname, c.relkind, c.relname;
```

Map:

- `r`: table
- `p`: partitioned table
- `v`: view
- `m`: materialized view

### Columns

```sql
select
  n.nspname as schema_name,
  c.relname as table_name,
  a.attname as column_name,
  a.attnum as ordinal,
  pg_catalog.format_type(a.atttypid, a.atttypmod) as type_name,
  not a.attnotnull as is_nullable,
  pg_get_expr(ad.adbin, ad.adrelid) as default_expression,
  col_description(a.attrelid, a.attnum) as comment
from pg_catalog.pg_attribute a
join pg_catalog.pg_class c on c.oid = a.attrelid
join pg_catalog.pg_namespace n on n.oid = c.relnamespace
left join pg_catalog.pg_attrdef ad on ad.adrelid = a.attrelid and ad.adnum = a.attnum
where a.attnum > 0
  and not a.attisdropped
  and n.nspname not like 'pg_%'
  and n.nspname <> 'information_schema'
  and c.relkind in ('r', 'p', 'v', 'm')
order by n.nspname, c.relname, a.attnum;
```

### Indexes

```sql
select
  schemaname as schema_name,
  tablename as table_name,
  indexname as index_name,
  indexdef as definition
from pg_catalog.pg_indexes
where schemaname not like 'pg_%'
  and schemaname <> 'information_schema'
order by schemaname, tablename, indexname;
```

Derive `isUnique` and `isPrimary` conservatively from `indexdef` initially, or use `pg_index` for stronger metadata.

### Constraints

```sql
select
  n.nspname as schema_name,
  c.relname as table_name,
  con.conname as constraint_name,
  con.contype,
  pg_get_constraintdef(con.oid) as definition
from pg_catalog.pg_constraint con
join pg_catalog.pg_class c on c.oid = con.conrelid
join pg_catalog.pg_namespace n on n.oid = c.relnamespace
where n.nspname not like 'pg_%'
  and n.nspname <> 'information_schema'
order by n.nspname, c.relname, con.conname;
```

Map:

- `p`: primary key
- `f`: foreign key
- `u`: unique
- `c`: check
- `x`: exclusion

### Functions

```sql
select
  n.nspname as schema_name,
  p.proname as function_name,
  pg_get_function_arguments(p.oid) as arguments,
  pg_get_function_result(p.oid) as return_type,
  l.lanname as language
from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n on n.oid = p.pronamespace
left join pg_catalog.pg_language l on l.oid = p.prolang
where n.nspname not like 'pg_%'
  and n.nspname <> 'information_schema'
order by n.nspname, p.proname, arguments;
```

### Extensions

```sql
select
  e.extname as name,
  e.extversion as version,
  n.nspname as schema_name
from pg_catalog.pg_extension e
left join pg_catalog.pg_namespace n on n.oid = e.extnamespace
order by e.extname;
```

## Service Design

### CatalogIntrospectionService

```swift
protocol CatalogIntrospecting {
    func loadCatalog(for profile: ConnectionProfile, password: String) async throws -> DatabaseCatalog
}
```

Implementation:

- Build connection settings from `ConnectionProfile`.
- Connect with `postgres-nio`.
- Execute introspection queries.
- Decode rows into intermediate records.
- Assemble normalized `DatabaseCatalog`.
- Close/cancel connection cleanly.

Use one connection per load operation.

### CatalogRepository

```swift
@MainActor
@Observable
final class CatalogRepository {
    private(set) var catalogByConnectionID: [UUID: DatabaseCatalog]
    private(set) var loadingStateByConnectionID: [UUID: CatalogLoadingState]

    func loadCatalog(for profile: ConnectionProfile, forceRefresh: Bool = false) async
    func refreshCatalog(for profile: ConnectionProfile) async
    func clearCatalog(for connectionID: UUID)
}
```

Repository responsibilities:

- Load cached catalog first, if present.
- Start async refresh when requested.
- Track loading/error/loaded state per connection.
- Avoid duplicate simultaneous loads for the same connection.
- Save successful refreshes to cache.
- Surface user-facing errors.

### CatalogLoadingState

```swift
enum CatalogLoadingState: Equatable {
    case idle
    case loading
    case loaded(Date)
    case failed(String)
}
```

## UI Plan

### Sidebar

Replace placeholder `Database Objects` rows with real catalog content.

Connection row states:

- Not selected.
- Selected, catalog not loaded.
- Loading.
- Loaded.
- Failed.

Required UI:

- Disclosure for connection.
- Schemas under selected connection.
- Object groups under each schema.
- Columns under each table/view.
- Refresh button for selected connection.
- Search field at top of sidebar.

Initial row actions:

- Connection row:
  - Edit.
  - Duplicate.
  - Delete.
  - Refresh Catalog.
- Table/view row:
  - Open Structure.
  - Copy Name.
  - Copy Qualified Name.
  - Generate `select * from schema.table limit 100;`
- Column row:
  - Copy Name.
  - Copy Qualified Name.

Context menus are acceptable for Phase 2, but object selection should work with normal clicks.

### Main Workspace

When selecting an object:

- Schema: show schema summary.
- Table/view/materialized view: show structure detail.
- Column: show column detail.
- Function: show signature and return type.
- Extension: show version/schema.

Create `CatalogObjectDetailView` with compact sections:

- Header: object name, type, schema.
- Columns table for tables/views.
- Indexes.
- Constraints.
- Metadata.

Do not render row data yet.

### Search

Add sidebar search for:

- Schemas.
- Tables.
- Views.
- Materialized views.
- Columns.
- Functions.
- Extensions.

Search behavior:

- Case-insensitive.
- Matches qualified names.
- Keeps object type visible.
- Debounced only if needed; local catalog search should be immediate.

Use a pure Swift `CatalogSearch` service:

```swift
struct CatalogSearch {
    func results(in catalog: DatabaseCatalog, matching query: String) -> [CatalogSearchResult]
}
```

## App State Integration

Evolve `AppState`:

```swift
struct AppState {
    var selectedConnectionID: ConnectionProfile.ID?
    var selectedCatalogItem: CatalogSelection?
    var workspaceTabs: [WorkspaceTab]
    var selectedTabID: WorkspaceTab.ID?
}
```

Add:

```swift
enum CatalogSelection: Hashable {
    case schema(connectionID: UUID, schema: String)
    case table(connectionID: UUID, schema: String, name: String)
    case view(connectionID: UUID, schema: String, name: String)
    case materializedView(connectionID: UUID, schema: String, name: String)
    case column(connectionID: UUID, schema: String, table: String, name: String)
    case function(connectionID: UUID, schema: String, name: String, arguments: String)
    case extension(connectionID: UUID, name: String)
}
```

Keep `ConnectionProfileRepository` separate from `CatalogRepository`.

## Caching Plan

### CatalogCacheStore

```swift
protocol CatalogCacheStore {
    func loadCatalog(connectionID: UUID) throws -> DatabaseCatalog?
    func saveCatalog(_ catalog: DatabaseCatalog) throws
    func deleteCatalog(connectionID: UUID) throws
}
```

Use JSON initially.

Cache invalidation:

- Refresh button always reloads from database.
- Selecting a connection loads cache first, then may offer refresh.
- Deleting a connection should delete its catalog cache.
- Future: TTL or stale indicator.

## Performance Requirements

Phase 2 should handle thousands of objects without freezing.

Implementation requirements:

- Introspection runs off the main actor.
- UI state updates happen on main actor.
- Loading can be cancelled when switching connections.
- Search operates on already-loaded in-memory catalog.
- Use lazy UI containers for trees/lists.
- Avoid rebuilding large flattened arrays on every render unless cached.

## Error Handling

User-facing errors:

- Missing password in Keychain.
- Connection failed.
- Permission denied for catalog queries.
- Query timeout.
- Cancelled refresh.
- Cache decode failed.

Error display:

- Inline row state in sidebar.
- Retry/Refresh affordance.
- Do not block the whole app.
- Do not log passwords or connection URLs.

## Security And Privacy

Catalog cache may store:

- Schema names.
- Table/view/function names.
- Column names/types/default expressions.
- Index/constraint definitions.
- Comments.

Catalog cache must not store:

- Database password.
- Full connection URL.
- Table row data.
- Query history.

Users should eventually be able to clear cached metadata, but a simple delete-on-connection-delete is enough for Phase 2.

## Testing Plan

### Unit Tests

Add tests for:

- Catalog model identity stability.
- Relation kind mapping.
- Constraint type mapping.
- Catalog assembly from unordered query rows.
- Search by table name.
- Search by qualified table name.
- Search by column name.
- Search is case-insensitive.
- Cache save/load roundtrip.
- Cache delete.
- Repository does not refresh twice concurrently for same connection.

### UI Tests

Use isolated connection/profile storage as in Phase 1.

Recommended UI tests:

- Saved connection appears.
- Selecting connection shows catalog loading affordance.
- Failed load shows retry state when password/connection is invalid.
- Search filters loaded mock catalog.

Avoid requiring a live external database in standard UI tests.

### Integration Tests

Add optional integration tests against a local PostgreSQL fixture if available.

Test:

- Load schemas.
- Load tables.
- Load columns.
- Load indexes.
- Load constraints.
- Load functions.
- Load extensions.

These tests should be opt-in through environment variables:

```text
DEEPDROP_INTEGRATION_POSTGRES_URL
```

If the environment variable is absent, skip integration tests.

## Build And Validation

Validation points:

1. Catalog models compile and unit tests pass.
2. Cache roundtrip works.
3. Introspection service loads a real database catalog.
4. Sidebar renders loaded catalog.
5. Search works on loaded catalog.
6. Refresh updates changed metadata.
7. Build succeeds with no database required to launch.

Use:

- Xcode diagnostics on changed Swift files.
- `BuildProject`.
- Manual test against the known working PostgreSQL connection from Phase 1.
- Optional integration test when `DEEPDROP_INTEGRATION_POSTGRES_URL` is set.

## Meaningful Review Checkpoints

Stop for review after each checkpoint.

### Checkpoint 1: Catalog Models And Cache

Deliver:

- Catalog model types.
- Catalog cache store.
- Search service shell.
- Unit tests for identity/cache/search basics.

User can review:

- Data model shape.
- Cache location.
- Naming and object hierarchy.

### Checkpoint 2: Introspection Service

Deliver:

- `CatalogIntrospectionService`.
- PostgreSQL catalog queries.
- Optional integration test using a real database URL.

User can review:

- Whether real schemas/tables/columns load correctly.
- Error handling for invalid credentials/permissions.

### Checkpoint 3: Sidebar Catalog Tree

Deliver:

- Selecting a saved connection loads catalog.
- Sidebar shows schemas/object groups/tables/columns.
- Loading/error/refresh states.

User can review:

- Core browsing workflow.
- Responsiveness.
- Sidebar hierarchy.

### Checkpoint 4: Search And Object Details

Deliver:

- Sidebar search.
- Main workspace structure detail view.
- Copy name / copy qualified name actions.

User can review:

- Search usefulness.
- Detail layout.
- Object action behavior.

### Checkpoint 5: Phase 2 Validation

Deliver:

- Tests.
- Build validation.
- Updated Phase 2 completion notes.

User can review:

- Acceptance criteria before commit/push.

## Acceptance Criteria

Phase 2 is complete when:

- Selecting a saved connection can load real catalog metadata.
- Loaded catalog shows schemas and tables in the sidebar.
- Tables/views can reveal columns.
- Workspace can show basic object structure.
- Catalog refresh works.
- Search finds schemas, tables, columns, functions, and extensions.
- Catalog metadata is cached per connection.
- Deleting a connection removes its catalog cache.
- Large catalogs do not freeze the UI during loading/search.
- App still launches without requiring a database.
- Unit tests cover catalog models, search, cache, and repository behavior.
- Optional integration test can load a real PostgreSQL catalog when configured.

## Risks And Mitigations

### Risk: Large Catalogs Freeze SwiftUI

Mitigation: use lazy disclosure groups/lists, keep search results separate, and avoid expanding everything by default.

### Risk: Introspection Queries Miss PostgreSQL Edge Cases

Mitigation: start with robust `pg_catalog` queries, keep model extensible, and add tests against representative databases.

### Risk: Cache Becomes Stale

Mitigation: make refresh obvious and show `loadedAt`. Treat cache as a fast starting point, not source of truth.

### Risk: Permission-Limited Users Fail Catalog Queries

Mitigation: load partial metadata where possible and show per-load errors instead of crashing the whole browser.

### Risk: Sidebar UX Becomes Crowded

Mitigation: keep object groups collapsed by default, add search, and defer final visual polish until the catalog data model is stable.

## Open Questions Before Implementation

- Should system schemas be hidden by default with a later toggle?
- Should cache load immediately on selection, or only after first successful live load?
- Should selecting a connection auto-refresh catalog, or require explicit refresh after showing cache?
- Should table row count use estimates only, or run exact counts on demand later?
- Should functions be grouped by overloaded name or listed by full signature?
- Should object actions be visible buttons now, or remain context menus until the UX pass?

## Completion Notes

Implemented:

- Catalog domain models for schemas, relations, columns, indexes, constraints, functions, and extensions.
- Live PostgreSQL introspection through `postgres-nio`.
- Sidebar catalog tree for schemas, tables, views, materialized views, columns, functions, and extensions.
- Catalog loading/error states.
- Manual catalog refresh.
- JSON catalog cache scoped by connection ID.
- Cache-first loading with a 15-minute freshness window.
- Stale cache refreshes in the background while cached data remains visible.
- Catalog search for schemas, relations, columns, functions, and extensions.
- Workspace structure detail view for selected catalog objects.
- Context-menu copy actions for catalog names, qualified names, and generated `select * ... limit 100` SQL.
- Delete-connection cleanup of catalog cache.
- Unit tests for search, cache, and repository freshness behavior.
- Optional integration test gated by `DEEPDROP_INTEGRATION_POSTGRES_URL`.
- UI test catalog cache isolation through `DEEPDROP_CATALOG_CACHE_DIR`.

Current tradeoffs:

- Catalog UI is functional and temporary; final sidebar and detail design should be revisited in a dedicated UX pass.
- System schemas are hidden by default.
- Table row counts use PostgreSQL estimates, not exact counts.
- Index primary-key detection is conservative for the initial implementation.
- Object actions are still context-menu based.
- SSL certificate verification remains limited by Phase 1's missing advanced SSL configuration UI.

Deferred:

- Opening table row data.
- Query editor integration for generated SQL.
- Rich object action toolbar/buttons.
- Exact row counts on demand.
- System schema visibility setting.
- Catalog-aware SQL autocomplete.
- Dependency graph or relationship visualization.
