//
//  CatalogViewIntegration.swift
//  Flameworker
//
//  Integration helpers for CatalogView COE filtering
//  Created by TDD on 10/5/25.
//

import Foundation

/// Integration helpers for CatalogView filtering system
struct CatalogViewIntegration {
    
    /// Apply all filters in correct order: COE → Tags → Search
    /// This is the main integration point for CatalogView
    static func applyAllFilters(
        items: [CatalogItem],
        selectedTags: Set<String>,
        searchText: String
    ) -> [CatalogItem] {
        var filteredItems = items
        
        // 1. Apply COE filter first (as requested)
        filteredItems = CatalogViewHelpers.applyCOEFilter(filteredItems)
        
        // 2. Apply tag filter using existing FilterUtilities
        filteredItems = FilterUtilities.filterCatalogByTags(filteredItems, selectedTags: selectedTags)
        
        // 3. Apply search filter using existing SearchUtilities
        if !searchText.isEmpty {
            filteredItems = SearchUtilities.searchCatalogItems(filteredItems, query: searchText)
        }
        
        return filteredItems
    }
    
    /// Apply manufacturer and COE filters (COE first, then manufacturer)
    static func applyManufacturerAndCOEFilters(
        items: [CatalogItem],
        enabledManufacturers: Set<String>
    ) -> [CatalogItem] {
        var filteredItems = items
        
        // 1. Apply COE filter first
        filteredItems = CatalogViewHelpers.applyCOEFilter(filteredItems)
        
        // 2. Apply manufacturer filter using existing FilterUtilities
        filteredItems = FilterUtilities.filterCatalogByManufacturers(filteredItems, enabledManufacturers: enabledManufacturers)
        
        return filteredItems
    }
    
    /// Apply complete filter chain: COE → Manufacturer → Tags → Search
    /// This is the comprehensive filtering method for CatalogView
    static func applyCompleteFilterChain(
        items: [CatalogItem],
        enabledManufacturers: Set<String>,
        selectedTags: Set<String>,
        searchText: String
    ) -> [CatalogItem] {
        var filteredItems = items
        
        // 1. Apply COE filter first (as requested - before all other filters)
        filteredItems = CatalogViewHelpers.applyCOEFilter(filteredItems)
        
        // 2. Apply manufacturer filter
        filteredItems = FilterUtilities.filterCatalogByManufacturers(filteredItems, enabledManufacturers: enabledManufacturers)
        
        // 3. Apply tag filter
        filteredItems = FilterUtilities.filterCatalogByTags(filteredItems, selectedTags: selectedTags)
        
        // 4. Apply search filter
        if !searchText.isEmpty {
            filteredItems = SearchUtilities.searchCatalogItems(filteredItems, query: searchText)
        }
        
        return filteredItems
    }
}
