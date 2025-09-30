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
    @State private var date = Date()
    @State private var paymentMethod = ""
    @State private var notes = ""
    
    @FocusState private var isSupplierFocused: Bool
    
    let paymentMethods = ["Cash", "Credit Card", "Debit Card", "Check", "Bank Transfer", "Other"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Purchase Information") {
                    TextField("Supplier Name", text: $supplier)
                        .focused($isSupplierFocused)
                    
                    HStack {
                        Text("$")
                        TextField("0.00", text: $totalAmount)
                            .keyboardType(.decimalPad)
                    }
                    
                    DatePicker("Purchase Date", selection: $date, displayedComponents: .date)
                    
                    Picker("Payment Method", selection: $paymentMethod) {
                        Text("Select Payment Method").tag("")
                        ForEach(paymentMethods, id: \.self) { method in
                            Text(method).tag(method)
                        }
                    }
                }
                
                Section("Notes") {
                    TextField("Additional notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
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
        }
    }
    
    private var isValidForm: Bool {
        !supplier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !totalAmount.isEmpty &&
        Double(totalAmount) != nil &&
        Double(totalAmount) ?? 0 >= 0
    }
    
    private func savePurchaseRecord() {
        guard let amount = Double(totalAmount) else { return }
        
        let newRecord = PurchaseRecord(context: viewContext)
        
        newRecord.setValue(supplier.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "supplier")
        newRecord.setValue(amount, forKey: "totalAmount")
        newRecord.setValue(date, forKey: "date")
        newRecord.setValue(paymentMethod.isEmpty ? nil : paymentMethod, forKey: "paymentMethod")
        newRecord.setValue(notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes, forKey: "notes")
        
        // Set timestamps if the entity supports them
        if let _ = newRecord.entity.attributesByName["createdAt"] {
            newRecord.setValue(Date(), forKey: "createdAt")
        }
        if let _ = newRecord.entity.attributesByName["modifiedAt"] {
            newRecord.setValue(Date(), forKey: "modifiedAt")
        }
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error saving purchase record: \(error)")
        }
    }
}

#Preview {
    AddPurchaseRecordView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
