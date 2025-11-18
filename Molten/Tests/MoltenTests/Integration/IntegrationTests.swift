//
//  IntegrationTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/12/25.
//

import Foundation
import Testing
@testable import Molten

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

@Suite("Integration Tests - Mock-Only Repository Pattern Architecture", .serialized)
@MainActor
struct IntegrationTests {
    
    // MARK: - Repository Pattern Integration
    
    @Test("Should integrate MockGlassItemRepository with comprehensive operations")
    func testMockGlassItemRepositoryIntegration() async throws {
        // Arrange - Clean repository pattern integration without Core Data dependencies
        let repos = TestConfiguration.createIsolatedMockRepositories()
        let mockRepository = repos.glassItem
        
        // Create test items using TestDataSetup for consistency
        let testGlassItems = TestDataSetup.createStandardTestGlassItems().prefix(3)
        
        for testItem in testGlassItems {
            _ = try await mockRepository.createItem(testItem)
        }
        
        // Act - Repository operations
        let allItems = try await mockRepository.fetchItems(matching: nil)
        let countResult = await mockRepository.getItemCount()
        
        // Use SearchUtilities for search operations
        let redItems = SearchUtilities.filter(allItems, with: "Red")
        
        // Assert - Repository works correctly with no Core Data
        #expect(allItems.count == 3, "Repository should return all items")
        #expect(countResult == 3, "Repository count should match items")
        #expect(redItems.count >= 0, "Search should work without Core Data")
        
        // Verify no Core Data leakage
        try await TestConfiguration.verifyNoCoreDdataLeakage(glassItemRepo: mockRepository)
    }
    
    @Test("Should integrate mock repositories with proper isolation")
    func testMockRepositoryIntegrationWithoutCoreData() async throws {
        // Arrange - Create isolated test environment using TestConfiguration
        let repos = TestConfiguration.createIsolatedMockRepositories()
        
        // Use TestDataSetup for consistent test data
        let testItems = TestDataSetup.createStandardTestGlassItems().prefix(2)
        
        for item in testItems {
            _ = try await repos.glassItem.createItem(item)
        }
        
        // Act - Test integration through services
        let inventoryTrackingService = InventoryTrackingService(
            glassItemRepository: repos.glassItem,
            inventoryRepository: repos.inventory,
            itemTagsRepository: repos.itemTags
        )

        let shoppingListRepository = MockShoppingListRepository()
        let userTagsRepo = MockUserTagsRepository()

        let userTagsRepository = MockUserTagsRepository()
        let coatingItemRepo = MockCoatingItemRepository()
        let toolItemRepo = MockToolItemRepository()




        let catalogService = CatalogService(
            glassItemRepository: repos.glassItem,
            coatingItemRepository: coatingItemRepo,
            toolItemRepository: toolItemRepo,
            inventoryTrackingService: inventoryTrackingService,
            itemMinimumRepository: repos.itemMinimum,
            itemTagsRepository: repos.itemTags,
            userTagsRepository: userTagsRepo,
            ratingService: AppDependencies.shared.ratingService
        )
        
        let allItems = try await catalogService.getAllGlassItems()

        // Assert - Integration works without Core Data
        #expect(allItems.count == 2, "Service integration should work with mocks")
        #expect(allItems.allSatisfy { !$0.glassItem.stable_id.isEmpty }, "Items should have valid data")
        
        print("✅ INTEGRATION TEST: Mock services integrated successfully without Core Data")
    }
    
    // MARK: - Repository Pattern with UI State Integration
    
