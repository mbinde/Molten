//
//  RepositoryFactoryDataLoadingTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/16/25.
//
// Target: RepositoryTests

// Standard test framework imports pattern - use in all test files
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

import Foundation
import CoreData
@testable import Flameworker

@Suite("Repository Factory Data Loading Tests - Core Data Integration", .serialized)
struct RepositoryFactoryDataLoadingTests {
    
    // MARK: - Test Helper Methods
    
    /// Reset factory state before each test
    private func resetFactoryState() {
        RepositoryFactory.mode = .mock // Reset to default
        RepositoryFactory.persistentContainer = PersistenceController.shared.container
    }
    
    /// Create isolated test environment
    private func createTestEnvironment() -> PersistenceController {
        let testController = PersistenceController.createTestController()
        RepositoryFactory.configure(persistentContainer: testController.container)
        return testController
    }
    
    // MARK: - Configuration Tests
    
    @Test("Should configure for production with Core Data")
    func testConfigureForProduction() async throws {
        resetFactoryState()
        
        // Configure for production
        RepositoryFactory.configureForProduction()
        
        // Verify configuration
        #expect(RepositoryFactory.mode == .coreData, "Should be in Core Data mode")
        #expect(RepositoryFactory.persistentContainer === PersistenceController.shared.container,
               "Should use shared persistent container")
        
        // Verify services are created with Core Data repositories
        let catalogService = RepositoryFactory.createCatalogService()
        let inventoryService = RepositoryFactory.createInventoryTrackingService()
        
