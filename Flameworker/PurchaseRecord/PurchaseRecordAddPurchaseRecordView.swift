//
//  AddPurchaseRecordView.swift
//  Flameworker
//
//  Created by Assistant on 9/30/25.
//

import SwiftUI
import CoreData

struct AddPurchaseRecordView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var supplier = ""
    @State private var totalAmount = ""
    @State private var purchaseDate = Date()
    @State private var paymentMethod = ""
    @State private var notes = ""
    @State private var errorMessage: String?
    
    let paymentMethods = ["Cash", "Credit Card", "Debit Card", "Check", "PayPal", "Bank Transfer", "Other"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Purchase Details") {
                    HStack {
                        Text("Supplier")
                            .fontWeight(.medium)
                        TextField("Enter supplier name", text: $supplier)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Total Amount")
                            .fontWeight(.medium)
                        Spacer()
                        Text("$")
                            .foregroundColor(.secondary)
                        TextField("0.00", text: $totalAmount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
                    }
                    
                    DatePicker("Purchase Date", selection: $purchaseDate, displayedComponents: [.date])
                    
                    Picker("Payment Method", selection: $paymentMethod) {
                        Text("Select method").tag("")
                        ForEach(paymentMethods, id: \.self) { method in
                            Text(method).tag(method)
                        }
                    }
                }
                
                Section("Additional Information") {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .textInputAutocapitalization(.sentences)
                }
            }
            .navigationTitle("New Purchase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePurchase()
                    }
                    .disabled(!isValidPurchase)
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    // MARK: - Validation
    
    private var isValidPurchase: Bool {
        return !supplier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !totalAmount.isEmpty &&
               (Double(totalAmount) ?? 0) > 0
    }
    
    // MARK: - Actions
    
    private func savePurchase() {
        let trimmedSupplier = supplier.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedSupplier.isEmpty else {
            errorMessage = "Please enter a supplier name"
            return
        }
        
        guard let amount = Double(totalAmount), amount > 0 else {
            errorMessage = "Please enter a valid amount"
            return
        }
        
        withAnimation {
            let newPurchase = PurchaseRecord(context: viewContext)
            newPurchase.supplier = trimmedSupplier
            newPurchase.totalAmount = amount
            newPurchase.date = purchaseDate
            newPurchase.paymentMethod = paymentMethod.isEmpty ? nil : paymentMethod
            newPurchase.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            
            // Set creation timestamp if the entity has one
            if let entityDescription = newPurchase.entity.attributesByName["createdAt"] {
                newPurchase.setValue(Date(), forKey: "createdAt")
            }
            
            do {
                try viewContext.save()
                dismiss()
            } catch {
                errorMessage = "Failed to save purchase record: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    AddPurchaseRecordView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}