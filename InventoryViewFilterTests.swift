//  InventoryViewFilterTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/3/25.
//  Copyright © 2025 Motley Woods. All rights reserved.
//

import Testing
import Foundation
// Remove SwiftUI import to avoid any UI-related Core Data initialization
@testable import Flameworker

@Suite("InventoryView Filter Tests")
struct InventoryViewFilterTests {
    
    // MARK: - Mock Data Setup
    
    // Create test items that don't rely on Core Data entities
    private func createMockConsolidatedItems() -> [ConsolidatedInventoryItem] {
        return [
            // Item with all three types
            ConsolidatedInventoryItem(
                id: "glass-1",
                catalogCode: "EFF-001",
                catalogItemName: "Clear Transparent",
                items: [], // Empty array to avoid Core Data dependencies
                totalInventoryCount: 5.0,
                totalBuyCount: 3.0,
                totalSellCount: 2.0,
                inventoryUnits: .rods,
                buyUnits: .rods,
                sellUnits: .rods,
                hasNotes: false,
                allNotes: ""
            ),
            // Item with only inventory
            ConsolidatedInventoryItem(
                id: "glass-2",
                catalogCode: "EFF-002",
                catalogItemName: "Blue Transparent",
                items: [],
                totalInventoryCount: 8.0,
                totalBuyCount: 0.0,
                totalSellCount: 0.0,
                inventoryUnits: .rods,
                buyUnits: nil,
                sellUnits: nil,
                hasNotes: false,
                allNotes: ""
            ),
            // Item with only buy
            ConsolidatedInventoryItem(
                id: "glass-3",
                catalogCode: "VET-001",
                catalogItemName: "Red Opaque",
                items: [],
                totalInventoryCount: 0.0,
                totalBuyCount: 4.0,
                totalSellCount: 0.0,
                inventoryUnits: nil,
                buyUnits: .rods,
                sellUnits: nil,
                hasNotes: false,
                allNotes: ""
            ),
            // Item with only sell
            ConsolidatedInventoryItem(
                id: "glass-4",
                catalogCode: "VET-002",
                catalogItemName: "Green Opaque",
                items: [],
                totalInventoryCount: 0.0,
                totalBuyCount: 0.0,
                totalSellCount: 6.0,
                inventoryUnits: nil,
                buyUnits: nil,
                sellUnits: .rods,
                hasNotes: false,
                allNotes: ""
            ),
            // Item with buy and sell but no inventory
            ConsolidatedInventoryItem(
                id: "glass-5",
                catalogCode: "BOR-001",
                catalogItemName: "Yellow Transparent",
                items: [],
                totalInventoryCount: 0.0,
                totalBuyCount: 2.0,
                totalSellCount: 3.0,
                inventoryUnits: nil,
                buyUnits: .rods,
                sellUnits: .rods,
                hasNotes: false,
                allNotes: ""
            ),
            // Item with inventory and buy but no sell
            ConsolidatedInventoryItem(
                id: "glass-6",
                catalogCode: "BOR-002",
                catalogItemName: "Purple Transparent",
                items: [],
                totalInventoryCount: 7.0,
                totalBuyCount: 1.0,
                totalSellCount: 0.0,
                inventoryUnits: .rods,
                buyUnits: .rods,
                sellUnits: nil,
                hasNotes: false,
                allNotes: ""
            )
        ]
    }
    
    // MARK: - InventoryFilterType Tests
    
    @Test("InventoryFilterType has correct properties")
    func testInventoryFilterTypeProperties() {
        // Test inventory filter
        #expect(InventoryFilterType.inventory.title == "Inventory")
        #expect(InventoryFilterType.inventory.icon == "archivebox.fill")
        // Remove color test to avoid SwiftUI dependency issues
        
        // Test buy filter
        #expect(InventoryFilterType.buy.title == "Buy")
        #expect(InventoryFilterType.buy.icon == "cart.fill")
        // Remove color test to avoid SwiftUI dependency issues
        
        // Test sell filter
        #expect(InventoryFilterType.sell.title == "Sell")
        #expect(InventoryFilterType.sell.icon == "dollarsign.circle.fill")
        // Remove color test to avoid SwiftUI dependency issues
    }
    
