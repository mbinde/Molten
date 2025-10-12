//
//  IntegrationTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/12/25.
//

import Foundation
import Testing
import CoreData
@testable import Flameworker

@Suite("Integration Tests")
struct IntegrationTests {
    
    // MARK: - Basic Service Integration
    
    @Test("Should integrate DataLoadingService with Core Data")
    func testDataLoadingServiceIntegration() async throws {
        // Arrange - Create isolated test environment
        let testController = PersistenceController.createTestController()
        let context = testController.container.viewContext
        let dataLoadingService = DataLoadingService.shared
        
        // Verify clean starting state
        let initialCount = try BaseCoreDataService<CatalogItem>(entityName: "CatalogItem").count(in: context)
        #expect(initialCount == 0, "Should start with empty Core Data store")
        
        // Act - Load data
        try await dataLoadingService.loadCatalogItemsFromJSON(into: context)
        
        // Assert - Data was loaded
        let finalCount = try BaseCoreDataService<CatalogItem>(entityName: "CatalogItem").count(in: context)
        #expect(finalCount > 0, "Should have loaded items into Core Data")
        
        // Verify basic data integrity
        let loadedItems = try BaseCoreDataService<CatalogItem>(entityName: "CatalogItem")
            .fetch(sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)], in: context)
        
        #expect(!loadedItems.isEmpty, "Should have fetched items")
        
        // Check first item has required fields
        if let firstItem = loadedItems.first {
            #expect(firstItem.name != nil, "Item should have a name")
            #expect(firstItem.code != nil, "Item should have a code")
        }
    }
    
    // MARK: - Search Integration
    
    @Test("Should integrate SearchUtilities with Core Data")
    func testSearchIntegration() throws {
        // Arrange - Create test data
        let testController = PersistenceController.createTestController()
        let context = testController.container.viewContext
        let service = BaseCoreDataService<CatalogItem>(entityName: "CatalogItem")
        
        // Create test items
        let item1 = service.create(in: context)
        item1.name = "Red Glass Rod"
        item1.code = "RGR-001"
        item1.manufacturer = "Effetre"
        
        let item2 = service.create(in: context)
        item2.name = "Blue Glass Sheet"
        item2.code = "BGS-002"
        item2.manufacturer = "Bullseye"
        
        try CoreDataHelpers.safeSave(context: context, description: "Search integration test")
        
        let allItems = try service.fetch(in: context)
        
        // Act & Assert - Test basic search
        let glassResults = SearchUtilities.filter(allItems, with: "glass")
        #expect(glassResults.count == 2, "Should find both items containing 'glass'")
        
        // Test search with query string parsing
        let queryResults = SearchUtilities.filterWithQueryString(allItems, queryString: "glass rod")
        #expect(queryResults.count == 1, "Should find item matching both 'glass' and 'rod'")
    }
    
    // MARK: - UI State Integration
    
    @Test("Should integrate UI state managers")
    func testUIStateManagerIntegration() {
        // Arrange - Create state managers
        let loadingManager = LoadingStateManager()
        let selectionManager = SelectionStateManager<String>()
        let filterManager = FilterStateManager()
        
        // Test initial states
        #expect(!loadingManager.isLoading, "Should start not loading")
        #expect(selectionManager.selectedItems.isEmpty, "Should start with no selection")
        #expect(!filterManager.hasActiveFilters, "Should start with no active filters")
        
        // Act & Assert - Loading state
        let startedLoading = loadingManager.startLoading(operationName: "Test Operation")
        #expect(startedLoading, "Should start loading operation")
        #expect(loadingManager.isLoading, "Should be loading")
        
        loadingManager.completeLoading()
        #expect(!loadingManager.isLoading, "Should complete loading")
        
        // Act & Assert - Selection state
        selectionManager.toggle("item1")
        #expect(selectionManager.isSelected("item1"), "Should select item1")
        #expect(selectionManager.selectedItems.count == 1, "Should have 1 selected item")
        
        // Act & Assert - Filter state
        filterManager.setTextFilter("glass")
        #expect(filterManager.hasActiveFilters, "Should have active filters")
        #expect(filterManager.textFilter == "glass", "Should set text filter")
    }
    
    // MARK: - Coordinated Workflow
    
    @Test("Should support coordinated workflow across multiple components")
    func testCoordinatedWorkflow() async throws {
        // Arrange - Set up multiple components
        let testController = PersistenceController.createTestController()
        let context = testController.container.viewContext
        let loadingManager = LoadingStateManager()
        let service = BaseCoreDataService<CatalogItem>(entityName: "CatalogItem")
        
        var workflowSteps: [String] = []
        
        // Step 1: Start loading
        _ = loadingManager.startLoading(operationName: "Data Creation")
        workflowSteps.append("loading_started")
        #expect(loadingManager.isLoading, "Should be loading")
        
        // Step 2: Create data
        let newItem = service.create(in: context)
        newItem.name = "Workflow Test Item"
        newItem.code = "WTI-001"
        try CoreDataHelpers.safeSave(context: context, description: "Workflow test")
        workflowSteps.append("data_created")
        
        // Step 3: Complete loading
        loadingManager.completeLoading()
        workflowSteps.append("loading_completed")
        #expect(!loadingManager.isLoading, "Should complete loading")
        
        // Step 4: Verify data persisted
        let savedItems = try service.fetch(in: context)
        workflowSteps.append("data_verified")
        #expect(savedItems.count == 1, "Should have saved item")
        #expect(savedItems.first?.code == "WTI-001", "Should have correct item")
        
        // Assert workflow completed
        let expectedSteps = ["loading_started", "data_created", "loading_completed", "data_verified"]
        #expect(workflowSteps == expectedSteps, "Should complete all workflow steps in order")
    }
}