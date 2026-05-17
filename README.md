# DeepDrop

DeepDrop is a native macOS PostgreSQL client built with SwiftUI. It is focused on fast connection management, database catalog browsing, and a lightweight query editor workflow.

## Current Capabilities

- Store and manage PostgreSQL connection profiles.
- Validate connection details and test database connectivity.
- Browse cached database catalog metadata for schemas, tables, views, and columns.
- Search catalog objects.
- Open multiple query editor tabs per connection.
- Detect the SQL statement at the cursor.
- Run read-only query previews and inspect result rows.
- Keep local query history for reuse.

## Project Layout

- `deepdrop/App`: app shell, commands, and window restoration.
- `deepdrop/Core`: shared app state.
- `deepdrop/DesignSystem`: colors, spacing, typography, and visual helpers.
- `deepdrop/Features/Connections`: connection profile UI, validation, storage, and testing.
- `deepdrop/Features/Catalog`: catalog introspection, caching, search, and detail views.
- `deepdrop/Features/QueryEditor`: query documents, editor UI, SQL detection, execution, and history.
- `deepdrop/Features/Results`: query result preview UI.
- `deepdrop/Security`: credential storage.
- `deepdropTests`: unit and integration-oriented tests.

## Development Notes

The app is currently under active phased development. Phase 3 adds the query editor MVP: editable SQL tabs, relaxed statement detection, read-only execution previews, result display, elapsed-time feedback, and query history.

For validation, prefer Xcode builds and focused unit tests over broad test runs while the macOS UI and integration tests are still evolving.
