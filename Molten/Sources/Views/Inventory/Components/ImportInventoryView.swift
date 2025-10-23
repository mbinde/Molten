//
//  ImportInventoryView.swift
//  Molten
//
//  View for importing inventory from JSON files created by the web import tool
//

import SwiftUI

struct ImportInventoryView: View {
    let fileURL: URL
    @Environment(\.dismiss) private var dismiss

    @State private var preview: ImportPreview?
    @State private var isLoading = true
    @State private var isImporting = false
    @State private var error: Error?
    @State private var importResult: ImportResult?

    private let importService: InventoryImportService

    var onImportComplete: (() -> Void)?

    init(fileURL: URL, onImportComplete: (() -> Void)? = nil) {
        self.fileURL = fileURL
        self.onImportComplete = onImportComplete
        self.importService = InventoryImportService(
            catalogService: RepositoryFactory.createCatalogService(),
            inventoryTrackingService: RepositoryFactory.createInventoryTrackingService()
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()

                Group {
                    if isLoading {
                        loadingView
                    } else if let error = error {
                        errorView(error)
                    } else if let result = importResult {
                        resultView(result)
                    } else if let preview = preview {
                        previewView(preview)
                    } else {
                        Text("Unexpected state")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Import Inventory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if preview != nil && error == nil && importResult == nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Import") {
                            Task {
                                await importInventory()
                            }
                        }
                        .disabled(isImporting)
                    }
                }
            }
            .task {
                await loadPreview()
            }
        }
    }

    // MARK: - Views

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
            Text("Reading import file...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            VStack(spacing: 8) {
                Text("Import Failed")
                    .font(.headline)

                Text(error.localizedDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button("Dismiss") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func previewView(_ preview: ImportPreview) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                            .font(.title)
                            .foregroundColor(.orange)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ready to Import")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text("\(preview.itemCount) items")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack(spacing: 16) {
                        Label(preview.formattedDate, systemImage: "calendar")
                        Label(preview.formattedFileSize, systemImage: "doc")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section("Breakdown by Manufacturer") {
                ForEach(preview.manufacturerBreakdown, id: \.manufacturer) { item in
                    HStack {
                        Text(item.manufacturer)
                        Spacer()
                        Text("\(item.count)")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("Import Details")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    Text("All items will be created as rod inventory with quantity 1. You can edit the type and quantity after import.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if isImporting {
                Section {
                    HStack {
                        ProgressView()
                        Text("Importing inventory...")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func resultView(_ result: ImportResult) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Success icon and message
                VStack(spacing: 16) {
                    if result.hasFailures {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                    }

                    VStack(spacing: 8) {
                        Text(result.hasFailures ? "Partially Imported" : "Import Successful")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("\(result.successCount) of \(result.totalItems) items imported")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                // Statistics
                VStack(spacing: 12) {
                    HStack(spacing: 20) {
                        StatView(
                            title: "Success",
                            value: "\(result.successCount)",
                            color: .green
                        )

                        StatView(
                            title: "Failed",
                            value: "\(result.failedItems.count)",
                            color: result.hasFailures ? .red : .secondary
                        )

                        StatView(
                            title: "Success Rate",
                            value: String(format: "%.0f%%", result.successRate * 100),
                            color: result.successRate > 0.8 ? .green : .orange
                        )
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)

                // Failed items list
                if result.hasFailures {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundColor(.red)
                            Text("Failed Items")
                                .font(.headline)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(result.failedItems, id: \.code) { item in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.code)
                                        .font(.subheadline)
                                        .fontWeight(.medium)

                                    Text(item.error)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)

                                if item.code != result.failedItems.last?.code {
                                    Divider()
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                }

                // Done button
                Button {
                    onImportComplete?()
                    dismiss()
                } label: {
                    Text("Done")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top)
            }
            .padding()
        }
    }

    // MARK: - Helper Views

    private struct StatView: View {
        let title: String
        let value: String
        let color: Color

        var body: some View {
            VStack(spacing: 6) {
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                    .monospacedDigit()

                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Actions

    private func loadPreview() async {
        do {
            let preview = try await importService.previewImport(from: fileURL)
            await MainActor.run {
                self.preview = preview
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
    }

    private func importInventory() async {
        await MainActor.run {
            isImporting = true
        }

        do {
            let result = try await importService.importInventory(from: fileURL)

            await MainActor.run {
                self.importResult = result
                self.isImporting = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isImporting = false
            }
        }
    }
}

#Preview {
    ImportInventoryView(fileURL: URL(fileURLWithPath: "/tmp/test.json"))
}
