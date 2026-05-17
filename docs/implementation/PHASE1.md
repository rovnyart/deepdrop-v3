# Phase 1 Implementation Plan: Connection Management

## Goal

Let users create, validate, save, edit, duplicate, and delete PostgreSQL connection sources without storing secrets in plain local persistence.

Phase 1 turns the Phase 0 add-source placeholder into the first real product workflow. A user should be able to paste a PostgreSQL URL, inspect or adjust parsed fields, test the connection, save the profile, and see it in the sidebar after relaunch.

## Product Outcome

At the end of Phase 1, DeepDrop should support a complete local connection-management loop:

- Add a PostgreSQL source from a `postgres://` or `postgresql://` URL.
- Manually edit parsed host, port, database, username, password, SSL mode, and display name.
- Test the connection and show clear success/failure status.
- Save connection metadata locally.
- Store database passwords in Keychain only.
- List saved sources in the sidebar.
- Select, edit, duplicate, and delete saved sources.
- Relaunch the app and see saved non-secret profiles restored.

## Non-Goals

Phase 1 does not include:

- Schema introspection beyond a successful connection test.
- Persistent open database sessions.
- Sidebar schema/object tree loading.
- Query editor execution.
- Result grid rendering.
- SSH tunnels.
- Cloud secret stores.
- AI integration.
- Import from other database clients.

These belong to later phases.

## Current Starting Point

Phase 0 provides:

- `DeepDropAppShell`.
- `ConnectionListView`.
- `ConnectionEmptyStateView`.
- Placeholder `ConnectionProfile`.
- Placeholder add-source sheet.
- Dormant Core Data template stack.
- Basic app state in memory.

Phase 1 should replace placeholder connection behavior with real connection management while keeping the rest of the app shell static.

## Key Decisions

### Persistence Choice

Recommended for Phase 1:

- Use a simple JSON file in Application Support for connection profiles.
- Keep the existing Core Data stack dormant.
- Revisit Core Data or SwiftData when query history, snippets, catalog cache, and settings require more structured persistence.

Rationale:

- Connection profile metadata is small and easy to version.
- JSON keeps Phase 1 implementation focused and testable.
- Secrets remain outside the JSON file in Keychain.
- Avoids committing to a larger persistence architecture before catalog/query history requirements are active.

Recommended file:

```text
~/Library/Application Support/DeepDrop/connections.json
```

### Keychain

Use Keychain Services directly through a small injectable wrapper.

Secrets to store:

- Database password.

Do not store:

- Full connection URLs containing passwords.
- OpenAI API keys in Phase 1.
- Query text or result data.

Use stable Keychain identity:

```swift
service: "com.deepdrop.database-password"
account: profile.id.uuidString
```

### PostgreSQL Driver Spike

Phase 1 needs real `Test Connection`.

Recommended dependency:

- Evaluate `postgres-nio` first.

Implementation should isolate driver usage behind a protocol so the connection form and tests are not tied to a concrete package:

```swift
protocol ConnectionTesting {
    func testConnection(_ request: ConnectionTestRequest) async -> ConnectionTestResult
}
```

If adding the package becomes noisy, Phase 1 can be split:

1. Parser, Keychain, persistence, and UI.
2. Driver dependency and real test connection.

Do not fake a successful connection test in product UI.

## Proposed File Structure

Add or evolve files under the app target:

```text
deepdrop/
  Core/
    FileStore.swift
    UserFacingError.swift
  Features/
    Connections/
      ConnectionFormState.swift
      ConnectionFormView.swift
      ConnectionProfile.swift
      ConnectionProfileStore.swift
      ConnectionProfileRepository.swift
      ConnectionURLParser.swift
      ConnectionValidation.swift
      ConnectionTestService.swift
      ConnectionTestResult.swift
      SavedConnectionCommands.swift
  Security/
    KeychainCredentialStore.swift
    CredentialStore.swift
```

Test files:

```text
deepdropTests/
  ConnectionURLParserTests.swift
  ConnectionFormStateTests.swift
  ConnectionProfileRepositoryTests.swift
  KeychainCredentialStoreTests.swift
```

UI test additions:

```text
deepdropUITests/
  ConnectionManagementUITests.swift
```

If Xcode project organization becomes too granular, keep fewer files but preserve these ownership boundaries in type names.

## Domain Model

### ConnectionProfile

Evolve the current placeholder into the real non-secret profile model.

```swift
struct ConnectionProfile: Identifiable, Hashable, Codable {
    var id: UUID
    var displayName: String
    var host: String
    var port: Int
    var database: String
    var username: String
    var sslMode: SSLMode
    var colorTag: ConnectionColorTag
    var isProduction: Bool
    var createdAt: Date
    var updatedAt: Date
}
```