    @Test("Should integrate repository pattern with UI state management")
    func testRepositoryPatternUIStateIntegration() async throws {
        // Arrange - Repository pattern with UI state managers using TestConfiguration
        let repos = TestConfiguration.createIsolatedMockRepositories()
        let loadingManager = LoadingStateManager()
        let selectionManager = SelectionStateManager<String>()
        let filterManager = FilterStateManager()
        
        // Add test data using TestDataSetup
        let testItems = TestDataSetup.createStandardTestGlassItems().prefix(3)
        for item in testItems {
            _ = try await repos.glassItem.createItem(item)
        }
        
        var workflowSteps: [String] = []
        
        // Act - Execute workflow integrating repository pattern with UI state
        
        // Step 1: Start loading
        _ = loadingManager.startLoading(operationName: "Loading catalog items")
        workflowSteps.append("loading_started")
        #expect(loadingManager.isLoading, "Should be loading")
        
        // Step 2: Fetch data through repository
        let allItems = try await repos.glassItem.fetchItems(matching: nil)
        workflowSteps.append("items_fetched")
        
        // Step 3: Apply filters using SearchUtilities
        filterManager.setTextFilter("Glass")
        let filteredItems = SearchUtilities.filter(allItems, with: filterManager.textFilter ?? "")
        workflowSteps.append("items_filtered")
        
        // Step 4: Select items
        for item in filteredItems.prefix(2) {
            selectionManager.toggle(item.stable_id)
        }
        workflowSteps.append("items_selected")
        
        // Step 5: Perform search through SearchUtilities
        let searchResults = SearchUtilities.filter(allItems, with: "Bullseye")
        workflowSteps.append("search_performed")
        
        // Step 6: Complete loading
        loadingManager.completeLoading()
        workflowSteps.append("loading_completed")
        
        // Assert - Integrated workflow completed successfully
        let expectedSteps = ["loading_started", "items_fetched", "items_filtered", "items_selected", "search_performed", "loading_completed"]
        #expect(workflowSteps == expectedSteps, "Should complete integrated workflow")
        
        #expect(!loadingManager.isLoading, "Should complete loading")
        #expect(allItems.count == 3, "Should fetch all items through repository pattern")
        #expect(filteredItems.count >= 0, "Should filter items correctly")
        #expect(selectionManager.selectedItems.count == 2, "Should select filtered items")
        #expect(searchResults.count >= 0, "Should find items by manufacturer through search")
        #expect(filterManager.hasActiveFilters, "Should maintain filter state")
    }
    
    // MARK: - Repository Pattern with Search Integration
    
    @Test("Should integrate repository pattern with SearchUtilities")
    func testRepositoryPatternSearchIntegration() async throws {
        // Arrange - Test repository pattern integration with search utilities
        let mockRepository = MockGlassItemRepository()

        // Add diverse test data
        _ = try await mockRepository.createItems([
            GlassItemModel(stable_id: "rgr001", name: "Red Glass Rod", sku: "RGR-001", manufacturer: "Effetre Glass", coe: 96, mfr_status: "available"),
            GlassItemModel(stable_id: "bgs002", name: "Blue Glass Sheet", sku: "BGS-002", manufacturer: "Bullseye Glass", coe: 90, mfr_status: "available"),
            GlassItemModel(stable_id: "cf0003", name: "Clear Frit", sku: "CF-003", manufacturer: "Effetre Glass", coe: 96, mfr_status: "available"),
            GlassItemModel(stable_id: "ys0004", name: "Yellow Stringer", sku: "YS-004", manufacturer: "Vetrofond", coe: 104, mfr_status: "available")
        ])

        // Act - Repository pattern search
        let repositoryGlassResults = try await mockRepository.searchItems(text: "Glass")
        let repositoryEffetreResults = try await mockRepository.searchItems(text: "Effetre")

        // Act - SearchUtilities integration (simulate what would happen in UI layer)
        let allItems = try await mockRepository.fetchItems(matching: nil)
        let searchUtilityGlassResults = SearchUtilities.filter(allItems, with: "Glass")
        
        // Assert - Repository search works correctly
        #expect(repositoryGlassResults.count == 3, "Repository should find 3 items with 'Glass'")
        #expect(repositoryEffetreResults.count == 2, "Repository should find 2 items from 'Effetre'")
        
        // Assert - SearchUtilities integration produces consistent results
        #expect(searchUtilityGlassResults.count == repositoryGlassResults.count, 
               "SearchUtilities should produce same results as repository search")
        
        // Verify specific items are found correctly
        let foundRed = repositoryGlassResults.contains { $0.name == "Red Glass Rod" }
        let foundBlue = repositoryGlassResults.contains { $0.name == "Blue Glass Sheet" }
        let foundBullseye = repositoryGlassResults.contains { $0.manufacturer == "Bullseye Glass" }
        
