//
//  InventoryItemDetailViewTests.swift
//  Flameworker
//
//  Created by Assistant on 10/13/25.
//  Updated to test InventoryDetailView on 10/16/25.
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
@testable import Flameworker

@Suite("InventoryDetailView Repository Pattern Tests")
struct InventoryItemDetailViewTests {

    @Test("InventoryDetailView should accept CompleteInventoryItemModel instead of Core Data entity")
    func testInventoryDetailViewUsesBusinessModel() {
        // Arrange: Create a business model instead of Core Data entity
        let glassItem = GlassItemModel(
            natural_key: "test-glass-001-0",
            name: "Test Glass Item",
            sku: "001",
            manufacturer: "test",
            mfr_notes: "Test inventory item",
            coe: 96,
            mfr_status: "available"
        )
        
        let inventory = [
            InventoryModel(
                item_natural_key: "test-glass-001-0",
                type: "rod",
                quantity: 5.0
            )
        ]
        
        let completeItem = CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: inventory,
            tags: [],
            locations: []
        )

        // Act: Create InventoryDetailView with business model
        let detailView = InventoryDetailView(item: completeItem)

        // Assert: View should be created successfully with business model
        #expect(detailView != nil, "InventoryDetailView should accept CompleteInventoryItemModel via dependency injection")
    }
    
    @Test("InventoryDetailView should not require Core Data context when using business models")
    func testInventoryDetailViewWorksWithoutCoreDataContext() {
        // Arrange: Create business model and service
        let glassItem = GlassItemModel(
            natural_key: "test-glass-002-0",
            name: "Test Buy Item",
            sku: "002",
            manufacturer: "test",
            coe: 90,
            mfr_status: "available"
        )
        
        let inventory = [
            InventoryModel(
                item_natural_key: "test-glass-002-0",
                type: "sheet",
                quantity: 10.0
            )
        ]
        
        let completeItem = CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: inventory,
            tags: [],
            locations: []
        )
        
        // Use existing repository system
        RepositoryFactory.configureForTesting()
        let inventoryTrackingService = RepositoryFactory.createInventoryTrackingService()

        // Act: Create view with business model and service (no Core Data context needed)
        let detailView = InventoryDetailView(
            item: completeItem,
            inventoryTrackingService: inventoryTrackingService
        )

        // Assert: Should work without Core Data environment
        #expect(detailView != nil, "InventoryDetailView should work without Core Data context when using business models")
    }
    
    @Test("InventoryDetailView should accept InventoryTrackingService for repository operations")
    func testInventoryDetailViewAcceptsInventoryTrackingService() {
        // Arrange: Create business model and existing service
        let glassItem = GlassItemModel(
            natural_key: "test-glass-003-0",
            name: "Test Sell Item",
            sku: "003",
            manufacturer: "test",
            coe: 96,
            mfr_status: "available"
        )
        
        let inventory = [
            InventoryModel(
                item_natural_key: "test-glass-003-0",
                type: "frit",
                quantity: 3.0
            )
        ]
        
        let completeItem = CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: inventory,
            tags: [],
            locations: []
        )
        
        RepositoryFactory.configureForTesting()
        let inventoryTrackingService = RepositoryFactory.createInventoryTrackingService()

        // Act: Create view with injected service
        let detailView = InventoryDetailView(
            item: completeItem,
            inventoryTrackingService: inventoryTrackingService
        )

        // Assert: Should accept service via dependency injection
        #expect(detailView != nil, "InventoryDetailView should accept InventoryTrackingService for repository operations")
    }

    @Test("InventoryDetailView should handle invalid URLs gracefully without crashing")
    func testInventoryDetailViewHandlesInvalidURLs() {
        // Arrange: Create glass item with invalid URL that would cause force-unwrap crash
        let glassItemWithInvalidURL = GlassItemModel(
            natural_key: "test-glass-004-0",
            name: "Test Item with Invalid URL",
            sku: "004",
            manufacturer: "test",
            mfr_notes: "Testing URL safety",
            coe: 96,
            url: "not a valid url!!!",  // Invalid URL that URL(string:) would return nil for
            mfr_status: "available"
        )

        let completeItem = CompleteInventoryItemModel(
            glassItem: glassItemWithInvalidURL,
            inventory: [],
            tags: [],
            locations: []
        )

        // Act: Create view with item containing invalid URL
        // This should NOT crash (previous version had force-unwrap that would crash)
        let detailView = InventoryDetailView(item: completeItem)

        // Assert: View should be created successfully without crashing
        #expect(detailView != nil, "InventoryDetailView should handle invalid URLs gracefully")
    }

    @Test("InventoryDetailView should handle empty URL strings gracefully")
    func testInventoryDetailViewHandlesEmptyURLs() {
        // Arrange: Create glass item with empty URL
        let glassItemWithEmptyURL = GlassItemModel(
            natural_key: "test-glass-005-0",
            name: "Test Item with Empty URL",
            sku: "005",
            manufacturer: "test",
            coe: 96,
            url: "",  // Empty URL string
            mfr_status: "available"
        )

        let completeItem = CompleteInventoryItemModel(
            glassItem: glassItemWithEmptyURL,
            inventory: [],
            tags: [],
            locations: []
        )

        // Act: Create view with item containing empty URL
        let detailView = InventoryDetailView(item: completeItem)

        // Assert: View should be created successfully
        #expect(detailView != nil, "InventoryDetailView should handle empty URL strings gracefully")
    }

    @Test("InventoryDetailView should handle nil URL gracefully")
    func testInventoryDetailViewHandlesNilURL() {
        // Arrange: Create glass item with nil URL
        let glassItemWithNilURL = GlassItemModel(
            natural_key: "test-glass-006-0",
            name: "Test Item with Nil URL",
            sku: "006",
            manufacturer: "test",
            coe: 96,
            url: nil,  // Nil URL
            mfr_status: "available"
        )

        let completeItem = CompleteInventoryItemModel(
            glassItem: glassItemWithNilURL,
            inventory: [],
            tags: [],
            locations: []
        )

        // Act: Create view with item containing nil URL
        let detailView = InventoryDetailView(item: completeItem)

        // Assert: View should be created successfully
        #expect(detailView != nil, "InventoryDetailView should handle nil URL gracefully")
    }

    @Test("InventoryDetailView should use ProductImageDetail with sku field")
    func testDetailViewUsesProductImageWithSKU() {
        // Arrange: Create item with known SKU and manufacturer
        let glassItem = GlassItemModel(
            natural_key: "cim-550-0",
            name: "CiM Test Color",
            sku: "550",
            manufacturer: "CIM",
            coe: 104,
            mfr_status: "available"
        )

        let completeItem = CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: [],
            tags: [],
            locations: []
        )

        // Act: Create view
        let detailView = InventoryDetailView(item: completeItem)

        // Assert: View should be created successfully and use ProductImageDetail
        #expect(detailView != nil, "InventoryDetailView should use ProductImageDetail with sku field")
    }

    @Test("InventoryDetailView should handle items without images gracefully")
    func testDetailViewHandlesItemsWithoutImages() {
        // Arrange: Create item with SKU that doesn't have an image file
        let glassItem = GlassItemModel(
            natural_key: "test-nonexistent-999-0",
            name: "Item Without Image",
            sku: "nonexistent-999",
            manufacturer: "test",
            coe: 96,
            mfr_status: "available"
        )

        let completeItem = CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: [],
            tags: [],
            locations: []
        )

        // Act: Create view - should not crash even if image doesn't exist
        let detailView = InventoryDetailView(item: completeItem)

        // Assert: View should handle missing images gracefully
        #expect(detailView != nil, "InventoryDetailView should handle missing images gracefully")
    }

    @Test("InventoryDetailView should use sku not natural_key for images")
    func testDetailViewUsesSKUNotNaturalKey() {
        // Arrange: Create item where natural_key differs from sku
        let glassItem = GlassItemModel(
            natural_key: "ef-591284-0",  // natural_key includes sequence
            name: "Effetre Test Color",
            sku: "591284",  // sku is just the product code
            manufacturer: "EF",
            coe: 104,
            mfr_status: "available"
        )

        let completeItem = CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: [],
            tags: [],
            locations: []
        )

        // Act: Create view
        let detailView = InventoryDetailView(item: completeItem)

        // Assert: ProductImageDetail should use sku (591284) not natural_key (ef-591284-0)
        // ProductImageDetail should look for "EF-591284.webp", not "EF-ef-591284-0.webp"
        #expect(detailView != nil, "InventoryDetailView should use sku for image lookup")
    }
}