Keep password out of this type.

### DatabaseCredentialRef

Add a credential reference if useful for repository APIs:

```swift
struct DatabaseCredentialRef: Codable, Hashable {
    var profileID: UUID
    var keychainService: String
    var keychainAccount: String
}
```

This may be computed rather than persisted if the scheme remains stable.

### ConnectionDraft

Use a separate form/draft model that may contain password while editing:

```swift
struct ConnectionDraft: Equatable {
    var id: UUID?
    var displayName: String
    var host: String
    var portText: String
    var database: String
    var username: String
    var password: String
    var sslMode: SSLMode
    var colorTag: ConnectionColorTag
    var isProduction: Bool
}
```

This type should not be `Codable` unless there is a clear reason, to reduce accidental persistence risk.

## URL Parser

### Supported Inputs

Support:

- `postgres://user:password@localhost:5432/dbname`
- `postgresql://user:password@localhost/dbname`
- URL-escaped usernames and passwords.
- IPv4 hosts.
- Hostnames.
- `localhost`.
- Query parameters such as `sslmode=require`.

Consider support for:

- IPv6 host syntax.
- Percent-encoded database names.
- Additional query params stored for future use.

Do not silently accept:

- Non-PostgreSQL schemes.
- Missing host.
- Missing database.
- Invalid port.
- Empty username if authentication is required by the form.

### Defaults

Defaults:

- Port: `5432`.
- SSL mode: `.prefer`.
- Display name: derived from database and host, for example `mydb localhost`.

### Parser Output

```swift
struct ParsedConnectionURL: Equatable {
    var displayName: String
    var host: String
    var port: Int
    var database: String
    var username: String
    var password: String
    var sslMode: SSLMode
}
```

Parser errors should be typed and user-facing:

```swift
enum ConnectionURLParserError: Error, Equatable {
    case unsupportedScheme(String?)
    case missingHost
    case missingDatabase
    case invalidPort(String)
}
```

## Validation

Validation should run continuously in the form.

Required fields:

- Display name.
- Host.
- Port.
- Database.
- Username.

Password may be empty for local trust or passwordless auth, but the UI should make that explicit.

Port validation:

- Integer.
- Range `1...65535`.

Save button enabled when:

- Required fields are valid.
- No active parse error exists.
- A test connection is either successful or the user has explicitly chosen to save without testing, if that behavior is allowed.

Recommended Phase 1 default:

- Allow saving without a successful test, but label the state clearly as `Not tested`.
- Do not block local workflows where the database is temporarily offline.

## Add/Edit Connection UI

Replace the placeholder sheet with a real form.

### Layout

Use a macOS sheet or dedicated detail surface. Recommended first implementation: sheet.

Fields:

- Connection URL paste field.
- Display name.
- Host.
- Port.
- Database.
- User.
- Password.
- SSL mode.
- Color tag.
- Production marker.

Advanced section:

- Application name.
- Connect timeout.
- Statement timeout.

Advanced fields can be non-functional placeholders in Phase 1 only if they are clearly not persisted. Prefer leaving them out until they are implemented.

### Interactions

- Pasting a URL parses immediately.
- Parsed fields update the form.
- Manual edits remain manual until the user pastes/parses again.
- Password field uses secure entry.
- Test Connection shows progress and disables duplicate tests.
- Save persists profile and password.
- Cancel discards draft.

### Status Copy

Use compact, specific statuses:

- `Not tested`
- `Testing...`
- `Connected in 84 ms`
- `Authentication failed`
- `Host unreachable`
- `SSL mode rejected by server`
- `Database does not exist`

Avoid raw driver errors unless no mapping exists.

## Sidebar Behavior

Update `ConnectionListView`:

- Show saved connections from repository state.
- Selecting a connection updates `AppState.selectedConnectionID`.
- Show host/database metadata.
- Show production marker when enabled.
- Add context menu:
  - Edit.
  - Duplicate.
  - Delete.
  - Copy Host.
  - Copy Database Name.

Delete behavior:

- Confirm deletion.
- Delete profile metadata.
- Delete associated Keychain password.
- Clear selection if the deleted profile was selected.

Duplicate behavior:

- Copy metadata.
- Generate new ID.
- Copy password into new Keychain entry if available.
- Suffix display name with `Copy`.

## Settings Behavior

Update the Connections settings tab enough to be useful:

- Show count of saved sources.
- Provide credential reset or delete-all placeholder only if implemented safely.

Do not expose raw passwords.

## Repository Design

Recommended repository responsibilities:

