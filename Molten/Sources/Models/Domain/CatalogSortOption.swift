//
//  CatalogSortOption.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//  Migrated to Repository Pattern on 10/13/25.
//  Updated for GlassItem Architecture on 10/14/25.
//

import Foundation

enum SortOption: String, CaseIterable {
    case name = "Name"
    case code = "Code" // Maps to SKU in new architecture
    case manufacturer = "Manufacturer"
    case rating = "Rating"

    /// KeyPath for CompleteInventoryItemModel (new architecture)
    /// Note: SKU may be optional for some manufacturers
    var keyPath: PartialKeyPath<CompleteInventoryItemModel> {
        switch self {
        case .name: return \CompleteInventoryItemModel.glassItem.name
        case .code: return \CompleteInventoryItemModel.glassItem.sku
        case .manufacturer: return \CompleteInventoryItemModel.glassItem.manufacturer
        case .rating: return \CompleteInventoryItemModel.rating
        }
    }
    
    /// Sort function for items conforming to GlassItemSortable (using protocol from SortUtilities.swift)
    func sort<T: GlassItemSortable>(_ items: [T]) -> [T] {
        switch self {
        case .name:
            return items.sorted { (item1: T, item2: T) -> Bool in
                item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
            }
        case .code:
            // Sort by name since SKU alone doesn't provide meaningful ordering
            return items.sorted { (item1: T, item2: T) -> Bool in
                item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
            }
        case .manufacturer:
            return items.sorted { (item1: T, item2: T) -> Bool in
                item1.manufacturer.localizedCaseInsensitiveCompare(item2.manufacturer) == .orderedAscending
            }
        case .rating:
            // Rating sort only works with CompleteInventoryItemModel, fallback to name for protocol
            return items.sorted { (item1: T, item2: T) -> Bool in
                item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
            }
        }
    }

    /// Sort function specifically for CompleteInventoryItemModel arrays
    func sortCompleteItems(_ items: [CompleteInventoryItemModel]) -> [CompleteInventoryItemModel] {
        if self == .rating {
            // Sort by rating (highest first), items without ratings at the end
            return items.sorted { (item1, item2) -> Bool in
                switch (item1.rating, item2.rating) {
                case (.some(let r1), .some(let r2)):
                    // Both have ratings - sort by average rating (descending)
                    if r1.averageRating != r2.averageRating {
                        return r1.averageRating > r2.averageRating
                    }
                    // Same rating - sort by total number of ratings (descending)
                    if r1.totalRatings != r2.totalRatings {
                        return r1.totalRatings > r2.totalRatings
                    }
                    // Same rating and count - sort by name
                    return item1.glassItem.name.localizedCaseInsensitiveCompare(item2.glassItem.name) == .orderedAscending
                case (.some, .none):
                    // item1 has rating, item2 doesn't - item1 comes first
                    return true
                case (.none, .some):
                    // item2 has rating, item1 doesn't - item2 comes first
                    return false
                case (.none, .none):
                    // Neither has rating - sort by name
                    return item1.glassItem.name.localizedCaseInsensitiveCompare(item2.glassItem.name) == .orderedAscending
                }
            }
        } else {
            return sort(items)
        }
    }
    
    var sortIcon: String {
        switch self {
        case .name:
            return "textformat.abc"
        case .code:
            return "number"
        case .manufacturer:
            return "building.2"
        case .rating:
            return "star.fill"
        }
    }
}

// MARK: - Bridge to New Architecture

/// Convert legacy SortOption to new GlassItemSortOption
extension SortOption {
    var asGlassItemSortOption: GlassItemSortOption {
        switch self {
        case .name: return .name
        case .code: return .name // Map to name since natural_key sort was removed
        case .manufacturer: return .manufacturer
        case .rating: return .rating
        }
    }
}

/// Convert new GlassItemSortOption to legacy SortOption (for backwards compatibility)
extension GlassItemSortOption {
    var asLegacySortOption: SortOption? {
        switch self {
        case .name: return .name
        case .manufacturer: return .manufacturer
        case .rating: return .rating
        case .coe, .totalQuantity: return nil // No legacy equivalent
        }
    }
}
