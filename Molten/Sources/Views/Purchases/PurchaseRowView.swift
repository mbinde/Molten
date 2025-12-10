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
        Group {
            if let notes = purchase.notes, !notes.isEmpty {
                ListRowContainer(
                    header: { headerContent },
                    footer: { footerContent(notes) }
                )
            } else {
                ListRowContainer(
                    header: { headerContent }
                )
            }
        }
    }

    private var headerContent: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(purchase.supplier)
                    .font(.headline)
                    .lineLimit(1)

                Text(purchase.dateAdded, style: .date)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(purchase.formattedPrice ?? "—")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
        }
    }

    private func footerContent(_ notes: String) -> some View {
        Text(notes)
            .font(.caption)
            .foregroundColor(DesignSystem.Colors.textSecondary)
            .lineLimit(2)
            .padding(.top, 2)
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