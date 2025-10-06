//
//  CoreDataLogicTests.swift
//  FlameworkerTests
//
//  Created by Logic Fix on 10/5/25.
//

import Testing
import CoreData
@testable import Flameworker

@Suite("Core Data Logic Tests")
struct CoreDataLogicTests {
    
    @Test("InventoryUnits enum should have correct properties")
    func inventoryUnitsEnumShouldHaveCorrectProperties() async throws {
        // Test all enum cases
        let allUnits = InventoryUnits.allCases
        #expect(allUnits.count == 5, "Should have 5 inventory unit types")
        
        // Test specific cases
        #expect(InventoryUnits.rods.displayName == "Rods", "Rods display name should be correct")
        #expect(InventoryUnits.ounces.displayName == "oz", "Ounces display name should be correct")
        #expect(InventoryUnits.pounds.displayName == "lb", "Pounds display name should be correct")
        #expect(InventoryUnits.grams.displayName == "g", "Grams display name should be correct")
        #expect(InventoryUnits.kilograms.displayName == "kg", "Kilograms display name should be correct")
        
        // Test raw values
        #expect(InventoryUnits.rods.rawValue == 1, "Rods raw value should be 1")
        #expect(InventoryUnits.ounces.rawValue == 2, "Ounces raw value should be 2")
        
        // Test ID property
        #expect(InventoryUnits.rods.id == 1, "ID should match raw value")
    }
    
    @Test("safe collection operations should work with generic collections")
    func safeCollectionOperationsShouldWork() async throws {
        // Create a simple collection to test safe enumeration
        let items = ["Item1", "Item2", "Item3"]
        let itemSet = Set(items)
        
        var processedItems: [String] = []
        CoreDataHelpers.safelyEnumerate(itemSet) { item in
            processedItems.append(item)
        }
        
        #expect(processedItems.count == 3, "Should process all items")
        #expect(Set(processedItems) == itemSet, "Should process all items correctly")
    }
    
    @Test("image helper sanitization should work correctly")
    func imageHelperSanitizationShouldWork() async throws {
        // Test filename sanitization
        let unsafeCode = "CIM/101\\Test"
        let sanitized = ImageHelpers.sanitizeItemCodeForFilename(unsafeCode)
        
        #expect(sanitized == "CIM-101-Test", "Should replace slashes with dashes")
        
        // Test with already safe code
        let safeCode = "CIM-101-Safe"
        let sanitizedSafe = ImageHelpers.sanitizeItemCodeForFilename(safeCode)
        
        #expect(sanitizedSafe == safeCode, "Should not modify already safe code")
    }
    
    @Test("fetch request manual configuration should be consistent")
    func fetchRequestManualConfigurationShouldBeConsistent() async throws {
        // Test that we can create a fetch request without crashing
        // This tests our manual configuration approach
        let fetchRequest = NSFetchRequest<CatalogItem>(entityName: "CatalogItem")
        
        #expect(fetchRequest.entityName == "CatalogItem", "Entity name should be set correctly")
        
        // Test with predicate
        fetchRequest.predicate = NSPredicate(format: "id == %@", "TEST")
        #expect(fetchRequest.predicate != nil, "Predicate should be set")
        
        // Test with limit
        fetchRequest.fetchLimit = 1
        #expect(fetchRequest.fetchLimit == 1, "Fetch limit should be set")
    }
}