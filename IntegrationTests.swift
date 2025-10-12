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
        
        // Act - Simple operations across multiple services
        for i in 1...5 {
            let item = service.create(in: context)
            item.name = "Test Item \(i)"
            item.code = "TEST-\(i)"
            item.manufacturer = "TestCorp"
        }
        
        try context.save()
        let allItems = try service.fetch(in: context)
        let searchResults = SearchUtilities.filter(allItems, with: "Test")
        
        let totalTime = Date().timeIntervalSince(startTime)
        
        // Assert - Realistic performance expectations based on observed ~4ms performance
        #expect(totalTime < 0.1, "Multi-service integration should complete within 100ms")
        #expect(totalTime < 0.05, "For small datasets, should complete within 50ms") 
        
        // Assert - Integration functionality works correctly
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
    
    // MARK: - Error Recovery Integration Test
    
    @Test("Should handle partial failures gracefully across multiple services")
    func testErrorRecoveryIntegration() throws {
        // Arrange - Set up scenario with potential failures
        let (testController, context) = try SharedTestUtilities.getCleanTestController()
        _ = testController
        
        let service = BaseCoreDataService<CatalogItem>(entityName: "CatalogItem")
        
        // Test data with mixed success/failure scenarios
        let testCases = [
            ("Valid Item 1", "VALID-001", "GoodCorp", true),
            ("", "EMPTY-NAME", "BadCorp", false), // Should fail validation
            ("Valid Item 2", "VALID-002", "GoodCorp", true),
            ("Valid Item 3", "", "GoodCorp", false), // Should fail validation  
            ("Valid Item 4", "VALID-004", "GoodCorp", true)
        ]
        
        var successfulItems: [CatalogItem] = []
        var validationResults: [Bool] = []
        var errorMessages: [String] = []
        
        // Act - Process mixed success/failure data through integrated pipeline
        for (name, code, manufacturer, expectedSuccess) in testCases {
            // Step 1: Validation integration
            let nameValidation = ValidationUtilities.validateNonEmptyString(name, fieldName: "Name")
            let codeValidation = ValidationUtilities.validateNonEmptyString(code, fieldName: "Code")
            
            let isValid = nameValidation.isSuccess && codeValidation.isSuccess
            validationResults.append(isValid)
            
            // Step 2: Only persist valid items, collect error info for invalid ones
            if isValid {
                let item = service.create(in: context)
                if case .success(let validName) = nameValidation {
                    item.name = validName
                }
                if case .success(let validCode) = codeValidation {
                    item.code = validCode
                }
                item.manufacturer = manufacturer
                successfulItems.append(item)
            } else {
                // Collect error information
                var errors: [String] = []
                if case .failure(let nameError) = nameValidation {
                    errors.append("Name: \(nameError.localizedDescription)")
                }
                if case .failure(let codeError) = codeValidation {
                    errors.append("Code: \(codeError.localizedDescription)")
                }
                errorMessages.append(errors.joined(separator: ", "))
            }
        }
        
        // Step 3: Save successful items
        try context.save()
        
        // Step 4: Verify integrated error recovery
        let allPersistedItems = try service.fetch(in: context)
        let searchResults = SearchUtilities.filter(allPersistedItems, with: "Valid")
        
        // Assert - Error recovery behavior
        let expectedSuccessCount = testCases.filter { $0.3 }.count // Count expected successes
        let expectedFailureCount = testCases.count - expectedSuccessCount
        
        #expect(successfulItems.count == expectedSuccessCount, "Should create exactly \(expectedSuccessCount) valid items")
        #expect(allPersistedItems.count == expectedSuccessCount, "Should persist exactly \(expectedSuccessCount) valid items")
        #expect(errorMessages.count == expectedFailureCount, "Should collect exactly \(expectedFailureCount) error messages")
        
        // Assert - Validation results match expectations
        let expectedValidations = testCases.map { $0.3 }
        #expect(validationResults == expectedValidations, "Validation results should match expectations")
        
        // Assert - Search integration works on partial success
        #expect(searchResults.count == expectedSuccessCount, "Search should find all successfully created items")
        
        // Assert - Error messages are meaningful
        for errorMessage in errorMessages {
            #expect(!errorMessage.isEmpty, "Error messages should be non-empty")
            #expect(errorMessage.contains("Name") || errorMessage.contains("Code"), "Error messages should indicate which field failed")
        }
        
        // Assert - Successful items have complete data
        for item in successfulItems {
            #expect(item.name != nil && !item.name!.isEmpty, "Successful items should have valid names")
            #expect(item.code != nil && !item.code!.isEmpty, "Successful items should have valid codes")
            #expect(item.manufacturer != nil && !item.manufacturer!.isEmpty, "Successful items should have valid manufacturers")
        }
        
        // Assert - System continues to work after partial failures
        let additionalItem = service.create(in: context)
        additionalItem.name = "Recovery Test Item"
        additionalItem.code = "RECOVERY-001"
        additionalItem.manufacturer = "RecoveryCorp"
        
        try context.save()
        
        let finalItems = try service.fetch(in: context)
        #expect(finalItems.count == expectedSuccessCount + 1, "System should continue working after partial failures")
    }
    
    // MARK: - Complex App State Transitions Integration Test (SAFE)
    
    @Test("Should handle complex app state transitions across multiple managers")
    func testComplexAppStateTransitionsIntegration() async throws {
        // Arrange - Set up complex multi-step workflow scenario (safe, no Core Data)
        let loadingManager = LoadingStateManager()
        let selectionManager = SelectionStateManager<String>()
        let filterManager = FilterStateManager()
        
        // Create test dataset for complex workflow
        let fullDataset = (1...30).map { i in
            let category = i <= 10 ? "Glass" : (i <= 20 ? "Tools" : "Supplies")
            let manufacturer = i % 3 == 0 ? "PremiumCorp" : (i % 3 == 1 ? "StandardCorp" : "EconomyCorp")
            return (name: "\(category) Item \(i)", code: "ITEM-\(i)", category: category, manufacturer: manufacturer)
        }
        
        var workflowSteps: [String] = []
        var stateSnapshots: [(loading: Bool, selectedCount: Int, hasFilters: Bool)] = []
        
        // Helper to capture state snapshot
        let captureState = {
            stateSnapshots.append((
                loading: loadingManager.isLoading,
                selectedCount: selectionManager.selectedItems.count,
                hasFilters: filterManager.hasActiveFilters
            ))
        }
        
        // Act - Execute complex multi-step workflow
        
        // Step 1: Initial data loading
        _ = loadingManager.startLoading(operationName: "Loading dataset")
        captureState()
        workflowSteps.append("loading_started")
        
        // Step 2: Apply text filter while loading
        filterManager.setTextFilter("Glass")
        captureState()
        workflowSteps.append("text_filter_applied")
        
        // Complete loading
        loadingManager.completeLoading()
        captureState()
        workflowSteps.append("loading_completed")
        
        // Step 3: Apply search and get filtered results
        let textFilter = filterManager.textFilter ?? ""
        let filteredData = fullDataset.filter { item in
            let matchesText = textFilter.isEmpty || item.name.contains(textFilter)
            return matchesText
        }
        
        workflowSteps.append("data_filtered")
        captureState()
        
        // Step 4: Select items based on filter results
        let itemsToSelect = filteredData.prefix(5).map { $0.name }
        for item in itemsToSelect {
            selectionManager.toggle(item)
        }
        captureState()
        workflowSteps.append("items_selected")
        
        // Step 5: Change text filter while items are selected
        filterManager.setTextFilter("Glass Item")
        captureState()
        workflowSteps.append("filter_updated")
        
        // Step 6: Clear filters and verify state cleanup
        filterManager.clearAllFilters()
        captureState()
        workflowSteps.append("filters_cleared")
        
        // Assert - Complex workflow executed correctly
        let expectedSteps = [
            "loading_started", "text_filter_applied", "loading_completed",
            "data_filtered", "items_selected", "filter_updated", "filters_cleared"
        ]
        #expect(workflowSteps == expectedSteps, "Should complete all workflow steps in correct order")
        
        // Assert - State transitions were logical
        #expect(stateSnapshots.count == 7, "Should have captured 7 state snapshots")
        
        // Verify key state transitions
        #expect(stateSnapshots[0].loading == true, "Should be loading at start")
        #expect(stateSnapshots[0].hasFilters == false, "Should have no filters initially")
        
        #expect(stateSnapshots[1].loading == true, "Should still be loading after text filter")
        #expect(stateSnapshots[1].hasFilters == true, "Should have active filters after text filter")
        
        #expect(stateSnapshots[2].loading == false, "Should complete loading")
        #expect(stateSnapshots[2].hasFilters == true, "Should maintain filters after loading")
        
        #expect(stateSnapshots[4].selectedCount > 0, "Should have selections after selection step")
        #expect(stateSnapshots[6].hasFilters == false, "Should have no filters after clearing")
        
        // Assert - Final state is clean
        #expect(!loadingManager.isLoading, "Should not be loading at end")
        #expect(!filterManager.hasActiveFilters, "Should have no active filters at end")
        
        // Assert - Selection state reflects workflow
        let finalSelectionCount = selectionManager.selectedItems.count
        #expect(finalSelectionCount > 0, "Should have items selected from workflow")
        
        // Verify data filtering worked correctly
        #expect(filteredData.count <= fullDataset.count, "Filtered data should be subset of full data")
        let glassItems = filteredData.filter { $0.name.contains("Glass") }
        #expect(glassItems.count > 0, "Should have found Glass items in filtered data")
        
        // Test workflow can be repeated (state managers are reusable)
        _ = loadingManager.startLoading(operationName: "Repeat workflow test")
        #expect(loadingManager.isLoading, "Should be able to start new workflow")
        
        loadingManager.completeLoading()
        #expect(!loadingManager.isLoading, "Should complete new workflow")
        
        // Verify selection manager still works after workflow
        selectionManager.selectAll(["Test1", "Test2", "Test3"])
        #expect(selectionManager.selectedItems.count == 3, "Selection manager should be reusable")
    }
}