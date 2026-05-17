//
//  ConnectionFormView.swift
//  deepdrop
//
//  Created by Codex on 17.05.2026.
//

import SwiftUI

struct ConnectionFormView: View {
    @State private var connectionURL = ""
    @State private var draft: ConnectionDraft
    @State private var parseError: String?
    @State private var lastParsedURL = ""
    @State private var connectionTestResult = ConnectionTestResult.notTested
    @State private var saveErrorMessage: String?

    let connectionTester: ConnectionTesting
    let onSave: (ConnectionDraft) throws -> Void
    let onCancel: () -> Void

    init(
        draft: ConnectionDraft = ConnectionDraft(),
        connectionTester: ConnectionTesting = PostgresConnectionTestService(),
        onSave: @escaping (ConnectionDraft) throws -> Void,
        onCancel: @escaping () -> Void
    ) {
        _draft = State(initialValue: draft)
        self.connectionTester = connectionTester
        self.onSave = onSave
        self.onCancel = onCancel
    }

    private var validation: ConnectionValidationResult {
        ConnectionValidation.validate(draft)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: DeepDropSpacing.xl) {
                    urlSection
                    profileSection
                    securitySection
                    testConnectionSection
                    saveErrorSection
                    validationSummary
                }
                .padding(DeepDropSpacing.xl)
            }

            Divider()

            footer
        }
        .frame(width: 640, height: 640)
    }

    private var header: some View {
        HStack(spacing: DeepDropSpacing.md) {
            Image(systemName: "server.rack")
                .font(.title2)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(draft.id == nil ? "Add Database Source" : "Edit Database Source")
                    .font(.title2.weight(.semibold))
                Text(draft.id == nil ? "Paste a PostgreSQL URL or fill the connection fields manually." : "Update connection metadata and credentials.")
                    .font(DeepDropTypography.metadata)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(DeepDropSpacing.xl)
    }

    private var urlSection: some View {
        VStack(alignment: .leading, spacing: DeepDropSpacing.sm) {
            Text("Connection URL")
                .font(DeepDropTypography.sectionTitle)

            TextField("postgresql://user:password@localhost:5432/database", text: $connectionURL)
                .textFieldStyle(.roundedBorder)
                .font(DeepDropTypography.sql)
                .accessibilityIdentifier("connection-url-field")
                .onChange(of: connectionURL) { _, newValue in
                    parseURLIfNeeded(newValue)
                }
                .onSubmit {
                    parseURL(connectionURL)
                }

            if let parseError {
                Label(parseError, systemImage: "exclamationmark.triangle")
                    .font(DeepDropTypography.metadata)
                    .foregroundStyle(.orange)
            } else {
                Text("Supported schemes: postgres:// and postgresql://")
                    .font(DeepDropTypography.metadata)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: DeepDropSpacing.md) {
            Text("Profile")
                .font(DeepDropTypography.sectionTitle)

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: DeepDropSpacing.lg, verticalSpacing: DeepDropSpacing.md) {
                formRow("Name") {
                    TextField("Local DeepDrop", text: $draft.displayName)
                        .accessibilityIdentifier("connection-name-field")
                } message: {
                    validation.message(for: .displayName)
                }

                formRow("Host") {
                    TextField("localhost", text: $draft.host)
                        .accessibilityIdentifier("connection-host-field")
                } message: {
                    validation.message(for: .host)
                }

                formRow("Port") {
                    TextField("5432", text: $draft.portText)
                        .frame(width: 96)
                        .accessibilityIdentifier("connection-port-field")
                } message: {
                    validation.message(for: .port)
                }

                formRow("Database") {
                    TextField("postgres", text: $draft.database)
                        .accessibilityIdentifier("connection-database-field")
                } message: {
                    validation.message(for: .database)
                }

                formRow("User") {
                    TextField("postgres", text: $draft.username)
                        .accessibilityIdentifier("connection-username-field")
                } message: {
                    validation.message(for: .username)
                }

                formRow("Password") {
                    SecureField("Optional", text: $draft.password)
                        .accessibilityIdentifier("connection-password-field")
                } message: {
                    nil
                }
            }
        }
    }

    private var securitySection: some View {
        VStack(alignment: .leading, spacing: DeepDropSpacing.md) {
            Text("Connection Options")
                .font(DeepDropTypography.sectionTitle)

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: DeepDropSpacing.lg, verticalSpacing: DeepDropSpacing.md) {
                GridRow {
                    Text("SSL Mode")
                        .foregroundStyle(.secondary)
                    Picker("SSL Mode", selection: $draft.sslMode) {
                        ForEach(SSLMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                    .accessibilityIdentifier("connection-ssl-mode-picker")
                }

                GridRow {
                    Text("Color")
                        .foregroundStyle(.secondary)
                    Picker("Color", selection: $draft.colorTag) {
                        ForEach(ConnectionColorTag.allCases) { tag in
                            Text(tag.displayName).tag(tag)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                    .accessibilityIdentifier("connection-color-picker")
                }

                GridRow {
                    Text("Safety")
                        .foregroundStyle(.secondary)
                    Toggle("Mark as production", isOn: $draft.isProduction)
                        .accessibilityIdentifier("connection-production-toggle")
                }
            }
        }
    }

    @ViewBuilder
    private var testConnectionSection: some View {
        VStack(alignment: .leading, spacing: DeepDropSpacing.sm) {
            Text("Connection Test")
                .font(DeepDropTypography.sectionTitle)

            Label(connectionTestResult.message, systemImage: connectionTestIcon)
                .font(DeepDropTypography.metadata)
                .foregroundStyle(connectionTestColor)

            if let version = connectionTestResult.serverVersion {
                Text(version)
                    .font(DeepDropTypography.metadata)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    @ViewBuilder
    private var saveErrorSection: some View {
        if let saveErrorMessage {
            Label(saveErrorMessage, systemImage: "xmark.octagon")
                .font(DeepDropTypography.metadata)
                .foregroundStyle(.red)
                .padding(DeepDropSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityIdentifier("connection-save-error")
        }
    }

    @ViewBuilder
    private var validationSummary: some View {
        if validation.isValid {
            Label("Ready to save. Passwords are stored separately in Keychain.", systemImage: "checkmark.circle")
                .font(DeepDropTypography.metadata)
                .foregroundStyle(.green)
        } else {
            Label("Complete the required fields to save this source.", systemImage: "info.circle")
                .font(DeepDropTypography.metadata)
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        HStack(spacing: DeepDropSpacing.md) {
            Button("Test Connection") {
                testConnection()
            }
            .disabled(!validation.isValid || connectionTestResult.status == .testing)
            .accessibilityIdentifier("connection-test-button")

            Spacer()

            Button("Cancel", action: onCancel)
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("connection-form-cancel-button")

            Button("Save") {
                saveDraft()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!validation.isValid)
            .accessibilityIdentifier("connection-form-save-button")
        }
        .padding(DeepDropSpacing.xl)
    }

    private var connectionTestIcon: String {
        switch connectionTestResult.status {
        case .notTested:
            return "circle"
        case .testing:
            return "progress.indicator"
        case .succeeded:
            return "checkmark.circle"
        case .failed:
            return "xmark.octagon"
        }
    }

    private var connectionTestColor: Color {
        switch connectionTestResult.status {
        case .notTested, .testing:
            return .secondary
        case .succeeded:
            return .green
        case .failed:
            return .red
        }
    }

    private func formRow<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content,
        message: () -> String?
    ) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 88, alignment: .leading)

            VStack(alignment: .leading, spacing: DeepDropSpacing.xs) {
                content()
                    .textFieldStyle(.roundedBorder)

                if let message = message() {
                    Text(message)
                        .font(DeepDropTypography.metadata)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func parseURLIfNeeded(_ value: String) {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedValue != lastParsedURL else {
            return
        }

        if trimmedValue.isEmpty {
            parseError = nil
            return
        }

        guard trimmedValue.hasPrefix("postgres://") || trimmedValue.hasPrefix("postgresql://") else {
            parseError = nil
            return
        }

        parseURL(trimmedValue)
    }

    private func parseURL(_ value: String) {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            draft = ConnectionDraft(parsedURL: try ConnectionURLParser.parse(trimmedValue))
            parseError = nil
            saveErrorMessage = nil
            lastParsedURL = trimmedValue
        } catch let error as ConnectionURLParserError {
            parseError = error.localizedDescription
        } catch {
            parseError = "Unable to parse connection URL."
        }
    }

    private func testConnection() {
        guard let request = draft.connectionTestRequest else {
            return
        }

        connectionTestResult = ConnectionTestResult(
            status: .testing,
            duration: nil,
            serverVersion: nil,
            message: "Testing..."
        )

        Task {
            connectionTestResult = await connectionTester.testConnection(request)
        }
    }

    private func saveDraft() {
        do {
            try onSave(draft)
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ConnectionFormView(onSave: { _ in }, onCancel: {})
}
