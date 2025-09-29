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
    @Binding var units: String
    @Binding var type: String
    @Binding var notes: String
    
    var body: some View {
        Section {
            CountUnitsTypeInputRow(count: $count, units: $units, type: $type)
            
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
    @Binding var units: String
    @Binding var type: String
    
    var body: some View {
        HStack {
            TextField("Count", text: $count)
                .keyboardType(.decimalPad)
            
            TextField("Units", text: $units)
                .keyboardType(.numberPad)
            
            TextField("Type", text: $type)
                .keyboardType(.numberPad)
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
    @Published var units = ""
    @Published var type = ""
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
        units = String(item.units)
        type = String(item.type)
        notes = item.notes ?? ""
    }
    
    /// Reset all fields to empty values
    func reset() {
        catalogCode = ""
        count = ""
        units = ""
        type = ""
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
        let unitsValue = Int16(units) ?? 0
        let typeValue = Int16(type) ?? 0
        
        return try InventoryService.shared.createInventoryItem(
            catalogCode: catalogCode.isEmpty ? nil : catalogCode,
            count: countValue,
            units: unitsValue,
            type: typeValue,
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
        let unitsValue = Int16(units) ?? 0
        let typeValue = Int16(type) ?? 0
        
        try InventoryService.shared.updateInventoryItem(
            item,
            catalogCode: catalogCode.isEmpty ? nil : catalogCode,
            count: countValue,
            units: unitsValue,
            type: typeValue,
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
                type: $formState.type,
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
                formState.units = String(item.units)
                formState.type = String(item.type)
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