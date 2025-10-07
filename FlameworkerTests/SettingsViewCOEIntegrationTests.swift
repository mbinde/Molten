//
//  SettingsViewCOEIntegrationTests.swift
//  FlameworkerTests
//
//  Tests for COE filter integration in SettingsView
//  Created by TDD on 10/5/25.
//

import Testing
import Foundation
@testable import Flameworker

@Suite("SettingsView COE Integration Tests")
struct SettingsViewCOEIntegrationTests {
    
    @Test("Should have COE filter section in SettingsView when feature enabled")
    func testCOEFilterSectionInSettings() {
        // Test that SettingsView shows COE filter section
        let isFeatureEnabled = DebugConfig.FeatureFlags.coeGlassFilter
        
        if isFeatureEnabled {
            // Should be able to access COE settings in SettingsView
            let shouldShowSection = SettingsViewHelpers.shouldShowCOEFilterSection()
            #expect(shouldShowSection, "Should show COE filter section when feature enabled")
            
            // Should provide section title
            let sectionTitle = SettingsViewHelpers.coeFilterSectionTitle
            #expect(sectionTitle == "Glass COE Filter", "Should have appropriate section title")
            
            // Should provide section footer text
            let footerText = SettingsViewHelpers.coeFilterSectionFooter
            #expect(footerText.contains("COE"), "Footer should mention COE")
            #expect(footerText.contains("filter"), "Footer should mention filtering")
        } else {
            // When feature disabled, section should not show
            let shouldShowSection = SettingsViewHelpers.shouldShowCOEFilterSection()
            #expect(!shouldShowSection, "Should not show COE filter section when feature disabled")
        }
    }
    
    @Test("Should integrate COE picker with existing settings layout")
    func testCOEPickerIntegration() {
        // Test COE picker integration with existing settings structure
        let isFeatureEnabled = DebugConfig.FeatureFlags.coeGlassFilter
        
        if isFeatureEnabled {
            // Create isolated test UserDefaults
            let testSuite = "SettingsPickerTest_\(UUID().uuidString)"
            let testDefaults = UserDefaults(suiteName: testSuite)!
            COEGlassPreference.setUserDefaults(testDefaults)
            COEGlassPreference.resetToDefault()
            
            // Should provide picker configuration
            let pickerConfig = SettingsViewHelpers.getCOEPickerConfiguration()
            #expect(pickerConfig.options.count == 5, "Picker should have 5 options")
            #expect(pickerConfig.currentSelection.title == "None", "Should start with None selected")
            
            // Test picker selection update
            let coe96Option = COEGlassSettingsOption(title: "COE 96", coeType: .coe96)
            SettingsViewHelpers.updateCOESelection(coe96Option)
            
            let updatedConfig = SettingsViewHelpers.getCOEPickerConfiguration()
            #expect(updatedConfig.currentSelection.title == "COE 96", "Should update selection")
            
            // Clean up
            COEGlassPreference.resetToDefault()
            testDefaults.removeSuite(named: testSuite)
        } else {
            // Feature disabled - picker should not be available
            let shouldShow = SettingsViewHelpers.shouldShowCOEFilterSection()
            #expect(!shouldShow, "Picker should not be available when feature disabled")
        }
    }
    
    @Test("Should position COE filter section appropriately in settings")
    func testCOEFilterSectionPosition() {
        // Test that COE filter appears in logical position within existing settings
        let isFeatureEnabled = DebugConfig.FeatureFlags.coeGlassFilter
        
        if isFeatureEnabled {
            // Should appear in filtering/display section
            let sectionGroup = SettingsViewHelpers.coeFilterSectionGroup
            #expect(sectionGroup == .filtering, "COE filter should be in filtering section group")
            
            // Should have appropriate priority for ordering
            let sectionPriority = SettingsViewHelpers.coeFilterSectionPriority
            #expect(sectionPriority > 0, "Should have positive priority for section ordering")
            
            // Should integrate with existing manufacturer filtering
            let isRelatedToManufacturerSettings = SettingsViewHelpers.isRelatedToManufacturerFiltering
            #expect(isRelatedToManufacturerSettings, "Should be related to manufacturer filtering")
        } else {
            // When disabled, section organization doesn't matter
            #expect(true, "Section position is irrelevant when feature disabled")
        }
    }
}
