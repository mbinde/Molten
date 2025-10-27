//  UIStateManagementTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/11/25.
//

// Standard test framework imports pattern - use in all test files
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

import SwiftUI
import Foundation
import Combine
@testable import Molten

@Suite("UI State Management Tests", .serialized)
struct UIStateManagementTests {
    
    // MARK: - Loading State Transition Tests
    
    @Test("Should manage basic loading state correctly")
    func testBasicLoadingStateManagement() async {
        // Arrange - Test our LoadingStateManager
        let stateManager = LoadingStateManager()
        
        // Assert initial state
        #expect(stateManager.isLoading == false, "Should start in idle state")
        #expect(stateManager.operationName == nil, "Should have no operation name initially")
        
        // Act - Start loading
        stateManager.startLoading(operationName: "Test Operation")
        
        // Assert loading state
        #expect(stateManager.isLoading == true, "Should be in loading state")
        #expect(stateManager.operationName == "Test Operation", "Should track operation name")
        
        // Act - Complete loading
        stateManager.completeLoading()
        
        // Assert final state
        #expect(stateManager.isLoading == false, "Should return to idle state")
        #expect(stateManager.operationName == nil, "Should clear operation name")
    }
    
    @Test("Should prevent duplicate operations")
    func testDuplicateOperationPrevention() {
        // Arrange
        let stateManager = LoadingStateManager()
        
        // Act & Assert - First operation
        let firstResult = stateManager.startLoading(operationName: "First Operation")
        #expect(firstResult == true, "First operation should be allowed")
        #expect(stateManager.isLoading == true, "Should be in loading state")
        
        // Act & Assert - Second operation while first is running
        let secondResult = stateManager.startLoading(operationName: "Second Operation")
        #expect(secondResult == false, "Second operation should be blocked")
        #expect(stateManager.operationName == "First Operation", "Should maintain first operation name")
        
        // Act & Assert - Complete first operation
        stateManager.completeLoading()
        
        // Act & Assert - Third operation after first completes
        let thirdResult = stateManager.startLoading(operationName: "Third Operation")
        #expect(thirdResult == true, "Third operation should be allowed after first completes")
    }
    
    @Test("Should handle loading state with error scenarios")
    func testLoadingStateWithErrors() {
        // Arrange
        let stateManager = LoadingStateManager()
        
        // Act - Start operation
        stateManager.startLoading(operationName: "Failing Operation")
        #expect(stateManager.isLoading == true, "Should be in loading state")
        
        // Act - Complete with error
        stateManager.completeLoading(withError: "Operation failed")
        
        // Assert - Should still reset to idle state
        #expect(stateManager.isLoading == false, "Should return to idle state even after error")
        #expect(stateManager.operationName == nil, "Should clear operation name after error")
        
        // Assert - Can start new operation after error
        let newResult = stateManager.startLoading(operationName: "Recovery Operation")
        #expect(newResult == true, "Should allow new operations after error")
    }
    
    // MARK: - Selection State Management Tests
    
    @Test("Should manage selection state with sets correctly")
    func testSelectionStateManagement() {
        // Arrange
        let availableItems = ["Item1", "Item2", "Item3", "Item4", "Item5"]
        
        // Act & Assert - Initial empty selection
        let selectionManager = SelectionStateManager<String>()
        #expect(selectionManager.selectedItems.isEmpty, "Should start with empty selection")
        #expect(selectionManager.isSelected("Item1") == false, "Items should not be selected initially")
        
        // Act & Assert - Single selection
        selectionManager.toggle("Item1")
        #expect(selectionManager.selectedItems.contains("Item1"), "Should select Item1")
        #expect(selectionManager.selectedItems.count == 1, "Should have one selected item")
        #expect(selectionManager.isSelected("Item1") == true, "Item1 should be selected")
        
        // Act & Assert - Multiple selection
        selectionManager.toggle("Item3")
        selectionManager.toggle("Item5")
        #expect(selectionManager.selectedItems.count == 3, "Should have three selected items")
        #expect(selectionManager.isSelected("Item3") == true, "Item3 should be selected")
        #expect(selectionManager.isSelected("Item5") == true, "Item5 should be selected")
        
        // Act & Assert - Deselection
        selectionManager.toggle("Item1")
        #expect(selectionManager.selectedItems.count == 2, "Should have two selected items after deselection")
        #expect(selectionManager.isSelected("Item1") == false, "Item1 should be deselected")
        
        // Act & Assert - Select all
        selectionManager.selectAll(availableItems)
        #expect(selectionManager.selectedItems.count == 5, "Should select all available items")
        for item in availableItems {
            #expect(selectionManager.isSelected(item), "All items should be selected: \(item)")
        }
        
        // Act & Assert - Clear all
        selectionManager.clearAll()
        #expect(selectionManager.selectedItems.isEmpty, "Should clear all selections")
        for item in availableItems {
            #expect(selectionManager.isSelected(item) == false, "All items should be deselected: \(item)")
        }
    }
    
    // MARK: - Filter State Management Tests
    
    @Test("Should manage filter state with active filter detection")
    func testFilterStateManagement() {
        // Arrange & Act - Initial state
        let filterManager = FilterStateManager()
        #expect(filterManager.hasActiveFilters == false, "Should start with no active filters")
        #expect(filterManager.activeFilterCount == 0, "Should have zero active filters")
        
        // Act & Assert - Add text filter
        filterManager.setTextFilter("glass")
        #expect(filterManager.hasActiveFilters == true, "Should detect active text filter")
        #expect(filterManager.activeFilterCount == 1, "Should have one active filter")
        #expect(filterManager.textFilter == "glass", "Should store text filter value")
        
        // Act & Assert - Add category filters
        filterManager.setCategoryFilters(["Rods", "Sheets"])
        #expect(filterManager.activeFilterCount == 2, "Should have two active filters")
        #expect(filterManager.categoryFilters == ["Rods", "Sheets"], "Should store category filters")
        
        // Act & Assert - Add manufacturer filter
        filterManager.setManufacturerFilter("Bullseye Glass")
        #expect(filterManager.activeFilterCount == 3, "Should have three active filters")
        #expect(filterManager.manufacturerFilter == "Bullseye Glass", "Should store manufacturer filter")
        
        // Act & Assert - Remove text filter
        filterManager.clearTextFilter()
        #expect(filterManager.activeFilterCount == 2, "Should have two active filters after clearing text")
        #expect(filterManager.textFilter.isEmpty, "Text filter should be empty")
        #expect(filterManager.hasActiveFilters == true, "Should still have active filters")
        
        // Act & Assert - Clear all filters
        filterManager.clearAllFilters()
        #expect(filterManager.hasActiveFilters == false, "Should have no active filters after clearing all")
        #expect(filterManager.activeFilterCount == 0, "Should have zero active filters")
        #expect(filterManager.textFilter.isEmpty, "Text filter should be empty")
        #expect(filterManager.categoryFilters.isEmpty, "Category filters should be empty")
        #expect(filterManager.manufacturerFilter.isEmpty, "Manufacturer filter should be empty")
    }
}
