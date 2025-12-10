//
//  QuickAddInventoryView.swift
//  Molten
//
//  Quick add form for adding new inventory
//

import SwiftUI

/// Quick add form for adding new inventory
struct QuickAddInventoryView: View {
    let itemStableId: String
    let itemName: String
    let inventoryTrackingService: InventoryTrackingService
    let storageLocationDefinitionRepository: StorageLocationDefinitionRepository

    @Environment(\.dismiss) private var dismiss
    @State private var type = LastUsedInventoryTypePreference.type
    @State private var quantity = ""
    @State private var location = ""
    @State private var isSaving = false
    @State private var showingError = false
    @State private var errorMessage = ""

    private let types = ["rod", "tube", "sheet", "frit", "powder", "stringer", "twistie", "murrini", "cane"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    Text(itemName)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                Section("New Inventory") {
                    Picker("Type", selection: $type) {
                        ForEach(types, id: \.self) { type in
                            Text(type.capitalized).tag(type)
                        }
                    }

                    TextField("Quantity", text: $quantity)
                        .keyboardType(.decimalPad)

                    LocationAutoCompleteField(
                        location: $location,
                        storageLocationDefinitionRepository: storageLocationDefinitionRepository
                    )
                }
            }
            .navigationTitle("Add Inventory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("quick_add_inventory_cancel")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addInventory()
                    }
                    .disabled(isSaving)
                    .accessibilityIdentifier("quick_add_inventory_add")
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func addInventory() {
        guard let quantityValue = Double(quantity), quantityValue > 0 else {
            errorMessage = "Please enter a valid quantity"
            showingError = true
            return
        }

        isSaving = true

        Task {
            do {
                let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
                let finalLocation = trimmedLocation.isEmpty ? nil : trimmedLocation

                // Use service to add inventory - this also creates StorageLocation record
                _ = try await inventoryTrackingService.addInventory(
                    quantity: quantityValue,
                    type: type,
                    toItem: itemStableId,
                    atLocation: finalLocation
                )

                // Remember the type for next time
                LastUsedInventoryTypePreference.save(type: type, subtype: nil, subsubtype: nil)

                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to add inventory: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
}
