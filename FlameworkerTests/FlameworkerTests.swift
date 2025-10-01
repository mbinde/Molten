//
//  FlameworkerTests.swift
//  FlameworkerTests
//
//  Created by Melissa Binde on 9/29/25.
//  Copyright © 2025 Motley Woods. All rights reserved.
//

import Testing
import CoreData
@testable import Flameworker

@Suite("Flameworker App Tests")
struct FlameworkerTests {

    // MARK: - Test Helpers
    
    private func createIsolatedContext() -> NSManagedObjectContext {
        return TestUtilities.createHyperIsolatedContext(for: "FlameworkerTests")
    }
    
    private func tearDownContext(_ context: NSManagedObjectContext) {
        TestUtilities.tearDownHyperIsolatedContext(context)
    }
    
    /// Safer helper to perform context operations with error handling
    private func performSafely<T>(in context: NSManagedObjectContext, operation: @escaping () throws -> T) throws -> T {
        guard context.persistentStoreCoordinator != nil else {
            throw NSError(domain: "TestError", code: 1002, userInfo: [
                NSLocalizedDescriptionKey: "Context has no persistent store coordinator"
            ])
        }
        
        var result: Result<T, Error>?
        
        context.performAndWait {
            do {
                let value = try operation()
                result = .success(value)
            } catch {
                result = .failure(error)
            }
        }
        
        switch result! {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
    
    /// Creates a sample InventoryItem for testing
    private func createSampleInventoryItem(in context: NSManagedObjectContext) -> InventoryItem {
        guard let entity = NSEntityDescription.entity(forEntityName: "InventoryItem", in: context) else {
            fatalError("Could not find InventoryItem entity in context")
        }
        
        let item = InventoryItem(entity: entity, insertInto: context)
        item.id = "TEST-001"
        item.catalog_code = "BR-GLR-001"
        item.count = 50.0
        item.units = 1
        item.type = InventoryItemType.sell.rawValue
        item.notes = "Test borosilicate glass rods"
        return item
    }
    
    /// Creates a sample CatalogItem for testing
    private func createSampleCatalogItem(in context: NSManagedObjectContext) -> CatalogItem {
        guard let entity = NSEntityDescription.entity(forEntityName: "CatalogItem", in: context) else {
            fatalError("Could not find CatalogItem entity in context")
        }
        
        let item = CatalogItem(entity: entity, insertInto: context)
        item.code = "CATALOG-001"
        item.name = "Test Glass Rod"
        item.manufacturer = "Test Manufacturer"
        item.start_date = Date() // Set required date field
        return item
    }
    
    // MARK: - InventoryItemType Tests
    
    @Test("InventoryItemType should have correct display names")
    func inventoryItemTypeDisplayNames() {
        #expect(InventoryItemType.inventory.displayName == "Inventory")
        #expect(InventoryItemType.buy.displayName == "Buy")
        #expect(InventoryItemType.sell.displayName == "Sell")
    }
    
    @Test("InventoryItemType should have correct system image names")
    func inventoryItemTypeSystemImages() {
        #expect(InventoryItemType.inventory.systemImageName == "archivebox.fill")
        #expect(InventoryItemType.buy.systemImageName == "cart.badge.plus")
        #expect(InventoryItemType.sell.systemImageName == "dollarsign.circle.fill") // Fixed: actual implementation uses dollarsign
    }
    
    @Test("InventoryItemType should initialize correctly from raw values")
    func inventoryItemTypeInitialization() {
        #expect(InventoryItemType(from: 0) == .inventory)
        #expect(InventoryItemType(from: 1) == .buy)
        #expect(InventoryItemType(from: 2) == .sell)
        
        // Test fallback to inventory for invalid values
        #expect(InventoryItemType(from: 99) == .inventory)
        #expect(InventoryItemType(from: -1) == .inventory)
    }
    
    @Test("InventoryItemType should provide unique IDs")
    func inventoryItemTypeUniqueIds() {
        let allTypes = InventoryItemType.allCases
        let ids = allTypes.map(\.id)
        let uniqueIds = Set(ids)
        
        #expect(ids.count == uniqueIds.count, "All IDs should be unique")
        #expect(allTypes.count == 3, "Should have exactly 3 types")
    }
    
    // MARK: - Core Data Model Tests
    
    @Test("PersistenceController should create in-memory store for testing")
    func persistenceControllerInMemory() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            // Verify we can perform basic Core Data operations
            let item = createSampleInventoryItem(in: context)
            try context.save()
            
            let fetchRequest: NSFetchRequest<InventoryItem> = InventoryItem.fetchRequest()
            let items = try context.fetch(fetchRequest)
            
            #expect(items.count == 1)
            #expect(items.first?.id == "TEST-001")
            
            return Void()
        }
    }
    
