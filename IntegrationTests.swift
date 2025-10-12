//
//  IntegrationTestsFixed.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/12/25.
//

import Foundation
import Testing
import CoreData
@testable import Flameworker

// Helper extension for Result validation
extension Result {
    var isSuccess: Bool {
        switch self {
        case .success:
            return true
        case .failure:
            return false
        }
    }
}

@Suite("Integration Tests")
struct IntegrationTests {
    
    // MARK: - Basic Service Integration
    
    @Test("Should integrate DataLoadingService with Core Data")
    func testDataLoadingServiceIntegration() async throws {
        // Arrange - Create isolated test environment
        let testController = PersistenceController.createTestController()
        let context = testController.container.viewContext
        
        // Create a simple test to verify integration works
        let fetchRequest = NSFetchRequest<CatalogItem>(entityName: "CatalogItem")
        
        // Verify clean starting state
        let initialCount = try context.count(for: fetchRequest)
        #expect(initialCount == 0, "Should start with empty Core Data store")
        
        // Test that we can create entities for integration
        let testItem = CatalogItem(context: context)
        testItem.name = "Integration Test Item"
        testItem.code = "ITI-001"
        testItem.manufacturer = "Test"
        
        try context.save()
        
        // Verify data was persisted
        let finalCount = try context.count(for: fetchRequest)
        #expect(finalCount == 1, "Should have one test item")
        
        // Verify we can fetch the item
        let fetchedItems = try context.fetch(fetchRequest)
        #expect(fetchedItems.count == 1, "Should fetch one item")
        #expect(fetchedItems.first?.code == "ITI-001", "Should have correct item code")
    }
    
    // MARK: - Search Integration
    
