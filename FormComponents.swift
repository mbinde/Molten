//
//  FormComponents.swift
//  Flameworker
//
//  Created by Assistant on 9/29/25.
//

import SwiftUI

/// Reusable form components to eliminate duplication across forms

// MARK: - Inventory Form Sections

/// Reusable form section for inventory-related input (amount, units, notes)
struct InventoryFormSection: View {
    let title: String
    let icon: String
    let color: Color
    
    @Binding var amount: String
    @Binding var units: String  
    @Binding var notes: String
    
    var body: some View {
        Section {
            AmountUnitsInputRow(amount: $amount, units: $units)
            
            NotesInputField(notes: $notes)
        } header: {
            Label(title, systemImage: icon)
                .foregroundColor(color)
        }
    }
}

/// Reusable amount and units input row
struct AmountUnitsInputRow: View {
    @Binding var amount: String
    @Binding var units: String
    
    var body: some View {
        HStack {
            TextField("Amount", text: $amount)
                .keyboardType(.numbersAndPunctuation)
            
            TextField("Units", text: $units)
                .textInputAutocapitalization(.words)
        }
    }
}

/// Reusable notes input field with consistent styling
struct NotesInputField: View {
    @Binding var notes: String
    
    var body: some View {
        TextField("Notes", text: $notes, axis: .vertical)
            .lineLimit(2...4)
            .textInputAutocapitalization(.sentences)
    }
}

/// Reusable general information section
struct GeneralFormSection: View {
    @Binding var customTags: String
    @Binding var isFavorite: Bool
    
    var body: some View {
        Section("General") {
            TextField("Custom Tags", text: $customTags)
                .textInputAutocapitalization(.words)
            
            Toggle("Favorite", isOn: $isFavorite)
        }
    }
}

// MARK: - Form State Management

/// Centralized form state for inventory items
@MainActor
class InventoryFormState: ObservableObject {
    @Published var customTags = ""
    @Published var isFavorite = false
    
    // Inventory section
    @Published var inventoryAmount = ""
    @Published var inventoryUnits = ""
    @Published var inventoryNotes = ""
    
    // Shopping section
    @Published var shoppingAmount = ""
    @Published var shoppingUnits = ""
    @Published var shoppingNotes = ""
    
    // For sale section
    @Published var forsaleAmount = ""
    @Published var forsaleUnits = ""
    @Published var forsaleNotes = ""
    
    // UI state
    @Published var isLoading = false
    @Published var showingError = false
    @Published var errorMessage = ""
    
    /// Initialize with empty values (for adding new items)
    init() {}
    
    /// Initialize from existing inventory item (for editing)
    init(from item: InventoryItem) {
        customTags = item.custom_tags ?? ""
        isFavorite = InventoryService.shared.isFavorite(item)
        
        inventoryAmount = item.inventory_amount ?? ""
        inventoryUnits = item.inventory_units ?? ""
        inventoryNotes = item.inventory_notes ?? ""
        
        shoppingAmount = item.shopping_amount ?? ""
        shoppingUnits = item.shopping_units ?? ""
        shoppingNotes = item.shopping_notes ?? ""
        
        forsaleAmount = item.forsale_amount ?? ""
        forsaleUnits = item.forsale_units ?? ""
        forsaleNotes = item.forsale_notes ?? ""
    }
    
    /// Reset all fields to empty values
    func reset() {
        customTags = ""
        isFavorite = false
        
        inventoryAmount = ""
        inventoryUnits = ""
        inventoryNotes = ""
        
        shoppingAmount = ""
        shoppingUnits = ""
        shoppingNotes = ""
        
        forsaleAmount = ""
        forsaleUnits = ""
        forsaleNotes = ""
        
        errorMessage = ""
        showingError = false
    }
    
    /// Validate form data
    func validate() -> Bool {
        // At least one field should have content
        let hasContent = !customTags.isEmpty ||
                        !inventoryAmount.isEmpty || !inventoryNotes.isEmpty ||
                        !shoppingAmount.isEmpty || !shoppingNotes.isEmpty ||
                        !forsaleAmount.isEmpty || !forsaleNotes.isEmpty
        
        if !hasContent {
            errorMessage = "Please enter at least some information"
            showingError = true
            return false
        }
        
        return true
    }
    
