//
//  CatalogViewIntegration.swift
//  Flameworker
//
//  Integration helpers for CatalogView COE filtering using new GlassItem architecture
//  Created by TDD on 10/5/25.
//  Migrated to business models on 10/13/25.
//  Updated for GlassItem Architecture on 10/14/25.
//

import Foundation

/// Integration helpers for CatalogView filtering system using GlassItem architecture
struct CatalogViewIntegration {
    
    /// Apply all filters in correct order: COE → Tags → Search
    /// This is the main integration point for CatalogView using CompleteInventoryItemModel
    static func applyAllFilters(
        items: [CompleteInventoryItemModel],
        selectedTags: Set<String>,
        searchText: String
    ) -> [CompleteInventoryItemModel] {
        var filteredItems = items
        
        // 1. Apply COE filter first (as requested)
        filteredItems = applyCOEFilter(filteredItems)
        
        // 2. Apply tag filter
        filteredItems = filterByTags(filteredItems, selectedTags: selectedTags)
        
        // 3. Apply search filter
        if !searchText.isEmpty {
            filteredItems = searchItems(filteredItems, query: searchText)
        }
        
        return filteredItems
    }
    
    /// Apply manufacturer and COE filters (COE first, then manufacturer)
    static func applyManufacturerAndCOEFilters(
        items: [CompleteInventoryItemModel],
        enabledManufacturers: Set<String>
    ) -> [CompleteInventoryItemModel] {
        var filteredItems = items
        
        // 1. Apply COE filter first
        filteredItems = applyCOEFilter(filteredItems)
        
        // 2. Apply manufacturer filter
        filteredItems = filterByManufacturers(filteredItems, enabledManufacturers: enabledManufacturers)
        
        return filteredItems
    }
    
    /// Apply complete filter chain: COE → Manufacturer → Tags → Search
    /// This is the comprehensive filtering method for CatalogView using GlassItem architecture
    static func applyCompleteFilterChain(
        items: [CompleteInventoryItemModel],
        enabledManufacturers: Set<String>,
        selectedTags: Set<String>,
        searchText: String
    ) -> [CompleteInventoryItemModel] {
        var filteredItems = items
        
        // 1. Apply COE filter first (as requested - before all other filters)
        filteredItems = applyCOEFilter(filteredItems)
        
        // 2. Apply manufacturer filter
        filteredItems = filterByManufacturers(filteredItems, enabledManufacturers: enabledManufacturers)
        
        // 3. Apply tag filter
        filteredItems = filterByTags(filteredItems, selectedTags: selectedTags)
        
        // 4. Apply search filter
        if !searchText.isEmpty {
            filteredItems = searchItems(filteredItems, query: searchText)
        }
        
        return filteredItems
    }
    
    // MARK: - Private Filtering Methods
    
    /// Apply COE filter to items - delegates to CatalogViewHelpers
    private static func applyCOEFilter(_ items: [CompleteInventoryItemModel]) -> [CompleteInventoryItemModel] {
        // Delegate to CatalogViewHelpers which reads user preferences
        return CatalogViewHelpers.applyCOEFilter(items)
    }
    
    /// Filter items by manufacturers
    private static func filterByManufacturers(
        _ items: [CompleteInventoryItemModel],
        enabledManufacturers: Set<String>
    ) -> [CompleteInventoryItemModel] {
        guard !enabledManufacturers.isEmpty else { return items }
        
        return items.filter { item in
            enabledManufacturers.contains(item.glassItem.manufacturer.lowercased())
        }
    }
    
    /// Filter items by tags
    private static func filterByTags(
        _ items: [CompleteInventoryItemModel],
        selectedTags: Set<String>
    ) -> [CompleteInventoryItemModel] {
        guard !selectedTags.isEmpty else { return items }
        
        return items.filter { item in
            let itemTags = Set(item.tags.map { $0.lowercased() })
            let searchTags = Set(selectedTags.map { $0.lowercased() })
            
            // Item must have at least one of the selected tags
            return !itemTags.isDisjoint(with: searchTags)
        }
    }
    
