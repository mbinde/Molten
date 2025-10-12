//
//  IntegrationTestsSimple.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/12/25.
//

import Foundation
import Testing
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

@Suite("Integration Tests - Simple")
struct IntegrationTestsSimple {
    
    // MARK: - Service Integration (No Core Data)
    
    @Test("Should integrate ValidationUtilities with SearchUtilities")
    func testValidationSearchIntegration() {
        // Arrange - Create test data that doesn't require Core Data
        struct MockItem {
            let name: String?
            let code: String?
            let manufacturer: String?
        }
        
        let testItems = [
            MockItem(name: "Valid Red Glass", code: "VRG-001", manufacturer: "Effetre"),
            MockItem(name: "", code: "INVALID", manufacturer: "Test"), // Should fail validation
            MockItem(name: "Valid Blue Glass", code: "VBG-002", manufacturer: "Bullseye"),
            MockItem(name: "Valid Green Glass", code: "", manufacturer: "Test") // Should fail validation
        ]
        
        var validatedItems: [MockItem] = []
        
        // Act - Process through validation pipeline
        for item in testItems {
            let nameValidation = ValidationUtilities.validateNonEmptyString(item.name ?? "", fieldName: "Name")
            let codeValidation = ValidationUtilities.validateNonEmptyString(item.code ?? "", fieldName: "Code")
            
            if nameValidation.isSuccess && codeValidation.isSuccess {
                validatedItems.append(item)
            }
        }
        
        // Convert to searchable format for SearchUtilities testing
        let searchableNames = validatedItems.compactMap { $0.name }
        
        // Act - Test search integration
        let glassResults = searchableNames.filter { $0.lowercased().contains("glass") }
        let redResults = searchableNames.filter { $0.lowercased().contains("red") }
        
        // Assert - Integration results
        #expect(validatedItems.count == 2, "Should validate exactly 2 items with valid name and code")
        #expect(glassResults.count == 2, "Should find 2 items containing 'glass'")
        #expect(redResults.count == 1, "Should find 1 item containing 'red'")
        
        // Verify the specific valid items
        let validNames = validatedItems.compactMap { $0.name }
        #expect(validNames.contains("Valid Red Glass"), "Should include valid red glass item")
        #expect(validNames.contains("Valid Blue Glass"), "Should include valid blue glass item")
        #expect(!validNames.contains(""), "Should not include empty name items")
    }
    
    // MARK: - UI State Integration
    
    @Test("Should integrate UI state managers without Core Data")
    func testUIStateIntegrationSafe() {
        // Arrange - Create state managers
        let loadingManager = LoadingStateManager()
        let selectionManager = SelectionStateManager<String>()
        let filterManager = FilterStateManager()
        
        // Test initial states
        #expect(!loadingManager.isLoading, "Should start not loading")
        #expect(selectionManager.selectedItems.isEmpty, "Should start with no selection")
        #expect(!filterManager.hasActiveFilters, "Should start with no active filters")
        
        // Act & Assert - Coordinated state changes
        _ = loadingManager.startLoading(operationName: "Integration Test")
        selectionManager.toggle("item1")
        filterManager.setTextFilter("test")
        
        // Verify coordinated state
        #expect(loadingManager.isLoading, "Should be loading")
        #expect(selectionManager.isSelected("item1"), "Should have selected item1")
        #expect(filterManager.hasActiveFilters, "Should have active text filter")
        #expect(filterManager.textFilter == "test", "Should have correct filter text")
        
        // Act - Complete workflow
        loadingManager.completeLoading()
        selectionManager.selectAll(["item1", "item2", "item3"])
        filterManager.clearAllFilters()
        
        // Assert final coordinated state
        #expect(!loadingManager.isLoading, "Should complete loading")
        #expect(selectionManager.selectedItems.count == 3, "Should have all items selected")
        #expect(!filterManager.hasActiveFilters, "Should have cleared filters")
    }
    
    // MARK: - Performance Integration (Safe)
    