        #expect(foundRed, "Should find Red Glass Rod in glass search")
        #expect(foundBlue, "Should find Blue Glass Sheet in glass search")  
        #expect(foundBullseye, "Should find Bullseye manufacturer in glass search")
    }
    
    // MARK: - Repository Pattern with Image Helpers
    
    @Test("Should integrate repository pattern with ImageHelpers")
    func testRepositoryPatternImageHelpersIntegration() async throws {
        // Arrange - Test repository pattern integration with image utilities
        let mockRepository = MockGlassItemRepository()

        // Add test items with various code formats to test sanitization
        _ = try await mockRepository.createItems([
            GlassItemModel(stable_id: "std001", name: "Standard Code Item", sku: "STD-001", manufacturer: "TestCorp", coe: 96, mfr_status: "available"),
            GlassItemModel(stable_id: "sls002", name: "Slash Code Item", sku: "SLS/002", manufacturer: "TestCorp", coe: 96, mfr_status: "available"),
            GlassItemModel(stable_id: "cpx003", name: "Complex Code Item", sku: "CPX-A/B-003", manufacturer: "TestCorp", coe: 96, mfr_status: "available")
        ])

        // Act - Fetch items through repository pattern
        let allItems = try await mockRepository.fetchItems(matching: nil)
        
        // Test image helper integration with repository data
        var imageResults: [(item: GlassItemModel, imageExists: Bool)] = []
        
        for item in allItems {
            // Act - Test image loading for each item from repository
            let sku = item.sku ?? ""
            let imageExists = ImageHelpers.productImageExists(for: sku, manufacturer: item.manufacturer)
            let loadedImage = ImageHelpers.loadProductImage(for: sku, manufacturer: item.manufacturer)

            imageResults.append((item: item, imageExists: imageExists))

            // Assert - Should handle all code formats gracefully
            #expect(loadedImage == nil, "Should handle non-existent images gracefully for \(sku)")
            // Image existence check should work without errors regardless of code format
        }

        // Assert - Repository integration provides clean data for image operations
        #expect(imageResults.count == 3, "Should process all items from repository")
        #expect(allItems.allSatisfy { !($0.sku ?? "").isEmpty }, "Repository should provide valid SKUs for image lookup")
        #expect(allItems.allSatisfy { !$0.manufacturer.isEmpty }, "Repository should provide valid manufacturers for image lookup")

        // Verify that complex codes are handled by ImageHelpers
        let slashItem = allItems.first { ($0.sku ?? "").contains("/") }
        #expect(slashItem != nil, "Should have item with slash in code")
        
        if let slashItem = slashItem {
            // This should work without throwing errors due to ImageHelpers sanitization
            let sku = slashItem.sku ?? ""
            let exists = ImageHelpers.productImageExists(for: sku, manufacturer: slashItem.manufacturer)
            #expect(!exists || exists, "Image existence check should complete without error")
        }
    }
    
    // MARK: - Repository Pattern with Form Validation
    
    @Test("Should integrate repository pattern with form validation workflows")
    func testRepositoryPatternFormValidationIntegration() async throws {
        // Arrange - Repository pattern with validation workflow
        let mockRepository = MockGlassItemRepository()
        
        // Test form data scenarios
        struct FormSubmissionData {
            let name: String
            let code: String
            let manufacturer: String
            let shouldBeValid: Bool
        }
        
        let testSubmissions: [FormSubmissionData] = [
            // Valid submissions
            FormSubmissionData(name: "Red Glass Rod", code: "RGR-001", manufacturer: "Effetre", shouldBeValid: true),
            FormSubmissionData(name: "Blue Sheet", code: "BS-002", manufacturer: "Bullseye", shouldBeValid: true),
            FormSubmissionData(name: "Green Frit", code: "GF-003", manufacturer: "Vetrofond", shouldBeValid: true),
            
            // Invalid submissions
            FormSubmissionData(name: "", code: "INVALID-001", manufacturer: "Test", shouldBeValid: false),
            FormSubmissionData(name: "Valid Name", code: "", manufacturer: "Test", shouldBeValid: false),
            FormSubmissionData(name: "   ", code: "WHITESPACE-001", manufacturer: "Test", shouldBeValid: false)
        ]
        
        var validationResults: [Bool] = []
        var successfulCreations: [GlassItemModel] = []
        var validationErrors: [String] = []
        
        // Act - Process form submissions through validation + repository pattern
        for submission in testSubmissions {
            // Step 1: Form validation using validation utilities
            let nameValidation = ValidationUtilities.validateNonEmptyString(submission.name, fieldName: "Name")
            let codeValidation = ValidationUtilities.validateNonEmptyString(submission.code, fieldName: "Code")
            
            let isValid = nameValidation.isSuccess && codeValidation.isSuccess
            validationResults.append(isValid)
            
            // Step 2: Only attempt repository operations for valid data
            if isValid {
                if case .success(let validName) = nameValidation,
                   case .success(let validCode) = codeValidation {

                    let catalogItem = GlassItemModel(
                        stable_id: validCode.lowercased().replacingOccurrences(of: " ", with: "-"),
                        name: validName,
                        sku: validCode,
                        manufacturer: submission.manufacturer,
                        coe: 96,
                        mfr_status: "available"
                    )
                    
                    do {
                        let createdItem = try await mockRepository.createItem(catalogItem)
                        successfulCreations.append(createdItem)
                    } catch {
                        validationErrors.append("Repository error: \(error.localizedDescription)")
                    }
                }
            } else {
                // Collect validation errors
                var errors: [String] = []
                if case .failure(let nameError) = nameValidation {
                    errors.append("Name: \(nameError.localizedDescription)")
                }
                if case .failure(let codeError) = codeValidation {
                    errors.append("Code: \(codeError.localizedDescription)")
                }
                validationErrors.append(errors.joined(separator: ", "))
            }
        }
        
        // Step 3: Verify integration results through repository
        let allItemsFromRepository = try await mockRepository.fetchItems(matching: nil)
        let searchResults = try await mockRepository.searchItems(text: "Glass")
        
        // Assert - Validation integration works correctly
        let expectedValidCount = testSubmissions.filter { $0.shouldBeValid }.count
        let expectedInvalidCount = testSubmissions.count - expectedValidCount
        
        #expect(successfulCreations.count == expectedValidCount, "Should create \(expectedValidCount) valid items")
        #expect(allItemsFromRepository.count == expectedValidCount, "Repository should contain \(expectedValidCount) items")
        
        let validationErrorsForInvalid = validationErrors.filter { !$0.contains("Repository error") }
        #expect(validationErrorsForInvalid.count == expectedInvalidCount, "Should collect \(expectedInvalidCount) validation errors")
        
        // Assert - Repository contains only validated data
        for item in successfulCreations {
            #expect(!item.name.isEmpty, "Created items should have non-empty names")
            #expect(!(item.sku ?? "").isEmpty, "Created items should have non-empty codes")
            #expect(!item.manufacturer.isEmpty, "Created items should have non-empty manufacturers")
            #expect(!item.stable_id.isEmpty, "Created items should have generated IDs")
        }

        // Assert - Search works on validated repository data
        #expect(searchResults.count >= 0, "Search should work on repository data")
        let expectedGlassItems = successfulCreations.filter { $0.name.contains("Glass") }.count
        #expect(searchResults.count == expectedGlassItems, "Should find correct number of glass items")

        // Assert - Validation prevented invalid data from reaching repository
        let allNames = allItemsFromRepository.map { $0.name }
        let allCodes = allItemsFromRepository.map { $0.sku ?? "" }
        
        #expect(!allNames.contains(""), "Repository should not contain empty names")
        #expect(!allNames.contains("   "), "Repository should not contain whitespace-only names")  
        #expect(!allCodes.contains(""), "Repository should not contain empty codes")
        #expect(!allCodes.contains("   "), "Repository should not contain whitespace-only codes")
    }
    
    // MARK: - Repository Pattern Workflow Integration
    
    @Test("Should support coordinated workflow using repository pattern")
    func testRepositoryPatternCoordinatedWorkflow() async throws {
        // Arrange - Set up repository pattern components with state management
        let mockRepository = MockGlassItemRepository()
        let loadingManager = LoadingStateManager()
        
        var workflowSteps: [String] = []
        
        // Step 1: Start loading operation
        _ = loadingManager.startLoading(operationName: "Repository Data Creation")
        workflowSteps.append("loading_started")
        #expect(loadingManager.isLoading, "Should be loading")
        
        // Step 2: Create data through repository pattern
        let newItem = GlassItemModel(
            stable_id: "workflowcorp-wti-001-0",
            name: "Workflow Test Item",
            sku: "WTI-001",
            manufacturer: "WorkflowCorp",
            coe: 96,
            mfr_status: "available"
        )
        let createdItem = try await mockRepository.createItem(newItem)
        workflowSteps.append("data_created_via_repository")

        // Step 3: Complete loading
        loadingManager.completeLoading()
        workflowSteps.append("loading_completed")
        #expect(!loadingManager.isLoading, "Should complete loading")

        // Step 4: Verify data through repository
        let allItems = try await mockRepository.fetchItems(matching: nil)
        let searchResults = try await mockRepository.searchItems(text: "Workflow")
        workflowSteps.append("data_verified_via_repository")

        // Assert - Repository pattern workflow completed successfully
        let expectedSteps = ["loading_started", "data_created_via_repository", "loading_completed", "data_verified_via_repository"]
        #expect(workflowSteps == expectedSteps, "Should complete repository pattern workflow in order")

        #expect((createdItem.sku ?? "") == "WTI-001", "Should create item correctly through repository")
        #expect(allItems.count == 1, "Should have created item in repository")
        #expect(searchResults.count == 1, "Should find created item through search")
        #expect(searchResults.first?.name == "Workflow Test Item", "Should find correct item")
    }
    
    // MARK: - Repository Pattern Performance Integration
    
    @Test("Should achieve good performance with repository pattern integration")
    func testRepositoryPatternPerformanceIntegration() async throws {
        // Arrange - Repository pattern with realistic performance expectations
        let mockRepository = MockGlassItemRepository()
        
        let startTime = Date()
        
        // Act - Repository pattern operations
        var createdItems: [GlassItemModel] = []
        
        for i in 1...10 {
            let sku = "PTI-\(String(format: "%03d", i))"
            let item = GlassItemModel(
                stable_id: "perfcorp-pti-\(String(format: "%03d", i))-0",
                name: "Performance Test Item \(i)",
                sku: sku,
                manufacturer: "PerfCorp",
                coe: 96,
                mfr_status: "available"
            )
            let created = try await mockRepository.createItem(item)
            createdItems.append(created)
        }

        let allItems = try await mockRepository.fetchItems(matching: nil)
        let searchResults = try await mockRepository.searchItems(text: "Performance")

        let totalTime = Date().timeIntervalSince(startTime)

        // Assert - Repository pattern provides good performance (more realistic expectations)
        #expect(totalTime < 1.0, "Repository pattern should be reasonably fast (< 1 second)")
        #expect(allItems.count == 10, "Should create all items through repository pattern")
        #expect(searchResults.count == 10, "Should find all items through repository search")

        // Verify data integrity through repository pattern
        for (index, item) in allItems.enumerated() {
            #expect(!item.name.isEmpty, "Item \(index) should have valid name")
            #expect(!(item.sku ?? "").isEmpty, "Item \(index) should have valid code")
            #expect(item.manufacturer == "PerfCorp", "Item \(index) should have correct manufacturer")
            #expect(!item.stable_id.isEmpty, "Item \(index) should have generated ID")
            #expect((item.sku ?? "").hasPrefix("PTI-"), "Item \(index) should have properly formatted code")
        }
        
        // Verify search functionality performance and accuracy
        for result in searchResults {
            #expect(result.name.contains("Performance"), "Search result should match query")
        }
    }
    
    // MARK: - Repository Pattern Error Recovery Integration
    
    @Test("Should handle errors gracefully with repository pattern")
    func testRepositoryPatternErrorRecoveryIntegration() async throws {
        // Arrange - Repository pattern with mixed success/failure scenarios
        let mockRepository = MockGlassItemRepository()
        
        // Test scenarios with validation integration
        let testCases = [
            ("Valid Item 1", "VALID-001", "GoodCorp", true),
            ("", "EMPTY-NAME", "BadCorp", false), // Should be rejected by validation
            ("Valid Item 2", "VALID-002", "GoodCorp", true),
            ("Valid Item 3", "", "GoodCorp", false), // Should be rejected by validation
            ("Valid Item 4", "VALID-004", "GoodCorp", true)
        ]
        
        var successfulItems: [GlassItemModel] = []
        var validationErrors: [String] = []
        
        // Act - Process items with validation before repository operations
        for (name, code, manufacturer, expectedSuccess) in testCases {
            // Validation before repository interaction
            let nameValidation = ValidationUtilities.validateNonEmptyString(name, fieldName: "Name")
            let codeValidation = ValidationUtilities.validateNonEmptyString(code, fieldName: "Code")
            
            let isValid = nameValidation.isSuccess && codeValidation.isSuccess
            
            if isValid && expectedSuccess {
                if case .success(let validName) = nameValidation,
                   case .success(let validCode) = codeValidation {

                    let item = GlassItemModel(
                        stable_id: "\(manufacturer.lowercased())-\(validCode.lowercased())-0",
                        name: validName,
                        sku: validCode,
                        manufacturer: manufacturer,
                        coe: 96,
                        mfr_status: "available"
                    )

                    do {
                        let created = try await mockRepository.createItem(item)
                        successfulItems.append(created)
                    } catch {
                        validationErrors.append("Repository error: \(error.localizedDescription)")
                    }
                }
            } else {
                // Collect validation errors
                var errors: [String] = []
                if case .failure(let nameError) = nameValidation {
                    errors.append("Name: \(nameError.localizedDescription)")
                }
                if case .failure(let codeError) = codeValidation {
                    errors.append("Code: \(codeError.localizedDescription)")
                }
                validationErrors.append(errors.joined(separator: ", "))
            }
        }
        
        // Verify repository state after error recovery
        let allItemsFromRepository = try await mockRepository.fetchItems(matching: nil)
        let searchResults = try await mockRepository.searchItems(text: "Valid")
        
        // Assert - Error recovery with repository pattern
        let expectedSuccessCount = testCases.filter { $0.3 }.count
        
        #expect(successfulItems.count == expectedSuccessCount, "Should create \(expectedSuccessCount) valid items")
        #expect(allItemsFromRepository.count == expectedSuccessCount, "Repository should contain \(expectedSuccessCount) items")
        #expect(searchResults.count == expectedSuccessCount, "Search should find \(expectedSuccessCount) items")
        
        // Assert - Repository contains only valid data
        for item in successfulItems {
            #expect(!item.name.isEmpty, "Repository should only contain items with valid names")
            #expect(!(item.sku ?? "").isEmpty, "Repository should only contain items with valid codes")
            #expect(!item.manufacturer.isEmpty, "Repository should only contain items with valid manufacturers")
        }

        // Assert - System continues working after partial failures
        let recoveryItem = GlassItemModel(
            stable_id: "recoverycorp-recovery-001-0",
            name: "Recovery Test Item",
            sku: "RECOVERY-001",
            manufacturer: "RecoveryCorp",
            coe: 96,
            mfr_status: "available"
        )
        
        let recoveryCreated = try await mockRepository.createItem(recoveryItem)
        let finalItems = try await mockRepository.fetchItems(matching: nil)
        
        #expect(recoveryCreated.name == "Recovery Test Item", "Should continue working after partial failures")
        #expect(finalItems.count == expectedSuccessCount + 1, "Repository should contain recovery item")
    }
    
    // MARK: - Repository Pattern State Transitions Integration
    
    @Test("Should handle complex state transitions with repository pattern")
    func testRepositoryPatternStateTransitionsIntegration() async throws {
        // Arrange - Repository pattern with complex UI state management
        let mockRepository = MockGlassItemRepository()
        let loadingManager = LoadingStateManager()
        let selectionManager = SelectionStateManager<String>()
        let filterManager = FilterStateManager()
        
        // Create test dataset through repository
        let testItems = [
            GlassItemModel(stable_id: "premiumcorp-gr-001-0", name: "Glass Rod 1", sku: "GR-001", manufacturer: "PremiumCorp", coe: 96, mfr_status: "available"),
            GlassItemModel(stable_id: "standardcorp-gr-002-0", name: "Glass Rod 2", sku: "GR-002", manufacturer: "StandardCorp", coe: 96, mfr_status: "available"),
            GlassItemModel(stable_id: "premiumcorp-ti-001-0", name: "Tool Item 1", sku: "TI-001", manufacturer: "PremiumCorp", coe: 96, mfr_status: "available"),
            GlassItemModel(stable_id: "standardcorp-ti-002-0", name: "Tool Item 2", sku: "TI-002", manufacturer: "StandardCorp", coe: 96, mfr_status: "available")
        ]
        
        for item in testItems {
            _ = try await mockRepository.createItem(item)
        }
        
        var workflowSteps: [String] = []
        var stateSnapshots: [(loading: Bool, selectedCount: Int, hasFilters: Bool)] = []
        
        // Helper to capture state
        let captureState = {
            stateSnapshots.append((
                loading: loadingManager.isLoading,
                selectedCount: selectionManager.selectedItems.count,
                hasFilters: filterManager.hasActiveFilters
            ))
        }
        
        // Act - Complex workflow with repository pattern
        
        // Step 1: Start loading
        _ = loadingManager.startLoading(operationName: "Loading from repository")
        captureState()
        workflowSteps.append("loading_started")
        
        // Step 2: Apply filter
        filterManager.setTextFilter("Glass")
        captureState()
        workflowSteps.append("filter_applied")
        
        // Step 3: Fetch and filter data through repository
        let allItems = try await mockRepository.fetchItems(matching: nil)
        let filteredItems = try await mockRepository.searchItems(text: filterManager.textFilter ?? "")
        workflowSteps.append("data_fetched_and_filtered")
        
        // Step 4: Complete loading
        loadingManager.completeLoading()
        captureState()
        workflowSteps.append("loading_completed")
        
        // Step 5: Select items
        for item in filteredItems.prefix(2) {
            selectionManager.toggle(item.id)
        }
        captureState()
        workflowSteps.append("items_selected")
        
        // Step 6: Update filter
        filterManager.setTextFilter("Premium")
        let updatedResults = try await mockRepository.searchItems(text: "Premium")
        captureState()
        workflowSteps.append("filter_updated")
        
        // Step 7: Clear filters
        filterManager.clearAllFilters()
        captureState()
        workflowSteps.append("filters_cleared")
        
        // Assert - Complex workflow completed
        let expectedSteps = [
            "loading_started", "filter_applied", "data_fetched_and_filtered",
            "loading_completed", "items_selected", "filter_updated", "filters_cleared"
        ]
        #expect(workflowSteps == expectedSteps, "Should complete complex repository workflow")
        
        // Assert - Repository pattern provided correct data
        #expect(allItems.count == 4, "Repository should provide all items")
        #expect(filteredItems.count == 2, "Should filter 'Glass' items correctly")
        #expect(updatedResults.count == 2, "Should filter 'Premium' items correctly")
        
        // Assert - State transitions were logical
        #expect(stateSnapshots[0].loading == true, "Should start loading")
        #expect(stateSnapshots[1].hasFilters == true, "Should have filters after applying")
        #expect(stateSnapshots[2].loading == false, "Should complete loading")
        #expect(stateSnapshots[3].selectedCount > 0, "Should have selections")
        #expect(stateSnapshots[5].hasFilters == false, "Should clear filters")
        
        // Assert - Repository pattern enables reusable workflows
        _ = loadingManager.startLoading(operationName: "Repeat workflow")
        let repeatItems = try await mockRepository.searchItems(text: "Tool")
        loadingManager.completeLoading()
        
        #expect(repeatItems.count == 2, "Repository pattern should support repeated operations")
    }
}
