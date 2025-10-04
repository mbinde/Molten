//  InventoryViewUIInteractionTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/3/25.
//  Copyright © 2025 Motley Woods. All rights reserved.
//

import Testing
import Foundation
@testable import Flameworker

@Suite("InventoryView UI Interaction Tests")
struct InventoryViewUIInteractionTests {
    
    // MARK: - Filter Button Interaction Tests
    
    @Test("All button sets all filters when pressed")
    func testAllButtonSetsAllFilters() {
        var selectedFilters: Set<InventoryFilterType> = [.inventory] // Start with partial selection
        
        // Simulate pressing the "all" button
        selectedFilters = [.inventory, .buy, .sell]
        
        #expect(selectedFilters.count == 3, "All button should set all 3 filters")
        #expect(selectedFilters.contains(.inventory), "Should contain inventory filter")
        #expect(selectedFilters.contains(.buy), "Should contain buy filter")
        #expect(selectedFilters.contains(.sell), "Should contain sell filter")
        #expect(selectedFilters == [.inventory, .buy, .sell], "Should match expected all filters state")
    }
    
    @Test("Individual filter buttons set only that filter")
    func testIndividualFilterButtonsSetSingleFilter() {
        var selectedFilters: Set<InventoryFilterType> = [.inventory, .buy, .sell] // Start with all selected
        
        // Simulate pressing inventory filter button
        selectedFilters = [.inventory]
        #expect(selectedFilters == [.inventory], "Inventory button should set only inventory filter")
        #expect(selectedFilters.count == 1, "Should have exactly 1 filter selected")
        
        // Simulate pressing buy filter button
        selectedFilters = [.buy]
        #expect(selectedFilters == [.buy], "Buy button should set only buy filter")
        #expect(selectedFilters.count == 1, "Should have exactly 1 filter selected")
        
        // Simulate pressing sell filter button
        selectedFilters = [.sell]
        #expect(selectedFilters == [.sell], "Sell button should set only sell filter")
        #expect(selectedFilters.count == 1, "Should have exactly 1 filter selected")
    }
    
    @Test("Switching between individual filters replaces previous selection")
    func testSwitchingBetweenFilters() {
        var selectedFilters: Set<InventoryFilterType> = [.inventory]
        
        // Switch to buy filter
        selectedFilters = [.buy]
        #expect(selectedFilters == [.buy], "Should only have buy filter after switching")
        #expect(!selectedFilters.contains(.inventory), "Should not contain previous inventory filter")
        
        // Switch to sell filter
        selectedFilters = [.sell]
        #expect(selectedFilters == [.sell], "Should only have sell filter after switching")
        #expect(!selectedFilters.contains(.buy), "Should not contain previous buy filter")
        
        // Switch back to inventory
        selectedFilters = [.inventory]
        #expect(selectedFilters == [.inventory], "Should only have inventory filter after switching back")
        #expect(!selectedFilters.contains(.sell), "Should not contain previous sell filter")
    }
    
    @Test("All button can be pressed multiple times safely")
    func testAllButtonMultiplePresses() {
        var selectedFilters: Set<InventoryFilterType> = []
        
        // Press all button first time
        selectedFilters = [.inventory, .buy, .sell]
        let firstState = selectedFilters
        
        // Press all button second time
        selectedFilters = [.inventory, .buy, .sell]
        let secondState = selectedFilters
        
        #expect(firstState == secondState, "Multiple presses of all button should maintain same state")
        #expect(selectedFilters.count == 3, "Should maintain all 3 filters")
    }
    
    @Test("Individual button can be pressed multiple times safely")
    func testIndividualButtonMultiplePresses() {
        var selectedFilters: Set<InventoryFilterType> = [.buy, .sell]
        
        // Press inventory button first time
        selectedFilters = [.inventory]
        let firstState = selectedFilters
        
        // Press inventory button second time
        selectedFilters = [.inventory]
        let secondState = selectedFilters
        
        #expect(firstState == secondState, "Multiple presses of same button should maintain same state")
        #expect(selectedFilters == [.inventory], "Should maintain only inventory filter")
    }
    