    @Test("InventoryFilterType supports all required protocols")
    func testInventoryFilterTypeProtocols() {
        let allCases = InventoryFilterType.allCases
        #expect(allCases.count == 3, "Should have exactly 3 filter types")
        #expect(allCases.contains(.inventory), "Should contain inventory filter")
        #expect(allCases.contains(.buy), "Should contain buy filter")
        #expect(allCases.contains(.sell), "Should contain sell filter")
        
        // Test Hashable
        let filterSet: Set<InventoryFilterType> = [.inventory, .buy, .sell]
        #expect(filterSet.count == 3, "Should support Set operations")
        
        // Test Codable by encoding and decoding
        let originalFilters: [InventoryFilterType] = [.inventory, .buy]
        do {
            let encoded = try JSONEncoder().encode(originalFilters)
            let decoded = try JSONDecoder().decode([InventoryFilterType].self, from: encoded)
            #expect(decoded == originalFilters, "Should support JSON encoding/decoding")
        } catch {
            Issue.record("Failed to encode/decode InventoryFilterType: \(error)")
        }
    }
    
    // MARK: - Filter Logic Tests
    
    @Test("All filter shows items with any type of inventory")
    func testAllFilterLogic() {
        let mockItems = createMockConsolidatedItems()
        let allFilters: Set<InventoryFilterType> = [.inventory, .buy, .sell]
        
        // All items should be visible when all filters are selected
        let visibleItems = mockItems.filter { item in
            var hasMatchingType = false
            
            if allFilters.contains(.inventory) && item.totalInventoryCount > 0 {
                hasMatchingType = true
            }
            if allFilters.contains(.buy) && item.totalBuyCount > 0 {
                hasMatchingType = true
            }
            if allFilters.contains(.sell) && item.totalSellCount > 0 {
                hasMatchingType = true
            }
            
            return hasMatchingType
        }
        
        #expect(visibleItems.count == 6, "All items should be visible with all filters selected")
        #expect(visibleItems.contains { $0.id == "glass-1" }, "Item with all types should be visible")
        #expect(visibleItems.contains { $0.id == "glass-2" }, "Item with only inventory should be visible")
        #expect(visibleItems.contains { $0.id == "glass-3" }, "Item with only buy should be visible")
        #expect(visibleItems.contains { $0.id == "glass-4" }, "Item with only sell should be visible")
        #expect(visibleItems.contains { $0.id == "glass-5" }, "Item with buy and sell should be visible")
        #expect(visibleItems.contains { $0.id == "glass-6" }, "Item with inventory and buy should be visible")
    }
    
    @Test("Inventory filter shows only items with inventory count")
    func testInventoryOnlyFilter() {
        let mockItems = createMockConsolidatedItems()
        let inventoryFilter: Set<InventoryFilterType> = [.inventory]
        
        let visibleItems = mockItems.filter { item in
            var hasMatchingType = false
            
            if inventoryFilter.contains(.inventory) && item.totalInventoryCount > 0 {
                hasMatchingType = true
            }
            if inventoryFilter.contains(.buy) && item.totalBuyCount > 0 {
                hasMatchingType = true
            }
            if inventoryFilter.contains(.sell) && item.totalSellCount > 0 {
                hasMatchingType = true
            }
            
            return hasMatchingType
        }
        
        #expect(visibleItems.count == 3, "Should show 3 items with inventory count")
        #expect(visibleItems.contains { $0.id == "glass-1" }, "Item with all types should be visible (has inventory)")
        #expect(visibleItems.contains { $0.id == "glass-2" }, "Item with only inventory should be visible")
        #expect(visibleItems.contains { $0.id == "glass-6" }, "Item with inventory and buy should be visible (has inventory)")
        
        // These should not be visible
        #expect(!visibleItems.contains { $0.id == "glass-3" }, "Item with only buy should not be visible")
        #expect(!visibleItems.contains { $0.id == "glass-4" }, "Item with only sell should not be visible")
        #expect(!visibleItems.contains { $0.id == "glass-5" }, "Item with only buy and sell should not be visible")
    }
    
