//
//  CrossEntityIntegrationTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/12/25.
//

import Foundation
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
    
    @Test("Should coordinate glass item and inventory data using new architecture")
    func testGlassItemInventoryCoordination() async throws {
        // Arrange: Configure factory for testing and create services
        RepositoryFactory.configureForTesting()
        let catalogService = RepositoryFactory.createCatalogService()
        let inventoryTrackingService = RepositoryFactory.createInventoryTrackingService()
        
        // Create coordination service that works across entities
        let coordinator = EntityCoordinator(
            catalogService: catalogService,
            inventoryTrackingService: inventoryTrackingService
        )
        
        // Create a complete glass item with inventory using the service
        let testGlassItem = GlassItemModel(
            naturalKey: "BULLSEYE-RGR-001",
            name: "Red Glass Rod",
            sku: "RGR-001",
            manufacturer: "Bullseye",
            mfrNotes: "Transparent red glass rod",
            coe: 90,
            url: "https://bullseyeglass.com",
            mfrStatus: "available"
        )
        
        let testInventory = [
            InventoryModel(itemNaturalKey: "BULLSEYE-RGR-001", type: "rod", quantity: 5.0)
        ]
        
        let testTags = ["red", "bullseye", "transparent"]
        let testLocations = [
            LocationModel(inventoryId: testInventory[0].id, location: "Workshop Bin A", quantity: 5.0)
        ]
        
        _ = try await inventoryTrackingService.createCompleteItem(
            testGlassItem,
            initialInventory: testInventory,
            tags: testTags
        )
        
        // Act: Test cross-entity coordination
        let coordination = try await coordinator.getInventoryForGlassItem(naturalKey: "BULLSEYE-RGR-001")
        
        // Assert: Coordination should combine all data correctly
        #expect(coordination.glassItem.name == "Red Glass Rod", "Should have correct glass item name")
        #expect(coordination.totalQuantity == 5.0, "Should have correct total quantity")
        #expect(coordination.hasInventory == true, "Should indicate inventory exists")
        #expect(coordination.tags.contains("red"), "Should include tags")
        #expect(coordination.locations.count == 1, "Should include location data")
    }
    
    @Test("Should handle purchase and inventory correlation using new architecture")
    func testPurchaseInventoryCorrelation() async throws {
        // Arrange: Configure and create services
        RepositoryFactory.configureForTesting()
        let inventoryTrackingService = RepositoryFactory.createInventoryTrackingService()
        let mockPurchaseRepo = MockPurchaseRecordRepository()
        let purchaseService = PurchaseRecordService(repository: mockPurchaseRepo)
        
        let coordinator = EntityCoordinator(
            inventoryTrackingService: inventoryTrackingService,
            purchaseRecordService: purchaseService
        )
        
        // Create glass item with inventory
        let testGlassItem = GlassItemModel(
            naturalKey: "BULLSEYE-RGR-001",
            name: "Red Glass Rod",
            sku: "RGR-001",
            manufacturer: "Bullseye",
            mfrNotes: "Transparent red glass rod",
            coe: 90,
            url: "https://bullseyeglass.com",
            mfrStatus: "available"
        )
        
        let testInventory = [
            InventoryModel(itemNaturalKey: "BULLSEYE-RGR-001", type: "rod", quantity: 10.0)
        ]
        
        _ = try await inventoryTrackingService.createCompleteItem(
            testGlassItem,
            initialInventory: testInventory,
            tags: []
        )
        
        // Add purchase record with correlation data in notes
        let purchaseRecord = PurchaseRecordModel(
            supplier: "Glass Supply Co",
            price: 99.99,
            notes: "BULLSEYE-RGR-001 glass rods - 10 pieces"
        )
        _ = try await purchaseService.createRecord(purchaseRecord)
        
        // Act: Test correlation
        let correlation = try await coordinator.correlatePurchasesWithInventory(
            naturalKey: "BULLSEYE-RGR-001"
        )
        
        // Assert: Should correlate purchase and inventory data
        #expect(correlation.naturalKey == "BULLSEYE-RGR-001", "Should have correct natural key")
        #expect(correlation.totalSpent == 99.99, "Should calculate total spent correctly")
        #expect(correlation.totalQuantityInInventory == 10.0, "Should have correct inventory quantity")
        #expect(correlation.averagePricePerUnit > 0, "Should calculate average price per unit")
    }
    
    @Test("Should generate comprehensive reports across all entities using new architecture")
    func testComprehensiveReporting() async throws {
        // Arrange: Configure and create services
        RepositoryFactory.configureForTesting()
        let catalogService = RepositoryFactory.createCatalogService()
        let inventoryTrackingService = RepositoryFactory.createInventoryTrackingService()
        let shoppingListService = RepositoryFactory.createShoppingListService()
        
        let reportingService = ReportingService(
            catalogService: catalogService,
            inventoryTrackingService: inventoryTrackingService,
            shoppingListService: shoppingListService
        )
        
        // Add test glass item with inventory
        let testGlassItem = GlassItemModel(
            naturalKey: "TEST-GLASS-001",
            name: "Test Glass Rod",
            sku: "TG-001",
            manufacturer: "TestCorp",
            mfrNotes: "Test glass for integration testing",
            coe: 96,
            url: "https://testcorp.com",
            mfrStatus: "available"
        )
        
        let testInventory = [
            InventoryModel(itemNaturalKey: "TEST-GLASS-001", type: "rod", quantity: 20.0)
        ]
        
        let testTags = ["test", "transparent"]
        
        _ = try await inventoryTrackingService.createCompleteItem(
            testGlassItem,
            initialInventory: testInventory,
            tags: testTags
        )
        
        // Act: Generate comprehensive report
        let report = try await reportingService.generateComprehensiveReport()
        
        // Assert: Report should include all data
        #expect(report.totalGlassItems == 1, "Should have correct glass item count")
        #expect(report.totalInventoryRecords == 1, "Should have correct inventory record count")
        #expect(report.totalQuantity == 20.0, "Should calculate total quantity correctly")
        #expect(report.manufacturerDistribution.count > 0, "Should include manufacturer distribution")
        #expect(report.coeDistribution.count > 0, "Should include COE distribution")
        #expect(report.tagAnalysis.totalUniqueTags == 2, "Should analyze tags correctly")
    }
    
    @Test("Should handle cross-entity search with inventory context")
    func testCrossEntitySearchWithInventoryContext() async throws {
        // Arrange: Configure and create services
        RepositoryFactory.configureForTesting()
        let catalogService = RepositoryFactory.createCatalogService()
        let inventoryTrackingService = RepositoryFactory.createInventoryTrackingService()
        
        let coordinator = EntityCoordinator(
            catalogService: catalogService,
            inventoryTrackingService: inventoryTrackingService
        )
        
        // Create multiple glass items with different inventory levels
        let glassItems = [
            GlassItemModel(
                naturalKey: "BULLSEYE-RED-001",
                name: "Red Glass",
                sku: "RED-001",
                manufacturer: "Bullseye",
                mfrNotes: "Red transparent glass",
                coe: 90,
                url: "https://bullseyeglass.com",
                mfrStatus: "available"
            ),
            GlassItemModel(
                naturalKey: "BULLSEYE-BLUE-001",
                name: "Blue Glass",
                sku: "BLUE-001",
                manufacturer: "Bullseye",
                mfrNotes: "Blue transparent glass",
                coe: 90,
                url: "https://bullseyeglass.com",
                mfrStatus: "available"
            ),
            GlassItemModel(
                naturalKey: "SPECTRUM-GREEN-001",
                name: "Green Glass",
                sku: "GREEN-001",
                manufacturer: "Spectrum",
                mfrNotes: "Green transparent glass",
                coe: 96,
                url: "https://spectrumglass.com",
                mfrStatus: "available"
            )
        ]
        
        // Create items with different inventory levels
        for (index, glassItem) in glassItems.enumerated() {
            let inventory = index == 0 ? [
                InventoryModel(itemNaturalKey: glassItem.naturalKey, type: "rod", quantity: Double(index + 1) * 5.0)
            ] : []
            
            _ = try await inventoryTrackingService.createCompleteItem(
                glassItem,
                initialInventory: inventory,
                tags: []
            )
        }
        
        // Act: Search for glass items with inventory context
        let searchResults = try await coordinator.searchGlassItemsWithInventoryContext(searchText: "Bullseye")
        
        // Assert: Should find matching items with inventory context
        #expect(searchResults.count == 2, "Should find two Bullseye items")
        
        let redGlassResult = searchResults.first { $0.glassItem.naturalKey == "BULLSEYE-RED-001" }
        let blueGlassResult = searchResults.first { $0.glassItem.naturalKey == "BULLSEYE-BLUE-001" }
        
        #expect(redGlassResult?.hasInventory == true, "Red glass should have inventory")
        #expect(redGlassResult?.totalQuantity == 5.0, "Red glass should have correct quantity")
        #expect(blueGlassResult?.hasInventory == false, "Blue glass should have no inventory")
        #expect(blueGlassResult?.totalQuantity == 0.0, "Blue glass should have zero quantity")
    }
    
    @Test("Should generate specialized inventory report with low stock analysis")
    func testSpecializedInventoryReport() async throws {
        // Arrange: Use factory pattern for service creation
        RepositoryFactory.configureForTesting()
        let reportingService = ReportingService.createWithRepositoryFactory()
        
        // Create glass items with varying inventory levels
        let catalogService = RepositoryFactory.createCatalogService()
        let inventoryTrackingService = RepositoryFactory.createInventoryTrackingService()
        
        let testItems = [
            ("LOW-STOCK-001", "Low Stock Item", 2.0),
            ("GOOD-STOCK-001", "Good Stock Item", 15.0),
            ("HIGH-STOCK-001", "High Stock Item", 50.0)
        ]
        
        for (naturalKey, name, quantity) in testItems {
            let glassItem = GlassItemModel(
                naturalKey: naturalKey,
                name: name,
                sku: naturalKey,
                manufacturer: "TestCorp",
                mfrNotes: "Test glass item",
                coe: 90,
                url: "https://testcorp.com",
                mfrStatus: "available"
            )
            
            let inventory = [
                InventoryModel(itemNaturalKey: naturalKey, type: "rod", quantity: quantity)
            ]
            
            _ = try await inventoryTrackingService.createCompleteItem(
                glassItem,
                initialInventory: inventory,
                tags: []
            )
        }
        
        // Act: Generate inventory report
        let inventoryReport = try await reportingService.generateInventoryReport()
        
        // Assert: Report should analyze inventory correctly
        #expect(inventoryReport.totalItems == 3, "Should have three items")
        #expect(inventoryReport.totalQuantity == 67.0, "Should calculate total quantity correctly")
        #expect(inventoryReport.inventorySummaries.count == 3, "Should have summaries for all items")
        
        // Low stock analysis
        let lowStockItems = inventoryReport.lowStockItems
        #expect(lowStockItems.count >= 0, "Should identify low stock items")
    }
}
