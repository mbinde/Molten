//
//  BackupSettingsView.swift
//  Molten
//
//  Settings view for automatic inventory backups
//  Allows enabling/disabling backups and showing the backup key
//

import SwiftUI

struct BackupSettingsView: View {
    @Environment(\.appDependencies) private var dependencies
    @State private var isEnabled: Bool = false
    @State private var backupKey: String?
    @State private var isEnabling = false
    @State private var isRerolling = false
    @State private var errorMessage: String?
    @State private var showingRerollConfirmation = false
    @State private var lastBackupTimestamp: Date?
    @State private var showCopiedFeedback = false

    private var backupService: BackupService {
        dependencies.backupService
    }

    var body: some View {
        List {
            // Status Section
            Section {
                if isEnabled, let key = backupKey {
                    // Backup is enabled - show key
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Backups Enabled")
                                .font(.headline)
                        }

                        Text("Your inventory is automatically backed up to the cloud.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)

                    // Backup Key Display
                    HStack {
                        Text("Backup Key")
                        Spacer()
                        Text(key)
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.semibold)

                        Button {
                            UIPasteboard.general.string = key
                            withAnimation {
                                showCopiedFeedback = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    showCopiedFeedback = false
                                }
                            }
                        } label: {
                            Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                                .foregroundColor(showCopiedFeedback ? .green : .accentColor)
                        }
                        .buttonStyle(.borderless)
                    }

                    // Last Backup Time
                    if let lastBackup = lastBackupTimestamp {
                        HStack {
                            Text("Last Backup")
                            Spacer()
                            Text(lastBackup, style: .relative)
                                .foregroundColor(.secondary)
                            Text("ago")
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    // Backup not enabled - show enable button
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "icloud.slash")
                                .foregroundColor(.secondary)
                            Text("Backups Disabled")
                                .font(.headline)
                        }

                        Text("Enable automatic backups to protect your inventory data. Backups are stored securely in the cloud and can be restored on any device.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)

                    Button {
                        enableBackups()
                    } label: {
                        HStack {
                            Spacer()
                            if isEnabling {
                                ProgressView()
                                    .progressViewStyle(.circular)
                            } else {
                                Image(systemName: "icloud.and.arrow.up")
                                Text("Enable Backups")
                            }
                            Spacer()
                        }
                    }
                    .disabled(isEnabling)
                }
            } header: {
                Text("Automatic Backups")
            } footer: {
                if isEnabled {
                    Text("Save this backup key in a safe place. You'll need it to restore your data on a new device.")
                } else {
                    Text("Backups happen automatically when you open the app (if 20+ hours have passed) and when the app goes to background.")
                }
            }

            // Actions Section (only show when enabled)
            if isEnabled {
                Section {
                    Button(role: .destructive) {
                        showingRerollConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Generate New Backup Key")
                            if isRerolling {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(.circular)
                            }
                        }
                    }
                    .disabled(isRerolling)

                    Button(role: .destructive) {
                        disableBackups()
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text("Disable Backups")
                        }
                    }
                } header: {
                    Text("Actions")
                } footer: {
                    Text("Generating a new key will invalidate the old one. Existing backups under the old key will remain but won't be accessible with the new key.")
                }
            }

            // Error Display
            if let error = errorMessage {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // How It Works Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(icon: "clock", text: "Backs up automatically every 20+ hours")
                    InfoRow(icon: "checkmark.seal", text: "Only uploads when data has changed")
                    InfoRow(icon: "lock.shield", text: "Encrypted and signed for security")
                    InfoRow(icon: "arrow.counterclockwise", text: "Keeps up to 50 backup versions")
                }
            } header: {
                Text("How It Works")
            }
        }
        .navigationTitle("Backups")
        .onAppear {
            loadState()
        }
        .confirmationDialog(
            "Generate New Backup Key?",
            isPresented: $showingRerollConfirmation,
            titleVisibility: .visible
        ) {
            Button("Generate New Key", role: .destructive) {
                rerollKey()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will create a new backup key. Your old key will no longer work. Make sure to save the new key.")
        }
    }

    // MARK: - Private Methods

    private func loadState() {
        isEnabled = backupService.isSetUp
        backupKey = backupService.backupKey
        lastBackupTimestamp = BackupPreferences().lastBackupTimestamp
    }

    private func enableBackups() {
        isEnabling = true
        errorMessage = nil

        Task { @MainActor in
            do {
                let newKey = try await backupService.enableBackups()
                backupKey = newKey
                isEnabled = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isEnabling = false
        }
    }

    private func disableBackups() {
        backupService.disableBackups()
        isEnabled = false
        backupKey = nil
        lastBackupTimestamp = nil
    }

    private func rerollKey() {
        isRerolling = true
        errorMessage = nil

        Task { @MainActor in
            do {
                let newKey = try await backupService.rerollBackupKey()
                backupKey = newKey
            } catch {
                errorMessage = error.localizedDescription
            }
            isRerolling = false
        }
    }
}

// MARK: - Info Row

private struct InfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        BackupSettingsView()
    }
}
