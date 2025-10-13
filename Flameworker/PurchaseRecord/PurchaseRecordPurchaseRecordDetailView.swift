//
//  PurchaseRecordDetailAlternateView.swift
//  Flameworker
//
//  Created by Assistant on 9/30/25.
//

import SwiftUI
import CoreData

// MARK: - Release Configuration
// Set to false for simplified release builds
private let isPurchaseRecordsEnabled = false

struct PurchaseRecordDetailAlternateView: View {
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
                Text(supplierText)
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let date = purchaseDate {
                    Text(date, style: .date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedTotalAmount)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                if itemCount > 0 {
                    Text("\(itemCount) item\(itemCount == 1 ? "" : "s")")
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
                    detailRow(label: "Supplier", value: supplierText)
                    detailRow(label: "Total Amount", value: formattedTotalAmount)
                    
                    if let date = purchaseDate {
                        detailRow(label: "Date", value: DateFormatter.detailFormatter.string(from: date))
                    }
                    
                    
                    detailRow(label: "Type", value: typeDisplayName)
                    detailRow(label: "Units", value: unitsDisplayName)
                }
            }
            
            // Notes
            if let notes = notesText, !notes.isEmpty {
                sectionView(title: "Notes") {
                    Text(notes)
                        .font(.body)
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
    
    // MARK: - Computed Properties
    
    private var supplierText: String {
        return (purchase.value(forKey: "supplier") as? String) ?? "Unknown Supplier"
    }
    
    private var purchaseDate: Date? {
        return purchase.value(forKey: "date") as? Date
    }
    
    private var totalAmount: Double {
        return (purchase.value(forKey: "totalAmount") as? Double) ?? 0.0
    }
    
    
    private var notesText: String? {
        let notes = purchase.value(forKey: "notes") as? String
        return notes?.isEmpty == false ? notes : nil
    }
    
    private var formattedTotalAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: totalAmount)) ?? "$0.00"
    }
    
    private var itemCount: Int {
        return 0 // No longer using purchaseItems relationship
    }
    
    private var typeDisplayName: String {
        let typeValue = purchase.value(forKey: "type") as? Int16 ?? 0
        let itemType = InventoryItemType(from: typeValue)
        return itemType.displayName
    }
    
    private var unitsDisplayName: String {
        let unitsValue = purchase.value(forKey: "units") as? Int16 ?? 0
        let units = InventoryUnits.fromLegacyInt16(unitsValue)
        return units.displayName
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
    static let detailFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

#Preview {
    NavigationStack {
        PurchaseRecordDetailAlternateView(purchase: PreviewData.samplePurchaseRecord)
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

// MARK: - Preview Data
private struct PreviewData {
    static var samplePurchaseRecord: PurchaseRecord {
        let context = PersistenceController.preview.container.viewContext
        let purchase = PurchaseRecord(context: context)
        purchase.setValue("Mountain Glass", forKey: "supplier")
        purchase.setValue(125.50, forKey: "totalAmount")
        purchase.setValue(Date(), forKey: "date")
        purchase.setValue("Monthly glass rod order - various colors and sizes for upcoming projects", forKey: "notes")
        purchase.setValue(Int16(1), forKey: "type") // .buy
        purchase.setValue(Int16(3), forKey: "units") // .pounds
        return purchase
    }
}