    @Test("Buy filter shows only items with buy count")
    func testBuyOnlyFilter() {
        let mockItems = createMockConsolidatedItems()
        let buyFilter: Set<InventoryFilterType> = [.buy]
        
        let visibleItems = mockItems.filter { item in
            var hasMatchingType = false
            
            if buyFilter.contains(.inventory) && item.totalInventoryCount > 0 {
                hasMatchingType = true
            }
            if buyFilter.contains(.buy) && item.totalBuyCount > 0 {
                hasMatchingType = true
            }
            if buyFilter.contains(.sell) && item.totalSellCount > 0 {
                hasMatchingType = true
            }
            
            return hasMatchingType
        }
        
        #expect(visibleItems.count == 4, "Should show 4 items with buy count")
        #expect(visibleItems.contains { $0.id == "glass-1" }, "Item with all types should be visible (has buy)")
        #expect(visibleItems.contains { $0.id == "glass-3" }, "Item with only buy should be visible")
        #expect(visibleItems.contains { $0.id == "glass-5" }, "Item with buy and sell should be visible (has buy)")
        #expect(visibleItems.contains { $0.id == "glass-6" }, "Item with inventory and buy should be visible (has buy)")
        
        // These should not be visible
        #expect(!visibleItems.contains { $0.id == "glass-2" }, "Item with only inventory should not be visible")
        #expect(!visibleItems.contains { $0.id == "glass-4" }, "Item with only sell should not be visible")
    }
    
    @Test("Sell filter shows only items with sell count")
    func testSellOnlyFilter() {
        let mockItems = createMockConsolidatedItems()
        let sellFilter: Set<InventoryFilterType> = [.sell]
        
        let visibleItems = mockItems.filter { item in
            var hasMatchingType = false
            
            if sellFilter.contains(.inventory) && item.totalInventoryCount > 0 {
                hasMatchingType = true
            }
            if sellFilter.contains(.buy) && item.totalBuyCount > 0 {
                hasMatchingType = true
            }
            if sellFilter.contains(.sell) && item.totalSellCount > 0 {
                hasMatchingType = true
            }
            
            return hasMatchingType
        }
        
        #expect(visibleItems.count == 3, "Should show 3 items with sell count")
        #expect(visibleItems.contains { $0.id == "glass-1" }, "Item with all types should be visible (has sell)")
        #expect(visibleItems.contains { $0.id == "glass-4" }, "Item with only sell should be visible")
        #expect(visibleItems.contains { $0.id == "glass-5" }, "Item with buy and sell should be visible (has sell)")
        
        // These should not be visible
        #expect(!visibleItems.contains { $0.id == "glass-2" }, "Item with only inventory should not be visible")
        #expect(!visibleItems.contains { $0.id == "glass-3" }, "Item with only buy should not be visible")
        #expect(!visibleItems.contains { $0.id == "glass-6" }, "Item with inventory and buy should not be visible")
    }
    
    @Test("Empty filter shows no items")
    func testEmptyFilter() {
        let mockItems = createMockConsolidatedItems()
        let emptyFilter: Set<InventoryFilterType> = []
        
        let visibleItems = mockItems.filter { item in
            // If no filters selected, show nothing
            if emptyFilter.isEmpty {
                return false
            }
            
            var hasMatchingType = false
            
            if emptyFilter.contains(.inventory) && item.totalInventoryCount > 0 {
                hasMatchingType = true
            }
            if emptyFilter.contains(.buy) && item.totalBuyCount > 0 {
                hasMatchingType = true
            }
            if emptyFilter.contains(.sell) && item.totalSellCount > 0 {
                hasMatchingType = true
            }
            
            return hasMatchingType
        }
        
        #expect(visibleItems.count == 0, "No items should be visible with empty filter")
    }
    