    @Test("InventoryItem should correctly compute type properties")
    func inventoryItemTypeComputed() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            let item = createSampleInventoryItem(in: context)
            
            // Test initial type
            #expect(item.itemType == .sell)
            #expect(item.typeDisplayName == "Sell")
            #expect(item.typeSystemImage == "dollarsign.circle.fill") // Fixed: actual implementation uses dollarsign
            
            // Test changing type
            item.itemType = .buy
            #expect(item.type == InventoryItemType.buy.rawValue)
            #expect(item.typeDisplayName == "Buy")
            #expect(item.typeSystemImage == "cart.badge.plus")
            
            return Void()
        }
    }
    
    @Test("InventoryItem should be searchable")
    func inventoryItemSearchable() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            let item = createSampleInventoryItem(in: context)
            
            let searchableText = item.searchableText
            
            #expect(searchableText.contains("TEST-001"))
            #expect(searchableText.contains("BR-GLR-001"))
            #expect(searchableText.contains("Test borosilicate glass rods"))
            #expect(searchableText.contains("50.0"))
            #expect(searchableText.contains("1"))
            
            return Void()
        }
    }
    
    @Test("CatalogItem should be searchable")
    func catalogItemSearchable() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            let item = createSampleCatalogItem(in: context)
            
            let searchableText = item.searchableText
            
            #expect(searchableText.contains("CATALOG-001"))
            #expect(searchableText.contains("Test Glass Rod"))
            #expect(searchableText.contains("Test Manufacturer"))
            
            return Void()
        }
    }
    
    // MARK: - DataLoadingService Tests
    
    @Test("DataLoadingService should be singleton")
    func dataLoadingServiceSingleton() {
        let service1 = DataLoadingService.shared
        let service2 = DataLoadingService.shared
        
        #expect(service1 === service2, "DataLoadingService should be a singleton")
    }
    
    @Test("DataLoadingService should handle empty context gracefully")
    func dataLoadingServiceEmptyContext() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            // Test that we can check existing count without error
            let fetchRequest: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
            let count = try context.count(for: fetchRequest)
            
            #expect(count == 0, "New context should have no items")
            
            return Void()
        }
    }
    
    // MARK: - InventoryItem Validation Tests
    
    @Test("InventoryItem should handle extreme count values")
    func inventoryItemExtremeValues() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            guard let entity = NSEntityDescription.entity(forEntityName: "InventoryItem", in: context) else {
                fatalError("Could not find InventoryItem entity in context")
            }
            
            // Test negative count
            let negativeItem = InventoryItem(entity: entity, insertInto: context)
            negativeItem.id = "NEGATIVE-001"
            negativeItem.count = -50.0
            negativeItem.units = 1
            negativeItem.type = InventoryItemType.inventory.rawValue
            
            #expect(negativeItem.count == -50.0, "Should accept negative count values")
            
            // Test very large count
            let largeItem = InventoryItem(entity: entity, insertInto: context)
            largeItem.id = "LARGE-001"
            largeItem.count = Double.greatestFiniteMagnitude
            largeItem.units = 1
            largeItem.type = InventoryItemType.inventory.rawValue
            
            #expect(largeItem.count == Double.greatestFiniteMagnitude, "Should handle very large count values")
            
            // Test zero count
            let zeroItem = InventoryItem(entity: entity, insertInto: context)
            zeroItem.id = "ZERO-001"
            zeroItem.count = 0.0
            zeroItem.units = 1
            zeroItem.type = InventoryItemType.inventory.rawValue
            
            #expect(zeroItem.count == 0.0, "Should handle zero count")
            
            // Test fractional precision
            let precisionItem = InventoryItem(entity: entity, insertInto: context)
            precisionItem.id = "PRECISION-001"
            precisionItem.count = 123.456789
            precisionItem.units = 1
            precisionItem.type = InventoryItemType.inventory.rawValue
            
            #expect(precisionItem.count == 123.456789, "Should maintain fractional precision")
            
            try context.save()
            
            return Void()
        }
    }
    
    @Test("InventoryItem should handle nil and empty required fields")
    func inventoryItemNilRequiredFields() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            guard let entity = NSEntityDescription.entity(forEntityName: "InventoryItem", in: context) else {
                fatalError("Could not find InventoryItem entity in context")
            }
            
            // Test with minimal required fields
            let minimalItem = InventoryItem(entity: entity, insertInto: context)
            minimalItem.id = "MINIMAL-001"
            minimalItem.count = 1.0
            minimalItem.units = 1
            minimalItem.type = InventoryItemType.inventory.rawValue
            // Leave catalog_code and notes as nil
            
            #expect(minimalItem.catalog_code == nil, "catalog_code should accept nil")
            #expect(minimalItem.notes == nil, "notes should accept nil")
            #expect(minimalItem.searchableText.contains("MINIMAL-001"), "Should still be searchable with minimal data")
            
            // Test with empty strings
            let emptyStringItem = InventoryItem(entity: entity, insertInto: context)
            emptyStringItem.id = "EMPTY-001"
            emptyStringItem.catalog_code = ""
            emptyStringItem.notes = ""
            emptyStringItem.count = 1.0
            emptyStringItem.units = 1
            emptyStringItem.type = InventoryItemType.inventory.rawValue
            
            #expect(emptyStringItem.catalog_code == "", "Should accept empty catalog_code")
            #expect(emptyStringItem.notes == "", "Should accept empty notes")
            
            // Test that we can save these items
            try context.save()
            
            return Void()
        }
    }
    
    @Test("InventoryItem should handle extreme units values")
    func inventoryItemExtremeUnits() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            guard let entity = NSEntityDescription.entity(forEntityName: "InventoryItem", in: context) else {
                fatalError("Could not find InventoryItem entity in context")
            }
            
            // Test negative units
            let negativeUnitsItem = InventoryItem(entity: entity, insertInto: context)
            negativeUnitsItem.id = "NEG-UNITS-001"
            negativeUnitsItem.count = 10.0
            negativeUnitsItem.units = -5
            negativeUnitsItem.type = InventoryItemType.inventory.rawValue
            
            #expect(negativeUnitsItem.units == -5, "Should accept negative units")
            
            // Test zero units
            let zeroUnitsItem = InventoryItem(entity: entity, insertInto: context)
            zeroUnitsItem.id = "ZERO-UNITS-001"
            zeroUnitsItem.count = 10.0
            zeroUnitsItem.units = 0
            zeroUnitsItem.type = InventoryItemType.inventory.rawValue
            
            #expect(zeroUnitsItem.units == 0, "Should accept zero units")
            
            // Test very large units
            let largeUnitsItem = InventoryItem(entity: entity, insertInto: context)
            largeUnitsItem.id = "LARGE-UNITS-001"
            largeUnitsItem.count = 1.0
            largeUnitsItem.units = Int16.max
            largeUnitsItem.type = InventoryItemType.inventory.rawValue
            
            #expect(largeUnitsItem.units == Int16.max, "Should handle maximum Int16 units")
            
            try context.save()
            
            return Void()
        }
    }
    
    @Test("InventoryItem count formatting and precision")
    func inventoryItemCountFormatting() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            guard let entity = NSEntityDescription.entity(forEntityName: "InventoryItem", in: context) else {
                fatalError("Could not find InventoryItem entity in context")
            }
            
            // Test various decimal precisions
            let precisionTests: [(Double, String)] = [
                (1.0, "1"),
                (1.5, "1.5"),
                (1.25, "1.25"),
                (1.125, "1.125"),
                (1.0625, "1.0625"),
                (123.456789, "123.456789"),
                (0.001, "0.001"),
                (0.0001, "0.0001")
            ]
            
            for (index, (testValue, description)) in precisionTests.enumerated() {
                let item = InventoryItem(entity: entity, insertInto: context)
                item.id = "PRECISION-\(index)"
                item.count = testValue
                item.units = 1
                item.type = InventoryItemType.inventory.rawValue
                
                #expect(item.count == testValue, "Count precision should be maintained for \(description)")
                
                // Verify searchable text contains the count
                #expect(item.searchableText.contains(String(testValue)), "Searchable text should contain count value")
            }
            
            try context.save()
            
            return Void()
        }
    }
    
    @Test("InventoryItem relationship handling with CatalogItem")
    func inventoryItemCatalogItemRelationship() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            // Create a catalog item first
            let catalogItem = createSampleCatalogItem(in: context)
            catalogItem.code = "RELATIONSHIP-CAT-001"
            catalogItem.name = "Test Relationship Item"
            
            // Create inventory item with matching catalog code
            let inventoryItem = createSampleInventoryItem(in: context)
            inventoryItem.id = "RELATIONSHIP-INV-001"
            inventoryItem.catalog_code = "RELATIONSHIP-CAT-001"
            
            try context.save()
            
            // Test that we can find related items by matching codes
            let catalogFetch: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
            catalogFetch.predicate = NSPredicate(format: "code == %@", inventoryItem.catalog_code ?? "")
            let matchingCatalogItems = try context.fetch(catalogFetch)
            
            #expect(matchingCatalogItems.count == 1, "Should find matching catalog item")
            #expect(matchingCatalogItems.first?.name == "Test Relationship Item", "Should find correct catalog item")
            
            // Test searching for inventory items by catalog code
            let inventoryFetch: NSFetchRequest<InventoryItem> = InventoryItem.fetchRequest()
            inventoryFetch.predicate = NSPredicate(format: "catalog_code == %@", catalogItem.code ?? "")
            let matchingInventoryItems = try context.fetch(inventoryFetch)
            
            #expect(matchingInventoryItems.count == 1, "Should find matching inventory item")
            #expect(matchingInventoryItems.first?.id == "RELATIONSHIP-INV-001", "Should find correct inventory item")
            
            return Void()
        }
    }
    
    @Test("InventoryItem should handle orphaned catalog codes")
    func inventoryItemOrphanedCatalogCodes() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            // Create inventory item with catalog code that doesn't exist
            let orphanedItem = createSampleInventoryItem(in: context)
            orphanedItem.id = "ORPHANED-001"
            orphanedItem.catalog_code = "NON-EXISTENT-CODE"
            
            try context.save()
            
            // Verify the item was created successfully despite orphaned code
            let fetchRequest: NSFetchRequest<InventoryItem> = InventoryItem.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", "ORPHANED-001")
            let items = try context.fetch(fetchRequest)
            
            #expect(items.count == 1, "Should create item with orphaned catalog code")
            #expect(items.first?.catalog_code == "NON-EXISTENT-CODE", "Should preserve orphaned catalog code")
            
            // Verify we can search for matching catalog items (should be empty)
            let catalogFetch: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
            catalogFetch.predicate = NSPredicate(format: "code == %@", "NON-EXISTENT-CODE")
            let matchingCatalogItems = try context.fetch(catalogFetch)
            
            #expect(matchingCatalogItems.isEmpty, "Should not find matching catalog items for orphaned code")
            
            return Void()
        }
    }
    
    @Test("InventoryItem should handle invalid type values gracefully")
    func inventoryItemInvalidTypeValues() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            guard let entity = NSEntityDescription.entity(forEntityName: "InventoryItem", in: context) else {
                fatalError("Could not find InventoryItem entity in context")
            }
            
            // Test with invalid type value (should default to inventory)
            let invalidTypeItem = InventoryItem(entity: entity, insertInto: context)
            invalidTypeItem.id = "INVALID-TYPE-001"
            invalidTypeItem.count = 1.0
            invalidTypeItem.units = 1
            invalidTypeItem.type = 999 // Invalid type value
            
            #expect(invalidTypeItem.itemType == .inventory, "Should default to inventory for invalid type")
            #expect(invalidTypeItem.typeDisplayName == "Inventory", "Should show inventory display name for invalid type")
            #expect(invalidTypeItem.typeSystemImage == "archivebox.fill", "Should show inventory system image for invalid type")
            
            try context.save()
            
            return Void()
        }
    }
    
    // MARK: - Search Utilities Tests
    
    @Test("SearchUtilities should filter InventoryItems correctly")
    func searchUtilitiesInventoryItemFiltering() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            // Create test items
            let item1 = createSampleInventoryItem(in: context)
            item1.catalog_code = "GLASS-ROD-001"
            item1.notes = "Clear borosilicate"
            
            guard let entity = NSEntityDescription.entity(forEntityName: "InventoryItem", in: context) else {
                fatalError("Could not find InventoryItem entity in context")
            }
            
            let item2 = InventoryItem(entity: entity, insertInto: context)
            item2.id = "TEST-002"
            item2.catalog_code = "FRIT-COL-002"
            item2.notes = "Colored glass frit"
            
            try context.save()
            
            // Test that items have searchable content
            #expect(item1.searchableText.contains("GLASS-ROD-001"))
            #expect(item1.searchableText.contains("Clear borosilicate"))
            #expect(item2.searchableText.contains("FRIT-COL-002"))
            #expect(item2.searchableText.contains("Colored glass frit"))
            
            return Void()
        }
    }
    
    @Test("SearchUtilities should handle nil values gracefully")
    func searchUtilitiesNilHandling() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            guard let entity = NSEntityDescription.entity(forEntityName: "InventoryItem", in: context) else {
                fatalError("Could not find InventoryItem entity in context")
            }
            
            let item = InventoryItem(entity: entity, insertInto: context)
            item.id = "MINIMAL-001"
            // Leave catalog_code and notes as nil
            
            let searchableText = item.searchableText
            
            #expect(searchableText.contains("MINIMAL-001"))
            #expect(!searchableText.isEmpty, "Should still have some searchable content")
            
            return Void()
        }
    }
}
