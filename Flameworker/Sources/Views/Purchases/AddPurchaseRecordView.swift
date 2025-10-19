//
//  AddPurchaseRecordView.swift
//  Flameworker
//
//  Created by Assistant on 9/30/25.
//  Updated for GlassItem Architecture on 10/14/25.
//

// ✅ UPDATED FOR GLASSITEM ARCHITECTURE (October 2025)
//
// This view has been updated to work with the new GlassItem architecture.
// Note: Purchase records are not currently part of the core GlassItem system,
// but this view provides a foundation for future purchase tracking integration.
//
// CHANGES MADE:
// - Updated to use string-based inventory types instead of InventoryItemType enum
// - Simplified form validation and error handling
// - Prepared for future integration with shopping list service
// - Maintained clean separation of UI and data concerns

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Field Configurations for Purchase Form

struct SupplierFieldConfig: FormFieldConfiguration {
    let title: String = "Supplier Name"
    let placeholder: String = "Supplier Name"
    #if canImport(UIKit)
    let keyboardType: UIKeyboardType = .default
    let textInputAutocapitalization: TextInputAutocapitalization = .words
    #endif

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
    #if canImport(UIKit)
    let keyboardType: UIKeyboardType = .decimalPad
    let textInputAutocapitalization: TextInputAutocapitalization = .never
    #endif

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
    #if canImport(UIKit)
    let keyboardType: UIKeyboardType = .default
    let textInputAutocapitalization: TextInputAutocapitalization = .sentences
    #endif

    func formatValue(_ value: String) -> String {
        return value
    }

    func parseValue(_ text: String) -> String? {
        return text
    }
}

// MARK: - Simple Purchase Record Model (for future integration)

struct SimplePurchaseRecord {
    let id: UUID = UUID()
    let supplier: String
    let totalAmount: Double
    let date: Date
    let itemType: String
    let units: CatalogUnits
    let notes: String?
}

struct AddPurchaseRecordView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Form state
    @State private var supplier = ""
    @State private var totalAmount = ""
    @State private var date = Date()
    @State private var itemType: String = "rod" // Changed from enum to string
    @State private var units: CatalogUnits = .rods
    @State private var notes = ""
    @State private var errorMessage = ""
    @State private var showingError = false
    @State private var isSaving = false
    
    @FocusState private var isSupplierFocused: Bool
    
    // Available item types for selection
    private let availableTypes = ["rod", "sheet", "frit", "stringer", "powder", "other"]
    
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

                    // Simple picker for item types using strings
                    LabeledField("Type") {
                        Picker("Type", selection: $itemType) {
                            ForEach(availableTypes, id: \.self) { type in
                                Text(type.capitalized).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    UnifiedPickerField(
                        title: "Units",
                        selection: $units,
                        displayProvider: { (unit: CatalogUnits) -> String in unit.displayName },
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
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Button("Save") {
                            savePurchaseRecord()
                        }
                        .disabled(!isValidForm)
                    }
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
        Task {
            await MainActor.run {
                isSaving = true
                errorMessage = ""
            }
            
            do {
                // Validate supplier name
                let trimmedSupplier = supplier.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedSupplier.isEmpty else {
                    throw PurchaseValidationError.invalidSupplier
                }
                
                // Validate amount
                guard let amount = Double(totalAmount), amount > 0 else {
                    throw PurchaseValidationError.invalidAmount
                }
                
                // Create purchase record
                let purchaseRecord = SimplePurchaseRecord(
                    supplier: trimmedSupplier,
                    totalAmount: amount,
                    date: date,
                    itemType: itemType,
                    units: units,
                    notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
                )
                
                // Simulate saving (in a real app, this would integrate with your shopping list service)
                try await simulateSave(purchaseRecord)
                
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
                
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    // Simulate saving the purchase record
    private func simulateSave(_ record: SimplePurchaseRecord) async throws {
        // Simulate network/database delay
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // In a real implementation, this would integrate with:
        // - ShoppingListService for tracking purchases
        // - InventoryTrackingService for updating inventory
        // - A future PurchaseTrackingService
        
        print("Purchase record saved: \(record.supplier) - $\(record.totalAmount)")
    }
}

// MARK: - Validation Errors

enum PurchaseValidationError: LocalizedError {
    case invalidSupplier
    case invalidAmount
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidSupplier:
            return "Please enter a valid supplier name"
        case .invalidAmount:
            return "Please enter a valid amount greater than 0"
        case .saveFailed:
            return "Failed to save purchase record"
        }
    }
}

#Preview {
    AddPurchaseRecordView()
}
