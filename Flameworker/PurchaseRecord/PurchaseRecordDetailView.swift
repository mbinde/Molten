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
    @StateObject private var errorState = ErrorAlertState()
    
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
                            Text(supplierText)
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Total Amount")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formattedAmount)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    if let date = purchaseDate {
                        HStack {
                            Text("Date")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(date, style: .date)
                                .font(.body)
                        }
                    }
                    
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Notes Section
                if let notes = notesText, !notes.isEmpty {
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
                        Text("Items")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button("Add Item") {
                            showingAddItem = true
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }
                    
                    Text("No items added yet")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .italic()
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
            // TODO: Create proper EditPurchaseRecordView
            Text("Edit functionality coming soon...")
                .navigationTitle("Edit Purchase")
        }
        .sheet(isPresented: $showingAddItem) {
            Text("Add Item - Not Implemented Yet")
                .navigationTitle("Add Item")
        }
        .alert("Delete Purchase Record", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deletePurchaseRecord()
            }
        } message: {
            Text("Are you sure you want to delete this purchase record? This action cannot be undone.")
        }
        .errorAlert(errorState)
    }
    
    // MARK: - Computed Properties
    
    private var supplierText: String {
        return (purchaseRecord.value(forKey: "supplier") as? String) ?? "Unknown Supplier"
    }
    
    private var purchaseDate: Date? {
        return purchaseRecord.value(forKey: "date") as? Date
    }
    
    private var totalAmount: Double {
        return (purchaseRecord.value(forKey: "totalAmount") as? Double) ?? 0.0
    }
    
    private var notesText: String? {
        let notes = purchaseRecord.value(forKey: "notes") as? String
        return notes?.isEmpty == false ? notes : nil
    }
    
    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: totalAmount)) ?? "$0.00"
    }
    
    private func deletePurchaseRecord() {
        let result = ErrorHandler.shared.execute(context: "Deleting purchase record") {
            viewContext.delete(purchaseRecord)
            try viewContext.save()
        }
        
        switch result {
        case .success:
            dismiss()
        case .failure(let error):
            errorState.show(error: error, context: "Failed to delete purchase record")
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    
    let sampleRecord = PurchaseRecord(context: context)
    sampleRecord.setValue(UUID(), forKey: "id")
    sampleRecord.setValue("Mountain Glass Supply", forKey: "supplier")
    sampleRecord.setValue(324.50, forKey: "totalAmount")
    sampleRecord.setValue(Date(), forKey: "date")
    sampleRecord.setValue("Monthly order of glass rods and tools", forKey: "notes")
    
    return NavigationView {
        PurchaseRecordDetailView(purchaseRecord: sampleRecord)
    }
    .environment(\.managedObjectContext, context)
}
