//
//  PurchaseRowView.swift  
//  Flameworker
//
//  Created by Assistant on 9/30/25.
//  Note: Renamed from PurchaseRecordRowView to avoid duplicate file conflicts
//

import SwiftUI

struct PurchaseRowView: View {
    let purchase: PurchaseRecordModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(purchase.supplier)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(purchase.dateAdded, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(purchase.formattedPrice ?? "—")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
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

#Preview {
    let samplePurchase = PurchaseRecordModel(
        supplier: "Mountain Glass",
        subtotal: Decimal(string: "100.00"),
        tax: Decimal(string: "8.50"),
        shipping: Decimal(string: "17.00"),
        notes: "Monthly glass rod order"
    )

    List {
        PurchaseRowView(purchase: samplePurchase)
        PurchaseRowView(purchase: samplePurchase)
    }
}