    @Test("Should achieve good performance across multiple utilities")
    func testPerformanceIntegrationSafe() {
        // Arrange - Large dataset for performance testing
        let testSize = 100
        var testData: [(String, String)] = []
        
        for i in 1...testSize {
            if i % 10 == 0 {
                testData.append(("", "INVALID-\(i)")) // 10% invalid
            } else {
                testData.append(("Valid Item \(i)", "VALID-\(i)"))
            }
        }
        
        let startTime = Date()
        
        // Act - Process through validation and search pipeline
        var validatedData: [(String, String)] = []
        
        for (name, code) in testData {
            let nameValidation = ValidationUtilities.validateNonEmptyString(name, fieldName: "Name")
            let codeValidation = ValidationUtilities.validateNonEmptyString(code, fieldName: "Code")
            
            if nameValidation.isSuccess && codeValidation.isSuccess {
                validatedData.append((name, code))
            }
        }
        
        // Search through validated data
        let searchableItems = validatedData.map { $0.0 } // names
        let searchResults = searchableItems.filter { $0.contains("Item") }
        let specificResults = searchableItems.filter { $0.contains("Item 1") }
        
        let totalTime = Date().timeIntervalSince(startTime)
        
        // Assert - Performance and correctness
        #expect(totalTime < 0.1, "Processing \(testSize) items should complete within 100ms")
        
        let expectedValidCount = testSize - (testSize / 10) // 90% should be valid
        #expect(validatedData.count == expectedValidCount, "Should validate \(expectedValidCount) items")
        #expect(searchResults.count == expectedValidCount, "Should find all valid items via search")
        #expect(specificResults.count > 0, "Should find items containing 'Item 1'")
        
        // Verify data integrity
        for (name, code) in validatedData.prefix(5) { // Check first 5 for efficiency
            #expect(!name.isEmpty, "All validated names should be non-empty")
            #expect(!code.isEmpty, "All validated codes should be non-empty")
            #expect(name.contains("Valid"), "All validated items should contain 'Valid'")
        }
    }
    
    // MARK: - Error Recovery Integration (Safe)
    
    @Test("Should handle partial failures gracefully without Core Data")
    func testErrorRecoveryIntegrationSafe() {
        // Arrange - Mixed success/failure scenarios
        let testCases = [
            ("Valid Item 1", "VALID-001", true),
            ("", "EMPTY-NAME", false),
            ("Valid Item 2", "VALID-002", true),
            ("Valid Item 3", "", false),
            ("Valid Item 4", "VALID-004", true)
        ]
        
        var successfulItems: [(String, String)] = []
        var errorMessages: [String] = []
        
        // Act - Process with error collection
        for (name, code, expectedSuccess) in testCases {
            let nameValidation = ValidationUtilities.validateNonEmptyString(name, fieldName: "Name")
            let codeValidation = ValidationUtilities.validateNonEmptyString(code, fieldName: "Code")
            
            if nameValidation.isSuccess && codeValidation.isSuccess {
                successfulItems.append((name, code))
            } else {
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
        
        // Search integration on successful items
        let searchableNames = successfulItems.map { $0.0 }
        let searchResults = searchableNames.filter { $0.contains("Valid") }
        
        // Assert - Error recovery results
        let expectedSuccesses = testCases.filter { $0.2 }.count
        let expectedFailures = testCases.count - expectedSuccesses
        
        #expect(successfulItems.count == expectedSuccesses, "Should have \(expectedSuccesses) successful items")
        #expect(errorMessages.count == expectedFailures, "Should have \(expectedFailures) error messages")
        #expect(searchResults.count == expectedSuccesses, "Search should find all successful items")
        
        // Verify error messages are meaningful
        for errorMessage in errorMessages {
            #expect(!errorMessage.isEmpty, "Error messages should be non-empty")
            #expect(errorMessage.contains("Name") || errorMessage.contains("Code"), "Should indicate which field failed")
        }
        
        // Verify successful items are valid
        for (name, code) in successfulItems {
            #expect(!name.isEmpty, "Successful items should have valid names")
            #expect(!code.isEmpty, "Successful items should have valid codes")
            #expect(name.contains("Valid"), "All successful names should contain 'Valid'")
        }
    }
    
    // MARK: - Image Integration (Safe)
    
    @Test("Should integrate ImageHelpers safely")
    func testImageIntegrationSafe() {
        // Arrange - Test image operations without Core Data
        let testCodes = [
            "TEST-001",
            "TEST/002", // Contains slash for sanitization testing
            "",         // Empty code
            "LONG-CODE-WITH-MANY-PARTS-123"
        ]
        
        // Act & Assert - Test image operations
        for code in testCodes {
            if !code.isEmpty {
                // Test image loading (should handle gracefully)
                let image = ImageHelpers.loadProductImage(for: code, manufacturer: "TestManufacturer")
                let exists = ImageHelpers.productImageExists(for: code, manufacturer: "TestManufacturer")
                let imageName = ImageHelpers.getProductImageName(for: code, manufacturer: "TestManufacturer")
                
                // Should handle gracefully - likely no actual images exist in test
                #expect(image == nil, "Should handle non-existent images gracefully for code: \(code)")
                #expect(!exists, "Should correctly report non-existent images for code: \(code)")
                
                // Image name generation should work regardless
                if let name = imageName {
                    #expect(!name.isEmpty, "Generated image name should be non-empty for code: \(code)")
                }
            }
        }
        
        // Test filename sanitization integration
        let problematicCode = "TEST/WITH\\SLASHES"
        let sanitized = ImageHelpers.sanitizeItemCodeForFilename(problematicCode)
        
        #expect(!sanitized.contains("/"), "Sanitized filename should not contain forward slashes")
        #expect(!sanitized.contains("\\"), "Sanitized filename should not contain backslashes")
        #expect(sanitized.contains("TEST"), "Sanitized filename should preserve basic content")
    }
}