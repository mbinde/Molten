//  InventorySearchSuggestionsTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/13/25.
//  Comprehensive tests for InventorySearchSuggestions complex search algorithm - CORRECTED VERSION
//

import Foundation
import CryptoKit
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

@testable import Molten

@Suite("Inventory Search Suggestions Tests - Complex Algorithm")
@MainActor
struct InventorySearchSuggestionsTests {
    
    // MARK: - Test Data Creation Helpers
    
    private func createTestCompleteItems() -> [CompleteInventoryItemModel] {
        let glassItems: [GlassItemModel] = [
            GlassItemModel(stable_id: generateStableId(manufacturer: "Bullseye", sku: "RGR-001"), name: "Red Glass Rod", sku: "RGR-001", manufacturer: "Bullseye", coe: 90, mfr_status: "available"),
            GlassItemModel(stable_id: generateStableId(manufacturer: "Spectrum", sku: "BSG-002"), name: "Blue Stringer Glass", sku: "BSG-002", manufacturer: "Spectrum", coe: 96, mfr_status: "available"),
            GlassItemModel(stable_id: generateStableId(manufacturer: "Bullseye", sku: "CFF-003"), name: "Clear Frit", sku: "CFF-003", manufacturer: "Bullseye", coe: 90, mfr_status: "available"),
            GlassItemModel(stable_id: generateStableId(manufacturer: "Effetre", sku: "GS-004"), name: "Green Stringer", sku: "GS-004", manufacturer: "Effetre", coe: 104, mfr_status: "available"),
            GlassItemModel(stable_id: generateStableId(manufacturer: "Vetrofond", sku: "YOR-005"), name: "Yellow Orange Rod", sku: "YOR-005", manufacturer: "Vetrofond", coe: 104, mfr_status: "available"),
            GlassItemModel(stable_id: generateStableId(manufacturer: "Double Helix", sku: "PT-006"), name: "Purple Tube", sku: "PT-006", manufacturer: "Double Helix", coe: 96, mfr_status: "available")
        ]

        return glassItems.map { glassItem in
            CompleteInventoryItemModel(
                glassItem: glassItem,
                inventory: [],
                tags: ["glass", "test"],
                userTags: []
            )
        }
    }
    
    private func createTestInventoryModels() -> [InventoryModel] {
        return [
            InventoryModel(item_stable_id: generateStableId(manufacturer: "Bullseye", sku: "RGR-001"), type: "inventory", quantity: 5.0),
            InventoryModel(item_stable_id: generateStableId(manufacturer: "Spectrum", sku: "BSG-002"), type: "buy", quantity: 3.0),
            InventoryModel(item_stable_id: generateStableId(manufacturer: "Bullseye", sku: "CFF-003"), type: "inventory", quantity: 2.0)
        ]
    }
    
    // MARK: - Basic Functionality Tests
    
    @Test("Should return suggestions for valid queries")
    func testBasicSuggestions() async throws {
        let completeItems = createTestCompleteItems()
        let inventoryModels = createTestInventoryModels()
        
        // Search for items not in inventory
        let greenSuggestions = InventorySearchSuggestions.suggestedGlassItems(
            query: "green",
            inventoryModels: inventoryModels,
            completeItems: completeItems
        )

        #expect(greenSuggestions.count == 1, "Should find one green item")
        if !greenSuggestions.isEmpty {
            #expect(greenSuggestions[0].glassItem.stable_id == "effetre-gs-004", "Should find the green stringer")
            #expect(greenSuggestions[0].glassItem.name == "Green Stringer", "Should match the correct item")
        }
    }
    
    // MARK: - Inventory Exclusion Tests
    
    @Test("Should exclude items already in inventory by matching name")
    func testExactNameExclusion() async throws {
        let completeItems = createTestCompleteItems()
        let inventoryModels = createTestInventoryModels()
        
        // Test 1: Search for item that's in inventory by name - should be excluded
        let excludedResults = InventorySearchSuggestions.suggestedGlassItems(
            query: "Red Glass Rod",
            inventoryModels: inventoryModels,
            completeItems: completeItems
        )
        #expect(excludedResults.isEmpty, "Red Glass Rod should be excluded as it's in inventory")
        
        // Test 2: Search for item that's NOT in inventory by name - should be found
        let includedResults = InventorySearchSuggestions.suggestedGlassItems(
            query: "Green Stringer",
            inventoryModels: inventoryModels,
            completeItems: completeItems
        )
        #expect(includedResults.count == 1, "Green Stringer should be found as it's not in inventory")
        if !includedResults.isEmpty {
            #expect(includedResults[0].glassItem.name == "Green Stringer", "Should find Green Stringer")
        }
        
        // Test 3: Verify exclusion by checking a non-excluded item is found
        let nonExcludedResults = InventorySearchSuggestions.suggestedGlassItems(
            query: "green",
            inventoryModels: inventoryModels,
            completeItems: completeItems
        )
        #expect(!nonExcludedResults.isEmpty, "Should find green items as they're not excluded")
        let greenKeys = Set(nonExcludedResults.map { $0.glassItem.stable_id })
        #expect(greenKeys.contains("effetre-gs-004"), "Should find Green Stringer")
    }
    