    /// Create new inventory item from form state
    func createInventoryItem(in context: NSManagedObjectContext) throws -> InventoryItem {
        guard validate() else {
            throw FormError.validationFailed(errorMessage)
        }
        
        isLoading = true
        defer { isLoading = false }
        
        return try InventoryService.shared.createInventoryItem(
            customTags: customTags.isEmpty ? nil : customTags,
            isFavorite: isFavorite,
            inventoryAmount: inventoryAmount.isEmpty ? nil : inventoryAmount,
            inventoryUnits: inventoryUnits.isEmpty ? nil : inventoryUnits,
            inventoryNotes: inventoryNotes.isEmpty ? nil : inventoryNotes,
            shoppingAmount: shoppingAmount.isEmpty ? nil : shoppingAmount,
            shoppingUnits: shoppingUnits.isEmpty ? nil : shoppingUnits,
            shoppingNotes: shoppingNotes.isEmpty ? nil : shoppingNotes,
            forsaleAmount: forsaleAmount.isEmpty ? nil : forsaleAmount,
            forsaleUnits: forsaleUnits.isEmpty ? nil : forsaleUnits,
            forsaleNotes: forsaleNotes.isEmpty ? nil : forsaleNotes,
            in: context
        )
    }
    
    /// Update existing inventory item with form state
    func updateInventoryItem(_ item: InventoryItem, in context: NSManagedObjectContext) throws {
        guard validate() else {
            throw FormError.validationFailed(errorMessage)
        }
        
        isLoading = true
        defer { isLoading = false }
        
        try InventoryService.shared.updateInventoryItem(
            item,
            customTags: customTags.isEmpty ? nil : customTags,
            isFavorite: isFavorite,
            inventoryAmount: inventoryAmount.isEmpty ? nil : inventoryAmount,
            inventoryUnits: inventoryUnits.isEmpty ? nil : inventoryUnits,
            inventoryNotes: inventoryNotes.isEmpty ? nil : inventoryNotes,
            shoppingAmount: shoppingAmount.isEmpty ? nil : shoppingAmount,
            shoppingUnits: shoppingUnits.isEmpty ? nil : shoppingUnits,
            shoppingNotes: shoppingNotes.isEmpty ? nil : shoppingNotes,
            forsaleAmount: forsaleAmount.isEmpty ? nil : forsaleAmount,
            forsaleUnits: forsaleUnits.isEmpty ? nil : forsaleUnits,
            forsaleNotes: forsaleNotes.isEmpty ? nil : forsaleNotes,
            in: context
        )
    }
}

// MARK: - Form Error Handling

enum FormError: Error, LocalizedError {
    case validationFailed(String)
    case saveFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .validationFailed(let message):
            return message
        case .saveFailed(let message):
            return "Failed to save: \(message)"
        }
    }
}

// MARK: - Complete Form View

/// Complete inventory form using all reusable components
struct InventoryFormView: View {
    @StateObject private var formState = InventoryFormState()
    let editingItem: InventoryItem?
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    init(editingItem: InventoryItem? = nil) {
        self.editingItem = editingItem
    }
    
    var body: some View {
        Form {
            GeneralFormSection(
                customTags: $formState.customTags,
                isFavorite: $formState.isFavorite
            )
            
            InventoryFormSection(
                title: "Inventory",
                icon: "archivebox.fill",
                color: .green,
                amount: $formState.inventoryAmount,
                units: $formState.inventoryUnits,
                notes: $formState.inventoryNotes
            )
            
            InventoryFormSection(
                title: "Shopping List",
                icon: "cart.fill",
                color: .orange,
                amount: $formState.shoppingAmount,
                units: $formState.shoppingUnits,
                notes: $formState.shoppingNotes
            )
            
            InventoryFormSection(
                title: "For Sale",
                icon: "dollarsign.circle.fill",
                color: .blue,
                amount: $formState.forsaleAmount,
                units: $formState.forsaleUnits,
                notes: $formState.forsaleNotes
            )
        }
        .navigationTitle(editingItem == nil ? "Add Item" : "Edit Item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .disabled(formState.isLoading)
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button(editingItem == nil ? "Add" : "Save") {
                    saveItem()
                }
                .disabled(formState.isLoading)
            }
        }
        .onAppear {
            if let item = editingItem {
                formState.customTags = item.custom_tags ?? ""
                formState.isFavorite = InventoryService.shared.isFavorite(item)
                formState.inventoryAmount = item.inventory_amount ?? ""
                formState.inventoryUnits = item.inventory_units ?? ""
                formState.inventoryNotes = item.inventory_notes ?? ""
                formState.shoppingAmount = item.shopping_amount ?? ""
                formState.shoppingUnits = item.shopping_units ?? ""
                formState.shoppingNotes = item.shopping_notes ?? ""
                formState.forsaleAmount = item.forsale_amount ?? ""
                formState.forsaleUnits = item.forsale_units ?? ""
                formState.forsaleNotes = item.forsale_notes ?? ""
            }
        }
        .alert("Error", isPresented: $formState.showingError) {
            Button("OK") {
                formState.showingError = false
            }
        } message: {
            Text(formState.errorMessage)
        }
    }
    
    private func saveItem() {
        do {
            if let item = editingItem {
                try formState.updateInventoryItem(item, in: viewContext)
            } else {
                _ = try formState.createInventoryItem(in: viewContext)
            }
            dismiss()
        } catch {
            formState.errorMessage = error.localizedDescription
            formState.showingError = true
        }
    }
}