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

    @AppStorage("showRatingsInCatalog") private var showRatingsInCatalog = true

    /// Data required to display a glass item row
    struct GlassItemRowData {
        let name: String
        let manufacturer: String
        let sku: String?  // Optional - some manufacturers don't use SKUs
        let stableId: String
        let imagePath: String?
        let imageThumbPath: String?
        let dominantColors: [String]?
        let tags: [String]
        let rating: AggregatedRatingModel?  // Optional rating data

        init(from completeItem: CompleteInventoryItemModel) {
            self.name = completeItem.glassItem.name
            self.manufacturer = completeItem.glassItem.manufacturer
            self.sku = completeItem.glassItem.sku
            self.stableId = completeItem.glassItem.stable_id
            self.imagePath = completeItem.glassItem.image_path
            self.imageThumbPath = completeItem.glassItem.image_thumb_path
            self.dominantColors = completeItem.glassItem.dominant_colors
            self.tags = completeItem.allTags
            self.rating = completeItem.rating
        }

        init(from detailedShoppingItem: DetailedShoppingListItemModel) {
            self.name = detailedShoppingItem.catalogItem.name
            self.manufacturer = detailedShoppingItem.catalogItem.manufacturer
            self.sku = detailedShoppingItem.catalogItem.sku
            self.stableId = detailedShoppingItem.catalogItem.stable_id
            self.imagePath = detailedShoppingItem.catalogItem.image_path
            self.imageThumbPath = detailedShoppingItem.catalogItem.image_thumb_path
            self.dominantColors = detailedShoppingItem.catalogItem.dominant_colors
            self.tags = detailedShoppingItem.allTags
            self.rating = nil  // Shopping list items don't include ratings
        }

        init(from enrichedItem: EnrichedFriendInventoryItem) {
            // Use catalog data if available, otherwise use snapshot data with fallbacks
            self.name = enrichedItem.catalogData?.name ?? enrichedItem.snapshot.sku
            self.manufacturer = enrichedItem.snapshot.manufacturer
            self.sku = enrichedItem.snapshot.sku
            self.stableId = enrichedItem.snapshot.stableId
            self.imagePath = enrichedItem.catalogData?.imagePath
            self.imageThumbPath = enrichedItem.catalogData?.imageThumbPath
            self.dominantColors = enrichedItem.catalogData?.dominantColors
            self.tags = enrichedItem.catalogData?.tags ?? []
            self.rating = nil  // Friend inventory items don't include ratings
        }

        init(name: String, manufacturer: String, sku: String?, stableId: String, imagePath: String? = nil, imageThumbPath: String? = nil, dominantColors: [String]? = nil, tags: [String], rating: AggregatedRatingModel? = nil) {
            self.name = name
            self.manufacturer = manufacturer
            self.sku = sku
            self.stableId = stableId
            self.imagePath = imagePath
            self.imageThumbPath = imageThumbPath
            self.dominantColors = dominantColors
            self.tags = tags
            self.rating = rating
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

            mainContent
        }
        .padding(.vertical, 4)
    }

    /// The main content (image + text) without the leading accessory
    /// Use this when you want to wrap only the content in a NavigationLink
    var mainContent: some View {
        HStack(spacing: 12) {
            thumbnail

            textContent

            Spacer()
        }
    }

    /// Just the thumbnail image
    var thumbnail: some View {
        ProductImageThumbnail(
            itemCode: item.stableId,
            manufacturer: item.manufacturer,
            stableId: item.stableId,
            imagePath: item.imagePath,
            imageThumbPath: item.imageThumbPath,
            dominantColors: item.dominantColors,
            size: 60
        )
    }

    /// Just the text content (name, manufacturer, SKU, badges, tags)
    var textContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Item name with rating
            HStack(spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .lineLimit(1)

                // Show rating inline after name if available, has enough ratings, and setting is enabled
                if showRatingsInCatalog, let rating = item.rating, rating.hasEnoughRatings {
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)

                    Text(rating.formattedAverageRating)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("(\(rating.totalRatings))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)

            // Manufacturer on second line
            Text(GlassManufacturers.fullName(for: item.manufacturer) ?? item.manufacturer)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)

            // SKU on third line (only if it exists and doesn't look synthetic)
            if shouldDisplaySKU {
                Text(showFullCode ? item.stableId : (item.sku ?? ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            // Optional badge content (quantity, status, etc.)
            if let badge = badgeContent {
                badge
            }

            // Tags if available
            if !item.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(item.tags, id: \.self) { tag in
                            BadgeLabel.tag(tag)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
    }

    /// Determines if the SKU should be displayed (not empty, not synthetic)
    private var shouldDisplaySKU: Bool {
        guard let sku = item.sku, !sku.isEmpty else { return false }

        // Don't show SKUs that look synthetic (manufacturer-hash pattern)
        // Pattern: XXX-[8 hex chars] like "GRE-8bf530c2"
        let parts = sku.split(separator: "-")
        if parts.count == 2 {
            let prefix = String(parts[0])
            let suffix = String(parts[1])

            // Check if prefix is 2-4 uppercase letters and suffix is 8 hex chars
            let isValidPrefix = prefix.count >= 2 && prefix.count <= 4 && prefix.allSatisfy { $0.isUppercase && $0.isLetter }
            let isValidSuffix = suffix.count == 8 && suffix.allSatisfy { $0.isHexDigit }

            if isValidPrefix && isValidSuffix {
                return false
            }
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
                    .foregroundColor(Color.accentColor)

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
                        .foregroundColor(Color.accentColor)

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
        quantity: Binding<Double>? = nil,
        onBasketToggle: (() -> Void)? = nil
    ) -> GlassItemRowView {
        // Leading accessory: checkbox + compact quantity editor for shopping mode
        let leadingAccessory: AnyView? = isShoppingMode ? AnyView(
            HStack(spacing: 8) {
                // Checkbox (on the left) with quantity difference indicator below
                VStack(spacing: 2) {
                    Button(action: {
                        onBasketToggle?()
                    }) {
                        Image(systemName: isInBasket ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundColor(isInBasket ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)

                    // Show quantity difference if user adjusted from needed amount
                    if let quantityBinding = quantity {
                        let difference = quantityBinding.wrappedValue - item.shoppingListItem.neededQuantity
                        if abs(difference) > 0.01 {  // Only show if there's a meaningful difference
                            Text(difference > 0 ? "+\(Int(difference))" : "\(Int(difference))")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(difference > 0 ? .green : .red)
                        }
                    }
                }

                // Compact quantity editor (number with +/- stacked above/below)
                if let quantityBinding = quantity {
                    VStack(spacing: 0) {
                        // Plus button on top
                        Button(action: {
                            quantityBinding.wrappedValue += 1.0
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .frame(height: 12)

                        // Editable number field in middle
                        TextField("Qty", value: quantityBinding, format: .number)
                            .multilineTextAlignment(.center)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .monospacedDigit()
                            .frame(width: 40)
                            #if os(iOS)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.decimalPad)
                            #endif

                        // Minus button on bottom
                        Button(action: {
                            let newValue = max(0.1, quantityBinding.wrappedValue - 1.0)
                            quantityBinding.wrappedValue = newValue
                        }) {
                            Image(systemName: "minus")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .frame(height: 12)
                    }
                }
            }
        ) : nil

        // Badge and tags: show for normal shopping list, hide for shopping mode
        let badgeContent: AnyView?
        let tags: [String]

        if isShoppingMode {
            // Shopping mode: no badge or tags - keep it clean and compact
            badgeContent = nil
            tags = []
        } else {
            // Normal shopping list: show Need/Current/Store badge
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

            badgeContent = AnyView(
                HStack(spacing: 6) {
                    ForEach(0..<badgeComponents.count, id: \.self) { index in
                        badgeComponents[index]
                    }
                }
            )

            tags = item.allTags
        }

        return GlassItemRowView(
            item: GlassItemRowData(
                name: item.catalogItem.name,
                manufacturer: item.catalogItem.manufacturer,
                sku: item.catalogItem.sku,
                stableId: item.catalogItem.stable_id,
                imagePath: item.catalogItem.image_path,
                imageThumbPath: item.catalogItem.image_thumb_path,
                dominantColors: item.catalogItem.dominant_colors,
                tags: tags,
                rating: nil
            ),
            leadingAccessory: leadingAccessory,
            badgeContent: badgeContent,
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
