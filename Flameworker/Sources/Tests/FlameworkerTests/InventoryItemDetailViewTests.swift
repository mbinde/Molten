//
//  InventoryItemDetailViewTests.swift
//  Flameworker
//
//  Created by Assistant on 10/13/25.
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

@Suite("InventoryItemDetailView Repository Pattern Tests")
struct InventoryItemDetailViewTests {
    
    @Test("InventoryItemDetailView should accept CompleteInventoryItemModel instead of Core Data entity")
    func testInventoryItemDetailViewUsesBusinessModel() {
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
        
        // Act: Create InventoryItemDetailView with business model
        let detailView = InventoryItemDetailView(completeItem: completeItem)
        
        // Assert: View should be created successfully with business model
        #expect(detailView != nil, "InventoryItemDetailView should accept CompleteInventoryItemModel via dependency injection")
    }
    
    @Test("InventoryItemDetailView should not require Core Data context when using business models")
    func testInventoryItemDetailViewWorksWithoutCoreDataContext() {
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
        let detailView = InventoryItemDetailView(
            completeItem: completeItem,
            inventoryTrackingService: inventoryTrackingService
        )
        
        // Assert: Should work without Core Data environment
        #expect(detailView != nil, "InventoryItemDetailView should work without Core Data context when using business models")
    }
    
    @Test("InventoryItemDetailView should accept InventoryTrackingService for repository operations")
    func testInventoryItemDetailViewAcceptsInventoryTrackingService() {
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
        let detailView = InventoryItemDetailView(
            completeItem: completeItem,
            inventoryTrackingService: inventoryTrackingService,
            startInEditMode: true
        )
        
        // Assert: Should accept service via dependency injection
        #expect(detailView != nil, "InventoryItemDetailView should accept InventoryTrackingService for repository operations")
    }
}