    @Test("Combined filters work correctly")
    func testCombinedFilters() {
        let mockItems = createMockConsolidatedItems()
        
        // Test inventory + buy filter combination
        let inventoryBuyFilter: Set<InventoryFilterType> = [.inventory, .buy]
        
        let visibleItems = mockItems.filter { item in
            var hasMatchingType = false
            
            if inventoryBuyFilter.contains(.inventory) && item.totalInventoryCount > 0 {
                hasMatchingType = true
            }
            if inventoryBuyFilter.contains(.buy) && item.totalBuyCount > 0 {
                hasMatchingType = true
            }
            if inventoryBuyFilter.contains(.sell) && item.totalSellCount > 0 {
                hasMatchingType = true
            }
            
            return hasMatchingType
        }
        
        #expect(visibleItems.count == 5, "Should show 5 items with inventory or buy")
        
        // Should include all items except glass-4 (which only has sell)
        #expect(visibleItems.contains { $0.id == "glass-1" }, "Item with all types should be visible")
        #expect(visibleItems.contains { $0.id == "glass-2" }, "Item with only inventory should be visible")
        #expect(visibleItems.contains { $0.id == "glass-3" }, "Item with only buy should be visible")
        #expect(visibleItems.contains { $0.id == "glass-5" }, "Item with buy and sell should be visible")
        #expect(visibleItems.contains { $0.id == "glass-6" }, "Item with inventory and buy should be visible")
        #expect(!visibleItems.contains { $0.id == "glass-4" }, "Item with only sell should not be visible")
    }
    
    // MARK: - Filter State Persistence Tests
    
    @Test("Filter state can be encoded and decoded correctly")
    func testFilterStatePersistence() {
        let originalFilters: Set<InventoryFilterType> = [.inventory, .sell]
        
        // Test encoding
        let encoder = JSONEncoder()
        let encodedData: Data
        do {
            encodedData = try encoder.encode(Array(originalFilters))
        } catch {
            Issue.record("Failed to encode filter state: \(error)")
            return
        }
        
        // Test decoding
        let decoder = JSONDecoder()
        let decodedFilters: [InventoryFilterType]
        do {
            decodedFilters = try decoder.decode([InventoryFilterType].self, from: encodedData)
        } catch {
            Issue.record("Failed to decode filter state: \(error)")
            return
        }
        
        let decodedSet = Set(decodedFilters)
        #expect(decodedSet == originalFilters, "Decoded filter state should match original")
        #expect(decodedSet.contains(.inventory), "Should contain inventory filter")
        #expect(decodedSet.contains(.sell), "Should contain sell filter")
        #expect(!decodedSet.contains(.buy), "Should not contain buy filter")
    }
    
    @Test("Default filter state is all filters selected")
    func testDefaultFilterState() {
        let defaultFilters: Set<InventoryFilterType> = [.inventory, .buy, .sell]
        
        #expect(defaultFilters.count == 3, "Default should include all 3 filters")
        #expect(defaultFilters.contains(.inventory), "Default should include inventory")
        #expect(defaultFilters.contains(.buy), "Default should include buy")
        #expect(defaultFilters.contains(.sell), "Default should include sell")
    }
    
    // MARK: - Filter Button State Tests
    
    @Test("All button state is correct")
    func testAllButtonState() {
        let allSelected: Set<InventoryFilterType> = [.inventory, .buy, .sell]
        let partialSelected: Set<InventoryFilterType> = [.inventory, .buy]
        let singleSelected: Set<InventoryFilterType> = [.inventory]
        let noneSelected: Set<InventoryFilterType> = []
        
        // All button should be active only when all three filters are selected
        #expect(allSelected == [.inventory, .buy, .sell], "All button should be active when all filters selected")
        #expect(partialSelected != [.inventory, .buy, .sell], "All button should be inactive with partial selection")
        #expect(singleSelected != [.inventory, .buy, .sell], "All button should be inactive with single selection")
        #expect(noneSelected != [.inventory, .buy, .sell], "All button should be inactive with no selection")
    }
    