```swift
@MainActor
final class ConnectionProfileRepository: ObservableObject {
    @Published private(set) var profiles: [ConnectionProfile]

    func load() async
    func save(_ draft: ConnectionDraft) async throws -> ConnectionProfile
    func update(_ draft: ConnectionDraft) async throws -> ConnectionProfile
    func duplicate(_ profile: ConnectionProfile) async throws -> ConnectionProfile
    func delete(_ profile: ConnectionProfile) async throws
    func password(for profile: ConnectionProfile) async throws -> String?
}
```

Keep filesystem and Keychain APIs injectable:

```swift
protocol ConnectionProfileStore {
    func loadProfiles() throws -> [ConnectionProfile]
    func saveProfiles(_ profiles: [ConnectionProfile]) throws
}

protocol CredentialStore {
    func savePassword(_ password: String, account: String) throws
    func password(account: String) throws -> String?
    func deletePassword(account: String) throws
}
```

This makes tests independent of the real Keychain and user Application Support directory.

## Connection Testing

### Request

```swift
struct ConnectionTestRequest: Equatable {
    var host: String
    var port: Int
    var database: String
    var username: String
    var password: String
    var sslMode: SSLMode
}
```

### Result

```swift
struct ConnectionTestResult: Equatable {
    var status: ConnectionTestStatus
    var duration: Duration?
    var serverVersion: String?
    var message: String
}

enum ConnectionTestStatus: Equatable {
    case notTested
    case testing
    case succeeded
    case failed
}
```

Implementation should:

- Run off the main actor.
- Be cancellable.
- Apply a short timeout, for example 5-10 seconds.
- Connect, run a minimal query such as `select version()` or `select 1`, then close.
- Map known failures to friendly messages.

## Security Requirements

Mandatory:

- Never write password to JSON profile store.
- Never log password.
- Never display password in non-secure text.
- Never persist full connection URL.
- Delete Keychain password when profile is deleted.
- Tests should verify serialized profiles do not contain password text.

Recommended:

- Centralize redaction helpers before logging user-facing errors.
- Avoid printing raw connection strings during debug.

## App State Integration

Recommended Phase 1 app lifecycle:

1. `DeepDropAppShell` owns a `@StateObject` repository.
2. On appear, repository loads profiles.
3. `AppState.connections` is either removed or derived from repository profiles.
4. Sidebar selection updates selected connection.
5. Add/edit/delete actions call repository methods.

Prefer avoiding duplicate sources of truth. If repository owns profiles, `AppState` should keep only selection and workspace state.

## Testing Plan

### Unit Tests

Add tests for `ConnectionURLParser`:

- Parses `postgres://`.
- Parses `postgresql://`.
- Defaults missing port to `5432`.
- Parses URL-escaped password.
- Parses URL-escaped username.
- Parses `sslmode=require`.
- Rejects unsupported schemes.
- Rejects missing host.
- Rejects invalid port.
- Rejects missing database.

Add tests for validation:

- Empty required fields produce validation errors.
- Port must be numeric.
- Port must be in range.
- Empty password is allowed but represented clearly.

Add repository tests with mocks:

- Saving a profile writes metadata and Keychain password separately.
- Serialized metadata does not contain password.
- Deleting a profile deletes the Keychain password.
- Duplicating a profile creates a new ID and copies password.
- Loading invalid JSON surfaces a recoverable error.

Add Keychain wrapper tests:

- Prefer tests against a mock credential store.
- Real Keychain integration tests should be optional and isolated if added.

### UI Tests

Add tests for:

- Add connection sheet opens.
- Pasting a URL populates host, database, username, and port.
- Save disabled for invalid required fields.
- Save creates a sidebar row when valid.
- Delete removes a sidebar row.

For UI tests, use a test-only profile store path and mock connection tester if possible. Do not require a real PostgreSQL server for normal UI tests.

### Integration Test

Optional in Phase 1, useful if local PostgreSQL is available:

- Connect to local test database.
- Run connection test.
- Verify success status.

This should not be required for every build unless a test database fixture is managed.

## Build And Validation

Use these validation points:

1. Parser and validation tests pass.
2. App builds after repository and Keychain wrapper.
3. Add/edit UI compiles and opens.
4. Save/list/delete works with local profile store.
5. Real connection test works against a manually provided database.
6. UI tests pass with mocked/non-network behavior.

Run:

- Xcode diagnostics for changed Swift files.
- `BuildProject`.
- Unit tests from Xcode.
- UI tests after stabilizing accessibility identifiers.

## Meaningful Review Checkpoints

Stop for review after each checkpoint.

### Checkpoint 1: Parser And Draft Model

Deliver:

