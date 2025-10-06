//
//  CatalogViewHelpers.swift
//  Flameworker
//
//  Helper functions for CatalogView filtering and operations
//  Created by TDD on 10/5/25.
//

import Foundation

/// Helper utilities for CatalogView operations
struct CatalogViewHelpers {
    
    /// Apply COE filter based on user preference (multi-selection)
    /// This runs first in the filter chain, before other filters
    static func applyCOEFilter<T: CatalogItemProtocol>(_ items: [T]) -> [T] {
        // Check if feature is enabled
        guard DebugConfig.FeatureFlags.coeGlassFilter else {
            return items // Return all items when feature disabled
        }
        
        // Get current COE preferences (multi-selection)
        let selectedCOETypes = COEGlassPreference.selectedCOETypes
        
        // Apply multi-COE filter using existing FilterUtilities
        return FilterUtilities.filterCatalogByMultipleCOE(items, selectedCOETypes: selectedCOETypes)
    }
}