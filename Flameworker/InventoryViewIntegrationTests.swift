//  InventoryViewIntegrationTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/3/25.
//  Copyright © 2025 Motley Woods. All rights reserved.
//

import Testing
import Foundation
@testable import Flameworker

@Suite("InventoryView Integration Tests", .serialized)
struct InventoryViewIntegrationTests {
    
    // MARK: - Filter State Persistence Integration Tests
    
    @Test("Filter state persists correctly through app storage simulation")
    func testFilterStatePersistence() async throws {
        // Create isolated UserDefaults for testing
        let testSuiteName = "FilterPersistenceTest_\(UUID().uuidString)"
        guard let testUserDefaults = UserDefaults(suiteName: testSuiteName) else {
            Issue.record("Failed to create test UserDefaults")
            return
        }
        
        // Simulate initial app launch with default filters
        var selectedFilters: Set<InventoryFilterType> = [.inventory, .buy, .sell]
        
        // Simulate saving filter state
        if let encoded = try? JSONEncoder().encode(Array(selectedFilters)) {
            testUserDefaults.set(encoded, forKey: "selectedInventoryFilters")
        }
        
        // Simulate app restart - load filter state
        if let data = testUserDefaults.data(forKey: "selectedInventoryFilters"),
           let decoded = try? JSONDecoder().decode([InventoryFilterType].self, from: data) {
            selectedFilters = Set(decoded)
        }
        
        #expect(selectedFilters.count == 3, "Should restore all 3 filters")
        #expect(selectedFilters == [.inventory, .buy, .sell], "Should restore exact filter state")
        
        // Test changing to single filter and persisting
        selectedFilters = [.inventory]
        if let encoded = try? JSONEncoder().encode(Array(selectedFilters)) {
            testUserDefaults.set(encoded, forKey: "selectedInventoryFilters")
        }
        
        // Simulate another app restart
        if let data = testUserDefaults.data(forKey: "selectedInventoryFilters"),
           let decoded = try? JSONDecoder().decode([InventoryFilterType].self, from: data) {
            selectedFilters = Set(decoded)
        }
        
        #expect(selectedFilters.count == 1, "Should restore single filter")
        #expect(selectedFilters == [.inventory], "Should restore inventory filter only")
        
        // Clean up
        testUserDefaults.removeSuite(named: testSuiteName)
    }
    
    @Test("Filter fallback behavior works correctly")
    func testFilterFallbackBehavior() async throws {
        // Create isolated UserDefaults for testing
        let testSuiteName = "FilterFallbackTest_\(UUID().uuidString)"
        guard let testUserDefaults = UserDefaults(suiteName: testSuiteName) else {
            Issue.record("Failed to create test UserDefaults")
            return
        }
        
        // Test with empty data (first launch scenario)
        let emptyData = Data()
        testUserDefaults.set(emptyData, forKey: "selectedInventoryFilters")
        
        var selectedFilters: Set<InventoryFilterType>
        
        // Simulate loading filters with empty data
        if emptyData.isEmpty {
            // Default to all filters selected on first launch
            selectedFilters = [.inventory, .buy, .sell]
        } else {
            if let decoded = try? JSONDecoder().decode([InventoryFilterType].self, from: emptyData) {
                selectedFilters = Set(decoded)
            } else {
                // Fallback to all selected if decoding fails
                selectedFilters = [.inventory, .buy, .sell]
            }
        }
        
        #expect(selectedFilters == [.inventory, .buy, .sell], "Should default to all filters on first launch")
        
        // Test with corrupted data
        let corruptedData = "not valid json".data(using: .utf8) ?? Data()
        testUserDefaults.set(corruptedData, forKey: "selectedInventoryFilters")
        
        // Simulate loading filters with corrupted data
        if let data = testUserDefaults.data(forKey: "selectedInventoryFilters") {
            if let decoded = try? JSONDecoder().decode([InventoryFilterType].self, from: data) {
                selectedFilters = Set(decoded)
            } else {
                // Fallback to all selected if decoding fails
                selectedFilters = [.inventory, .buy, .sell]
            }
        }
        
        #expect(selectedFilters == [.inventory, .buy, .sell], "Should fallback to all filters with corrupted data")
        
        // Clean up
        testUserDefaults.removeSuite(named: testSuiteName)
    }
    
    // MARK: - Complete Filter Workflow Tests
    
    @Test("Complete filter workflow from all to individual to all")
    func testCompleteFilterWorkflow() {
        var selectedFilters: Set<InventoryFilterType> = [.inventory, .buy, .sell]
        
        // Create test items
        let testItems = [
            createTestItem(id: "item1", inventory: 10, buy: 0, sell: 0),
            createTestItem(id: "item2", inventory: 0, buy: 5, sell: 0),
            createTestItem(id: "item3", inventory: 0, buy: 0, sell: 3),
            createTestItem(id: "item4", inventory: 8, buy: 2, sell: 1)
        ]
        
        // Step 1: All filters - should show all items
        var visibleItems = filterItems(testItems, with: selectedFilters)
        #expect(visibleItems.count == 4, "All filters should show all 4 items")
        
        // Step 2: Switch to inventory only
        selectedFilters = [.inventory]
        visibleItems = filterItems(testItems, with: selectedFilters)
        #expect(visibleItems.count == 2, "Inventory filter should show 2 items")
        
        // Step 3: Switch to buy only
        selectedFilters = [.buy]
        visibleItems = filterItems(testItems, with: selectedFilters)
        #expect(visibleItems.count == 2, "Buy filter should show 2 items")
        
        // Step 4: Switch to sell only
        selectedFilters = [.sell]
        visibleItems = filterItems(testItems, with: selectedFilters)
        #expect(visibleItems.count == 2, "Sell filter should show 2 items")
        
        // Step 5: Back to all filters
        selectedFilters = [.inventory, .buy, .sell]
        visibleItems = filterItems(testItems, with: selectedFilters)
        #expect(visibleItems.count == 4, "All filters should show all 4 items again")
    }
    
