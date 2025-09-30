//
//  AddPurchaseItemView.swift
//  Flameworker
//
//  Created by Assistant on 9/30/25.
//

import SwiftUI
import CoreData

struct AddPurchaseItemView: View {
    @ObservedObject var purchaseRecord: PurchaseRecord
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var itemName = ""
    @State private var catalogCode = ""
    @State private var quantity = "1"
    @State private var price = ""
    @State private var notes = ""
    
    @FocusState private var isItemNameFocused: Bool
    
    var body: some View {
        NavigationView {
            Form {
                Section("Item Information") {
                    TextField("Item Name", text: $itemName)
                        .focused($isItemNameFocused)
                    
                    TextField("Catalog Code (Optional)", text: $catalogCode)
                    
                    HStack {
                        Text("Quantity")
                        Spacer()
                        TextField("1", text: $quantity)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    
                    HStack {
                        Text("Price per item")
                        Spacer()
                        HStack {
                            Text("$")
                            TextField("0.00", text: $price)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        .frame(width: 100)
                    }
                }
                
                if let totalCost = calculateTotalCost() {
                    Section {
                        HStack {
                            Text("Total Cost")
                                .fontWeight(.semibold)
                            Spacer()
                            Text(formatCurrency(totalCost))
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                Section("Notes") {
                    TextField("Item notes...", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addPurchaseItem()
                    }
                    .disabled(!isValidForm)
                }
            }
            .onAppear {
                isItemNameFocused = true
            }
        }
    }
    
    private var isValidForm: Bool {
        !itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !quantity.isEmpty &&
        Int32(quantity) != nil &&
        Int32(quantity) ?? 0 > 0 &&
        !price.isEmpty &&
        Double(price) != nil &&
        Double(price) ?? 0 >= 0
    }
    
    private func calculateTotalCost() -> Double? {
        guard let qty = Int32(quantity),
              let unitPrice = Double(price) else {
            return nil
        }
        return Double(qty) * unitPrice
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
    
    private func addPurchaseItem() {
        guard let qty = Int32(quantity),
              let unitPrice = Double(price) else {
            return
        }
        
        let newItem = PurchaseItem(context: viewContext)
        newItem.id = UUID()
        newItem.itemName = itemName.trimmingCharacters(in: .whitespacesAndNewlines)
        newItem.catalogCode = catalogCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : catalogCode
        newItem.quantity = qty
        newItem.price = unitPrice
        newItem.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
        
        // Add the item to the purchase record
        purchaseRecord.addToPurchaseItems(newItem)
        
        // Update the total amount of the purchase record
        purchaseRecord.totalAmount += newItem.totalCost
        purchaseRecord.modifiedAt = Date()
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error adding purchase item: \(error)")
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let sampleRecord = PurchaseRecord(context: context)
    sampleRecord.supplier = "Mountain Glass Supply"
    sampleRecord.totalAmount = 100.0
    
    return AddPurchaseItemView(purchaseRecord: sampleRecord)
        .environment(\.managedObjectContext, context)
}