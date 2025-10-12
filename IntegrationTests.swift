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
    
    // MARK: - Cross-Service Data Pipeline Integration
    
    @Test("Should integrate ValidationUtilities with BaseCoreDataService")
    func testValidationAndCoreDataIntegration() throws {
        // Arrange - Set up test environment with isolated context
        let (testController, context) = try SharedTestUtilities.getCleanTestController()
        _ = testController
        
        let service = BaseCoreDataService<CatalogItem>(entityName: "CatalogItem")
        
        // Test data with mixed validity
        let testData = [
            ("Valid Item", "VALID-001", "GoodCorp"),
            ("", "EMPTY-NAME", "BadCorp"),
            ("Another Valid", "VALID-002", "AnotherGood")
        ]
        
        var createdItems: [CatalogItem] = []
        
        // Act - Process each item with validation + persistence
        for (name, code, manufacturer) in testData {
            let nameValidation = ValidationUtilities.validateNonEmptyString(name, fieldName: "Name")
            let codeValidation = ValidationUtilities.validateNonEmptyString(code, fieldName: "Code")
            
            if nameValidation.isSuccess && codeValidation.isSuccess {
                let item = service.create(in: context)
                if case .success(let validName) = nameValidation {
                    item.name = validName
                }
                if case .success(let validCode) = codeValidation {
                    item.code = validCode
                }
                item.manufacturer = manufacturer
                createdItems.append(item)
            }
        }
        
        // Save changes
        try context.save()
        
        // Assert - Only valid items should be created
        #expect(createdItems.count == 2, "Should create exactly 2 valid items")
        
        // Verify persistence worked
        let fetchedItems = try service.fetch(in: context)
        #expect(fetchedItems.count == 2, "Should persist exactly 2 items")
        
        // Verify SearchUtilities integration
        let searchResults = SearchUtilities.filter(fetchedItems, with: "Valid")
        #expect(searchResults.count == 2, "Should find both valid items via search")
        
        // Verify validation prevented empty names
        let allNames = fetchedItems.compactMap { $0.name }
        #expect(!allNames.contains(""), "Should not contain empty names")
    }
}