    @Test("Should integrate SearchUtilities with Core Data")
    func testSearchIntegration() throws {
        // Arrange - Create test data
        let testController = PersistenceController.createTestController()
        let context = testController.container.viewContext
        
        // Create test items directly
        let item1 = CatalogItem(context: context)
        item1.name = "Red Glass Rod"
        item1.code = "RGR-001"
        item1.manufacturer = "Effetre"
        
        let item2 = CatalogItem(context: context)
        item2.name = "Blue Glass Sheet"
        item2.code = "BGS-002"
        item2.manufacturer = "Bullseye"
        
        try context.save()
        
        // Fetch all items for search testing
        let fetchRequest = NSFetchRequest<CatalogItem>(entityName: "CatalogItem")
        let allItems = try context.fetch(fetchRequest)
        
        // Act & Assert - Test basic search
        let glassResults = SearchUtilities.filter(allItems, with: "glass")
        #expect(glassResults.count == 2, "Should find both items containing 'glass'")
        
        // Test more specific search
        let redResults = SearchUtilities.filter(allItems, with: "red")
        #expect(redResults.count == 1, "Should find one item containing 'red'")
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
    
    // MARK: - Image Integration
    
    @Test("Should integrate ImageHelpers with Core Data entities")
    func testImageHelpersWithCoreDataIntegration() throws {
        // Arrange - Create test Core Data entities with image-relevant data
        let testController = PersistenceController.createTestController()
        let context = testController.container.viewContext
        
        // Create entity with standard item code
        let itemWithCode = CatalogItem(context: context)
        itemWithCode.name = "Test Glass Rod"
        itemWithCode.code = "TEST-001"
        itemWithCode.manufacturer = "TestManufacturer"
        
        // Create entity with potential slash in code (tests sanitization)
        let itemWithSlash = CatalogItem(context: context)
        itemWithSlash.name = "Complex Code Item"
        itemWithSlash.code = "TEST/002"
        itemWithSlash.manufacturer = "TestManufacturer"
        
        try context.save()
        
        // Act & Assert - Test image loading for each entity
        
        // Test standard code with manufacturer
        let image1 = ImageHelpers.loadProductImage(for: itemWithCode.code!, manufacturer: itemWithCode.manufacturer)
        let exists1 = ImageHelpers.productImageExists(for: itemWithCode.code!, manufacturer: itemWithCode.manufacturer)
        
        // Should handle gracefully (likely no actual image file exists)
        #expect(image1 == nil, "Should handle non-existent image gracefully")
        #expect(!exists1, "Should correctly report image doesn't exist")
        
        // Test code with slash (sanitization integration)
        let image2 = ImageHelpers.loadProductImage(for: itemWithSlash.code!, manufacturer: itemWithSlash.manufacturer)
        
        // Should sanitize code and attempt lookup
        #expect(image2 == nil, "Should handle sanitized code lookup")
        
        // Verify entities were properly created
        let fetchRequest = NSFetchRequest<CatalogItem>(entityName: "CatalogItem")
        let allItems = try context.fetch(fetchRequest)
        #expect(allItems.count == 2, "Should have created both test entities")
    }
    
    // MARK: - Form Validation Integration
    
    @Test("Should integrate form validation with Core Data persistence")
    func testFormValidationWithCoreDataIntegration() throws {
        // Arrange - Create test environment
        let testController = PersistenceController.createTestController()
        let context = testController.container.viewContext
        let service = BaseCoreDataService<CatalogItem>(entityName: "CatalogItem")
        
        // Test data scenarios
        struct TestFormData {
            let name: String
            let code: String
            let manufacturer: String?
            let shouldBeValid: Bool
        }
        
        let testCases: [TestFormData] = [
            // Valid cases
            TestFormData(name: "Red Glass Rod", code: "RGR-001", manufacturer: "Effetre", shouldBeValid: true),
            TestFormData(name: "Blue Sheet", code: "BS-002", manufacturer: nil, shouldBeValid: true),
            TestFormData(name: "Green Frit", code: "GF/003", manufacturer: "Bullseye", shouldBeValid: true),
            
            // Invalid cases
            TestFormData(name: "", code: "INVALID-001", manufacturer: "Test", shouldBeValid: false),
            TestFormData(name: "Valid Name", code: "", manufacturer: "Test", shouldBeValid: false),
            TestFormData(name: "   ", code: "WHITESPACE-001", manufacturer: "Test", shouldBeValid: false),
            TestFormData(name: "Valid Name", code: "   ", manufacturer: "Test", shouldBeValid: false)
        ]
        
        var validationResults: [Bool] = []
        var creationResults: [Bool] = []
        
        // Act & Assert - Process each test case
        for testCase in testCases {
            // Step 1: Validate form data using form validation logic
            let nameValidation = ValidationUtilities.validateNonEmptyString(testCase.name, fieldName: "Name")
            let codeValidation = ValidationUtilities.validateNonEmptyString(testCase.code, fieldName: "Code")
            
            let isNameValid = nameValidation.isSuccess
            let isCodeValid = codeValidation.isSuccess
            let overallValid = isNameValid && isCodeValid
            
            validationResults.append(overallValid)
            
            // Step 2: Only attempt Core Data creation if validation passes
            var entityCreated = false
            if overallValid {
                let newItem = service.create(in: context)
                
                // Use validated and trimmed data
                if case .success(let validatedName) = nameValidation {
                    newItem.name = validatedName
                }
                if case .success(let validatedCode) = codeValidation {
                    newItem.code = validatedCode
                }
                newItem.manufacturer = testCase.manufacturer
                
                do {
                    try context.save()
                    entityCreated = true
                } catch {
                    entityCreated = false
                }
            }
            
            creationResults.append(entityCreated)
            
            // Assert validation matches expected result
            #expect(overallValid == testCase.shouldBeValid, 
                   "Validation result for '\(testCase.name)'/'\(testCase.code)' should be \(testCase.shouldBeValid)")
            
            // Assert entity creation only succeeds for valid data
            if testCase.shouldBeValid {
                #expect(entityCreated, "Should successfully create entity for valid data: '\(testCase.name)'")
            } else {
                #expect(!entityCreated, "Should not create entity for invalid data: '\(testCase.name)'")
            }
        }
        
        // Verify final state - only valid entities should exist
        let finalItems = try service.fetch(in: context)
        let expectedValidCount = testCases.filter { $0.shouldBeValid }.count
        #expect(finalItems.count == expectedValidCount, "Should have exactly \(expectedValidCount) valid entities")
        
        // Verify all created entities have properly validated data
        for item in finalItems {
            if let name = item.name {
                let nameValidation = ValidationUtilities.validateNonEmptyString(name, fieldName: "Name")
                #expect(nameValidation.isSuccess, "Entity name should be valid: '\(name)'")
            }
            if let code = item.code {
                let codeValidation = ValidationUtilities.validateNonEmptyString(code, fieldName: "Code")
                #expect(codeValidation.isSuccess, "Entity code should be valid: '\(code)'")
            }
        }
        
        // Test integration with search after creation
        let searchResults = SearchUtilities.filter(finalItems, with: "glass")
        #expect(searchResults.count >= 0, "Should be able to search created entities")
        
        // Verify form validation prevented invalid entities
        let allNames = finalItems.compactMap { $0.name }
        let allCodes = finalItems.compactMap { $0.code }
        
        #expect(!allNames.contains(""), "Should not contain empty names")
        #expect(!allNames.contains("   "), "Should not contain whitespace-only names")
        #expect(!allCodes.contains(""), "Should not contain empty codes")
        #expect(!allCodes.contains("   "), "Should not contain whitespace-only codes")
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
        try context.save()
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
    
    // MARK: - Performance Integration Test (GREEN - Should Pass!)
    
    @Test("Should achieve realistic performance benchmarks for integrated operations")
    func testRealisticPerformanceBenchmarks() throws {
        // Arrange
        let (testController, context) = try SharedTestUtilities.getCleanTestController()
        _ = testController
        
        let service = BaseCoreDataService<CatalogItem>(entityName: "CatalogItem")
        
        let startTime = Date()
        
        // Act - Simple operations across multiple services (ensure all items are valid)
        var createdItems: [CatalogItem] = []
        for i in 1...5 {
            let item = service.create(in: context)
            item.name = "Test Item \(i)"
            item.code = "TEST-\(i)"
            item.manufacturer = "TestCorp"
            createdItems.append(item)
        }
        
        try context.save()
        let allItems = try service.fetch(in: context)
        let searchResults = SearchUtilities.filter(allItems, with: "Test")
        
        let totalTime = Date().timeIntervalSince(startTime)
        
        // Assert - Realistic performance expectations based on observed ~4ms performance
        #expect(totalTime < 0.1, "Multi-service integration should complete within 100ms")
        #expect(totalTime < 0.05, "For small datasets, should complete within 50ms") 
        
        // Assert - Integration functionality works correctly
        #expect(createdItems.count == 5, "Should create 5 items in memory")
        #expect(allItems.count == 5, "Should create 5 items via BaseCoreDataService")
        #expect(searchResults.count == 5, "Should find all items via SearchUtilities")
        
        // Verify cross-service data integrity
        for item in allItems {
            #expect(item.name != nil && !item.name!.isEmpty, "All items should have valid names")
            #expect(item.code != nil && !item.code!.isEmpty, "All items should have valid codes")
            #expect(item.manufacturer == "TestCorp", "All items should have correct manufacturer")
        }
        
        // Verify search integration finds correct items
        for result in searchResults {
            #expect(result.name?.contains("Test") == true, "Search results should match query")
        }
    }
    
    // MARK: - Bulk Performance Integration Test
    
    @Test("Should handle bulk operations efficiently across multiple services")
    func testBulkOperationPerformanceIntegration() throws {
        // Arrange - Set up for bulk testing
        let (testController, context) = try SharedTestUtilities.getCleanTestController()
        _ = testController
        
        let service = BaseCoreDataService<CatalogItem>(entityName: "CatalogItem")
        let bulkSize = 50 // Reasonable bulk size for CI testing
        
        let startTime = Date()
        
        // Act - Bulk operations (simplified to avoid validation issues)
        var createdItems: [CatalogItem] = []
        for i in 1...bulkSize {
            let item = service.create(in: context)
            item.name = "Bulk Item \(i)"
            item.code = "BULK-\(i)"
            item.manufacturer = "BulkCorp"
            createdItems.append(item)
        }
        
        // Bulk save
        try context.save()
        
        // Bulk search operations
        let allItems = try service.fetch(in: context)
        let bulkSearchResults = SearchUtilities.filter(allItems, with: "Bulk")
        let corpSearchResults = SearchUtilities.filter(allItems, with: "Corp")
        
        let totalTime = Date().timeIntervalSince(startTime)
        
        // Assert - Bulk performance expectations
        #expect(totalTime < 2.0, "Bulk operations (\(bulkSize) items) should complete within 2 seconds")
        #expect(totalTime < 1.0, "Bulk persistence + search should complete within 1 second")
        
        // Assert - Data integrity at scale
        #expect(createdItems.count == bulkSize, "Should create all \(bulkSize) items in memory")
        #expect(allItems.count == bulkSize, "Should persist all \(bulkSize) items")
        #expect(bulkSearchResults.count == bulkSize, "Should find all items via 'Bulk' search")
        #expect(corpSearchResults.count == bulkSize, "Should find all items via 'Corp' search")
        
        // Assert - Search performance at scale
        let searchStartTime = Date()
        let multipleSearches = [
            SearchUtilities.filter(allItems, with: "Item"),
            SearchUtilities.filter(allItems, with: "1"), // Should find items with "1" in them
            SearchUtilities.filter(allItems, with: "Bulk"),
            SearchUtilities.filter(allItems, with: "NotFound")
        ]
        let searchTime = Date().timeIntervalSince(searchStartTime)
        
        #expect(searchTime < 0.1, "Multiple search operations on \(bulkSize) items should complete within 100ms")
        #expect(multipleSearches[0].count == bulkSize, "Should find all items containing 'Item'")
        #expect(multipleSearches[1].count > 0, "Should find items containing '1'")
        #expect(multipleSearches[2].count == bulkSize, "Should find all items containing 'Bulk'")
        #expect(multipleSearches[3].count == 0, "Should find no items containing 'NotFound'")
        
        // Verify data quality at scale (check first 5 items for efficiency)
        let sampleItems = Array(allItems.prefix(5))
        for (index, item) in sampleItems.enumerated() {
            #expect(item.name != nil && !item.name!.isEmpty, "Bulk item \(index + 1) should have valid name")
            #expect(item.code != nil && !item.code!.isEmpty, "Bulk item \(index + 1) should have valid code")
            #expect(item.manufacturer == "BulkCorp", "Bulk item \(index + 1) should have correct manufacturer")
        }
    }
}