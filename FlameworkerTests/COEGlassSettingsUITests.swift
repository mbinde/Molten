//
//  COEGlassSettingsUITests.swift
//  FlameworkerTests
//
//  Tests for COE glass filter Settings UI integration
//  Created by TDD on 10/5/25.
//

import Testing
@testable import Flameworker

@Suite("COE Glass Settings UI Tests")
struct COEGlassSettingsUITests {
    
    @Test("Should have COE filter section in settings when feature enabled")
    func testCOEFilterSettingsSection() {
        // Test that Settings UI provides COE filter options
        let isFeatureEnabled = DebugConfig.FeatureFlags.coeGlassFilter
        
        if isFeatureEnabled {
            // Should be able to get COE options for settings
            let settingsOptions = COEGlassSettingsHelper.availableCOEOptions
            #expect(settingsOptions.count == 5, "Should have 4 COE options + None option")
            
            // Verify options include all COE types plus "None"
            let optionTitles = settingsOptions.map { $0.title }
            #expect(optionTitles.contains("None"), "Should include None option")
            #expect(optionTitles.contains("COE 33"), "Should include COE 33 option")
            #expect(optionTitles.contains("COE 90"), "Should include COE 90 option")
            #expect(optionTitles.contains("COE 96"), "Should include COE 96 option")
            #expect(optionTitles.contains("COE 104"), "Should include COE 104 option")
        } else {
            // When feature disabled, settings helper should indicate unavailable
            let isAvailable = COEGlassSettingsHelper.isFeatureAvailable
            #expect(!isAvailable, "Settings should indicate feature is unavailable")
        }
    }
    
    @Test("Should track current COE selection in settings")
    func testCurrentCOESelectionInSettings() {
        // Create isolated test UserDefaults
        let testSuite = "SettingsUITest_\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: testSuite)!
        COEGlassPreference.setUserDefaults(testDefaults)
        
        // Test default selection (None)
        COEGlassPreference.resetToDefault()
        let defaultSelection = COEGlassSettingsHelper.currentSelection
        #expect(defaultSelection.title == "None", "Should default to None selection")
        #expect(defaultSelection.coeType == nil, "Default selection should have nil COE type")
        
        // Test COE 33 selection
        COEGlassPreference.setCOEFilter(.coe33)
        let coe33Selection = COEGlassSettingsHelper.currentSelection
        #expect(coe33Selection.title == "COE 33", "Should show COE 33 selection")
        #expect(coe33Selection.coeType == .coe33, "Should have COE 33 type")
        
        // Test COE 104 selection
        COEGlassPreference.setCOEFilter(.coe104)
        let coe104Selection = COEGlassSettingsHelper.currentSelection
        #expect(coe104Selection.title == "COE 104", "Should show COE 104 selection")
        #expect(coe104Selection.coeType == .coe104, "Should have COE 104 type")
        
        // Clean up
        COEGlassPreference.resetToDefault()
        testDefaults.removeSuite(named: testSuite)
    }
    
    @Test("Should update preference when settings selection changes")
    func testSettingsSelectionUpdatesPref() {
        // Create isolated test UserDefaults
        let testSuite = "SettingsUpdateTest_\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: testSuite)!
        COEGlassPreference.setUserDefaults(testDefaults)
        COEGlassPreference.resetToDefault()
        
        // Test selecting COE 33
        let coe33Option = COEGlassSettingsOption(title: "COE 33", coeType: .coe33)
        COEGlassSettingsHelper.updateSelection(coe33Option)
        
        let updatedPreference = COEGlassPreference.current
        #expect(updatedPreference == .coe33, "Should update preference to COE 33")
        
        // Test selecting None (clear filter)
        let noneOption = COEGlassSettingsOption(title: "None", coeType: nil)
        COEGlassSettingsHelper.updateSelection(noneOption)
        
        let clearedPreference = COEGlassPreference.current
        #expect(clearedPreference == nil, "Should clear preference when None selected")
        
        // Clean up
        COEGlassPreference.resetToDefault()
        testDefaults.removeSuite(named: testSuite)
    }
    
    @Test("Should provide settings helper for SwiftUI integration")
    func testSwiftUISettingsIntegration() {
        // Test that settings helper works with SwiftUI binding patterns
        let isFeatureEnabled = DebugConfig.FeatureFlags.coeGlassFilter
        
        if isFeatureEnabled {
            // Create isolated test UserDefaults
            let testSuite = "SwiftUITest_\(UUID().uuidString)"
            let testDefaults = UserDefaults(suiteName: testSuite)!
            COEGlassPreference.setUserDefaults(testDefaults)
            COEGlassPreference.resetToDefault()
            
            // Test getting current selection for UI binding
            var currentSelection = COEGlassSettingsHelper.currentSelection
            #expect(currentSelection.title == "None", "Should start with None")
            
            // Test updating selection (simulating user tap)
            let newOption = COEGlassSettingsOption(title: "COE 96", coeType: .coe96)
            COEGlassSettingsHelper.updateSelection(newOption)
            
            // Verify selection updated
            currentSelection = COEGlassSettingsHelper.currentSelection
            #expect(currentSelection.title == "COE 96", "Should update to COE 96")
            #expect(currentSelection.coeType == .coe96, "Should have correct COE type")
            
            // Clean up
            COEGlassPreference.resetToDefault()
            testDefaults.removeSuite(named: testSuite)
        } else {
            // Feature disabled - settings should be unavailable
            #expect(!COEGlassSettingsHelper.isFeatureAvailable, "Feature should be unavailable")
        }
    }
}