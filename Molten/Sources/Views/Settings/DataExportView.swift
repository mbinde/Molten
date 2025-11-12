//
//  DataExportView.swift
//  Molten
//
//  View for exporting all app data to JSON
//

import SwiftUI

struct DataExportView: View {
    @State private var isExporting = false
    @State private var showingShareSheet = false
    @State private var exportFileURL: URL?
    @State private var includeImages = true
    @State private var includeUserNotes = true
    @State private var includeArchivedProjects = false
    @State private var lastExportResult: DataExportResult?
    @StateObject private var errorState = ErrorAlertState()

    private let exportService: DataExportService

    init(exportService: DataExportService) {
        self.exportService = exportService
    }

    /// Convenience init using AppDependencies
    init(deps: AppDependencies = AppDependencies()) {
        self.exportService = deps.dataExportService
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Export all your Molten data to a folder containing JSON files for each entity type.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("This export can be used for backup, data analysis, or migration purposes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Export Options") {
                Toggle("Include Images", isOn: $includeImages)
                    .help("Include user-uploaded images in the export. Images are Base64-encoded and can significantly increase file size.")

                Toggle("Include User Notes", isOn: $includeUserNotes)
                    .help("Include your personal notes about glass items")

                Toggle("Include Archived Projects", isOn: $includeArchivedProjects)
                    .help("Include projects that have been archived")
            }

            if let result = lastExportResult {
                Section("Last Export") {
                    HStack {
                        Text("Date")
                        Spacer()
                        Text(result.exportDate.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("File Size")
                        Spacer()
                        Text(formatFileSize(result.fileSize))
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Glass Items")
                        Spacer()
                        Text("\(result.entityCounts.glassItems)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Inventory Records")
                        Spacer()
                        Text("\(result.entityCounts.inventoryRecords)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Projects")
                        Spacer()
                        Text("\(result.entityCounts.projects)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Logbook Entries")
                        Spacer()
                        Text("\(result.entityCounts.logbookEntries)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Purchase Records")
                        Spacer()
                        Text("\(result.entityCounts.purchaseRecords)")
                            .foregroundStyle(.secondary)
                    }

                    if result.includedImages {
                        HStack {
                            Text("User Images")
                            Spacer()
                            Text("\(result.entityCounts.userImages)")
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Text("Total Entities")
                        Spacer()
                        Text("\(result.entityCounts.total)")
                            .foregroundStyle(.secondary)
                            .fontWeight(.semibold)
                    }
                }
            }

            Section {
                Button {
                    performExport()
                } label: {
                    HStack {
                        if isExporting {
                            ProgressView()
                                .progressViewStyle(.circular)
                            Text("Exporting...")
                        } else {
                            Label("Export Data", systemImage: "square.and.arrow.up")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(isExporting)
                .buttonStyle(.borderedProminent)
            } footer: {
                if isExporting {
                    Text("Please wait while your data is being exported...")
                        .foregroundStyle(.secondary)
                } else if includeImages {
                    Text("Note: Including images will create a larger export file and may take longer.")
                        .foregroundStyle(.orange)
                } else {
                    Text("Tap Export Data to create a folder with all your data as JSON files.")
                }
            }
        }
        .navigationTitle("Export Data")
        .errorAlert(errorState)
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportFileURL {
                ShareSheet(items: [url])
            }
        }
    }

    // MARK: - Export Logic

    private func performExport() {
        guard !isExporting else { return }

        isExporting = true

        Task {
            let configuration = DataExportConfiguration(
                includeImages: includeImages,
                includeUserNotes: includeUserNotes,
                includeArchivedProjects: includeArchivedProjects
            )
            let result = await exportService.exportAllData(configuration: configuration)

            await MainActor.run {
                isExporting = false

                switch result {
                case .success(let exportResult):
                    lastExportResult = exportResult
                    exportFileURL = exportResult.fileURL
                    showingShareSheet = true
                    print("✅ Export completed successfully")

                case .failure(let error):
                    errorState.show(error: error, context: "Data export failed")
                    print("❌ Export failed: \(error)")
                }
            }
        }
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// Note: ShareSheet is defined in Shared/Components/ShareSheet.swift

// MARK: - Preview

#Preview {
    NavigationStack {
        DataExportView()
    }
}
