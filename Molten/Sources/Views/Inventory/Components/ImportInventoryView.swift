//
//  ImportInventoryView.swift
//  Molten
//
//  View for importing inventory from JSON files created by the web import tool
//

import SwiftUI

@MainActor
struct ImportInventoryView: View {
    let fileURL: URL
    @Environment(\.dismiss) private var dismiss

    @State private var preview: ImportPreview?
    @State private var isLoading = true
    @State private var isImporting = false
    @State private var error: Error?
    @State private var importResult: ImportResult?
    @State private var selectedMode: InventoryImportMode = .addNewOnly
    @State private var showModeSelection = false

    // For interactive mode
    @State private var pendingDecision: (item: ImportItem, existing: InventoryModel)?
    @State private var showDecisionSheet = false
    @State private var decisionContinuation: CheckedContinuation<ImportItemAction, Never>?

    private let importService: InventoryImportService

    var onImportComplete: (() -> Void)?

    init(fileURL: URL, onImportComplete: (() -> Void)? = nil) {
        self.fileURL = fileURL
        self.onImportComplete = onImportComplete
        let service = InventoryImportService(
            catalogService: RepositoryFactory.createCatalogService(),
            inventoryTrackingService: RepositoryFactory.createInventoryTrackingService(),
            locationRepository: RepositoryFactory.createLocationRepository()
        )
        self.importService = service
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
            .sheet(isPresented: $showModeSelection) {
                modeSelectionSheet
            }
            .sheet(isPresented: $showDecisionSheet) {
                if let pending = pendingDecision {
                    itemDecisionSheet(item: pending.item, existing: pending.existing)
                }
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

            Section("Import Mode") {
                Button {
                    showModeSelection = true
                } label: {
                    HStack {
                        Image(systemName: selectedMode.icon)
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(selectedMode.displayName)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Text(selectedMode.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
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

                    Text("Items will be imported with the specified type, quantity, and storage location.")
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

                        if result.skippedCount > 0 {
                            Text("\(result.successCount) imported, \(result.skippedCount) skipped")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text("\(result.successCount) of \(result.totalItems) items imported")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
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

                        if result.skippedCount > 0 {
                            StatView(
                                title: "Skipped",
                                value: "\(result.skippedCount)",
                                color: .orange
                            )
                        }

                        StatView(
                            title: "Failed",
                            value: "\(result.failedItems.count)",
                            color: result.hasFailures ? .red : .secondary
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

        // Set delegate for interactive mode
        if selectedMode == .askPerItem {
            importService.delegate = self
        }

        do {
            let result = try await importService.importInventory(from: fileURL, mode: selectedMode)

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

    // MARK: - Mode Selection Sheet

    private var modeSelectionSheet: some View {
        NavigationStack {
            List {
                ForEach(InventoryImportMode.allCases) { mode in
                    Button {
                        selectedMode = mode
                        showModeSelection = false
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: mode.icon)
                                .font(.title2)
                                .foregroundColor(.orange)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(mode.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)

                                Text(mode.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer()

                            if mode == selectedMode {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Import Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        showModeSelection = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Item Decision Sheet

    private func itemDecisionSheet(item: ImportItem, existing: InventoryModel) -> some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Item info
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)

                    VStack(spacing: 4) {
                        Text("Item Already Exists")
                            .font(.title3)
                            .fontWeight(.semibold)

                        Text(item.name)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                // Current vs Import
                HStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("Current")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(Int(existing.quantity))")
                            .font(.title)
                            .fontWeight(.bold)
                        Text(existing.type)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)

                    Image(systemName: "arrow.right")
                        .foregroundColor(.secondary)

                    VStack(spacing: 8) {
                        Text("Importing")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(item.quantity)")
                            .font(.title)
                            .fontWeight(.bold)
                        Text(item.type)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                }

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        decisionContinuation?.resume(returning: .replace)
                        decisionContinuation = nil
                        showDecisionSheet = false
                    } label: {
                        Label("Replace (use \(item.quantity))", systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)

                    Button {
                        let total = Int(existing.quantity) + item.quantity
                        decisionContinuation?.resume(returning: .increase)
                        decisionContinuation = nil
                        showDecisionSheet = false
                    } label: {
                        let total = Int(existing.quantity) + item.quantity
                        Label("Increase (total: \(total))", systemImage: "plus.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    Button {
                        decisionContinuation?.resume(returning: .skip)
                        decisionContinuation = nil
                        showDecisionSheet = false
                    } label: {
                        Label("Skip", systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top)

                Spacer()
            }
            .padding()
            .navigationTitle("Conflict")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled()
    }
}

// MARK: - Import Delegate

extension ImportInventoryView: InventoryImportDelegate {
    func shouldImportItem(_ item: ImportItem, existing: InventoryModel) async -> ImportItemAction {
        return await withCheckedContinuation { continuation in
            self.decisionContinuation = continuation
            self.pendingDecision = (item, existing)
            self.showDecisionSheet = true
        }
    }
}

#Preview {
    ImportInventoryView(fileURL: URL(fileURLWithPath: "/tmp/test.json"))
}
