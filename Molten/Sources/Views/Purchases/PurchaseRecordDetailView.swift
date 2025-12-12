//
//  PurchaseRecordDetailView.swift
//  Flameworker
//
//  Created by Assistant on 9/30/25.
//

import SwiftUI

struct PurchaseRecordDetailView: View {
    @State private var purchaseRecord: PurchaseRecordModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var errorState = ErrorAlertState()

    private let catalogService: CatalogService

    @State private var showingEditSheet = false
    @State private var catalogItems: [String: UnifiedCatalogItem] = [:]

    init(purchaseRecord: PurchaseRecordModel, catalogService: CatalogService? = nil) {
        self._purchaseRecord = State(initialValue: purchaseRecord)

        if let service = catalogService {
            self.catalogService = service
        } else {
            self.catalogService = AppDependencies.shared.catalogService
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Information
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        LabeledDetailRow.prominent(
                            label: "Supplier",
                            value: purchaseRecord.supplier,
                            alignment: .leading
                        )

                        Spacer()

                        LabeledDetailRow.prominent(
                            label: "Total",
                            value: purchaseRecord.formattedPrice ?? "—",
                            alignment: .trailing
                        )
                    }

                    HStack {
                        LabeledDetailRow.horizontal(
                            label: "Date",
                            value: purchaseRecord.datePurchased.formatted(date: .abbreviated, time: .omitted)
                        )

                        Spacer()

                        if let orderNumber = purchaseRecord.orderNumber {
                            LabeledDetailRow.horizontal(
                                label: "Order #",
                                value: orderNumber
                            )
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)

                // Notes Section
                if let notes = purchaseRecord.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)
                        Text(notes)
                            .font(.body)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                }

                // Purchase Items Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Items (\(purchaseRecord.items.count))")
                        .font(.headline)

                    if purchaseRecord.items.isEmpty {
                        CustomEmptyStateView(
                            icon: "cart",
                            iconSize: 40,
                            title: "No Items",
                            description: "No items recorded for this purchase"
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 150)
                    } else {
                        ForEach(purchaseRecord.items) { item in
                            PurchaseItemRow(
                                item: item,
                                catalogItem: catalogItems[item.item_stable_id],
                                currency: purchaseRecord.currency
                            )
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Purchase Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await loadCatalogItems()
        }
        .errorAlert(errorState)
    }

    private func loadCatalogItems() async {
        // Batch fetch catalog items for all purchase items
        var items: [String: UnifiedCatalogItem] = [:]
        for purchaseItem in purchaseRecord.items {
            if let catalogItem = try? await catalogService.getCatalogItem(byStableId: purchaseItem.item_stable_id) {
                items[purchaseItem.item_stable_id] = catalogItem
            }
        }
        catalogItems = items
    }
}

// MARK: - Purchase Item Row

private struct PurchaseItemRow: View {
    let item: PurchaseRecordItemModel
    let catalogItem: UnifiedCatalogItem?
    let currency: String

    /// Display name: "Manufacturer Name" or fallback to stable_id
    private var displayName: String {
        if let catalogItem = catalogItem {
            return "\(catalogItem.manufacturer) \(catalogItem.name)"
        }
        return item.item_stable_id
    }

    /// Whether this is a container type (jar)
    private var isContainerType: Bool {
        return item.type.lowercased() == "jar"
    }

    /// Quantity with type: "10 rods", "1 lb frit", "2 jars of frit"
    private var quantityDescription: String {
        let qty = Int(item.quantity.rounded())
        return formatQuantityWithType(qty: qty)
    }

    /// Format quantity with appropriate unit based on type
    private func formatQuantityWithType(qty: Int) -> String {
        let baseType = item.type.lowercased()

        switch baseType {
        case "rod":
            return qty == 1 ? "1 rod" : "\(qty) rods"
        case "frit":
            return qty == 1 ? "1 lb frit" : "\(qty) lbs frit"
        case "sheet":
            return qty == 1 ? "1 sheet" : "\(qty) sheets"
        case "tube":
            return qty == 1 ? "1 tube" : "\(qty) tubes"
        case "stringer":
            return qty == 1 ? "1 stringer" : "\(qty) stringers"
        case "accessory":
            return qty == 1 ? "1 accessory" : "\(qty) accessories"
        case "jar":
            let subtype = item.subtype ?? "frit"
            return qty == 1 ? "1 jar of \(subtype)" : "\(qty) jars of \(subtype)"
        default:
            return qty == 1 ? "1 \(baseType)" : "\(qty) \(baseType)"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                Spacer()
                if let price = item.formattedPrice(currency: currency) {
                    Text(price)
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }

            HStack {
                Text(quantityDescription)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                // Show subtype for non-container types (containers include subtype in quantity)
                if let subtype = item.subtype, !isContainerType {
                    Text("• \(subtype)")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                Spacer()
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(8)
    }
}

#Preview {
    let sampleRecord = PurchaseRecordModel(
        supplier: "Mountain Glass Supply",
        subtotal: Decimal(string: "300.00"),
        tax: Decimal(string: "24.50"),
        shipping: Decimal(string: "0.00"),
        notes: "Monthly order of glass rods and tools",
        items: [
            PurchaseRecordItemModel(
                item_stable_id: "bullseye-0312-rod",
                type: "rod",
                quantity: 5.0,
                totalPrice: Decimal(125.00)
            ),
            PurchaseRecordItemModel(
                item_stable_id: "bullseye-1807-frit",
                type: "frit",
                subtype: "coarse",
                quantity: 2.0,
                totalPrice: Decimal(45.00)
            )
        ],
        orderNumber: "MGS-2024-12345"
    )

    NavigationView {
        PurchaseRecordDetailView(purchaseRecord: sampleRecord)
    }
}
