//
//  PurchaseRecordRowView.swift
//  Flameworker
//
//  Created by Assistant on 9/30/25.
//

import SwiftUI
import CoreData

struct PurchaseRecordRowView: View {
    let purchase: PurchaseRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(supplierText)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if let date = purchaseDate {
                        Text(date, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formattedAmount)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if itemCount > 0 {
                        Text("\(itemCount) item\(itemCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Notes preview
            if let notes = notesText, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
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
    
    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: totalAmount)) ?? "$0.00"
    }
    
    private var itemCount: Int {
        return 0 // No longer using purchaseItems relationship
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let samplePurchase = PurchaseRecord(context: context)
    
    // Use setValue to safely set Core Data properties
    samplePurchase.setValue(UUID(), forKey: "id")
    samplePurchase.setValue("Mountain Glass", forKey: "supplier")
    samplePurchase.setValue(125.50, forKey: "totalAmount")
    samplePurchase.setValue(Date(), forKey: "date")
    samplePurchase.setValue("Monthly glass rod order - various colors and sizes", forKey: "notes")
    
    return List {
        PurchaseRecordRowView(purchase: samplePurchase)
        PurchaseRecordRowView(purchase: samplePurchase)
    }
    .environment(\.managedObjectContext, context)
}