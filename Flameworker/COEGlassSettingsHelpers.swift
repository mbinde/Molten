//
//  COEGlassSettingsHelpers.swift
//  Flameworker
//
//  Settings UI helpers for COE glass filter
//  Created by TDD on 10/5/25.
//

import Foundation

/// Data model for COE filter options in Settings UI (legacy single selection)
struct COEGlassSettingsOption: Equatable, Hashable {
    let title: String
    let coeType: COEGlassType?
    
    init(title: String, coeType: COEGlassType?) {
        self.title = title
        self.coeType = coeType
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
        hasher.combine(coeType)
    }
}

/// Data model for multi-selection COE options
struct COEMultiSelectionState {
    let coeType: COEGlassType
    let isSelected: Bool
    
    var displayName: String {
        return coeType.displayName
    }
}

/// Helper for multi-selection COE UI
struct COEGlassMultiSelectionHelper {
    
    /// Get all available COE types for multi-selection
    static var availableCOETypes: [COEGlassType] {
        return Array(COEGlassType.allCases)
    }
    
    /// Get selection states for all COE types
    static func getSelectionStates() -> [COEMultiSelectionState] {
        let selectedTypes = COEGlassPreference.selectedCOETypes
        
        return COEGlassType.allCases.map { coeType in
            COEMultiSelectionState(
                coeType: coeType,
                isSelected: selectedTypes.contains(coeType)
            )
        }
    }
    
    /// Toggle selection for a specific COE type
    static func toggleCOEType(_ coeType: COEGlassType) {
        let currentSelection = COEGlassPreference.selectedCOETypes
        
        if currentSelection.contains(coeType) {
            COEGlassPreference.removeCOEType(coeType)
        } else {
            COEGlassPreference.addCOEType(coeType)
        }
    }
}

/// Helper for integrating COE filter with Settings UI (legacy single selection)
struct COEGlassSettingsHelper {
    
    /// Check if COE filter feature is available
    static var isFeatureAvailable: Bool {
        return DebugConfig.FeatureFlags.coeGlassFilter
    }
    
    /// Get all available COE options for settings picker
    static var availableCOEOptions: [COEGlassSettingsOption] {
        guard isFeatureAvailable else { return [] }
        
        var options: [COEGlassSettingsOption] = []
        
        // Add "None" option first
        options.append(COEGlassSettingsOption(title: "None", coeType: nil))
        
        // Add all COE type options
        for coeType in COEGlassType.allCases {
            options.append(COEGlassSettingsOption(title: coeType.displayName, coeType: coeType))
        }
        
        return options
    }
    
    /// Get current selection based on user preference
    static var currentSelection: COEGlassSettingsOption {
        let currentPreference = COEGlassPreference.current
        
        if let preference = currentPreference {
            return COEGlassSettingsOption(title: preference.displayName, coeType: preference)
        } else {
            return COEGlassSettingsOption(title: "None", coeType: nil)
        }
    }
    
    /// Update selection when user changes settings
    static func updateSelection(_ option: COEGlassSettingsOption) {
        COEGlassPreference.setCOEFilter(option.coeType)
    }
}
