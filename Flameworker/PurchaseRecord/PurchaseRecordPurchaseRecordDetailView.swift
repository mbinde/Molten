//
//  PurchaseRecordDetailView.swift
//  Flameworker
//
//  Created by Assistant on 9/30/25.
//

import SwiftUI
import CoreData

struct PurchaseRecordDetailView: View {
    let purchase: PurchaseRecord
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var isEditing = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    headerSection
                    
                    // Main content
                    if isEditing {
                        editingForm
                    } else {
                        readOnlyContent
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle(isEditing ? "Edit Purchase" : "Purchase Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isEditing ? "Cancel" : "Done") {
                        if isEditing {
                            isEditing = false
                        } else {
                            dismiss()
                        }
                    }
                }
                
                if !isEditing {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Edit") {
                            isEditing = true
                        }
                    }
                } else {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Save") {
                            saveChanges()
                        }
                    }
                }
                
                ToolbarItem(placement: .destructiveAction) {
                    Button("Delete") {
                        showingDeleteAlert = true
                    }
                    .foregroundColor(.red)
                }
            }
            .alert("Delete Purchase Record", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deletePurchase()
                }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Views
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(purchase.supplier ?? "Unknown Supplier")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let date = purchase.date {
                    Text(date, style: .date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(purchase.formattedTotalAmount)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                if purchase.itemCount > 0 {
                    Text("\(purchase.itemCount) item\(purchase.itemCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.bottom, 10)
    }
    
    private var readOnlyContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Purchase Info
            sectionView(title: "Purchase Information") {
                VStack(alignment: .leading, spacing: 8) {
                    detailRow(label: "Supplier", value: purchase.supplier ?? "Unknown")
                    detailRow(label: "Total Amount", value: purchase.formattedTotalAmount)
                    
                    if let date = purchase.date {
                        detailRow(label: "Date", value: DateFormatter.mediumStyle.string(from: date))
                    }
                    
                    if let paymentMethod = purchase.paymentMethod, !paymentMethod.isEmpty {
                        detailRow(label: "Payment Method", value: paymentMethod)
                    }
                }
            }
            
            // Notes
            if let notes = purchase.notes, !notes.isEmpty {
                sectionView(title: "Notes") {
                    Text(notes)
                        .font(.body)
                }
            }
            
            // Purchase Items (if any)
            if let items = purchase.purchaseItems, items.count > 0 {
                sectionView(title: "Items Purchased") {
                    Text("Items: \(items.count)")
                        .font(.body)
                    // TODO: Add detailed item list when PurchaseItem entity is implemented
                }
            }
        }
    }
    
    private var editingForm: some View {
        VStack(spacing: 20) {
            Text("Editing functionality coming soon...")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding()
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionView<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            content()
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
    
    // MARK: - Actions
    
    private func saveChanges() {
        // TODO: Implement save functionality
        isEditing = false
    }
    
    private func deletePurchase() {
        viewContext.delete(purchase)
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("❌ Error deleting purchase record: \(error)")
        }
    }
}

// MARK: - Extensions
private extension DateFormatter {
    static let mediumStyle: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let samplePurchase = PurchaseRecord(context: context)
    samplePurchase.supplier = "Mountain Glass"
    samplePurchase.totalAmount = 125.50
    samplePurchase.date = Date()
    samplePurchase.notes = "Monthly glass rod order - various colors and sizes for upcoming projects"
    samplePurchase.paymentMethod = "Credit Card"
    
    return NavigationStack {
        PurchaseRecordDetailView(purchase: samplePurchase)
    }
    .environment(\.managedObjectContext, context)
}