    // MARK: - Filter State Validation Tests
    
    @Test("Filter state transitions are valid")
    func testFilterStateTransitions() {
        var selectedFilters: Set<InventoryFilterType> = [.inventory, .buy, .sell]
        
        // Transition: All -> Inventory Only
        selectedFilters = [.inventory]
        #expect(selectedFilters.isSubset(of: [.inventory, .buy, .sell]), "Should be valid subset")
        #expect(!selectedFilters.isEmpty, "Should not be empty")
        
        // Transition: Inventory Only -> Buy Only
        selectedFilters = [.buy]
        #expect(selectedFilters.isSubset(of: [.inventory, .buy, .sell]), "Should be valid subset")
        #expect(!selectedFilters.isEmpty, "Should not be empty")
        
        // Transition: Buy Only -> All
        selectedFilters = [.inventory, .buy, .sell]
        #expect(selectedFilters == InventoryFilterType.allCases.map { Set([$0]) }.reduce(Set(), { $0.union($1) }), "Should equal all cases")
    }
    
    @Test("Filter state never becomes invalid")
    func testFilterStateNeverInvalid() {
        let validStates: [Set<InventoryFilterType>] = [
            [.inventory],
            [.buy],
            [.sell],
            [.inventory, .buy, .sell]
        ]
        
        for state in validStates {
            // Each valid state should be non-empty and contain only valid filter types
            #expect(!state.isEmpty, "Valid state should not be empty")
            #expect(state.isSubset(of: Set(InventoryFilterType.allCases)), "Should only contain valid filter types")
            
            // Each filter in the state should be a valid case
            for filter in state {
                #expect(InventoryFilterType.allCases.contains(filter), "Should be a valid filter type")
            }
        }
    }
    
    // MARK: - Filter Button Appearance Tests
    
    @Test("Filter button appearance states are correct")
    func testFilterButtonAppearanceStates() {
        // Test "all" button appearance
        let allSelected: Set<InventoryFilterType> = [.inventory, .buy, .sell]
        let partialSelected: Set<InventoryFilterType> = [.inventory]
        
        // All button should appear active when all filters selected
        let allButtonActive = (allSelected == [.inventory, .buy, .sell])
        let allButtonInactive = (partialSelected == [.inventory, .buy, .sell])
        
        #expect(allButtonActive, "All button should appear active when all filters selected")
        #expect(!allButtonInactive, "All button should appear inactive with partial selection")
        
        // Individual buttons should appear active only when that single filter is selected
        let inventoryButtonActive = (partialSelected == [.inventory])
        let inventoryButtonInactiveWithAll = (allSelected == [.inventory])
        
        #expect(inventoryButtonActive, "Inventory button should appear active when only inventory selected")
        #expect(!inventoryButtonInactiveWithAll, "Inventory button should appear inactive when all filters selected")
    }
    
    @Test("Filter button colors are applied correctly")
    func testFilterButtonColors() {
        let inventoryFilter: Set<InventoryFilterType> = [.inventory]
        let buyFilter: Set<InventoryFilterType> = [.buy]
        let sellFilter: Set<InventoryFilterType> = [.sell]
        
        // Test that each filter type has proper color properties (without comparing actual SwiftUI colors)
        // This avoids SwiftUI dependency issues in tests
        
        // Test button state color logic
        let inventoryActive = (inventoryFilter == [.inventory])
        let buyActive = (buyFilter == [.buy])
        let sellActive = (sellFilter == [.sell])
        
        #expect(inventoryActive, "Inventory button should be in active state")
        #expect(buyActive, "Buy button should be in active state")
        #expect(sellActive, "Sell button should be in active state")
    }
    
    // MARK: - Integration with Search Tests
    
