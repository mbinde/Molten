//
//  PurchaseRowView.swift  
//  Flameworker
//
//  Created by Assistant on 9/30/25.
//  Note: Renamed from PurchaseRecordRowView to avoid duplicate file conflicts
//

import SwiftUI
import CoreData

struct PurchaseRowView: View {
    let purchase: NSManagedObject
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(purchase.value(forKey: "supplier") as? String ?? "Unknown Supplier")
                        .font(.headline)
                        .lineLimit(1)
                    
                    if let date = purchase.value(forKey: "date") as? Date {
                        Text(date, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatCurrency(purchase.value(forKey: "totalAmount") as? Double ?? 0.0))
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
            }
            
            // Notes preview
            if let notes = purchase.value(forKey: "notes") as? String, !notes.isEmpty {
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
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let samplePurchase = NSManagedObject(entity: NSEntityDescription.entity(forEntityName: "PurchaseRecord", in: context)!, insertInto: context)
    samplePurchase.setValue("Mountain Glass", forKey: "supplier")
    samplePurchase.setValue(125.50, forKey: "totalAmount")
    samplePurchase.setValue(Date(), forKey: "date")
    samplePurchase.setValue("Monthly glass rod order", forKey: "notes")
    
    return List {
        PurchaseRowView(purchase: samplePurchase)
        PurchaseRowView(purchase: samplePurchase)
    }
    .environment(\.managedObjectContext, context)
}