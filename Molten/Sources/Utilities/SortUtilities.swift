//
//  SortUtilities.swift
//  Flameworker
//
//  Created by Assistant on 10/3/25.
//

import Foundation

/// Protocol for objects that can be sorted by glass item criteria
protocol GlassItemSortable {
    nonisolated var name: String { get }
    nonisolated var manufacturer: String { get }
}

/// Protocol for objects that can be sorted by inventory criteria
protocol InventorySortable {
    nonisolated var item_stable_id: String { get }
    nonisolated var quantity: Double { get }
    nonisolated var type: String { get }
}

// MARK: - Model Conformance

/// Make GlassItemModel conform to GlassItemSortable
extension GlassItemModel: GlassItemSortable {
    // Already has name, manufacturer properties - no additional implementation needed
}

/// Make InventoryModel conform to InventorySortable
extension InventoryModel: InventorySortable {
    // Already has item_stable_id, quantity, type properties - no additional implementation needed
}

/// Make CompleteInventoryItemModel conform to GlassItemSortable protocol
extension CompleteInventoryItemModel: GlassItemSortable {
    nonisolated var name: String { glassItem.name }
    nonisolated var manufacturer: String { glassItem.manufacturer }
}

/// Sorting criteria for glass items - replaces old catalog sorting
enum GlassItemSortCriteria: String, CaseIterable {
    case name = "Name"
    case manufacturer = "Manufacturer"
    case coe = "COE"
    case sku = "SKU"
}

/// Sorting criteria for inventory items - updated for new architecture
enum InventorySortCriteria: String, CaseIterable {
    case item_stable_id = "Item Stable ID"
    case quantity = "Quantity"
    case type = "Type"
}