    /// Search items by text query
    private static func searchItems(
        _ items: [CompleteInventoryItemModel],
        query: String
    ) -> [CompleteInventoryItemModel] {
        let searchQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchQuery.isEmpty else { return items }
        
        return items.filter { item in
            item.glassItem.name.localizedCaseInsensitiveContains(searchQuery) ||
            item.glassItem.manufacturer.localizedCaseInsensitiveContains(searchQuery) ||
            (item.glassItem.sku?.localizedCaseInsensitiveContains(searchQuery) ?? false) ||
            item.glassItem.stable_id.localizedCaseInsensitiveContains(searchQuery) ||
            item.tags.contains { $0.localizedCaseInsensitiveContains(searchQuery) }
        }
    }
    
    // MARK: - Utility Methods for CatalogView
    
    /// Get unique manufacturers from items
    static func getUniqueManufacturers(from items: [CompleteInventoryItemModel]) -> [String] {
        let manufacturers = Set(items.map { $0.glassItem.manufacturer })
        return Array(manufacturers).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
    
    /// Get unique COE values from items
    static func getUniqueCOEValues(from items: [CompleteInventoryItemModel]) -> [Int32] {
        let coeValues = Set(items.map { $0.glassItem.coe })
        return Array(coeValues).sorted()
    }
    
    /// Get unique tags from items
    static func getUniqueTags(from items: [CompleteInventoryItemModel]) -> [String] {
        let allTags = items.flatMap { $0.tags }
        let uniqueTags = Set(allTags)
        return Array(uniqueTags).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
    
    /// Get items grouped by manufacturer
    static func groupItemsByManufacturer(_ items: [CompleteInventoryItemModel]) -> [String: [CompleteInventoryItemModel]] {
        return Dictionary(grouping: items) { $0.glassItem.manufacturer }
    }
    
    /// Get items grouped by COE
    static func groupItemsByCOE(_ items: [CompleteInventoryItemModel]) -> [Int32: [CompleteInventoryItemModel]] {
        return Dictionary(grouping: items) { $0.glassItem.coe }
    }
}

// MARK: - Extensions for Sorting

extension Array where Element == CompleteInventoryItemModel {
    
    /// Sort items by GlassItemSortOption
    func sorted(by option: GlassItemSortOption) -> [CompleteInventoryItemModel] {
        switch option {
        case .name:
            return sorted { (item1: CompleteInventoryItemModel, item2: CompleteInventoryItemModel) -> Bool in
                item1.glassItem.name.localizedCaseInsensitiveCompare(item2.glassItem.name) == .orderedAscending
            }
        case .manufacturer:
            return sorted { (item1: CompleteInventoryItemModel, item2: CompleteInventoryItemModel) -> Bool in
                let result = item1.glassItem.manufacturer.localizedCaseInsensitiveCompare(item2.glassItem.manufacturer)
                if result == .orderedSame {
                    return item1.glassItem.name.localizedCaseInsensitiveCompare(item2.glassItem.name) == .orderedAscending
                }
                return result == .orderedAscending
            }
        case .coe:
            return sorted { (item1: CompleteInventoryItemModel, item2: CompleteInventoryItemModel) -> Bool in
                if item1.glassItem.coe == item2.glassItem.coe {
                    return item1.glassItem.name.localizedCaseInsensitiveCompare(item2.glassItem.name) == .orderedAscending
                }
                return item1.glassItem.coe < item2.glassItem.coe
            }
        case .totalQuantity:
            return sorted { (item1: CompleteInventoryItemModel, item2: CompleteInventoryItemModel) -> Bool in
                item1.totalQuantity > item2.totalQuantity
            }
        case .rating:
            return sorted { (item1: CompleteInventoryItemModel, item2: CompleteInventoryItemModel) -> Bool in
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
        }
    }
}
