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

    // ViewModel manages all form state
    @State private var viewModel = AddPurchaseRecordViewModel()

    @FocusState private var isSupplierFocused: Bool

    // Available item types for selection
    private let availableTypes = ["rod", "sheet", "frit", "stringer", "powder", "other"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Purchase Information") {
                    UnifiedFormField(
                        config: SupplierFieldConfig(),
                        value: $viewModel.supplier
                    )
                    .focused($isSupplierFocused)
                    .accessibilityIdentifier("purchase.add.supplierField")

                    HStack {
                        Text("$")
                        UnifiedFormField(
                            config: AmountFieldConfig(),
                            value: $viewModel.totalAmount
                        )
                        .accessibilityIdentifier("purchase.add.amountField")
                    }

                    DateAddedInputField(dateAdded: $viewModel.date)
                        .accessibilityIdentifier("purchase.add.datePicker")

                    // Simple picker for item types using strings
                    LabeledField("Type") {
                        Picker("Type", selection: $viewModel.itemType) {
                            ForEach(availableTypes, id: \.self) { type in
                                Text(type.capitalized).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        .accessibilityIdentifier("purchase.add.typePicker")
                    }

                    UnifiedPickerField(
                        title: "Units",
                        selection: $viewModel.units,
                        displayProvider: { (unit: CatalogUnits) -> String in unit.displayName },
                        style: .menu
                    )
                    .accessibilityIdentifier("purchase.add.unitsPicker")
                }

                Section("Notes") {
                    UnifiedMultilineFormField(
                        config: PurchaseNotesFieldConfig(),
                        value: $viewModel.notes,
                        lineLimit: 3...6
                    )
                    .accessibilityIdentifier("purchase.add.notesField")
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
                    .disabled(viewModel.isSaving)
                    .accessibilityIdentifier("purchase.add.cancelButton")
                }

                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSaving {
                        ProgressView()
                            .scaleEffect(0.8)
                            .accessibilityIdentifier("purchase.add.savingIndicator")
                    } else {
                        Button("Save") {
                            savePurchaseRecord()
                        }
                        .disabled(!viewModel.isValid)
                        .accessibilityIdentifier("purchase.add.saveButton")
                    }
                }
            }
            .onAppear {
                isSupplierFocused = true
            }
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK") { viewModel.showingError = false }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
    
    private func savePurchaseRecord() {
        Task {
            let success = await viewModel.save()
            if success {
                dismiss()
            }
        }
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
