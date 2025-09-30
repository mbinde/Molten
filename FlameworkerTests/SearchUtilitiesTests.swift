//
//  SearchUtilitiesTests.swift
//  FlameworkerTests
//
//  Created by Melissa Binde on 9/29/25.
//  Copyright © 2025 Motley Woods. All rights reserved.
//

import Testing
import CoreData
import Foundation
@testable import Flameworker

@Suite("Search Utilities Tests")
struct SearchUtilitiesTests {
    
    // MARK: - Test Helpers
    
    private func createTestPersistenceController() -> PersistenceController {
        return PersistenceController(inMemory: true)
    }
    
    private func createTestInventoryItem(
        in context: NSManagedObjectContext,
        id: String = "TEST-001",
        catalogCode: String? = "BR-GLR-001",
        count: Double = 50.0,
        units: Int16 = 1,
        type: InventoryItemType = .sell,
        notes: String? = "Test notes"
    ) -> InventoryItem {
        let item = InventoryItem(context: context)
        item.id = id
        item.catalog_code = catalogCode
        item.count = count
        item.units = units
        item.type = type.rawValue
        item.notes = notes
        return item
    }
    
    private func createTestCatalogItem(
        in context: NSManagedObjectContext,
        code: String = "CATALOG-001",
        name: String = "Test Glass Rod",
        manufacturer: String? = "Test Manufacturer"
    ) -> CatalogItem {
        let item = CatalogItem(context: context)
        item.code = code
        item.name = name
        item.manufacturer = manufacturer
        return item
    }
    
    // MARK: - Searchable Protocol Tests
    
    @Test("InventoryItem should implement Searchable protocol correctly")
    func inventoryItemSearchableImplementation() async throws {
        let controller = createTestPersistenceController()
        let context = controller.container.viewContext
        
        let item = createTestInventoryItem(in: context)
        
        // Verify it conforms to Searchable
        #expect(item is Searchable, "InventoryItem should conform to Searchable protocol")
        
        let searchableText = item.searchableText
        #expect(!searchableText.isEmpty, "Searchable text should not be empty")
    }
    
    @Test("CatalogItem should implement Searchable protocol correctly")
    func catalogItemSearchableImplementation() async throws {
        let controller = createTestPersistenceController()
        let context = controller.container.viewContext
        
        let item = createTestCatalogItem(in: context)
        
        // Verify it conforms to Searchable
        #expect(item is Searchable, "CatalogItem should conform to Searchable protocol")
        
        let searchableText = item.searchableText
        #expect(!searchableText.isEmpty, "Searchable text should not be empty")
    }
    
    // MARK: - InventoryItem Search Tests
    
    @Test("InventoryItem searchableText should include all relevant fields")
    func inventoryItemSearchableTextFields() async throws {
        let controller = createTestPersistenceController()
        let context = controller.container.viewContext
        
        let item = createTestInventoryItem(
            in: context,
            id: "SEARCH-TEST-001",
            catalogCode: "GLASS-ROD-CLEAR",
            count: 25.5,
            units: 3,
            type: .buy,
            notes: "High quality borosilicate glass"
        )
        
        let searchableText = item.searchableText
        
        // Verify all expected fields are included
        #expect(searchableText.contains("SEARCH-TEST-001"), "Should include ID")
        #expect(searchableText.contains("GLASS-ROD-CLEAR"), "Should include catalog code")
        #expect(searchableText.contains("25.5"), "Should include count")
        #expect(searchableText.contains("3"), "Should include units")
        #expect(searchableText.contains("1"), "Should include type raw value (buy = 1)")
        #expect(searchableText.contains("High quality borosilicate glass"), "Should include notes")
    }
    
    @Test("InventoryItem searchableText should handle nil values gracefully")
    func inventoryItemSearchableTextNilHandling() async throws {
        let controller = createTestPersistenceController()
        let context = controller.container.viewContext
        
        let item = createTestInventoryItem(
            in: context,
            id: "MINIMAL-001",
            catalogCode: nil, // nil catalog code
            count: 10.0,
            units: 1,
            type: .inventory,
            notes: nil // nil notes
        )
        
        let searchableText = item.searchableText
        
        // Should still include non-nil fields
        #expect(searchableText.contains("MINIMAL-001"), "Should include ID even when other fields are nil")
        #expect(searchableText.contains("10.0"), "Should include count")
        #expect(searchableText.contains("1"), "Should include units")
        #expect(searchableText.contains("0"), "Should include type raw value (inventory = 0)")
        
        // Should not contain empty or nil values
        #expect(!searchableText.contains("nil"), "Should not contain 'nil' strings")
    }
    
    @Test("InventoryItem searchableText should handle empty strings")
    func inventoryItemSearchableTextEmptyStrings() async throws {
        let controller = createTestPersistenceController()
        let context = controller.container.viewContext
        
        let item = createTestInventoryItem(
            in: context,
            id: "EMPTY-TEST-001",
            catalogCode: "", // empty string
            count: 5.0,
            units: 1,
            type: .sell,
            notes: "" // empty string
        )
        
        let searchableText = item.searchableText
        
        // Should include non-empty fields
        #expect(searchableText.contains("EMPTY-TEST-001"), "Should include non-empty ID")
        #expect(searchableText.contains("5.0"), "Should include count")
        
        // Empty strings should be handled gracefully (likely filtered out or included as empty)
        #expect(searchableText.count >= 4, "Should have at least the non-empty fields")
    }
    
