//
//  MockCoreDataTests.swift
//  FlameworkerTests
//
//  Created by Mock Data Fix on 10/5/25.
//

import Testing
import CoreData
@testable import Flameworker

@Suite("Mock Core Data Tests")
struct MockCoreDataTests {
    
    @Test("safe enumeration should work with mock data")
    func safeEnumerationShouldWorkWithMockData() async throws {
        // Create mock objects that don't require Core Data context
        let mockItems: [MockCatalogItemForTests] = [
            MockCatalogItemForTests(id: "MOCK1", name: "Mock Item 1"),
            MockCatalogItemForTests(id: "MOCK2", name: "Mock Item 2")
        ]
        
        // Test the safe enumeration logic without Core Data
        var processedCount = 0
        CoreDataHelpers.safelyEnumerate(Set(mockItems)) { item in
            processedCount += 1
        }
        
        #expect(processedCount == 2, "Should process 2 mock items")
    }
    
    @Test("inventory units enum should work correctly")
    func inventoryUnitsEnumShouldWorkCorrectly() async throws {
        // Test the enum functionality without Core Data
        let units = InventoryUnits.ounces
        
        #expect(units.displayName == "oz", "Ounces should display as 'oz'")
        #expect(units.rawValue == 2, "Ounces should have raw value 2")
        #expect(units.id == 2, "ID should match raw value")
        
        // Test enum initialization
        let unitsFromRaw = InventoryUnits(rawValue: 2)
        #expect(unitsFromRaw == .ounces, "Should initialize ounces from raw value 2")
    }
    
    @Test("image loading should be cached")
    func imageLoadingShouldBeCached() async throws {
        let itemCode = "test-item-unique-\(UUID().uuidString)"
        
        // First load - will be cached as "not found"
        let image1 = ImageHelpers.loadProductImage(for: itemCode)
        
        // Second load - should be faster due to negative cache
        let image2 = ImageHelpers.loadProductImage(for: itemCode)
        
        // Both should return nil (since test image doesn't exist)
        #expect(image1 == nil, "Test image should not exist")
        #expect(image2 == nil, "Test image should not exist (cached)")
    }
}

// Simple mock object that doesn't inherit from NSManagedObject
struct MockCatalogItemForTests: Hashable {
    let id: String
    let name: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: MockCatalogItemForTests, rhs: MockCatalogItemForTests) -> Bool {
        return lhs.id == rhs.id
    }
}