/// Centralized sorting utilities for business models - new GlassItem architecture
nonisolated struct SortUtilities {
    
    /// Sort glass items based on the specified criteria
    /// - Parameters:
    ///   - items: Array of GlassItemModel objects to sort
    ///   - criteria: GlassItemSortCriteria specifying how to sort
    /// - Returns: Sorted array of GlassItemModel objects
    static func sortGlassItems(_ items: [GlassItemModel], by criteria: GlassItemSortCriteria) -> [GlassItemModel] {
        switch criteria {
        case .name:
            return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .manufacturer:
            return sortByManufacturer(items)
        case .coe:
            return items.sorted {
                if $0.coe != $1.coe {
                    return $0.coe < $1.coe
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .sku:
            return items.sorted {
                // Handle optional SKUs - items without SKUs go last
                guard let sku0 = $0.sku, let sku1 = $1.sku else {
                    if $0.sku == nil && $1.sku != nil { return false } // nil goes last
                    if $0.sku != nil && $1.sku == nil { return true }  // non-nil goes first
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending // both nil, sort by name
                }
                return sku0.localizedCaseInsensitiveCompare(sku1) == .orderedAscending
            }
        }
    }
    
    /// Sort complete inventory items based on glass item criteria
    /// - Parameters:
    ///   - items: Array of CompleteInventoryItemModel objects to sort
    ///   - criteria: GlassItemSortCriteria specifying how to sort
    /// - Returns: Sorted array of CompleteInventoryItemModel objects
    static func sortCompleteInventoryItems(_ items: [CompleteInventoryItemModel], by criteria: GlassItemSortCriteria) -> [CompleteInventoryItemModel] {
        switch criteria {
        case .name:
            return items.sorted { $0.glassItem.name.localizedCaseInsensitiveCompare($1.glassItem.name) == .orderedAscending }
        case .manufacturer:
            return sortCompleteItemsByManufacturer(items)
        case .coe:
            return items.sorted {
                if $0.glassItem.coe != $1.glassItem.coe {
                    return $0.glassItem.coe < $1.glassItem.coe
                }
                return $0.glassItem.name.localizedCaseInsensitiveCompare($1.glassItem.name) == .orderedAscending
            }
        case .sku:
            return items.sorted {
                // Handle optional SKUs - items without SKUs go last
                guard let sku0 = $0.glassItem.sku, let sku1 = $1.glassItem.sku else {
                    if $0.glassItem.sku == nil && $1.glassItem.sku != nil { return false } // nil goes last
                    if $0.glassItem.sku != nil && $1.glassItem.sku == nil { return true }  // non-nil goes first
                    return $0.glassItem.name.localizedCaseInsensitiveCompare($1.glassItem.name) == .orderedAscending // both nil, sort by name
                }
                return sku0.localizedCaseInsensitiveCompare(sku1) == .orderedAscending
            }
        }
    }
    
    /// Sort inventory models based on the specified criteria
    /// - Parameters:
    ///   - items: Array of InventoryModel objects to sort
    ///   - criteria: InventorySortCriteria specifying how to sort
    /// - Returns: Sorted array of InventoryModel objects
    static func sortInventoryModels(_ items: [InventoryModel], by criteria: InventorySortCriteria) -> [InventoryModel] {
        switch criteria {
        case .item_stable_id:
            return items.sorted { $0.item_stable_id.localizedCaseInsensitiveCompare($1.item_stable_id) == .orderedAscending }
        case .quantity:
            return items.sorted { $0.quantity > $1.quantity } // Descending order for quantity
        case .type:
            return items.sorted { item1, item2 in
                // Sort by type first, then by stable_id
                if item1.type == item2.type {
                    return item1.item_stable_id.localizedCaseInsensitiveCompare(item2.item_stable_id) == .orderedAscending
                }
                return item1.type.localizedCaseInsensitiveCompare(item2.type) == .orderedAscending
            }
        }
    }
    
    /// Generic sort using protocol - works with any GlassItemSortable type
    /// - Parameters:
    ///   - items: Array of GlassItemSortable objects to sort
    ///   - criteria: GlassItemSortCriteria specifying how to sort
    /// - Returns: Sorted array of GlassItemSortable objects
    static func sortByGlassItemCriteria<T: GlassItemSortable>(_ items: [T], by criteria: GlassItemSortCriteria) -> [T] {
        switch criteria {
        case .name:
            return sortByName(items)
        case .manufacturer:
            return sortByManufacturer(items)
        case .coe, .sku:
            // For protocols without COE/SKU, fall back to name sorting
            return sortByName(items)
        }
    }
    
    // MARK: - Legacy Methods (Deprecated)
    
    @available(*, deprecated, message: "Use sortGlassItems instead")
    static func sortCatalog<T>(_ items: [T], by criteria: Any) -> [T] {
        return items // Return unsorted for deprecated method
    }
    
    @available(*, deprecated, message: "Use sortInventoryModels instead")
    static func sortInventory<T>(_ items: [T], by criteria: Any) -> [T] {
        return items // Return unsorted for deprecated method
    }
    
    // MARK: - Private Sorting Methods
    
    private static func sortByName<T: GlassItemSortable>(_ items: [T]) -> [T] {
        return items.sorted { item1, item2 in
            let name1 = item1.name.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            let name2 = item2.name.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

            // Handle empty cases - sort to end
            if name1.isEmpty && !name2.isEmpty {
                return false
            }
            if !name1.isEmpty && name2.isEmpty {
                return true
            }

            // Case insensitive comparison
            return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
        }
    }

    private static func sortByManufacturer<T: GlassItemSortable>(_ items: [T]) -> [T] {
        return items.sorted { item1, item2 in
            let manufacturer1 = item1.manufacturer.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            let manufacturer2 = item2.manufacturer.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            
            // Handle empty cases - sort to end
            if manufacturer1.isEmpty && !manufacturer2.isEmpty {
                return false
            }
            if !manufacturer1.isEmpty && manufacturer2.isEmpty {
                return true
            }
            if manufacturer1.isEmpty && manufacturer2.isEmpty {
                return false // Both empty, maintain order
            }
            
            return manufacturer1.localizedCaseInsensitiveCompare(manufacturer2) == .orderedAscending
        }
    }
    
    private static func sortByManufacturer(_ items: [GlassItemModel]) -> [GlassItemModel] {
        return items.sorted { item1, item2 in
            let manufacturer1 = item1.manufacturer.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            let manufacturer2 = item2.manufacturer.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            
            // Handle empty cases - sort to end
            if manufacturer1.isEmpty && !manufacturer2.isEmpty {
                return false
            }
            if !manufacturer1.isEmpty && manufacturer2.isEmpty {
                return true
            }
            if manufacturer1.isEmpty && manufacturer2.isEmpty {
                return false // Both empty, maintain order
            }
            
            // If COEs are different, sort by COE
            if item1.coe != item2.coe {
                return item1.coe < item2.coe
            }
            
            // If COEs are the same, sort alphabetically by manufacturer name
            return manufacturer1.localizedCaseInsensitiveCompare(manufacturer2) == .orderedAscending
        }
    }
    
    private static func sortCompleteItemsByManufacturer(_ items: [CompleteInventoryItemModel]) -> [CompleteInventoryItemModel] {
        return items.sorted { item1, item2 in
            let manufacturer1 = item1.glassItem.manufacturer.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            let manufacturer2 = item2.glassItem.manufacturer.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            
            // Handle empty cases - sort to end
            if manufacturer1.isEmpty && !manufacturer2.isEmpty {
                return false
            }
            if !manufacturer1.isEmpty && manufacturer2.isEmpty {
                return true
            }
            if manufacturer1.isEmpty && manufacturer2.isEmpty {
                return false // Both empty, maintain order
            }
            
            // If COEs are different, sort by COE
            if item1.glassItem.coe != item2.glassItem.coe {
                return item1.glassItem.coe < item2.glassItem.coe
            }
            
            // If COEs are the same, sort alphabetically by manufacturer name
            return manufacturer1.localizedCaseInsensitiveCompare(manufacturer2) == .orderedAscending
        }
    }
}