    // MARK: - CatalogItem Search Tests
    
    @Test("CatalogItem searchableText should include all relevant fields")
    func catalogItemSearchableTextFields() async throws {
        let controller = createTestPersistenceController()
        let context = controller.container.viewContext
        
        let item = createTestCatalogItem(
            in: context,
            code: "CATALOG-SEARCH-001",
            name: "Premium Glass Rod Set",
            manufacturer: "Artisan Glassworks"
        )
        
        let searchableText = item.searchableText
        
        // Verify all expected fields are included
        #expect(searchableText.contains("CATALOG-SEARCH-001"), "Should include code")
        #expect(searchableText.contains("Premium Glass Rod Set"), "Should include name")
        #expect(searchableText.contains("Artisan Glassworks"), "Should include manufacturer")
    }
    
    @Test("CatalogItem searchableText should handle nil manufacturer")
    func catalogItemSearchableTextNilManufacturer() async throws {
        let controller = createTestPersistenceController()
        let context = controller.container.viewContext
        
        let item = createTestCatalogItem(
            in: context,
            code: "NO-MANUFACTURER-001",
            name: "Generic Glass Rod",
            manufacturer: nil // nil manufacturer
        )
        
        let searchableText = item.searchableText
        
        // Should still include non-nil fields
        #expect(searchableText.contains("NO-MANUFACTURER-001"), "Should include code")
        #expect(searchableText.contains("Generic Glass Rod"), "Should include name")
        
        // Should handle nil manufacturer gracefully
        #expect(!searchableText.contains("nil"), "Should not contain 'nil' strings")
    }
    
    @Test("CatalogItem searchableText should be case-sensitive as stored")
    func catalogItemSearchableTextCaseSensitivity() async throws {
        let controller = createTestPersistenceController()
        let context = controller.container.viewContext
        
        let item = createTestCatalogItem(
            in: context,
            code: "MixedCase-001",
            name: "Premium GLASS rod Set",
            manufacturer: "Artisan glassworks"
        )
        
        let searchableText = item.searchableText
        
        // Should preserve original case
        #expect(searchableText.contains("MixedCase-001"), "Should preserve code case")
        #expect(searchableText.contains("Premium GLASS rod Set"), "Should preserve name case")
        #expect(searchableText.contains("Artisan glassworks"), "Should preserve manufacturer case")
    }
    
    // MARK: - Search Performance Tests
    
    @Test("Searchable text generation should be efficient for large datasets")
    func searchableTextPerformance() async throws {
        let controller = createTestPersistenceController()
        let context = controller.container.viewContext
        
        // Create multiple items to test performance
        var items: [InventoryItem] = []
        for i in 0..<100 {
            let item = createTestInventoryItem(
                in: context,
                id: "PERF-TEST-\(i)",
                catalogCode: "CODE-\(i)",
                count: Double(i),
                units: Int16(i % 10),
                type: .inventory,
                notes: "Performance test item \(i)"
            )
            items.append(item)
        }
        
        let startTime = Date()
        
        // Generate searchable text for all items
        let allSearchableText = items.map { $0.searchableText }
        
        let endTime = Date()
        let timeElapsed = endTime.timeIntervalSince(startTime)
        
        #expect(allSearchableText.count == 100, "Should generate searchable text for all items")
        #expect(timeElapsed < 1.0, "Should complete within 1 second for 100 items")
        
        // Verify all searchable texts are unique and contain expected content
        let uniqueTexts = Set(allSearchableText.map { $0.joined(separator: " ") })
        #expect(uniqueTexts.count == 100, "Each item should have unique searchable text")
    }
    
    // MARK: - Integration Tests
    
    @Test("Search should work with Core Data queries")
    func searchCoreDataIntegration() async throws {
        let controller = createTestPersistenceController()
        let context = controller.container.viewContext
        
        // Create test items with specific searchable content
        let item1 = createTestInventoryItem(
            in: context,
            id: "GLASS-001",
            catalogCode: "CLEAR-GLASS",
            notes: "Clear borosilicate glass"
        )
        
        let item2 = createTestInventoryItem(
            in: context,
            id: "FRIT-001",
            catalogCode: "COLOR-FRIT",
            notes: "Colored glass frit"
        )
        
        try context.save()
        
        // Test that searchable text can be used for filtering
        let glassItems = [item1, item2].filter { item in
            item.searchableText.contains { $0.localizedCaseInsensitiveContains("glass") }
        }
        
        #expect(glassItems.count == 2, "Both items should match 'glass' search")
        
        let clearItems = [item1, item2].filter { item in
            item.searchableText.contains { $0.localizedCaseInsensitiveContains("clear") }
        }
        
        #expect(clearItems.count == 1, "Only one item should match 'clear' search")
        #expect(clearItems.first?.id == "GLASS-001", "Should find the correct item")
    }
}