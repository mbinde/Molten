//
//  FormComponents.swift
//  Flameworker
//
//  Created by Assistant on 9/29/25.
//

import SwiftUI
import CoreData
import Combine
import Foundation

/// Reusable form components to eliminate duplication across forms

// MARK: - Inventory Form Sections

/// Reusable form section for inventory input (count, units, type, notes)
struct InventoryFormSection: View {
    let title: String
    let icon: String
    let color: Color
    
    @Binding var count: String
    @Binding var units: InventoryUnits
    @Binding var selectedType: InventoryItemType
    @Binding var notes: String
    
    var body: some View {
        Section {
            CountUnitsTypeInputRow(count: $count, units: $units, selectedType: $selectedType)
            
            NotesInputField(notes: $notes)
        } header: {
            Label(title, systemImage: icon)
                .foregroundColor(color)
        }
    }
}

/// Reusable count, units, and type input row
struct CountUnitsTypeInputRow: View {
    @Binding var count: String
    @Binding var units: InventoryUnits
    @Binding var selectedType: InventoryItemType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("Count", text: $count)
                    .keyboardType(.decimalPad)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Units")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Picker("Units", selection: $units) {
                    ForEach(InventoryUnits.allCases) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Type")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("Type", selection: $selectedType) {
                    ForEach(InventoryItemType.allCases) { itemType in
                        HStack {
                            Image(systemName: itemType.systemImageName)
                                .foregroundColor(itemType.color)
                            Text(itemType.displayName)
                        }
                        .tag(itemType)
                    }
                }
                .pickerStyle(.segmented)
            }
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
    @Binding var catalogCode: String
    
    var body: some View {
        Section("General") {
            TextField("Catalog Code", text: $catalogCode)
                .textInputAutocapitalization(.words)
        }
    }
}

// MARK: - Form State Management

/// Centralized form state for inventory items
@MainActor
final class InventoryFormState: ObservableObject {
    @Published var catalogCode = ""
    @Published var count = ""
    @Published var units: InventoryUnits = .shorts
    @Published var selectedType: InventoryItemType = .inventory
    @Published var notes = ""
    
    // UI state
    @Published var isLoading = false
    @Published var showingError = false
    @Published var errorMessage = ""
    
    /// Initialize with empty values (for adding new items)
    init() {}
    
    /// Initialize from existing inventory item (for editing)
    init(from item: InventoryItem) {
        catalogCode = item.catalog_code ?? ""
        count = String(item.count)
        units = item.unitsKind
        selectedType = item.itemType
        notes = item.notes ?? ""
    }
    
    /// Reset all fields to empty values
    func reset() {
        catalogCode = ""
        count = ""
        units = .shorts
        selectedType = .inventory
        notes = ""
        
        errorMessage = ""
        showingError = false
    }
    
    /// Validate form data
    func validate() -> Bool {
        // At least one field should have content
        let hasContent = !catalogCode.isEmpty ||
                        !count.isEmpty || !notes.isEmpty
        
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
        
        let countValue = Double(count) ?? 0.0
        let unitsValue = units.rawValue
        
        return try InventoryService.shared.createInventoryItem(
            catalogCode: catalogCode.isEmpty ? nil : catalogCode,
            count: countValue,
            units: unitsValue,
            type: selectedType.rawValue,
            notes: notes.isEmpty ? nil : notes,
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
        
        let countValue = Double(count) ?? 0.0
        let unitsValue = units.rawValue
        
        try InventoryService.shared.updateInventoryItem(
            item,
            catalogCode: catalogCode.isEmpty ? nil : catalogCode,
            count: countValue,
            units: unitsValue,
            type: selectedType.rawValue,
            notes: notes.isEmpty ? nil : notes,
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
    @StateObject private var formState: InventoryFormState
    let editingItem: InventoryItem?
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    init(editingItem: InventoryItem? = nil) {
        self.editingItem = editingItem
        self._formState = StateObject(wrappedValue: InventoryFormState())
    }
    
    var body: some View {
        Form {
            GeneralFormSection(
                catalogCode: $formState.catalogCode
            )
            
            InventoryFormSection(
                title: "Item Details",
                icon: "archivebox.fill",
                color: .green,
                count: $formState.count,
                units: $formState.units,
                selectedType: $formState.selectedType,
                notes: $formState.notes
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
                formState.catalogCode = item.catalog_code ?? ""
                formState.count = String(item.count)
                formState.units = item.unitsKind
                formState.selectedType = item.itemType
                formState.notes = item.notes ?? ""
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