    @Test("Should exclude items with case-insensitive natural key matching")
    func testCaseInsensitiveExclusion() async throws {
        let completeItems = createTestCompleteItems()

        // Create inventory item with stable_id (case doesn't matter for stable_id generation)
        let inventoryWithUppercase = [
            InventoryModel(item_stable_id: generateStableId(manufacturer: "Bullseye", sku: "CFF-003"), type: "inventory", quantity: 2.0)
        ]
        
        // Search for clear items - bullseye-cff-003 should be excluded due to case-insensitive matching
        let clearSuggestions = InventorySearchSuggestions.suggestedGlassItems(
            query: "clear",
            inventoryModels: inventoryWithUppercase,
            completeItems: completeItems
        )
        
        #expect(clearSuggestions.isEmpty, "Clear frit should be excluded due to case-insensitive natural key match")
    }
    
    @Test("Should handle multiple exclusion patterns")
    func testMultipleExclusionPatterns() async throws {
        let completeItems = createTestCompleteItems()

        // Create inventory with various exclusion patterns using stable_id (not natural_key)
        let complexInventory = [
            InventoryModel(item_stable_id: generateStableId(manufacturer: "Bullseye", sku: "RGR-001"), type: "inventory", quantity: 5.0),
            InventoryModel(item_stable_id: generateStableId(manufacturer: "Spectrum", sku: "BSG-002"), type: "buy", quantity: 3.0),
            InventoryModel(item_stable_id: generateStableId(manufacturer: "Bullseye", sku: "CFF-003"), type: "inventory", quantity: 2.0),
            InventoryModel(item_stable_id: generateStableId(manufacturer: "Double Helix", sku: "PT-006"), type: "inventory", quantity: 1.0)
        ]
        
        let remainingSuggestions = InventorySearchSuggestions.suggestedGlassItems(
            query: "glass",
            inventoryModels: complexInventory,
            completeItems: completeItems
        )
        
        // Should only find items not excluded by any pattern
        let remainingKeys = Set(remainingSuggestions.map { $0.glassItem.stable_id })
        
        #expect(!remainingKeys.contains("bullseye-rgr-001"), "Should exclude bullseye-rgr-001")
        #expect(!remainingKeys.contains("spectrum-bsg-002"), "Should exclude spectrum-bsg-002")
        #expect(!remainingKeys.contains("bullseye-cff-003"), "Should exclude bullseye-cff-003")
        #expect(!remainingKeys.contains("doublehelix-pt-006"), "Should exclude doublehelix-pt-006")
        
        // Should find items that are not in inventory
        #expect(remainingKeys.contains("effetre-gs-004"), "Should include effetre-gs-004")
        #expect(remainingKeys.contains("vetrofond-yor-005"), "Should include vetrofond-yor-005")
    }
    
    // MARK: - Query Handling Tests
    
    @Test("Should handle empty and whitespace queries")
    func testEmptyQueries() async throws {
        let completeItems = createTestCompleteItems()
        let inventoryModels = createTestInventoryModels()
        
        // Test empty query
        let emptyResults = InventorySearchSuggestions.suggestedGlassItems(
            query: "",
            inventoryModels: inventoryModels,
            completeItems: completeItems
        )
        #expect(emptyResults.isEmpty, "Empty query should return no results")
        
        // Test whitespace-only query
        let whitespaceResults = InventorySearchSuggestions.suggestedGlassItems(
            query: "   \t\n  ",
            inventoryModels: inventoryModels,
            completeItems: completeItems
        )
        #expect(whitespaceResults.isEmpty, "Whitespace-only query should return no results")
    }
    
    // MARK: - Edge Cases and Error Handling
    
    @Test("Should handle empty inventory models")
    func testEmptyInventoryModels() async throws {
        let completeItems = createTestCompleteItems()
        let emptyInventory: [InventoryModel] = []

        // Test with a specific search by name (not natural key)
        let specificResults = InventorySearchSuggestions.suggestedGlassItems(
            query: "Red Glass Rod",
            inventoryModels: emptyInventory,
            completeItems: completeItems
        )

        #expect(specificResults.count == 1, "Should find exactly one item for specific name search")
        if !specificResults.isEmpty {
            #expect(specificResults[0].glassItem.name == "Red Glass Rod", "Should find Red Glass Rod")
        }
        
        // Test that searches work when no inventory exclusions apply
        let broadResults = InventorySearchSuggestions.suggestedGlassItems(
            query: "glass",
            inventoryModels: emptyInventory,
            completeItems: completeItems
        )
        
        #expect(broadResults.count >= 1, "Should find at least one item for broad search")
        
        // The key test: verify that when there are no exclusions, we get results
        let redResults = InventorySearchSuggestions.suggestedGlassItems(
            query: "red",
            inventoryModels: emptyInventory,
            completeItems: completeItems
        )
        
        #expect(redResults.count >= 1, "Should find at least one result for 'red' search")
        let redKeys = Set(redResults.map { $0.glassItem.stable_id })
        #expect(redKeys.contains("bullseye-rgr-001"), "Should include Red Glass Rod in red search results")
    }
    
    @Test("Should test deprecated method returns empty")
    func testDeprecatedMethod() async throws {
        // Test that the deprecated method returns empty array
        let deprecatedResults = InventorySearchSuggestions.suggestedCatalogItems(
            query: "test",
            inventoryItems: [],
            catalogItems: []
        )
        
        #expect(deprecatedResults.isEmpty, "Deprecated method should return empty array")
    }
}
