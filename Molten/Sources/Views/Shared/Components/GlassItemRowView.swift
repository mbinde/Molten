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
        let sku: String?  // Optional - some manufacturers don't use SKUs
        let stableId: String
        let imagePath: String?
        let imageThumbPath: String?
        let tags: [String]

        init(from completeItem: CompleteInventoryItemModel) {
            self.name = completeItem.glassItem.name
            self.manufacturer = completeItem.glassItem.manufacturer
            self.sku = completeItem.glassItem.sku
            self.stableId = completeItem.glassItem.stable_id
            self.imagePath = completeItem.glassItem.image_path
            self.imageThumbPath = completeItem.glassItem.image_thumb_path
            self.tags = completeItem.allTags

            // DEBUG: Log what we're receiving
            if ["2HC89p", "5bfSaX", "6pXaLx"].contains(self.stableId) {
                print("🔍 [GlassItemRowData] Creating for \(self.stableId): imagePath=\(self.imagePath ?? "nil"), imageThumbPath=\(self.imageThumbPath ?? "nil")")
            }
        }

        init(from detailedShoppingItem: DetailedShoppingListItemModel) {
            self.name = detailedShoppingItem.glassItem.name
            self.manufacturer = detailedShoppingItem.glassItem.manufacturer
            self.sku = detailedShoppingItem.glassItem.sku
            self.stableId = detailedShoppingItem.glassItem.stable_id
            self.imagePath = detailedShoppingItem.glassItem.image_path
            self.imageThumbPath = detailedShoppingItem.glassItem.image_thumb_path
            self.tags = detailedShoppingItem.allTags
        }

        init(from enrichedItem: EnrichedFriendInventoryItem) {
            // Use catalog data if available, otherwise use snapshot data with fallbacks
            self.name = enrichedItem.catalogData?.name ?? enrichedItem.snapshot.sku
            self.manufacturer = enrichedItem.snapshot.manufacturer
            self.sku = enrichedItem.snapshot.sku
            self.stableId = enrichedItem.snapshot.stableId
            self.imagePath = enrichedItem.catalogData?.imagePath
            self.imageThumbPath = enrichedItem.catalogData?.imageThumbPath
            self.tags = enrichedItem.catalogData?.tags ?? []
        }

        init(name: String, manufacturer: String, sku: String?, stableId: String, imagePath: String? = nil, imageThumbPath: String? = nil, tags: [String]) {
            self.name = name
            self.manufacturer = manufacturer
            self.sku = sku
            self.stableId = stableId
            self.imagePath = imagePath
            self.imageThumbPath = imageThumbPath
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

            // Product image thumbnail using stable_id (which is what image files are actually named with)
            ProductImageThumbnail(
                itemCode: item.stableId,
                manufacturer: item.manufacturer,
                stableId: item.stableId,
                imagePath: item.imagePath,
                imageThumbPath: item.imageThumbPath,
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

                    // Only show SKU if it exists and doesn't look synthetic
                    if shouldDisplaySKU {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        // Show SKU or full stable ID based on preference
                        Text(showFullCode ? item.stableId : (item.sku ?? ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .lineLimit(1)

                // Optional badge content (quantity, status, etc.)
                if let badge = badgeContent {
                    badge
                }

                // Rating badge
                RatingBadgeView(itemStableId: item.stableId)

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

    /// Determines if the SKU should be displayed (not empty, not synthetic)
    private var shouldDisplaySKU: Bool {
        guard let sku = item.sku, !sku.isEmpty else { return false }

        // Don't show SKUs that look synthetic (manufacturer-hash pattern)
        // Pattern: XXX-[8 hex chars] like "GRE-8bf530c2"
        let syntheticPattern = /^[A-Z]{2,4}-[a-f0-9]{8}$/
        if sku.wholeMatch(of: syntheticPattern) != nil {
            return false
        }

        return true
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
            showFullCode: false
        )
    }

    /// Friend inventory-style row with quantity and location
    static func friendInventory(item: EnrichedFriendInventoryItem) -> GlassItemRowView {
        let badge = AnyView(
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("\(item.snapshot.quantity, specifier: "%.1f")")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)

                    Text(item.snapshot.unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let location = item.snapshot.location {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(location)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        )

        return GlassItemRowView(
            item: .init(from: item),
            badgeContent: badge,
            showFullCode: false
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
            showFullCode: false
        )
    }
}

// MARK: - Preview

#Preview("Catalog Style") {
    let mockItem = CompleteInventoryItemModel(
        glassItem: GlassItemModel(
            stable_id: "be-clear-001",
            name: "Clear Glass",
            sku: "001",
            manufacturer: "be",
            coe: 104,
            mfr_status: "available",
            image_path: "be-clear-001.jpg"
        ),
        inventory: [],
        tags: ["clear", "transparent"],
        userTags: []
    )

    List {
        GlassItemRowView.catalog(item: mockItem)
    }
}

#Preview("Inventory Style") {
    let mockItem = CompleteInventoryItemModel(
        glassItem: GlassItemModel(
            stable_id: "cim-deep-blue-425",
            name: "Deep Blue",
            sku: "425",
            manufacturer: "cim",
            coe: 104,
            mfr_status: "available",
            image_path: "cim-deep-blue-425.jpg"
        ),
        inventory: [
            InventoryModel(item_stable_id: "cim-deep-blue-425", type: "rod", quantity: 15.5),
            InventoryModel(item_stable_id: "cim-deep-blue-425", type: "frit", quantity: 8.0)
        ],
        tags: ["blue", "transparent"],
        userTags: ["favorite"]
    )

    List {
        GlassItemRowView.inventory(item: mockItem)
    }
}