- `ConnectionURLParser`.
- `ConnectionDraft`.
- Validation types.
- Unit tests.

User can review:

- URL parsing behavior.
- Error messages.
- Field defaults.

### Checkpoint 2: Add/Edit Form UI

Deliver:

- Real add-connection sheet.
- Paste-to-parse behavior.
- Field validation.
- Disabled/enabled Save behavior.

User can review:

- Form layout.
- Copy.
- Interaction flow.

### Checkpoint 3: Local Persistence And Keychain

Deliver:

- JSON profile storage.
- Keychain password storage.
- Sidebar list restoration after relaunch.
- Delete and duplicate behavior.

User can review:

- Saved connection list.
- Relaunch behavior.
- Metadata shown in sidebar.

### Checkpoint 4: Test Connection

Deliver:

- PostgreSQL driver integration.
- Real connection test flow.
- Friendly connection error mapping.
- Cancellable progress state.

User can review:

- Testing against local/staging database.
- Failure copy.
- Timeout behavior.

### Checkpoint 5: Phase 1 Validation

Deliver:

- Unit tests.
- UI tests.
- Build validation.
- Updated Phase 1 completion notes.

User can review:

- Phase 1 acceptance criteria before commit/push.

## Acceptance Criteria

Phase 1 is complete when:

- User can add a connection from a PostgreSQL URL.
- User can add a connection manually.
- URL parser handles escaped passwords and default port.
- User can test a connection and see useful success/failure feedback.
- User can save a connection profile.
- Password is stored in Keychain only.
- Connection metadata is restored after app relaunch.
- Sidebar shows saved connections.
- User can edit, duplicate, and delete saved connections.
- Deleting a connection deletes its password from Keychain.
- Unit tests cover parser, validation, repository, and secret separation.
- UI tests cover the add connection flow at least through validation/save using non-network test doubles.
- App builds without requiring a database to launch.

## Risks And Mitigations

### Risk: PostgreSQL Driver Adds Build Complexity

Mitigation: isolate driver usage behind `ConnectionTesting` and complete parser/UI/persistence first. Add the package at Checkpoint 4.

### Risk: Keychain Behavior Is Hard To Test

Mitigation: use an injectable `CredentialStore` protocol and test most behavior with an in-memory mock. Keep real Keychain tests narrow.

### Risk: Accidental Secret Persistence

Mitigation: separate draft/password types from persisted profile types. Add tests that serialized profile JSON does not contain known password values.

### Risk: UI Form Gets Too Large

Mitigation: implement only required fields plus color and production marker. Defer advanced connection options until they are real.

### Risk: Local Persistence Choice Conflicts With Later Architecture

Mitigation: hide JSON storage behind `ConnectionProfileStore`. Later phases can replace the store with Core Data or SwiftData without changing UI code.

## Open Questions Before Implementation

- Should saving without a successful connection test be allowed?
- Should Phase 1 include real PostgreSQL driver integration immediately, or should it stop after parser/UI/persistence first?
- Should connection profiles be stored in JSON for now, or should we commit to Core Data/SwiftData in Phase 1?
- Should passwords be copied when duplicating a connection?
- Should production marker confirmation behavior start in Phase 1 or wait until query execution exists?

## Completion Notes

Implemented:

- PostgreSQL URL parser for `postgres://` and `postgresql://`.
- Connection draft model with validation.
- Add/edit connection form with paste-to-parse behavior.
- Save validation with inline duplicate/error feedback.
- JSON profile persistence in Application Support.
- Keychain-backed password storage through an injectable credential store.
- Sidebar restoration after relaunch.
- Edit, duplicate, and confirmed delete from saved connection rows.
- Exact duplicate prevention for `host + port + database + username + sslMode`.
- Real PostgreSQL connection test using `postgres-nio`.
- App Sandbox outgoing network capability enabled through Xcode build settings.
- UI test storage isolation through `DEEPDROP_CONNECTIONS_FILE` and `DEEPDROP_KEYCHAIN_SERVICE`.
- Unit tests for parser, validation, repository secret separation, duplicate prevention, delete, and duplicate behavior.

Current tradeoffs:

- Connection row actions still live in the context menu. A later UX pass should replace this with polished visible affordances.
- SSL verification modes currently use TLS without custom CA configuration because the app has no CA/certificate UI yet.
- Saving without a successful connection test is allowed.
- Connection profiles are persisted as JSON, not Core Data or SwiftData.

Deferred:

- Schema/object loading after selecting a connection.
- Persistent live database sessions.
- Advanced SSL certificate configuration.
- SSH tunnel support.
- Import/export of connection profiles.
- Production connection enforcement during query execution.
