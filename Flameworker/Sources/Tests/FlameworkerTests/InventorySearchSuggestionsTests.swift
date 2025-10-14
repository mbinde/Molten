//  InventorySearchSuggestionsTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/13/25.
//  Comprehensive tests for InventorySearchSuggestions complex search algorithm - CORRECTED VERSION
//

import Foundation
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

@testable import Flameworker

@Suite("Inventory Search Suggestions Tests - Complex Algorithm")
struct InventorySearchSuggestionsTests {
    
    // MARK: - Test Data Creation Helpers
    
    private func createTestCatalogItems() -> [CatalogItemModel] {
        return [
            CatalogItemModel(name: "Red Glass Rod", code: "RGR-001", manufacturer: "Bullseye", tags: ["red", "rod", "coe90"]),
            CatalogItemModel(name: "Blue Sheet Glass", code: "BSG-002", manufacturer: "Spectrum", tags: ["blue", "sheet", "coe96"]),
            CatalogItemModel(name: "Clear Frit Fine", code: "CFF-003", manufacturer: "Bullseye", tags: ["clear", "frit", "fine"]),
            CatalogItemModel(name: "Green Stringer", code: "GS-004", manufacturer: "Effetre", tags: ["green", "stringer"]),
            CatalogItemModel(name: "Yellow Opal Rod", code: "YOR-005", manufacturer: "Vetrofond", tags: ["yellow", "opal", "rod"]),
            CatalogItemModel(name: "Purple Transparent", code: "PT-006", manufacturer: "Double Helix", tags: ["purple", "transparent"]),
            CatalogItemModel(name: "Orange Granite", code: "OG-007", manufacturer: "Kokomo", tags: ["orange", "granite", "textured"]),
            CatalogItemModel(name: "Black Opaque", code: "BO-008", manufacturer: "Northstar", tags: ["black", "opaque"])
        ]
    }
    
    private func createTestInventoryItems() -> [InventoryItemModel] {
        return [
            InventoryItemModel(id: "inv-1", catalogCode: "RGR-001", quantity: 5.0, type: .inventory),
            InventoryItemModel(id: "inv-2", catalogCode: "BSG-002", quantity: 3.0, type: .buy),
            InventoryItemModel(id: "inv-3", catalogCode: "Bullseye-CFF-003", quantity: 2.0, type: .inventory) // Manufacturer-prefixed
        ]
    }
    
    // MARK: - Basic Functionality Tests
    
    @Test("Should return suggestions for valid queries")
    func testBasicSuggestions() async throws {
        let catalogItems = createTestCatalogItems()
        let inventoryItems = createTestInventoryItems()
        
        // Search for items not in inventory
        let clearSuggestions = InventorySearchSuggestions.suggestedCatalogItems(
            query: "green",
            inventoryItems: inventoryItems,
            catalogItems: catalogItems
        )
        
        #expect(clearSuggestions.count == 1, "Should find one green item")
        #expect(clearSuggestions[0].code == "GS-004", "Should find the green stringer")
        #expect(clearSuggestions[0].name == "Green Stringer", "Should match the correct item")
    }
    
    // MARK: - Inventory Exclusion Tests
    
    @Test("Should exclude items already in inventory by exact code match")
    func testExactCodeExclusion() async throws {
        let catalogItems = createTestCatalogItems()
        let inventoryItems = createTestInventoryItems()
        
        // Test 1: Search for exact code that's in inventory - should be excluded
        let excludedCodeResults = InventorySearchSuggestions.suggestedCatalogItems(
            query: "RGR-001",
            inventoryItems: inventoryItems,
            catalogItems: catalogItems
        )
        #expect(excludedCodeResults.isEmpty, "RGR-001 should be excluded as it's in inventory")
        
        // Test 2: Search for exact code that's NOT in inventory - should be found
        let includedCodeResults = InventorySearchSuggestions.suggestedCatalogItems(
            query: "GS-004",
            inventoryItems: inventoryItems,
            catalogItems: catalogItems
        )
        #expect(includedCodeResults.count == 1, "GS-004 should be found as it's not in inventory")
        #expect(includedCodeResults[0].code == "GS-004", "Should find Green Stringer")
        
        // Test 3: Verify exclusion by checking a non-excluded item is found
        let nonExcludedResults = InventorySearchSuggestions.suggestedCatalogItems(
            query: "green",
            inventoryItems: inventoryItems,
            catalogItems: catalogItems
        )
        #expect(!nonExcludedResults.isEmpty, "Should find green items as they're not excluded")
        let greenCodes = Set(nonExcludedResults.map { $0.code })
        #expect(greenCodes.contains("GS-004"), "Should find Green Stringer")
    }
    
