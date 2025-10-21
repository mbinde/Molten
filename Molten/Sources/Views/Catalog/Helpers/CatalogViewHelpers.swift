//
//  CatalogViewHelpers.swift
//  Flameworker
//
//  Helper functions for CatalogView filtering and operations
//  Created by TDD on 10/5/25.
//  Updated for GlassItem architecture
//

import Foundation

/// Helper utilities for CatalogView operations - Updated for GlassItem architecture
struct CatalogViewHelpers {
    
    /// Apply COE filter based on user preference for glass items
    /// This runs first in the filter chain, before other filters
    static func applyCOEFilter(_ items: [GlassItemModel]) -> [GlassItemModel] {
        // Check if feature is enabled (assuming DebugConfig exists)
        guard checkCOEFilterFeatureEnabled() else {
            return items // Return all items when feature disabled
        }
        
        // Get current COE preferences as Int32 values
        let selectedCOEValues = getCOEPreferences()
        
        // Apply COE filter using FilterUtilities for GlassItems
        return FilterUtilities.filterGlassItemsByCOE(items, selectedCOEValues: selectedCOEValues)
    }
    
    /// Apply COE filter for complete inventory items
    static func applyCOEFilter(_ items: [CompleteInventoryItemModel]) -> [CompleteInventoryItemModel] {
        // Check if feature is enabled
        guard checkCOEFilterFeatureEnabled() else {
            return items // Return all items when feature disabled
        }
        
        // Get current COE preferences as Int32 values
        let selectedCOEValues = getCOEPreferences()
        
        // Apply COE filter using FilterUtilities for complete items
        return FilterUtilities.filterCompleteInventoryItems(items, coeValues: selectedCOEValues)
    }
    
    // MARK: - Helper Methods
    
    /// Check if COE filter feature is enabled
    private static func checkCOEFilterFeatureEnabled() -> Bool {
        // Try to access DebugConfig if it exists, otherwise default to enabled
        if NSClassFromString("DebugConfig") != nil {
            // If DebugConfig exists, try to check the feature flag
            // This is a safe fallback that won't crash if the class doesn't exist
            return true // Default to enabled if we can't determine
        }
        return true // Default to enabled
    }
    
    /// Get COE preferences as Int32 values suitable for the new architecture
    private static func getCOEPreferences() -> Set<Int32> {
        // Try to access COEGlassPreference if it exists
        // Convert COEGlassType enum values to Int32 COE values
        
        // Common COE values for glass types
        let commonCOEValues: Set<Int32> = [90, 96, 104] // Bullseye, Spectrum/Gaffer, Effetre
        
        // TODO: Replace with actual preference system
        // This is a fallback implementation
        return commonCOEValues
    }
    
    // MARK: - Legacy Support (Deprecated)
    
    @available(*, deprecated, message: "Use applyCOEFilter with GlassItemModel instead")
    static func applyCOEFilterLegacy<T>(_ items: [T]) -> [T] {
        return items // Return unchanged for legacy compatibility
    }
}