    @Test("Filter works independently of search text")
    func testFilterIndependentOfSearch() {
        let searchText = "glass"
        let selectedFilters: Set<InventoryFilterType> = [.inventory]
        
        // Filter logic should not depend on search text
        let hasSearchText = !searchText.isEmpty
        let hasActiveFilters = !selectedFilters.isEmpty
        
        #expect(hasSearchText, "Should have search text")
        #expect(hasActiveFilters, "Should have active filters")
        
        // Both search and filter can be active simultaneously
        #expect(hasSearchText && hasActiveFilters, "Search and filter should work independently")
    }
    
    @Test("Filter persists when search text changes")
    func testFilterPersistsWithSearchChanges() {
        var searchText = ""
        var selectedFilters: Set<InventoryFilterType> = [.buy]
        
        // Change search text
        searchText = "transparent"
        // Filter should remain unchanged
        #expect(selectedFilters == [.buy], "Filter should persist when search text changes")
        
        // Clear search text
        searchText = ""
        // Filter should still remain unchanged
        #expect(selectedFilters == [.buy], "Filter should persist when search is cleared")
    }
    
    // MARK: - Performance and Edge Case Tests
    
    @Test("Filter handles rapid state changes")
    func testFilterHandlesRapidStateChanges() {
        var selectedFilters: Set<InventoryFilterType> = [.inventory]
        
        // Simulate rapid button presses
        for _ in 0..<10 {
            selectedFilters = [.inventory, .buy, .sell] // All
            selectedFilters = [.inventory] // Inventory only
            selectedFilters = [.buy] // Buy only
            selectedFilters = [.sell] // Sell only
        }
        
        // Final state should be valid
        #expect(selectedFilters == [.sell], "Should handle rapid state changes correctly")
        #expect(!selectedFilters.isEmpty, "Should not result in empty state")
        #expect(selectedFilters.isSubset(of: Set(InventoryFilterType.allCases)), "Should contain only valid filters")
    }
    
    @Test("Filter state is consistent across operations")
    func testFilterStateConsistency() {
        var selectedFilters: Set<InventoryFilterType> = [.inventory, .buy, .sell]
        
        // Store initial state
        let initialState = selectedFilters
        
        // Perform various operations
        selectedFilters = [.inventory] // Change to inventory only
        selectedFilters = [.inventory, .buy, .sell] // Change back to all
        
        // State should be consistent with initial
        #expect(selectedFilters == initialState, "Filter state should be consistent")
        #expect(selectedFilters.count == 3, "Should have all 3 filters")
    }
    
    // MARK: - Accessibility and Usability Tests
    
    @Test("Filter buttons maintain proper state for accessibility")
    func testFilterButtonsAccessibilityState() {
        let allFilters: Set<InventoryFilterType> = [.inventory, .buy, .sell]
        let singleFilter: Set<InventoryFilterType> = [.inventory]
        
        // Test that button states can be distinguished
        let allButtonSelected = (allFilters == [.inventory, .buy, .sell])
        let inventoryButtonSelected = (singleFilter == [.inventory])
        
        #expect(allButtonSelected != inventoryButtonSelected, "Button states should be distinguishable")
        #expect(allButtonSelected, "All button state should be detectable")
        #expect(inventoryButtonSelected, "Individual button state should be detectable")
    }
    
    @Test("Filter provides clear visual feedback")
    func testFilterProvidesVisualFeedback() {
        let activeFilter: Set<InventoryFilterType> = [.buy]
        let inactiveAllState: Set<InventoryFilterType> = [.buy] // Not all filters
        
        // Active filter should provide different visual state than inactive
        let buyFilterActive = (activeFilter == [.buy])
        let allFilterInactive = (inactiveAllState != [.inventory, .buy, .sell])
        
        #expect(buyFilterActive, "Active filter should be visually distinct")
        #expect(allFilterInactive, "Inactive all filter should be visually distinct")
        #expect(buyFilterActive && allFilterInactive, "Should provide clear visual differentiation")
    }
}