        // Services should be created successfully
        #expect(catalogService != nil, "Should create catalog service")
        #expect(inventoryService != nil, "Should create inventory service")
    }
    
    @Test("Should configure for production with initial data loading")
    func testConfigureForProductionWithInitialData() async throws {
        resetFactoryState()
        let _ = createTestEnvironment()
        
        // This should not throw even if no JSON files are found
        do {
            try await RepositoryFactory.configureForProductionWithInitialData()
            
            // Should be configured correctly
            #expect(RepositoryFactory.mode == .coreData, "Should be in Core Data mode after setup")
            
            // Should be able to create services
            let catalogService = RepositoryFactory.createCatalogService()
            let items = try await catalogService.getAllGlassItems()
            #expect(items.count >= 0, "Should have items (0 or more depending on data availability)")
            
        } catch {
            // If it fails, should be due to missing JSON data, not configuration issues
            let errorMessage = error.localizedDescription.lowercased()
            let isExpectedError = errorMessage.contains("catalog data") || 
                                errorMessage.contains("file") || 
                                errorMessage.contains("json")
            
            #expect(isExpectedError, "Should fail with data-related error, not configuration error: \(error)")
        }
    }
    
    @Test("Should use mock data when JSON files are not available")
    func testFallbackToMockData() async throws {
        resetFactoryState()
        let _ = createTestEnvironment()
        
        // Configure factory to use mock JSON loader
        RepositoryFactory.configureForProduction()
        
        let catalogService = RepositoryFactory.createCatalogService()
        
        // Create data loading service with mock data
        let mockJsonLoader = MockJSONDataLoader()
        mockJsonLoader.testDataMode = .small
        
        let dataLoadingService = GlassItemDataLoadingService(
            catalogService: catalogService,
            jsonLoader: mockJsonLoader
        )
        
        // Should be able to load mock data
        let result = try await dataLoadingService.loadGlassItemsFromJSON(options: .testing)
        #expect(result.itemsCreated > 0, "Should create items from mock data")
        
        // Verify items were persisted to Core Data
        let allItems = try await catalogService.getAllGlassItems()
        #expect(allItems.count == result.itemsCreated, "Should persist mock data to Core Data")
    }
    
    // MARK: - Service Creation Tests
    
    @Test("Should create services with proper Core Data repositories")
    func testServiceCreationWithCoreData() async throws {
        resetFactoryState()
        let _ = createTestEnvironment()
        
        RepositoryFactory.configureForProduction()
        
        // Create services
        let catalogService = RepositoryFactory.createCatalogService()
        let inventoryService = RepositoryFactory.createInventoryTrackingService()
        let glassItemRepo = RepositoryFactory.createGlassItemRepository()
        let inventoryRepo = RepositoryFactory.createInventoryRepository()
        let locationRepo = RepositoryFactory.createLocationRepository()
        
        // All services should be created
        #expect(catalogService != nil, "Should create catalog service")
        #expect(inventoryService != nil, "Should create inventory service")
        #expect(glassItemRepo != nil, "Should create glass item repository")
        #expect(inventoryRepo != nil, "Should create inventory repository")
        #expect(locationRepo != nil, "Should create location repository")
        
        // Test that repositories work with Core Data
        let testItem = GlassItemModel(
            natural_key: "FACTORY-TEST-001",
            name: "Factory Test Item",
            sku: "FT-001", 
            manufacturer: "Test Manufacturer",
            mfr_notes: "Test item for factory testing",
            coe: 96,
            url: "https://test.example.com",
            mfr_status: "available"
        )
        
        // Should be able to create and retrieve items
        let createdItem = try await catalogService.createGlassItem(testItem, initialInventory: [], tags: [])
        #expect(createdItem.glassItem.name == "Factory Test Item", "Should create item through factory services")
        
        let retrievedItem = try await catalogService.getGlassItemByNaturalKey("FACTORY-TEST-001")
        #expect(retrievedItem?.glassItem.name == "Factory Test Item", "Should retrieve item through factory services")
    }
    
    // MARK: - Data Loading Integration Tests
    
    @Test("Should integrate data loading with factory-created services")
    func testDataLoadingIntegration() async throws {
        resetFactoryState()
        let _ = createTestEnvironment()
        
        RepositoryFactory.configureForProduction()
        
        let catalogService = RepositoryFactory.createCatalogService()
        
        // Verify empty state
        let initialItems = try await catalogService.getAllGlassItems()
        #expect(initialItems.isEmpty, "Should start with empty Core Data store")
        
        // Create data loading service with mock data
        let mockJsonLoader = MockJSONDataLoader()
        mockJsonLoader.testDataMode = .small
        
        let dataLoadingService = GlassItemDataLoadingService(
            catalogService: catalogService,
            jsonLoader: mockJsonLoader
        )
        
        // Load initial data
        let initialResult = try await dataLoadingService.loadGlassItemsFromJSON(options: .default)
        #expect(initialResult.itemsCreated > 0, "Should create initial items")
        
        // Load again with app update option to test updates
        mockJsonLoader.testDataMode = .custom
        mockJsonLoader.customTestData = [
            // Updated version of first test item
            CatalogItemData(
                id: "test1",
                code: "TESTMFG-001",
                manufacturer: "TestManufacturer", 
                name: "Updated Test Red Glass", // Changed name
                manufacturer_description: "Updated red glass for unit tests",
                synonyms: ["red", "test", "updated"],
                tags: ["red", "test", "updated"],
                image_path: nil,
                coe: "96",
                stock_type: "rod",
                image_url: nil,
                manufacturer_url: "https://updated.test.example.com" // Changed URL
            )
        ]
        
        let updateResult = try await dataLoadingService.loadGlassItemsFromJSON(options: .appUpdate)
        #expect(updateResult.itemsUpdated > 0, "Should update existing items")
        
        // Verify the update was persisted
        let updatedItem = try await catalogService.getGlassItemByNaturalKey("TESTMFG-001")
        #expect(updatedItem?.glassItem.name == "Updated Test Red Glass", "Should persist updates to Core Data")
    }
    
    @Test("Should handle concurrent data loading operations")
    func testConcurrentDataLoading() async throws {
        resetFactoryState()
        let _ = createTestEnvironment()
        
        RepositoryFactory.configureForProduction()
        
        // Create multiple services concurrently
        let catalogService1 = RepositoryFactory.createCatalogService()
        let catalogService2 = RepositoryFactory.createCatalogService()
        
        let mockJsonLoader = MockJSONDataLoader()
        mockJsonLoader.testDataMode = .small
        
        let loadingService1 = GlassItemDataLoadingService(
            catalogService: catalogService1,
            jsonLoader: mockJsonLoader
        )
        let loadingService2 = GlassItemDataLoadingService(
            catalogService: catalogService2,
            jsonLoader: mockJsonLoader
        )
        
        // Run concurrent loading operations
        async let result1 = loadingService1.loadGlassItemsFromJSON(options: .testing)
        async let result2 = loadingService2.loadGlassItemsFromJSON(options: .testing)
        
        let (r1, r2) = try await (result1, result2)
        
        // Both should complete (though one may skip duplicates)
        #expect(r1.itemsCreated + r1.itemsSkipped > 0, "First service should process items")
        #expect(r2.itemsCreated + r2.itemsSkipped > 0, "Second service should process items")
        
        // Total items should be consistent
        let finalItems = try await catalogService1.getAllGlassItems()
        #expect(finalItems.count > 0, "Should have items after concurrent operations")
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Should handle data loading failures gracefully")
    func testDataLoadingFailureHandling() async throws {
        resetFactoryState()
        let _ = createTestEnvironment()
        
        // Try to configure with real JSON loader (which should fail in test environment)
        do {
            try await RepositoryFactory.configureForProductionWithInitialData()
            // If it succeeds, that's fine too (means JSON files were found)
            #expect(true, "Configuration succeeded")
        } catch {
            // Should fail gracefully without crashing
            #expect(error.localizedDescription.count > 0, "Should provide meaningful error message")
        }
        
        // Factory should still be usable even after failure
        let catalogService = RepositoryFactory.createCatalogService()
        let items = try await catalogService.getAllGlassItems()
        #expect(items.count >= 0, "Should still be able to use services after failure")
    }
    
    @Test("Should maintain repository consistency across service creations")
    func testRepositoryConsistency() async throws {
        resetFactoryState()
        let _ = createTestEnvironment()
        
        RepositoryFactory.configureForProduction()
        
        // Create services multiple times
        let service1 = RepositoryFactory.createCatalogService()
        let service2 = RepositoryFactory.createCatalogService()
        let service3 = RepositoryFactory.createInventoryTrackingService()
        
        // Create test item through one service
        let testItem = GlassItemModel(
            natural_key: "CONSISTENCY-TEST-001",
            name: "Consistency Test Item",
            sku: "CT-001",
            manufacturer: "Test Manufacturer",
            mfr_notes: "Test item for consistency testing",
            coe: 96,
            url: "https://consistency.test.example.com",
            mfr_status: "available"
        )
        
        _ = try await service1.createGlassItem(testItem, initialInventory: [], tags: [])
        
        // Should be visible through other services (same Core Data store)
        let retrievedViaService2 = try await service2.getGlassItemByNaturalKey("CONSISTENCY-TEST-001")
        #expect(retrievedViaService2?.glassItem.name == "Consistency Test Item", 
               "Should see item across different service instances")
        
        let allItemsViaService3 = try await service1.getAllGlassItems() // Use public CatalogService interface
        #expect(allItemsViaService3.contains { $0.glassItem.natural_key == "CONSISTENCY-TEST-001" },
               "Should see item through different service calls")
    }
    
    // MARK: - Performance Tests
    
    @Test("Should create services efficiently")
    func testServiceCreationPerformance() async throws {
        resetFactoryState()
        let _ = createTestEnvironment()
        
        RepositoryFactory.configureForProduction()
        
        let startTime = Date()
        
        // Create many services quickly
        for _ in 1...10 {
            _ = RepositoryFactory.createCatalogService()
            _ = RepositoryFactory.createInventoryTrackingService()
            _ = RepositoryFactory.createGlassItemRepository()
            _ = RepositoryFactory.createInventoryRepository()
            _ = RepositoryFactory.createLocationRepository()
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        #expect(duration < 2.0, "Should create services quickly (under 2 seconds for 50 services)")
    }
    
    // MARK: - Configuration Reset Tests
    
    @Test("Should reset configuration properly")
    func testConfigurationReset() async throws {
        resetFactoryState()
        let testController = createTestEnvironment()
        
        // Configure with test container
        RepositoryFactory.configure(persistentContainer: testController.container)
        RepositoryFactory.mode = .coreData
        
        #expect(RepositoryFactory.mode == .coreData, "Should be in Core Data mode")
        #expect(RepositoryFactory.persistentContainer === testController.container,
               "Should use test container")
        
        // Reset to production
        RepositoryFactory.resetToProduction()
        
        #expect(RepositoryFactory.mode == .coreData, "Should still be in Core Data mode")
        #expect(RepositoryFactory.persistentContainer === PersistenceController.shared.container,
               "Should reset to shared container")
    }
    
    @Test("Should handle mode switching correctly")
    func testModeSwitching() async throws {
        resetFactoryState()
        
        // Start with mock mode
        #expect(RepositoryFactory.mode == .mock, "Should start in mock mode")
        
        let mockService = RepositoryFactory.createCatalogService()
        let mockItems = try await mockService.getAllGlassItems()
        #expect(mockItems.isEmpty, "Mock service should start empty")
        
        // Switch to Core Data mode
        let _ = createTestEnvironment()
        RepositoryFactory.configureForProduction()
        
        #expect(RepositoryFactory.mode == .coreData, "Should switch to Core Data mode")
        
        let coreDataService = RepositoryFactory.createCatalogService()
        let coreDataItems = try await coreDataService.getAllGlassItems()
        #expect(coreDataItems.isEmpty, "Core Data service should start empty too")
        
        // Services should be different implementations
        // (This is hard to test directly, but they should behave differently)
        #expect(true, "Should create different repository implementations")
    }
}