//
//  AddPurchaseRecordView.swift
//  Flameworker
//
//  Created by Assistant on 9/30/25.
//

import SwiftUI
import CoreData

// MARK: - Field Configurations for Purchase Form

struct SupplierFieldConfig: FormFieldConfiguration {
    let title: String = "Supplier Name"
    let placeholder: String = "Supplier Name"
    let keyboardType: UIKeyboardType = .default
    let textInputAutocapitalization: TextInputAutocapitalization = .words
    
    func formatValue(_ value: String) -> String {
        return value
    }
    
    func parseValue(_ text: String) -> String? {
        return text
    }
}

struct AmountFieldConfig: FormFieldConfiguration {
    let title: String = "Total Amount"
    let placeholder: String = "0.00"
    let keyboardType: UIKeyboardType = .decimalPad
    let textInputAutocapitalization: TextInputAutocapitalization = .never
    
    func formatValue(_ value: String) -> String {
        return value
    }
    
    func parseValue(_ text: String) -> String? {
        return text
    }
}

struct PurchaseNotesFieldConfig: FormFieldConfiguration {
    let title: String = "Notes"
    let placeholder: String = "Enter purchase notes..."
    let keyboardType: UIKeyboardType = .default
    let textInputAutocapitalization: TextInputAutocapitalization = .sentences
    
    func formatValue(_ value: String) -> String {
        return value
    }
    
    func parseValue(_ text: String) -> String? {
        return text
    }
}

struct AddPurchaseRecordView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var supplier = ""
    @State private var totalAmount = ""
    @State private var date = Date()
    @State private var itemType: InventoryItemType = .inventory
    @State private var units: InventoryUnits = .rods
    @State private var notes = ""
    @State private var errorMessage = ""
    @State private var showingError = false
    
    @FocusState private var isSupplierFocused: Bool
    
    var body: some View {
        NavigationView {
            Form {
                Section("Purchase Information") {
                    UnifiedFormField(
                        config: SupplierFieldConfig(),
                        value: $supplier
                    )
                    .focused($isSupplierFocused)
                    
                    HStack {
                        Text("$")
                        UnifiedFormField(
                            config: AmountFieldConfig(),
                            value: $totalAmount
                        )
                    }
                    
                    DateAddedInputField(dateAdded: $date)
                    
                    UnifiedPickerField(
                        title: "Type",
                        selection: $itemType,
                        displayProvider: { $0.displayName },
                        style: .menu
                    )
                    
                    UnifiedPickerField(
                        title: "Units",
                        selection: $units,
                        displayProvider: { $0.displayName },
                        style: .menu
                    )
                }
                
                Section("Notes") {
                    UnifiedMultilineFormField(
                        config: PurchaseNotesFieldConfig(),
                        value: $notes,
                        lineLimit: 3...6
                    )
                }
            }
            .navigationTitle("New Purchase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePurchaseRecord()
                    }
                    .disabled(!isValidForm)
                }
            }
            .onAppear {
                isSupplierFocused = true
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { showingError = false }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var isValidForm: Bool {
        !supplier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !totalAmount.isEmpty &&
        Double(totalAmount) != nil &&
        (Double(totalAmount) ?? 0) > 0
    }
    
    private func savePurchaseRecord() {
        do {
            // Validate input using our utilities
            let supplierResult = ValidationUtilities.validateSupplierName(supplier)
            let amountResult = ValidationUtilities.validatePurchaseAmount(totalAmount)
            
            let validatedSupplier: String
            let validatedAmount: Double
            
            // Handle supplier validation
            switch supplierResult {
            case .success(let value):
                validatedSupplier = value
            case .failure(let error):
                throw error
            }
            
            // Handle amount validation  
            switch amountResult {
            case .success(let value):
                validatedAmount = value
            case .failure(let error):
                throw error
            }
            
            // Create new record
            let newRecord = PurchaseRecord(context: viewContext)
            
            // Set properties using safe Core Data extensions
            newRecord.setString(validatedSupplier, forKey: "supplier")
            newRecord.setDouble(validatedAmount, forKey: "price")
            newRecord.setDate(date, forKey: "date_added")
            newRecord.setString(notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes, forKey: "notes")
            
            // Set type and units using direct Core Data calls
            newRecord.setValue(itemType.rawValue, forKey: "type")
            newRecord.setValue(units.rawValue, forKey: "units")
            
            // Set timestamps if the entity supports them
            if newRecord.entity.attributesByName["createdAt"] != nil {
                newRecord.setValue(Date(), forKey: "createdAt")
            }
            if newRecord.entity.attributesByName["modifiedAt"] != nil {
                newRecord.setValue(Date(), forKey: "modifiedAt")
            }
            
            // Save context
            try viewContext.save()
            dismiss()
            
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

#Preview {
    AddPurchaseRecordView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
