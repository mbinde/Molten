//
//  InventoryEditView.swift
//  Molten
//
//  Quick edit form for updating an inventory record
//

import SwiftUI

/// Quick edit form for updating an inventory record
struct InventoryEditView: View {
    let record: InventoryModel
    let inventoryRepository: InventoryRepository
    let storageLocationDefinitionRepository: StorageLocationDefinitionRepository

    @Environment(\.dismiss) private var dismiss
    @State private var quantity: String
    @State private var location: String
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingDeleteConfirmation = false

    init(record: InventoryModel, inventoryRepository: InventoryRepository, storageLocationDefinitionRepository: StorageLocationDefinitionRepository) {
        self.record = record
        self.inventoryRepository = inventoryRepository
        self.storageLocationDefinitionRepository = storageLocationDefinitionRepository
        // Format quantity without decimal if it's a whole number
        let quantityString = record.quantity.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", record.quantity)
            : String(format: "%.1f", record.quantity)
        self._quantity = State(initialValue: quantityString)
        self._location = State(initialValue: record.location ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    LabeledContent("Type", value: (record.type ?? "").capitalized)
                    if let subtype = record.subtype {
                        LabeledContent("Subtype", value: subtype.capitalized)
                    }
                    if let dimensions = record.dimensions, !dimensions.isEmpty {
                        LabeledContent("Dimensions", value: GlassItemTypeSystem.formatDimensions(dimensions, for: record.type ?? ""))
                    }
                }

                Section("Edit") {
                    TextField("Quantity", text: $quantity)
                        .keyboardType(.decimalPad)
                    LocationAutoCompleteField(
                        location: $location,
                        storageLocationDefinitionRepository: storageLocationDefinitionRepository
                    )
                }

                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            if isDeleting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text("Delete Inventory Record")
                            }
                            Spacer()
                        }
                    }
                    .disabled(isSaving || isDeleting)
                    .accessibilityIdentifier("inventory_edit_delete")
                }
            }
            .navigationTitle("Edit Inventory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("inventory_edit_cancel")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(isSaving)
                    .accessibilityIdentifier("inventory_edit_save")
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .confirmationDialog(
                "Delete Inventory Record",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    deleteRecord()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this inventory record? This cannot be undone.")
            }
        }
    }

    private func deleteRecord() {
        isDeleting = true

        Task {
            do {
                try await inventoryRepository.deleteInventory(id: record.id)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
                    errorMessage = "Failed to delete: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }

    private func saveChanges() {
        guard let quantityValue = Double(quantity), quantityValue > 0 else {
            errorMessage = "Please enter a valid quantity"
            showingError = true
            return
        }

        isSaving = true

        Task {
            do {
                let updatedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
                let finalLocation = updatedLocation.isEmpty ? nil : updatedLocation

                // Create updated inventory model preserving all fields except quantity and location
                let updatedRecord = InventoryModel(
                    id: record.id,
                    item_stable_id: record.item_stable_id,
                    type: record.type ?? "",
                    subtype: record.subtype,
                    subsubtype: record.subsubtype,
                    dimensions: record.dimensions,
                    quantity: quantityValue,
                    location: finalLocation,
                    date_added: record.date_added,
                    date_modified: Date()
                )

                try await inventoryRepository.updateInventory(updatedRecord)

                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to save: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
}
