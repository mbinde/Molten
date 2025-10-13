//
//  CrossEntityIntegrationTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/12/25.
//

import Foundation
import CoreData
// Standard test framework imports pattern - use in all test files
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

@testable import Flameworker

@Suite("Cross-Entity Repository Integration Tests")
struct CrossEntityIntegrationTests {
    
    @Test("Should coordinate catalog and inventory data")
    func testCatalogInventoryCoordination() async throws {
        // This test will fail - need to create cross-entity coordination service
        let mockCatalogRepo = MockCatalogRepository()
        let mockInventoryRepo = MockInventoryRepository()
        
        let catalogService = CatalogService(repository: mockCatalogRepo)
        let inventoryService = InventoryService(repository: mockInventoryRepo)
        
        // Create coordination service that works across entities
        let coordinator = EntityCoordinator(
            catalogService: catalogService,
            inventoryService: inventoryService
        )
        
        // Add test catalog item
        let catalogItem = CatalogItemModel(
            name: "Red Glass Rod",
            rawCode: "RGR-001", 
            manufacturer: "Bullseye"
        )
        let savedCatalogItem = try await catalogService.createItem(catalogItem)
        
        // Add corresponding inventory item
        let inventoryItem = InventoryItemModel(
            catalogCode: savedCatalogItem.code,
            quantity: 5,
            type: .inventory
        )
        let savedInventoryItem = try await inventoryService.createItem(inventoryItem)
        
        // Test cross-entity coordination
        let coordination = try await coordinator.getInventoryForCatalogItem(catalogItemCode: savedCatalogItem.code)
        
        #expect(coordination.catalogItem.name == "Red Glass Rod")
        #expect(coordination.inventoryItems.count == 1)
        #expect(coordination.totalQuantity == 5)
        #expect(coordination.hasInventory == true)
    }
    
    @Test("Should handle purchase and inventory correlation")
    func testPurchaseInventoryCorrelation() async throws {
        let mockInventoryRepo = MockInventoryRepository()
        let mockPurchaseRepo = MockPurchaseRecordRepository()
        
        let inventoryService = InventoryService(repository: mockInventoryRepo)
        let purchaseService = PurchaseRecordService(repository: mockPurchaseRepo)
        
        let coordinator = EntityCoordinator(
            inventoryService: inventoryService,
            purchaseRecordService: purchaseService
        )
        
        // Add purchase record
        let purchaseRecord = PurchaseRecordModel(
            supplier: "Glass Supply Co",
            price: 99.99,
            notes: "BULLSEYE-RGR-001 glass rods"
        )
        let savedPurchase = try await purchaseService.createRecord(purchaseRecord)
        
        // Add related inventory
        let inventoryItem = InventoryItemModel(
            catalogCode: "BULLSEYE-RGR-001",
            quantity: 10,
            type: .buy
        )
        let savedInventory = try await inventoryService.createItem(inventoryItem)
        
        // Test correlation
        let correlation = try await coordinator.correlatePurchasesWithInventory(
            catalogCode: "BULLSEYE-RGR-001"
        )
        
        #expect(correlation.catalogCode == "BULLSEYE-RGR-001")
        #expect(correlation.totalSpent == 99.99)
        #expect(correlation.totalQuantityPurchased == 10)
        #expect(correlation.averagePricePerUnit > 0)
    }
    
    @Test("Should generate comprehensive reports across all entities")
    func testComprehensiveReporting() async throws {
        let mockCatalogRepo = MockCatalogRepository()
        let mockInventoryRepo = MockInventoryRepository()
        let mockPurchaseRepo = MockPurchaseRecordRepository()
        
        let catalogService = CatalogService(repository: mockCatalogRepo)
        let inventoryService = InventoryService(repository: mockInventoryRepo)
        let purchaseService = PurchaseRecordService(repository: mockPurchaseRepo)
        
        let reportingService = ReportingService(
            catalogService: catalogService,
            inventoryService: inventoryService,
            purchaseRecordService: purchaseService
        )
        
        // Add test data across all entities
        let catalogItem = CatalogItemModel(name: "Test Glass", rawCode: "TG-001", manufacturer: "TestCorp")
        let savedCatalog = try await catalogService.createItem(catalogItem)
        
        let inventoryItem = InventoryItemModel(catalogCode: savedCatalog.code, quantity: 20, type: .inventory)
        try await inventoryService.createItem(inventoryItem)
        
        let purchaseRecord = PurchaseRecordModel(supplier: "TestCorp", price: 150.00)
        try await purchaseService.createRecord(purchaseRecord)
        
        // Generate comprehensive report
        let report = try await reportingService.generateComprehensiveReport()
        
        #expect(report.totalCatalogItems == 1)
        #expect(report.totalInventoryItems == 1) 
        #expect(report.totalPurchases == 1)
        #expect(report.totalSpending == 150.00)
        #expect(report.inventoryValue > 0)
    }
}
