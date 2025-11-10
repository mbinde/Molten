//
//  CatalogInfoView.swift
//  Molten
//
//  Created by Assistant on 11/9/25.
//  View for displaying and managing catalog updates
//

import SwiftUI

struct CatalogInfoView: View {

    @State private var viewModel: CatalogUpdateViewModel
    @State private var showForceDownloadConfirmation = false

    init(viewModel: CatalogUpdateViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        List {
            // Current catalog info
            Section {
                LabeledContent("Current Version", value: "v\(viewModel.currentVersion)")

                if let lastUpdate = viewModel.lastSuccessfulUpdate {
                    LabeledContent("Last Updated") {
                        Text(lastUpdate, style: .relative)
                            .foregroundColor(.secondary)
                    }
                }

                LabeledContent("Source", value: viewModel.catalogSource)

                if let lastCheck = viewModel.lastUpdateCheck {
                    LabeledContent("Last Checked") {
                        Text(lastCheck, style: .relative)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Catalog Information")
            }

            // Update status
            Section {
                if viewModel.isChecking {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Checking for updates...")
                            .foregroundColor(.secondary)
                    }
                } else if let updateInfo = viewModel.availableUpdate {
                    // Update available
                    updateAvailableSection(updateInfo)
                } else {
                    // Up to date
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Catalog is up to date")
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
                .disabled(viewModel.isChecking || viewModel.isDownloading)
            } header: {
                Text("Updates")
            } footer: {
                if let lastCheck = viewModel.lastUpdateCheck {
                    Text("Last checked \(lastCheck, format: Date.RelativeFormatStyle()) ago")
                }
            }

            // Download settings
            Section {
                Toggle("Auto-Update Catalog", isOn: $viewModel.autoUpdateEnabled)

                Picker("Update Frequency", selection: $viewModel.updateFrequency) {
                    ForEach(CatalogUpdatePreferences.UpdateFrequency.allCases, id: \.self) { frequency in
                        Text(frequency.rawValue).tag(frequency)
                    }
                }
                .disabled(!viewModel.autoUpdateEnabled)

                Picker("Download Using", selection: $viewModel.downloadPolicy) {
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
        .navigationTitle("Catalog Updates")
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
            if viewModel.lastUpdateCheck == nil ||
               Date().timeIntervalSince(viewModel.lastUpdateCheck!) > 3600 {  // 1 hour
                await viewModel.checkForUpdates()
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func updateAvailableSection(_ updateInfo: CatalogUpdateInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.blue)
                Text("Update Available")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Version \(updateInfo.availableVersion)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if !updateInfo.changelog.isEmpty {
                    Text(updateInfo.changelog)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Release Date")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(updateInfo.releaseDate, style: .date)
                        .font(.caption)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Download Size")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(updateInfo.fileSizeFormatted)
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
                            .foregroundColor(.secondary)

                        Spacer()

                        Text("\(Int(viewModel.downloadProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
            return "Catalog updates will download automatically based on your selected frequency and network policy."
        } else {
            return "Auto-updates are disabled. Check for updates manually using the button above."
        }
    }
}

// MARK: - Previews

#Preview("Up to Date") {
    NavigationStack {
        CatalogInfoView(
            viewModel: CatalogUpdateViewModel(
                updateService: CatalogUpdateService(
                    apiClient: CatalogAPIClient(),
                    storageService: try! CatalogStorageService(),
                    dataLoadingService: RepositoryFactory.createGlassItemDataLoadingService(),
                    networkMonitor: NetworkMonitor.shared
                )
            )
        )
    }
}
