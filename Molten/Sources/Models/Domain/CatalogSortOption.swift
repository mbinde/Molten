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
    
    /// KeyPath for CompleteInventoryItemModel (new architecture)
    var keyPath: KeyPath<CompleteInventoryItemModel, String> {
        switch self {
        case .name: return \CompleteInventoryItemModel.glassItem.name
        case .code: return \CompleteInventoryItemModel.glassItem.sku
        case .manufacturer: return \CompleteInventoryItemModel.glassItem.manufacturer
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
        }
    }
    
    /// Sort function specifically for CompleteInventoryItemModel arrays
    func sortCompleteItems(_ items: [CompleteInventoryItemModel]) -> [CompleteInventoryItemModel] {
        return sort(items)
    }
    
    var sortIcon: String {
        switch self {
        case .name:
            return "textformat.abc"
        case .code:
            return "number"
        case .manufacturer:
            return "building.2"
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
        }
    }
}

/// Convert new GlassItemSortOption to legacy SortOption (for backwards compatibility)
extension GlassItemSortOption {
    var asLegacySortOption: SortOption? {
        switch self {
        case .name: return .name
        case .manufacturer: return .manufacturer
        case .coe, .totalQuantity: return nil // No legacy equivalent
        }
    }
}
