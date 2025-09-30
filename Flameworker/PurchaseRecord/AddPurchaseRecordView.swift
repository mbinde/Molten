//
//  AddPurchaseRecordView.swift
//  Flameworker
//
//  Created by Assistant on 9/30/25.
//

import SwiftUI
import CoreData
import Combine

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

// MARK: - Payment Method Enum

enum PaymentMethod: String, CaseIterable, Identifiable {
    case cash = "Cash"
    case creditCard = "Credit Card"
    case debitCard = "Debit Card"
    case check = "Check"
    case bankTransfer = "Bank Transfer"
    case other = "Other"
    case none = ""
    
    var id: String { rawValue }
    
    var displayName: String {
        return rawValue.isEmpty ? "Select Payment Method" : rawValue
    }
}

struct AddPurchaseRecordView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var errorState = ErrorAlertState()
    
    @State private var supplier = ""
    @State private var totalAmount = ""
    @State private var date = Date()
    @State private var paymentMethod: PaymentMethod = .none
    @State private var notes = ""
    
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
                        title: "Payment Method",
                        selection: $paymentMethod,
                        displayProvider: { $0.displayName },
                        style: .menu
                    )
                }
                
                Section("Notes") {
                    UnifiedMultilineFormField(
                        config: NotesFieldConfig(),
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
            .errorAlert(errorState)
        }
    }
    
    private var isValidForm: Bool {
        !supplier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !totalAmount.isEmpty &&
        Double(totalAmount) != nil &&
        Double(totalAmount) ?? 0 >= 0
    }
    
    private func savePurchaseRecord() {
        let result = ErrorHandler.shared.execute(context: "Saving purchase record") {
            guard let amount = Double(totalAmount) else {
                throw ErrorHandler.shared.createValidationError(
                    "Please enter a valid amount",
                    suggestions: ["Enter a number like 25.50", "Use only numbers and decimal point"]
                )
            }
            
            let newRecord = PurchaseRecord(context: viewContext)
            
            newRecord.setValue(supplier.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "supplier")
            newRecord.setValue(amount, forKey: "totalAmount")
            newRecord.setValue(date, forKey: "date")
            newRecord.setValue(paymentMethod == .none ? nil : paymentMethod.rawValue, forKey: "paymentMethod")
            newRecord.setValue(notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes, forKey: "notes")
            
            // Set timestamps if the entity supports them
            if let _ = newRecord.entity.attributesByName["createdAt"] {
                newRecord.setValue(Date(), forKey: "createdAt")
            }
            if let _ = newRecord.entity.attributesByName["modifiedAt"] {
                newRecord.setValue(Date(), forKey: "modifiedAt")
            }
            
            try viewContext.save()
        }
        
        switch result {
        case .success:
            dismiss()
        case .failure(let error):
            errorState.show(error: error, context: "Failed to save purchase record")
        }
    }
}

#Preview {
    AddPurchaseRecordView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
