//
//  PurchaseRecordDetailView.swift
//  Flameworker
//
//  Created by Assistant on 9/30/25.
//

import SwiftUI
import CoreData

struct PurchaseRecordDetailView: View {
    @ObservedObject var purchaseRecord: PurchaseRecord
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingEditSheet = false
    @State private var showingAddItem = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Information
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Supplier")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(purchaseRecord.supplier ?? "Unknown Supplier")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Total Amount")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(purchaseRecord.formattedAmount)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    if let date = purchaseRecord.date {
                        HStack {
                            Text("Date")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(date, style: .date)
                                .font(.body)
                        }
                    }
                    
                    if let paymentMethod = purchaseRecord.paymentMethod, !paymentMethod.isEmpty {
                        HStack {
                            Text("Payment Method")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(paymentMethod)
                                .font(.body)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Notes Section
                if let notes = purchaseRecord.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)
                        Text(notes)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                // Purchase Items Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Items (\(purchaseRecord.itemCount))")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button("Add Item") {
                            showingAddItem = true
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }
                    
                    if purchaseRecord.itemCount > 0 {
                        ForEach(purchaseRecord.purchaseItemsArray, id: \.objectID) { item in
                            PurchaseItemRowView(item: item)
                        }
                    } else {
                        Text("No items added yet")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Purchase Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Edit") {
                        showingEditSheet = true
                    }
                    Button("Delete", role: .destructive) {
                        showingDeleteAlert = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditPurchaseRecordView(purchaseRecord: purchaseRecord)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingAddItem) {
            AddPurchaseItemView(purchaseRecord: purchaseRecord)
                .environment(\.managedObjectContext, viewContext)
        }
        .alert("Delete Purchase Record", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deletePurchaseRecord()
            }
        } message: {
            Text("Are you sure you want to delete this purchase record? This action cannot be undone.")
        }
    }
    
    private func deletePurchaseRecord() {
        viewContext.delete(purchaseRecord)
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error deleting purchase record: \(error)")
        }
    }
}

struct PurchaseItemRowView: View {
    @ObservedObject var item: PurchaseItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayName)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    if let catalogCode = item.catalogCode, !catalogCode.isEmpty {
                        Text("Code: \(catalogCode)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(item.formattedTotalCost)
                        .font(.body)
                        .fontWeight(.semibold)
                    
                    Text("Qty: \(item.quantity) @ \(item.formattedPrice)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let notes = item.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    
    let sampleRecord = PurchaseRecord(context: context)
    sampleRecord.id = UUID()
    sampleRecord.supplier = "Mountain Glass Supply"
    sampleRecord.totalAmount = 324.50
    sampleRecord.date = Date()
    sampleRecord.paymentMethod = "Credit Card"
    sampleRecord.notes = "Monthly order of glass rods and tools"
    
    let item1 = PurchaseItem(context: context)
    item1.itemName = "Clear Glass Rod 7mm"
    item1.quantity = 10
    item1.price = 15.50
    item1.catalogCode = "CGR-7MM"
    sampleRecord.addToPurchaseItems(item1)
    
    let item2 = PurchaseItem(context: context)
    item2.itemName = "Blue Glass Rod 5mm"
    item2.quantity = 5
    item2.price = 18.00
    item2.catalogCode = "BGR-5MM"
    sampleRecord.addToPurchaseItems(item2)
    
    return NavigationView {
        PurchaseRecordDetailView(purchaseRecord: sampleRecord)
    }
    .environment(\.managedObjectContext, context)
}