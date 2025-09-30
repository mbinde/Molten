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
                    Text(purchase.supplier ?? "Unknown Supplier")
                        .font(.headline)
                        .lineLimit(1)
                    
                    if let date = purchase.date {
                        Text(date, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(purchase.formattedTotalAmount)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if purchase.itemCount > 0 {
                        Text("\(purchase.itemCount) item\(purchase.itemCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Notes preview
            if let notes = purchase.notes, !notes.isEmpty {
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
}

// MARK: - PurchaseRecord Extensions
extension PurchaseRecord {
    var formattedTotalAmount: String {
        return formattedAmount
    }
    
    var itemCount: Int {
        return 0 // No longer using purchaseItems relationship
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let samplePurchase = PurchaseRecord(context: context)
    samplePurchase.supplier = "Mountain Glass"
    samplePurchase.totalAmount = 125.50
    samplePurchase.date = Date()
    samplePurchase.notes = "Monthly glass rod order - various colors and sizes"
    
    return List {
        PurchaseRecordRowView(purchase: samplePurchase)
        PurchaseRecordRowView(purchase: samplePurchase)
    }
    .environment(\.managedObjectContext, context)
}