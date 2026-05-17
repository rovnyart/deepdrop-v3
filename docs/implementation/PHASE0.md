# Phase 0 Implementation Plan: Foundation

## Goal

Turn the default Xcode template into a maintainable native macOS application skeleton for DeepDrop.

Phase 0 should not connect to PostgreSQL, store real credentials, call AI APIs, or implement a query engine. Its job is to establish the app structure, visual foundation, navigation model, and testable seams that later phases can build on safely.

## Product Outcome

At the end of Phase 0, launching DeepDrop should show a native macOS shell that feels like the beginning of a database client rather than a template app.

The shell should include:

- A left sidebar for connections and database objects.
- A main workspace area for query tabs, table views, or empty states.
- A status/results region placeholder.
- A settings entry point.
- A first-launch connection empty state.
- No dependency on a real database or AI configuration.

## Non-Goals

Phase 0 explicitly does not include:

- PostgreSQL driver integration.
- Connection URL parsing.
- Keychain storage.
- Saved connection persistence beyond placeholder sample state.
- Schema introspection.
- Query editor implementation beyond a static placeholder.
- Result grid implementation beyond a static placeholder.
- AI settings or OpenAI integration.
- CRUD, export, command palette, or keyboard command completeness.

These belong to later phases.

## Current Starting Point

The project is currently the default Core Data SwiftUI template:

- `deepdrop/ContentView.swift` displays sample timestamp items.
- `deepdrop/deepdropApp.swift` injects `PersistenceController`.
- `deepdrop/Persistence.swift` contains template Core Data setup.
- `deepdrop.xcdatamodeld` contains the template `Item` entity.

Phase 0 should either remove template UI usage or isolate it so no sample item behavior appears in the product shell.

## Proposed File Structure

Create a feature-oriented structure under the app target:

```text
deepdrop/
  App/
    DeepDropAppShell.swift
    DeepDropCommands.swift
  DesignSystem/
    DeepDropColors.swift
    DeepDropSpacing.swift
    DeepDropTypography.swift
    ConnectionColorTag.swift
  Features/
    Connections/
      ConnectionListView.swift
      ConnectionEmptyStateView.swift
      ConnectionProfile.swift
    Workspace/
      WorkspaceView.swift
      WorkspaceTab.swift
      WorkspacePlaceholderView.swift
    Results/
      ResultsPlaceholderView.swift
    Settings/
      SettingsView.swift
  Core/
    AppState.swift
```

Keep `ContentView.swift` as the root integration view for now, or replace it with a very small wrapper that renders `DeepDropAppShell`.

Recommended Phase 0 root:

```swift
struct ContentView: View {
    var body: some View {
        DeepDropAppShell()
    }
}
```

## Architecture Decisions

### SwiftUI App Shell

Use SwiftUI for Phase 0. It is appropriate for the shell, sidebar, empty states, settings, and layout scaffolding.

Do not introduce AppKit bridges in Phase 0. The query editor and result grid may need AppKit later, but adding bridges now would create complexity before the editor/grid requirements are active.

### Keep Persistence Dormant

The current Core Data stack can remain in the project during Phase 0, but product UI should not depend on the template `Item` entity.

Recommended approach:

- Stop using `@FetchRequest` in `ContentView`.
- Keep `PersistenceController` untouched unless the project fails to build.
- Defer the Core Data vs SwiftData decision to the Phase 0 persistence spike or Phase 1 planning.

### App State

Introduce a lightweight app state object only if it simplifies the shell.

Example responsibilities:

- Selected sidebar item.
- Open workspace tabs.
- Active tab.
- Whether settings are visible.
- Placeholder connection list state.

Avoid persistence, database lifecycle, or AI settings in Phase 0 state.

## UI Scope

### Sidebar

The sidebar should establish the future hierarchy without pretending to be functional.

Required sections:

- Connections.
- Recent or sample placeholder area.
- Optional database objects placeholder shown only after a mock selected connection.

Required controls:

- Add connection button.
- Settings button or menu affordance.
- Search field placeholder if it can be added cleanly.

The add connection button may open a non-functional placeholder sheet or keep focus on the empty state. Full connection creation starts in Phase 1.

### Main Workspace

The workspace should communicate the intended product surface:

- Empty state when no connection exists.
- Query workspace placeholder.
- Results placeholder.
- Compact top bar for active context.

The first screen must be the usable connection starting point, not marketing copy.

Primary action:

- Add Database Source.

Secondary action:

- Paste Connection URL placeholder, disabled or presented as coming in Phase 1 only if necessary.

Avoid long explanatory paragraphs.

### Results Region

Add a bottom area placeholder so future query execution has an obvious home.

It should show compact inactive states such as:

- `Results`
- `Messages`
- `No query has been run`

Do not build a table/grid yet.

### Settings

Add a minimal settings surface with sections that map to future settings:

- General.
- Connections.
- AI.
- Safety.

Phase 0 settings should be mostly static placeholders. Do not add API key fields or fake credential behavior yet.

## Visual System

Create lightweight design tokens instead of scattering literal values.

### Spacing

Define common spacing constants:

- `xs`
- `sm`
- `md`
- `lg`
- `xl`

Use these in the shell and placeholder views.

### Typography

Use system fonts with clear roles:

- Sidebar labels.
- Workspace title.
- Metadata/status text.
- Monospace placeholder for future SQL surfaces.

Do not create custom font dependencies.

### Color

Use native macOS colors and semantic SwiftUI colors where possible.

Define connection color tags for future production/staging/local distinction:

- Blue.
- Green.
- Yellow.
- Orange.
- Red.
- Purple.
- Gray.

In Phase 0 they can be model values plus small swatches in mock UI.

Avoid decorative gradients and oversized cards. This app should feel like a focused professional tool.

