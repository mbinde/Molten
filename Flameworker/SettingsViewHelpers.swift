//
//  SettingsViewHelpers.swift
//  Flameworker
//
//  Helpers for integrating COE filter into SettingsView
//  Created by TDD on 10/5/25.
//

import Foundation

/// Settings section grouping for organization
enum SettingsSectionGroup {
    case filtering
    case display
    case data
    case about
}

/// Configuration for COE picker in Settings
struct COEPickerConfiguration {
    let options: [COEGlassSettingsOption]
    let currentSelection: COEGlassSettingsOption
}

/// Helpers for integrating COE filter into SettingsView
struct SettingsViewHelpers {
    
    /// Check if COE filter section should be shown
    static func shouldShowCOEFilterSection() -> Bool {
        return DebugConfig.FeatureFlags.coeGlassFilter
    }
    
    /// Title for COE filter section
    static let coeFilterSectionTitle = "Glass COE Filter"
    
    /// Footer text for COE filter section
    static let coeFilterSectionFooter = "Filter catalog items by their COE (Coefficient of Expansion) glass type. This filter is applied before other filters."
    
    /// Section group for COE filter (for layout organization)
    static let coeFilterSectionGroup: SettingsSectionGroup = .filtering
    
    /// Priority for section ordering (higher = later in list)
    static let coeFilterSectionPriority = 10
    
    /// Whether this is related to manufacturer filtering
    static let isRelatedToManufacturerFiltering = true
    
    /// Get picker configuration for SwiftUI
    static func getCOEPickerConfiguration() -> COEPickerConfiguration {
        return COEPickerConfiguration(
            options: COEGlassSettingsHelper.availableCOEOptions,
            currentSelection: COEGlassSettingsHelper.currentSelection
        )
    }
    
    /// Update COE selection from picker
    static func updateCOESelection(_ option: COEGlassSettingsOption) {
        COEGlassSettingsHelper.updateSelection(option)
    }
}