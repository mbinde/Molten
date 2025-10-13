//
//  AddPurchaseRecordView.swift
//  Flameworker
//
//  Created by Assistant on 9/30/25.
//

// ✅ UPDATED FOR REPOSITORY PATTERN MIGRATION (October 2025)
//
// This view has been migrated from direct Core Data usage to the repository pattern.
//
// CHANGES MADE:
// - Removed @Environment(\.managedObjectContext) dependency
// - Added PurchaseRecordService dependency injection (renamed from PurchaseService for clarity)
// - Updated to use PurchaseRecordModel instead of Core Data PurchaseRecord entity
// - Async/await pattern for service calls
// - Clean separation of UI and persistence concerns

import SwiftUI

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
    @Environment(\.dismiss) private var dismiss
    
    // Use repository pattern instead of Core Data context
    private let purchaseRecordService: PurchaseRecordService
    
    @State private var supplier = ""
    @State private var totalAmount = ""
    @State private var date = Date()
    @State private var itemType: InventoryItemType = .inventory
    @State private var units: CatalogUnits = .rods
    @State private var notes = ""
    @State private var errorMessage = ""
    @State private var showingError = false
    
    @FocusState private var isSupplierFocused: Bool
    
    init(purchaseRecordService: PurchaseRecordService? = nil) {
        // Use provided service or create default one
        if let service = purchaseRecordService {
            self.purchaseRecordService = service
        } else {
            // Create default service with mock repository for previews
            let mockRepository = MockPurchaseRecordRepository()
            self.purchaseRecordService = PurchaseRecordService(repository: mockRepository)
        }
    }
    
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
        Task {
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
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        showingError = true
                    }
                    return
                }
                
                // Handle amount validation  
                switch amountResult {
                case .success(let value):
                    validatedAmount = value
                case .failure(let error):
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        showingError = true
                    }
                    return
                }
                
                // Create PurchaseRecordModel using repository pattern
                let purchaseRecord = PurchaseRecordModel(
                    supplier: validatedSupplier,
                    price: validatedAmount,
                    dateAdded: date,
                    notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
                )
                
                // Save through service layer
                _ = try await purchaseRecordService.createRecord(purchaseRecord)
                
                await MainActor.run {
                    dismiss()
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

#Preview {
    AddPurchaseRecordView()
}