## Commands And Menus

Add only safe early commands:

- New Connection: `Cmd+N`.
- New Query Tab: `Cmd+T`, disabled or placeholder if no connection exists.
- Open Settings: `Cmd+,`.

Do not implement query execution commands yet because there is no query engine.

If commands become awkward in Phase 0, keep only settings and rely on visible buttons.

## Accessibility

Phase 0 should establish baseline accessibility:

- All icon-only buttons need labels or tooltips.
- Empty state actions should have clear labels.
- Sidebar rows should expose meaningful names.
- Text should not rely on color alone.

## Testing Scope

Phase 0 tests should be light but real.

Recommended unit tests:

- `ConnectionColorTag` has stable display names and colors.
- `WorkspaceTab` initializes with expected defaults, if modeled.
- `AppState` default state has no selected connection and a sensible empty workspace, if introduced.

Recommended UI test:

- App launches and shows the DeepDrop shell.
- First-launch empty state includes the add database source action.
- Settings can be opened.

Do not add tests for database behavior, parsing, or AI in Phase 0.

## Build Validation

Use Xcode build validation after implementation:

- Run `XcodeRefreshCodeIssuesInFile` on changed Swift files where practical.
- Run `BuildProject` after the shell compiles locally.

Expected result:

- App builds.
- App launches to the DeepDrop shell.
- No Core Data template UI is visible.
- No network, database, or API key is required.

## Implementation Steps

### Step 1: Create Folder Structure

Add source files under the app target using the proposed structure.

Keep changes scoped to app foundation files and tests.

### Step 2: Replace Template Content View

Remove the Core Data list from `ContentView`.

Render the new `DeepDropAppShell`.

Keep the preview working without requiring a managed object context.

### Step 3: Add Design Tokens

Create:

- `DeepDropSpacing`.
- `DeepDropTypography`.
- `DeepDropColors`.
- `ConnectionColorTag`.

Use the tokens in the shell immediately so they do not become dead abstractions.

### Step 4: Add Shell Views

Create:

- `DeepDropAppShell`.
- `ConnectionListView`.
- `ConnectionEmptyStateView`.
- `WorkspaceView`.
- `WorkspacePlaceholderView`.
- `ResultsPlaceholderView`.

The shell should use `NavigationSplitView` if the deployment target supports it cleanly. If not, use the most modern stable SwiftUI split layout available for the target.

### Step 5: Add Minimal Settings

Create a settings scene or sheet depending on what fits the existing app setup.

Preferred:

- Use SwiftUI `Settings` scene in `deepdropApp.swift`.
- Add `SettingsView`.

If the current app target setup makes a settings scene noisy, add a toolbar/settings button that opens a sheet and defer the app-level settings scene.

### Step 6: Add Placeholder State Models

Add simple value types for shell state only:

- `ConnectionProfile` placeholder without credentials.
- `WorkspaceTab`.
- Optional `AppState`.

Do not create final persistence models yet.

### Step 7: Add Tests

Add focused tests for stable pure Swift types introduced in Phase 0.

If test target wiring is awkward, keep tests minimal and document the blocker before moving to Phase 1.

### Step 8: Validate Build

Run diagnostics and build.

Fix all compile errors and obvious layout issues.

## Acceptance Criteria

Phase 0 is complete when:

- The app launches to a DeepDrop-branded native shell.
- The template Core Data item list is gone from the visible UI.
- The shell has a sidebar, workspace area, results placeholder, and settings entry.
- The first-launch state guides the user toward adding a database source.
- The code is organized into clear app, feature, core, and design-system areas.
- The app builds without requiring PostgreSQL, OpenAI, or secrets.
- At least one meaningful unit or UI test verifies the shell foundation.
- No unrelated database, AI, or CRUD behavior has been introduced.

## Risks And Mitigations

### Risk: Overbuilding The Shell

Mitigation: keep Phase 0 views static and structural. Avoid implementing real connection behavior until Phase 1.

### Risk: Premature Persistence Choice

Mitigation: leave Core Data dormant and defer the persistence decision until connection profiles are implemented.

### Risk: SwiftUI Layout Limitations

Mitigation: use SwiftUI for the shell only. Reserve AppKit evaluation for editor and grid spikes.

### Risk: Placeholder UI Feels Fake

Mitigation: make placeholders honest and compact. The first screen should focus on the add-connection workflow that Phase 1 will make real.

## Review Checklist

Before implementation starts, confirm:

- Whether to keep the existing Core Data stack dormant or remove it entirely.
- Minimum macOS deployment target.
- Whether `NavigationSplitView` is acceptable for the target.
- Whether settings should be a native Settings scene in Phase 0.
- Whether Phase 0 should include a real but non-persistent add-connection sheet, or only the shell and empty state.

## Completion Notes

Phase 0 is considered complete when the implementation matches this document and the project builds.

Implemented:

- Replaced the default Core Data sample screen with `DeepDropAppShell`.
- Added a native SwiftUI shell with sidebar, workspace, results placeholder, add-source placeholder, and settings scene.
- Added design-system tokens for spacing, typography, colors, and connection color tags.
- Added placeholder app/domain state types for connection profiles and workspace tabs.
- Added macOS window sizing, resizing, and frame autosave behavior.
- Added Swift Testing coverage for basic foundation model defaults.
- Replaced template UI tests with launch and add-source placeholder checks.

Intentionally deferred:

- Real connection persistence.
- Keychain-backed secrets.
- PostgreSQL URL parsing.
- Database driver integration.
- Query editor, result grid, schema browser, and AI behavior.

The existing Core Data template stack remains dormant. It is not used by the visible app shell and can be removed or repurposed when the persistence strategy is finalized in Phase 1.