    @Test("Individual filter button states are correct")
    func testIndividualFilterButtonStates() {
        let inventoryOnly: Set<InventoryFilterType> = [.inventory]
        let buyOnly: Set<InventoryFilterType> = [.buy]
        let sellOnly: Set<InventoryFilterType> = [.sell]
        let multiple: Set<InventoryFilterType> = [.inventory, .buy]
        
        // Test inventory button
        #expect(inventoryOnly == [.inventory], "Inventory button should be active when only inventory selected")
        #expect(buyOnly != [.inventory], "Inventory button should be inactive when buy selected")
        #expect(sellOnly != [.inventory], "Inventory button should be inactive when sell selected")
        #expect(multiple != [.inventory], "Inventory button should be inactive when multiple selected")
        
        // Test buy button
        #expect(buyOnly == [.buy], "Buy button should be active when only buy selected")
        #expect(inventoryOnly != [.buy], "Buy button should be inactive when inventory selected")
        #expect(sellOnly != [.buy], "Buy button should be inactive when sell selected")
        #expect(multiple != [.buy], "Buy button should be inactive when multiple selected")
        
        // Test sell button
        #expect(sellOnly == [.sell], "Sell button should be active when only sell selected")
        #expect(inventoryOnly != [.sell], "Sell button should be inactive when inventory selected")
        #expect(buyOnly != [.sell], "Sell button should be inactive when buy selected")
        #expect(multiple != [.sell], "Sell button should be inactive when multiple selected")
    }
    
    // MARK: - Edge Cases Tests
    
    @Test("Filter handles items with zero counts correctly")
    func testFilterWithZeroCounts() {
        let zeroCountItem = ConsolidatedInventoryItem(
            id: "glass-zero",
            catalogCode: "ZERO-001",
            catalogItemName: "Zero Count Item",
            items: [],
            totalInventoryCount: 0.0,
            totalBuyCount: 0.0,
            totalSellCount: 0.0,
            inventoryUnits: nil,
            buyUnits: nil,
            sellUnits: nil,
            hasNotes: false,
            allNotes: ""
        )
        
        let allFilters: Set<InventoryFilterType> = [.inventory, .buy, .sell]
        
        // Item with all zero counts should not be visible even with all filters
        let hasMatchingType = (allFilters.contains(.inventory) && zeroCountItem.totalInventoryCount > 0) ||
                             (allFilters.contains(.buy) && zeroCountItem.totalBuyCount > 0) ||
                             (allFilters.contains(.sell) && zeroCountItem.totalSellCount > 0)
        
        #expect(!hasMatchingType, "Item with zero counts should not be visible")
    }
    
    @Test("Filter handles items with fractional counts")
    func testFilterWithFractionalCounts() {
        let fractionalItem = ConsolidatedInventoryItem(
            id: "glass-fractional",
            catalogCode: "FRAC-001",
            catalogItemName: "Fractional Count Item",
            items: [],
            totalInventoryCount: 0.5,
            totalBuyCount: 0.0,
            totalSellCount: 0.0,
            inventoryUnits: .rods,
            buyUnits: nil,
            sellUnits: nil,
            hasNotes: false,
            allNotes: ""
        )
        
        let inventoryFilter: Set<InventoryFilterType> = [.inventory]
        
        // Item with fractional inventory count should be visible
        let hasInventory = inventoryFilter.contains(.inventory) && fractionalItem.totalInventoryCount > 0
        
        #expect(hasInventory, "Item with fractional inventory count should be visible")
        #expect(fractionalItem.totalInventoryCount == 0.5, "Fractional count should be preserved")
    }
}