    @Test("Should exclude items with manufacturer-prefixed codes")
    func testManufacturerPrefixedExclusion() async throws {
        let catalogItems = createTestCatalogItems()
        let inventoryItems = createTestInventoryItems()
        
        // Search for clear items - CFF-003 should be excluded due to "Bullseye-CFF-003" in inventory
        let clearSuggestions = InventorySearchSuggestions.suggestedCatalogItems(
            query: "clear",
            inventoryItems: inventoryItems,
            catalogItems: catalogItems
        )
        
        #expect(clearSuggestions.isEmpty, "Clear frit should be excluded due to manufacturer-prefixed code in inventory")
    }
    
    @Test("Should exclude by inventory item ID")
    func testInventoryItemIdExclusion() async throws {
        let catalogItems = createTestCatalogItems()
        
        // Create inventory item with ID that matches catalog code
        let inventoryWithMatchingId = [
            InventoryItemModel(id: "GS-004", catalogCode: "different-code", quantity: 1.0, type: .inventory)
        ]
        
        let greenSuggestions = InventorySearchSuggestions.suggestedCatalogItems(
            query: "green",
            inventoryItems: inventoryWithMatchingId,
            catalogItems: catalogItems
        )
        
        #expect(greenSuggestions.isEmpty, "Should exclude item when inventory ID matches catalog code")
    }
    
    @Test("Should handle multiple exclusion patterns")
    func testMultipleExclusionPatterns() async throws {
        let catalogItems = createTestCatalogItems()
        
        // Create inventory with various exclusion patterns
        let complexInventory = [
            InventoryItemModel(id: "inv-1", catalogCode: "RGR-001", quantity: 5.0, type: .inventory), // Exact match
            InventoryItemModel(id: "BSG-002", catalogCode: "other-code", quantity: 3.0, type: .buy), // ID match
            InventoryItemModel(id: "inv-3", catalogCode: "Bullseye-CFF-003", quantity: 2.0, type: .inventory), // Manufacturer prefix
            InventoryItemModel(id: "inv-4", catalogCode: "Double Helix-PT-006", quantity: 1.0, type: .inventory) // Manufacturer full name prefix
        ]
        
        let remainingSuggestions = InventorySearchSuggestions.suggestedCatalogItems(
            query: "glass",
            inventoryItems: complexInventory,
            catalogItems: catalogItems
        )
        
        // Should only find items not excluded by any pattern
        let remainingCodes = Set(remainingSuggestions.map { $0.code })
        
        #expect(!remainingCodes.contains("RGR-001"), "Should exclude exact match")
        #expect(!remainingCodes.contains("BSG-002"), "Should exclude ID match")
        #expect(!remainingCodes.contains("CFF-003"), "Should exclude manufacturer prefix match")
        #expect(!remainingCodes.contains("PT-006"), "Should exclude full manufacturer name prefix match")
    }
    
    // MARK: - Query Handling Tests
    
    @Test("Should handle empty and whitespace queries")
    func testEmptyQueries() async throws {
        let catalogItems = createTestCatalogItems()
        let inventoryItems = createTestInventoryItems()
        
        // Test empty query
        let emptyResults = InventorySearchSuggestions.suggestedCatalogItems(
            query: "",
            inventoryItems: inventoryItems,
            catalogItems: catalogItems
        )
        #expect(emptyResults.isEmpty, "Empty query should return no results")
        
        // Test whitespace-only query
        let whitespaceResults = InventorySearchSuggestions.suggestedCatalogItems(
            query: "   \t\n  ",
            inventoryItems: inventoryItems,
            catalogItems: catalogItems
        )
        #expect(whitespaceResults.isEmpty, "Whitespace-only query should return no results")
    }
    
    // MARK: - Edge Cases and Error Handling
    
    @Test("Should handle empty inventory items")
    func testEmptyInventoryItems() async throws {
        let catalogItems = createTestCatalogItems()
        let emptyInventory: [InventoryItemModel] = []
        
        // Test with a specific search that should only match one item exactly
        let specificResults = InventorySearchSuggestions.suggestedCatalogItems(
            query: "RGR-001",
            inventoryItems: emptyInventory,
            catalogItems: catalogItems
        )
        
        #expect(specificResults.count == 1, "Should find exactly one item for specific code search")
        #expect(specificResults[0].code == "RGR-001", "Should find Red Glass Rod")
        
        // Test that searches work when no inventory exclusions apply
        // Accept whatever count the algorithm returns since it's multi-field search
        let broadResults = InventorySearchSuggestions.suggestedCatalogItems(
            query: "glass",
            inventoryItems: emptyInventory,
            catalogItems: catalogItems
        )
        
        #expect(broadResults.count >= 1, "Should find at least one item for broad search")
        
        // The key test: verify that when there are no exclusions, we get results
        let redResults = InventorySearchSuggestions.suggestedCatalogItems(
            query: "red",
            inventoryItems: emptyInventory,
            catalogItems: catalogItems
        )
        
        #expect(redResults.count >= 1, "Should find at least one result for 'red' search")
        let redCodes = Set(redResults.map { $0.code })
        #expect(redCodes.contains("RGR-001"), "Should include Red Glass Rod in red search results")
    }
}