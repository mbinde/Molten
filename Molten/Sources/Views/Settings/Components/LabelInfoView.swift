//
//  LabelInfoView.swift
//  Molten
//
//  View for displaying and managing label database updates
//

import SwiftUI

struct LabelInfoView: View {

    @State private var viewModel: LabelUpdateViewModel
    @State private var showForceDownloadConfirmation = false

    init(viewModel: LabelUpdateViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        List {
            // Current label database info
            Section {
                LabeledContent("Current Version", value: viewModel.currentVersionDisplay)

                if let lastUpdate = viewModel.lastSuccessfulUpdate {
                    LabeledContent("Last Updated") {
                        Text(lastUpdate, style: .relative)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }

                LabeledContent("Source", value: viewModel.labelSource)

                if let lastCheck = viewModel.lastUpdateCheck {
                    LabeledContent("Last Checked") {
                        Text(lastCheck, style: .relative)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
            } header: {
                Text("Label Database Information")
            }

            // Update status
            Section {
                if !viewModel.isServiceAvailable {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Update service unavailable")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                } else if viewModel.isChecking {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Checking for updates...")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                } else if let updateInfo = viewModel.availableUpdate {
                    // Update available
                    updateAvailableSection(updateInfo)
                } else {
                    // Up to date
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Label database is up to date")
                    }
                }

                // Check for updates button
                Button {
                    Task {
                        await viewModel.checkForUpdates()
                    }
                } label: {
                    HStack {
                        Text(viewModel.isChecking ? "Checking..." : "Check for Updates")
                        Spacer()
                        if viewModel.isChecking {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
                .disabled(!viewModel.isServiceAvailable || viewModel.isChecking || viewModel.isDownloading)
                .accessibilityIdentifier("label_check_updates")
            } header: {
                Text("Updates")
            } footer: {
                if let lastCheck = viewModel.lastUpdateCheck {
                    Text("Last checked \(lastCheck, format: Date.RelativeFormatStyle()) ago")
                }
            }

            // Download settings (shared with catalog)
            Section {
                Toggle("Auto-Update", isOn: Binding(
                    get: { viewModel.autoUpdateEnabled },
                    set: { viewModel.autoUpdateEnabled = $0 }
                ))
                .accessibilityIdentifier("label_auto_update_toggle")

                Picker("Update Frequency", selection: Binding(
                    get: { viewModel.updateFrequency },
                    set: { viewModel.updateFrequency = $0 }
                )) {
                    ForEach(CatalogUpdatePreferences.UpdateFrequency.allCases, id: \.self) { frequency in
                        Text(frequency.rawValue).tag(frequency)
                    }
                }
                .disabled(!viewModel.autoUpdateEnabled)

                Picker("Download Using", selection: Binding(
                    get: { viewModel.downloadPolicy },
                    set: { viewModel.downloadPolicy = $0 }
                )) {
                    ForEach(CatalogUpdatePreferences.DownloadPolicy.allCases, id: \.self) { policy in
                        Text(policy.rawValue).tag(policy)
                    }
                }
            } header: {
                Text("Update Settings")
            } footer: {
                Text(downloadPolicyFooter)
            }

            // Network status
            Section {
                LabeledContent("Connection", value: viewModel.connectionDescription)

                if !viewModel.canDownloadNow {
                    Label("Downloads restricted by network policy", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            } header: {
                Text("Network Status")
            }
        }
        .navigationTitle("Label Updates")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Update Failed", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.dismissError()
            }
        } message: {
            if let error = viewModel.lastError {
                Text(error.localizedDescription)
            }
        }
        .confirmationDialog("Force Download?", isPresented: $showForceDownloadConfirmation) {
            Button("Download Anyway", role: .destructive) {
                Task {
                    await viewModel.forceDownloadUpdate()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your current network policy restricts downloads. Proceeding may use cellular data.")
        }
        .task {
            // Auto-check on view appearance if we haven't checked recently
            if viewModel.isServiceAvailable {
                if viewModel.lastUpdateCheck == nil ||
                   Date().timeIntervalSince(viewModel.lastUpdateCheck!) > 3600 {  // 1 hour
                    await viewModel.checkForUpdates()
                }
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func updateAvailableSection(_ updateInfo: LabelUpdateInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(Color.accentColor)
                Text("Update Available")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 4) {
                if updateInfo.isInitialVersionedUpdate {
                    Text("Version \(updateInfo.availableVersion) (First versioned release)")
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                } else {
                    Text("Version \(updateInfo.availableVersion)")
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                if let changelog = updateInfo.changelog, !changelog.isEmpty {
                    Text(changelog)
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Release Date")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Text(updateInfo.releaseDate, style: .date)
                        .font(.caption)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Download Size")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Text(ByteCountFormatter.string(fromByteCount: Int64(updateInfo.fileSize), countStyle: .file))
                        .font(.caption)
                }
            }

            // Download button or progress
            if viewModel.isDownloading {
                VStack(spacing: 8) {
                    ProgressView(value: viewModel.downloadProgress)

                    HStack {
                        Text("Downloading...")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        Spacer()

                        Text("\(Int(viewModel.downloadProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
            } else {
                Button {
                    if viewModel.canDownloadNow {
                        Task {
                            await viewModel.downloadUpdate()
                        }
                    } else {
                        showForceDownloadConfirmation = true
                    }
                } label: {
                    HStack {
                        Spacer()
                        Text(viewModel.canDownloadNow ? "Download Update" : "Download Anyway")
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isChecking || viewModel.isDownloading)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Computed Properties

    private var downloadPolicyFooter: String {
        if viewModel.autoUpdateEnabled {
            return "Label database updates will download automatically based on your selected frequency and network policy. These settings are shared with catalog updates."
        } else {
            return "Auto-updates are disabled. Check for updates manually using the button above."
        }
    }
}

// MARK: - Previews

#Preview("Up to Date") {
    NavigationStack {
        LabelInfoView(
            viewModel: LabelUpdateViewModel(updateService: nil)
        )
    }
}
