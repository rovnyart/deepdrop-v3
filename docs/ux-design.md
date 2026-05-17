# DeepDrop UX And Interaction Design

## Design Direction

DeepDrop should feel native, focused, and quietly premium. The UI should not try to look like a website, dashboard template, or overloaded IDE. The target feeling is: open the app, paste a database URL, and immediately feel oriented.

Keywords: fast, calm, sharp, spatially clear, friendly, trustworthy.

Avoid:

- Dense icon soup.
- Giant card layouts for serious work surfaces.
- Decorative gradients as the main visual idea.
- Overexplaining features in the UI.
- AI surfaces that compete with SQL instead of assisting it.

## App Shell

Recommended structure:

- Left source/sidebar: connections, schemas, objects.
- Main workspace: query tabs, table data, structure views.
- Bottom/results area: result sets, messages, execution timeline.
- Optional right inspector/AI panel: context-aware details, explain, chat.

The shell should support:

- Collapsible sidebars.
- Multiple tabs per connection.
- Connection color markers.
- Command palette.
- Search-first navigation.
- Split result/editor layout.

## First Launch

First launch should show a usable connection creation surface, not a marketing page.

Primary actions:

- Paste connection URL.
- Fill manually.
- Import later, if supported.

Tone:

- Short labels.
- Helpful inline validation.
- No long paragraphs.

## Connection Form

Fields:

- Name.
- URL paste box.
- Host.
- Port.
- Database.
- User.
- Password.
- SSL mode.
- Advanced: application name, connect timeout, search path, statement timeout.

Interactions:

- Pasting into URL parses immediately.
- Parsed fields animate/update subtly.
- Conflicting manual edits are preserved unless user reparses.
- Test connection button shows progress, success, and failure details.
- Save is disabled until required fields are valid.

## Sidebar

Hierarchy:

- Connection group.
- Database.
- Schemas.
- Objects grouped by type.

Object row actions:

- Open data.
- Open structure.
- Copy qualified name.
- Generate SQL.
- Refresh.

Search:

- `Cmd+P` or command palette for global object opening.
- Sidebar search filters tables, columns, functions.
- Search results should preserve object type and schema context.

## Query Editor

The query editor is the core product surface.

Required behaviors:

- Monospace font with user setting.
- PostgreSQL highlighting.
- Line numbers.
- Current statement highlight.
- Error markers.
- Inline completion popup.
- Autocomplete triggered by typing and manually by shortcut.
- Snippets for common query patterns.
- AI suggestion ghost text only when enabled and non-disruptive.

Execution behavior:

- `Cmd+Enter`: execute active statement at cursor.
- If there is selected text, execute selection.
- If active statement is multiline, show a compact confirmation sheet with the whole SQL and `Run` / `Cancel`.
- If statement appears destructive, show stronger confirmation with affected query classification.
- Query execution status should include elapsed time, cancellable spinner, row count, and connection target.

Active statement detection must understand:

- Semicolon boundaries.
- Single-line and block comments.
- Single and double quoted strings.
- Dollar-quoted strings.
- Common PostgreSQL function bodies.

## Results Area

Each execution can produce:

- One or more grids.
- Command tags.
- Notices/warnings.
- Errors.
- Execution plan.

Result tabs should be compact and scannable:

- `Result 1`.
- `Messages`.
- `Plan`.
- `Changes`, when editing.

Grid basics:

- Sticky column headers.
- Row numbers.
- Column type hint in header.
- Resize and reorder columns.
- Sort and filter.
- Copy/export.
- Virtual scrolling.

Editing:

- Edited cells show pending state.
- Changes accumulate in a review bar: `3 edits`, `1 insert`, `2 deletes`.
- Apply and discard are always visible when pending changes exist.
- Apply runs in transaction and reports affected rows.

## Type-Specific Cell Rendering

Use subtle type cues, not noisy badges everywhere.

- `NULL`: muted pill or italic token.
- Boolean: compact checkmark/toggle.
- Numeric: right aligned.
- Date/time: formatted readable value, exact value in tooltip/inspector.
- JSON/JSONB: collapsed preview with `{}`/`[]` affordance.
- UUID: monospace and truncated middle when narrow.
- Binary: byte count and hex preview.
- Arrays: bracketed preview.

JSON editor dialog:

- Large enough to be useful.
- Syntax highlighting.
- Format/minify.
- Validate.
- Search.
- Copy path/value, later.
- AI explain/transform JSON, later and only with explicit user action.

Date/time editor:

- Calendar.
- Time field.
- Time zone clarity for `timestamptz`.
- Preserve exact database value unless user changes it.

## AI Surfaces

AI should appear in three places:

- Inline editor assistant: complete, explain, fix error, generate query.
- Right-side AI panel: chat with database.
- Contextual menus: explain cell/table/query/error.

Rules:

- AI-generated SQL is draft until user runs it.
- AI chat messages that run database tools should show the exact SQL and result summary.
- Mutations require explicit setting plus final confirmation.
- When AI is disabled, the UI should remain clean; no nagging.

## Command Palette

Early command palette entries:

- Connect to database.
- Open table.
- New query.
- Run query.
- Explain query.
- Format SQL.
- Refresh schema.
- Toggle AI chat.
- Open settings.

## Keyboard Shortcuts

Initial defaults:

- `Cmd+N`: new connection or new query depending context.
- `Cmd+T`: new query tab.
- `Cmd+Enter`: run active statement/selection.
- `Shift+Cmd+Enter`: run all or run selected block, confirm exact behavior during implementation.
- `Cmd+P`: open object/command palette.
- `Cmd+F`: find in editor or grid.
- `Cmd+S`: save query/snippet, not save database changes.
- `Cmd+,`: settings.

## Visual System Notes

- Use macOS materials sparingly.
- Prefer subtle borders and spacing over heavy cards.
- Keep table density adjustable.
- Use connection color as a safety/status marker, not decoration.
- Make destructive states red and explicit.
- Use icons where they reduce reading, but every unfamiliar icon needs a tooltip.

