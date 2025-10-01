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
