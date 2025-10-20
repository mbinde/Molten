//
//  GlassItemRowView.swift
//  Flameworker
//
//  Created by Assistant on 10/19/25.
//  Unified glass item row view for consistent list display across the app
//

import SwiftUI

/// Unified row view for displaying glass items across Catalog, Inventory, and Shopping lists
struct GlassItemRowView: View {
    let item: GlassItemRowData
    let leadingAccessory: AnyView?
    let badgeContent: AnyView?
    let showFullCode: Bool

    /// Data required to display a glass item row
    struct GlassItemRowData {
        let name: String
        let manufacturer: String
        let sku: String
        let naturalKey: String
        let tags: [String]

        init(from completeItem: CompleteInventoryItemModel) {
            self.name = completeItem.glassItem.name
            self.manufacturer = completeItem.glassItem.manufacturer
            self.sku = completeItem.glassItem.sku
            self.naturalKey = completeItem.glassItem.natural_key
            self.tags = completeItem.allTags
        }

        init(from detailedShoppingItem: DetailedShoppingListItemModel) {
            self.name = detailedShoppingItem.glassItem.name
            self.manufacturer = detailedShoppingItem.glassItem.manufacturer
            self.sku = detailedShoppingItem.glassItem.sku
            self.naturalKey = detailedShoppingItem.glassItem.natural_key
            self.tags = detailedShoppingItem.allTags
        }

        init(name: String, manufacturer: String, sku: String, naturalKey: String, tags: [String]) {
            self.name = name
            self.manufacturer = manufacturer
            self.sku = sku
            self.naturalKey = naturalKey
            self.tags = tags
        }
    }

    init(
        item: GlassItemRowData,
        leadingAccessory: AnyView? = nil,
        badgeContent: AnyView? = nil,
        showFullCode: Bool = false
    ) {
        self.item = item
        self.leadingAccessory = leadingAccessory
        self.badgeContent = badgeContent
        self.showFullCode = showFullCode
    }

    var body: some View {
        HStack(spacing: 12) {
            // Optional leading accessory (e.g., checkbox for shopping mode)
            if let accessory = leadingAccessory {
                accessory
            }

            // Product image thumbnail
            ProductImageThumbnail(
                itemCode: item.sku,
                manufacturer: item.manufacturer,
                naturalKey: item.naturalKey,
                size: 60
            )

            // Item details
            VStack(alignment: .leading, spacing: 4) {
                // Item name
                Text(item.name)
                    .font(.headline)
                    .lineLimit(1)

                // Manufacturer and SKU/natural key
                HStack {
                    // Show full manufacturer name instead of abbreviation
                    Text(GlassManufacturers.fullName(for: item.manufacturer) ?? item.manufacturer)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Show SKU or full natural key based on preference
                    Text(showFullCode ? item.naturalKey : item.sku)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .lineLimit(1)

                // Optional badge content (quantity, status, etc.)
                if let badge = badgeContent {
                    badge
                }

                // Tags if available
                if !item.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(item.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.gray.opacity(0.15))
                                    .foregroundColor(.secondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Convenience Initializers

extension GlassItemRowView {
    /// Catalog-style row (shows SKU only)
    static func catalog(item: CompleteInventoryItemModel) -> GlassItemRowView {
        GlassItemRowView(
            item: .init(from: item),
            showFullCode: false
        )
    }

    /// Inventory-style row with quantity badge
    static func inventory(item: CompleteInventoryItemModel) -> GlassItemRowView {
        let badge = AnyView(
            HStack(spacing: 6) {
                Text("\(item.totalQuantity, specifier: "%.1f")")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)

                if !item.inventoryByType.isEmpty {
                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text("\(item.inventoryByType.count) type\(item.inventoryByType.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        )

        return GlassItemRowView(
            item: .init(from: item),
            badgeContent: badge,
            showFullCode: true
        )
    }

    /// Shopping list-style row with needed/current quantity
    static func shoppingList(
        item: DetailedShoppingListItemModel,
        showStore: Bool = false,
        isShoppingMode: Bool = false,
        isInBasket: Bool = false,
        onBasketToggle: (() -> Void)? = nil
    ) -> GlassItemRowView {
        // Leading accessory: checkbox for shopping mode
        let leadingAccessory: AnyView? = isShoppingMode ? AnyView(
            Button(action: {
                onBasketToggle?()
            }) {
                Image(systemName: isInBasket ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isInBasket ? .green : .secondary)
            }
            .buttonStyle(.plain)
        ) : nil

        // Badge: shopping quantities
        var badgeComponents: [AnyView] = []
        badgeComponents.append(AnyView(
            Text("Need: \(item.shoppingListItem.neededQuantity, specifier: "%.1f")")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.orange)
        ))

        badgeComponents.append(AnyView(
            Text("•")
                .font(.caption2)
                .foregroundColor(.secondary)
        ))

        badgeComponents.append(AnyView(
            Text("Current: \(item.shoppingListItem.currentQuantity, specifier: "%.1f")")
                .font(.caption)
                .foregroundColor(.secondary)
        ))

        if showStore {
            badgeComponents.append(AnyView(
                Text("•")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            ))

            badgeComponents.append(AnyView(
                Text(item.shoppingListItem.store)
                    .font(.caption)
                    .foregroundColor(.secondary)
            ))
        }

        let badge = AnyView(
            HStack(spacing: 6) {
                ForEach(0..<badgeComponents.count, id: \.self) { index in
                    badgeComponents[index]
                }
            }
        )

        return GlassItemRowView(
            item: .init(from: item),
            leadingAccessory: leadingAccessory,
            badgeContent: badge,
            showFullCode: true
        )
    }
}

// MARK: - Preview

#Preview("Catalog Style") {
    let mockItem = CompleteInventoryItemModel(
        glassItem: GlassItemModel(
            natural_key: "be-clear-001",
            name: "Clear Glass",
            sku: "001",
            manufacturer: "be",
            coe: 104,
            mfr_status: "available"
        ),
        inventory: [],
        tags: ["clear", "transparent"],
        userTags: [],
        locations: []
    )

    List {
        GlassItemRowView.catalog(item: mockItem)
    }
}

#Preview("Inventory Style") {
    let mockItem = CompleteInventoryItemModel(
        glassItem: GlassItemModel(
            natural_key: "cim-deep-blue-425",
            name: "Deep Blue",
            sku: "425",
            manufacturer: "cim",
            coe: 104,
            mfr_status: "available"
        ),
        inventory: [
            InventoryModel(item_natural_key: "cim-deep-blue-425", type: "rod", quantity: 15.5),
            InventoryModel(item_natural_key: "cim-deep-blue-425", type: "frit", quantity: 8.0)
        ],
        tags: ["blue", "transparent"],
        userTags: ["favorite"],
        locations: []
    )

    List {
        GlassItemRowView.inventory(item: mockItem)
    }
}