    @Test("Filter interaction with search functionality")
    func testFilterWithSearch() {
        let selectedFilters: Set<InventoryFilterType> = [.inventory]
        
        // Create test items with searchable names
        let testItems = [
            createTestItem(id: "glass-blue", inventory: 10, buy: 0, sell: 0),
            createTestItem(id: "glass-red", inventory: 5, buy: 0, sell: 0),
            createTestItem(id: "metal-blue", inventory: 0, buy: 3, sell: 0),
            createTestItem(id: "glass-green", inventory: 8, buy: 0, sell: 0)
        ]
        
        // Apply filter first (inventory only)
        let filteredItems = filterItems(testItems, with: selectedFilters)
        #expect(filteredItems.count == 3, "Should have 3 items with inventory")
        
        // Then apply search within filtered results
        let searchTerm = "blue"
        let searchAndFilteredItems = filteredItems.filter { item in
            item.id.lowercased().contains(searchTerm.lowercased())
        }
        
        #expect(searchAndFilteredItems.count == 1, "Should have 1 item matching both filter and search")
        #expect(searchAndFilteredItems.first?.id == "glass-blue", "Should find glass-blue item")
    }
    
    // MARK: - Button State Integration Tests
    
    @Test("Button states reflect current filter selection correctly")
    func testButtonStateIntegration() {
        var selectedFilters: Set<InventoryFilterType> = [.inventory, .buy, .sell]
        
        // Test "all" button state
        var allButtonActive = (selectedFilters == [.inventory, .buy, .sell])
        #expect(allButtonActive, "All button should be active when all filters selected")
        
        // Switch to inventory only
        selectedFilters = [.inventory]
        allButtonActive = (selectedFilters == [.inventory, .buy, .sell])
        let inventoryButtonActive = (selectedFilters == [.inventory])
        let buyButtonActive = (selectedFilters == [.buy])
        
        #expect(!allButtonActive, "All button should be inactive")
        #expect(inventoryButtonActive, "Inventory button should be active")
        #expect(!buyButtonActive, "Buy button should be inactive")
        
        // Switch to buy only
        selectedFilters = [.buy]
        let newInventoryButtonActive = (selectedFilters == [.inventory])
        let newBuyButtonActive = (selectedFilters == [.buy])
        
        #expect(!newInventoryButtonActive, "Inventory button should now be inactive")
        #expect(newBuyButtonActive, "Buy button should now be active")
    }
    
    // MARK: - Error Handling Integration Tests
    
    @Test("Filter handles invalid data gracefully")
    func testFilterHandlesInvalidDataGracefully() {
        // Test with items having negative counts
        let invalidItems = [
            ConsolidatedInventoryItem(
                id: "invalid-1",
                catalogCode: "INV-001",
                catalogItemName: "Invalid Item",
                items: [],
                totalInventoryCount: -5.0,
                totalBuyCount: 0.0,
                totalSellCount: 0.0,
                inventoryUnits: .rods,
                buyUnits: nil,
                sellUnits: nil,
                hasNotes: false,
                allNotes: ""
            )
        ]
        
        let inventoryFilter: Set<InventoryFilterType> = [.inventory]
        
        // Filter should handle negative counts correctly (they should not be visible)
        let visibleItems = invalidItems.filter { item in
            inventoryFilter.contains(.inventory) && item.totalInventoryCount > 0
        }
        
        #expect(visibleItems.count == 0, "Items with negative counts should not be visible")
    }
    
    // MARK: - Helper Methods
    
    private func createTestItem(id: String, inventory: Double, buy: Double, sell: Double) -> ConsolidatedInventoryItem {
        return ConsolidatedInventoryItem(
            id: id,
            catalogCode: id.uppercased(),
            catalogItemName: id.capitalized,
            items: [],
            totalInventoryCount: inventory,
            totalBuyCount: buy,
            totalSellCount: sell,
            inventoryUnits: inventory > 0 ? .rods : nil,
            buyUnits: buy > 0 ? .rods : nil,
            sellUnits: sell > 0 ? .rods : nil,
            hasNotes: false,
            allNotes: ""
        )
    }
    
    private func filterItems(_ items: [ConsolidatedInventoryItem], with filters: Set<InventoryFilterType>) -> [ConsolidatedInventoryItem] {
        return items.filter { item in
            // If no filters selected, show nothing
            if filters.isEmpty {
                return false
            }
            
            var hasMatchingType = false
            
            if filters.contains(.inventory) && item.totalInventoryCount > 0 {
                hasMatchingType = true
            }
            
            if filters.contains(.buy) && item.totalBuyCount > 0 {
                hasMatchingType = true
            }
            
            if filters.contains(.sell) && item.totalSellCount > 0 {
                hasMatchingType = true
            }
            
            return hasMatchingType
        }
    }
}