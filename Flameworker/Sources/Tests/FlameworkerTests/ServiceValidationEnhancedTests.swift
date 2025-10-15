//  ServiceValidationEnhancedTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/13/25.
//  Enhanced tests for ServiceValidation with complex validation scenarios
//

import Foundation
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

@testable import Flameworker

@Suite("Service Validation Enhanced Tests - Complex Validation Scenarios")
struct ServiceValidationEnhancedTests {
    
    // MARK: - Test Data Helpers
    
    private func createValidCatalogItem() -> CatalogItemModel {
        return CatalogItemModel(
            name: "Valid Glass Rod",
            rawCode: "VGR-001",
            manufacturer: "Valid Corp",
            tags: ["valid", "test", "glass"]
        )
    }
    
    private func createValidInventoryItem() -> InventoryItemModel {
        return InventoryItemModel(
            id: UUID().uuidString,
            catalogCode: "TEST-001",
            quantity: 5.0,
            type: "inventory"
        )
    }
    
    private func createValidPurchaseRecord() -> PurchaseRecordModel {
        return PurchaseRecordModel(
            supplier: "Test Supplier",
            price: 99.99,
            notes: "Test purchase record"
        )
    }
    
    // MARK: - CatalogItem Validation Tests
    

    

    
    // MARK: - Legacy validation tests removed as per tests.md cleanup instructions
    // Tests removed:
    // - testCatalogItemMultipleFieldFailures
    // - testCatalogItemWhitespaceValidation
    // - testCatalogItemEdgeCases
    // - testValidInventoryItemValidation
    // - testInventoryItemCatalogCodeValidation
    // - testInventoryItemQuantityValidation
    // - testInventoryItemQuantityEdgeCases
    // - testInventoryItemTypeValidation
    // - testInventoryItemMultipleFailures
    // - testBatchCatalogItemValidation
    // - testBatchInventoryItemValidation
    
    // MARK: - PurchaseRecord Validation Tests
    
    @Test("Should validate purchase records using model validation")
    func testPurchaseRecordValidation() async throws {
        let validRecord = createValidPurchaseRecord()
        let result = ServiceValidation.validatePurchaseRecord(validRecord)
        
        if validRecord.isValid {
            #expect(result.isValid == true, "Valid purchase record should pass validation")
            #expect(result.errors.isEmpty, "Valid purchase record should have no errors")
        } else {
            #expect(result.isValid == false, "Invalid purchase record should fail validation")
            #expect(!result.errors.isEmpty, "Invalid purchase record should have errors")
        }
    }
    
    @Test("Should handle purchase record validation edge cases")
    func testPurchaseRecordEdgeCases() async throws {
        // Test with minimal valid data
        let minimalRecord = PurchaseRecordModel(
            supplier: "A",
            price: 0.01,
            notes: ""
        )
        
        let minimalResult = ServiceValidation.validatePurchaseRecord(minimalRecord)
        if minimalRecord.isValid {
            #expect(minimalResult.isValid == true, "Minimal valid record should pass")
        }
        
        // Test with complex data
        let complexRecord = PurchaseRecordModel(
            supplier: "Very Long Supplier Name Corp & Associates LLC",
            price: 999999.99,
            notes: String(repeating: "Long notes content. ", count: 50)
        )
        
        let complexResult = ServiceValidation.validatePurchaseRecord(complexRecord)
        if complexRecord.isValid {
            #expect(complexResult.isValid == true, "Complex valid record should pass")
        }
    }
    
    // MARK: - ValidationResult Tests
    
    @Test("Should create validation results correctly")
    func testValidationResultCreation() async throws {
        // Test success result
        let success = ValidationResult.success()
        #expect(success.isValid == true, "Success result should be valid")
        #expect(success.errors.isEmpty, "Success result should have no errors")
        
        // Test failure result with single error
        let singleError = ValidationResult.failure(errors: ["Single error"])
        #expect(singleError.isValid == false, "Failure result should not be valid")
        #expect(singleError.errors.count == 1, "Should have one error")
        #expect(singleError.errors[0] == "Single error", "Should contain the correct error")
        
        // Test failure result with multiple errors
        let multipleErrors = ValidationResult.failure(errors: ["Error 1", "Error 2", "Error 3"])
        #expect(multipleErrors.isValid == false, "Multiple error result should not be valid")
        #expect(multipleErrors.errors.count == 3, "Should have three errors")
        #expect(multipleErrors.errors.contains("Error 1"), "Should contain first error")
        #expect(multipleErrors.errors.contains("Error 2"), "Should contain second error")
        #expect(multipleErrors.errors.contains("Error 3"), "Should contain third error")
        
        // Test custom result
        let customResult = ValidationResult(isValid: false, errors: ["Custom error"])
        #expect(customResult.isValid == false, "Custom result should respect isValid parameter")
        #expect(customResult.errors.count == 1, "Custom result should have one error")
        if !customResult.errors.isEmpty {
            #expect(customResult.errors[0] == "Custom error", "Custom result should contain correct error")
        }
    }
    
    @Test("Should handle empty error arrays")
    func testValidationResultEmptyErrors() async throws {
        // Test failure with empty errors array (edge case)
        let emptyErrorsResult = ValidationResult.failure(errors: [])
        #expect(emptyErrorsResult.isValid == false, "Should be invalid even with empty errors")
        #expect(emptyErrorsResult.errors.isEmpty, "Should have empty errors array")
        
        // Test custom result with valid=true and empty errors
        let validEmptyResult = ValidationResult(isValid: true, errors: [])
        #expect(validEmptyResult.isValid == true, "Should be valid with empty errors")
        #expect(validEmptyResult.errors.isEmpty, "Should have empty errors array")
    }
    

    
    @Test("Should provide meaningful error messages")
    func testValidationErrorMessages() async throws {
        let invalidCatalogItem = CatalogItemModel(
            name: "",
            rawCode: "",
            manufacturer: ""
        )
        
        let result = ServiceValidation.validateCatalogItem(invalidCatalogItem)
        #expect(result.isValid == false, "Should be invalid")
        
        // Check that error messages are meaningful and specific
        for error in result.errors {
            #expect(!error.isEmpty, "Error message should not be empty")
            #expect(error.count > 10, "Error message should be descriptive")
            
            // Should contain context about what failed
            let errorLower = error.lowercased()
            let hasContext = errorLower.contains("name") || 
                           errorLower.contains("code") || 
                           errorLower.contains("manufacturer") ||
                           errorLower.contains("catalog") ||
                           errorLower.contains("quantity")
            #expect(hasContext, "Error message should contain field context: \(error)")
        }
    }
    
    @Test("Should maintain validation consistency across multiple calls")
    func testValidationConsistency() async throws {
        let testItem = CatalogItemModel(
            id: UUID().uuidString,
            id2: UUID(),
            parent_id: UUID(),
            item_type: "rod",
            item_subtype: nil,
            stock_type: nil,
            manufacturer_url: nil,
            image_path: nil,
            image_url: nil,
            name: "", // Empty name to trigger validation failure
            code: "TEST CORP-TEST-001", // Valid code
            manufacturer: "Test Corp", // Valid manufacturer
            tags: [],
            units: 1
        )
        
        // Run validation multiple times
        let results = (1...5).map { _ in
            ServiceValidation.validateCatalogItem(testItem)
        }
        
        // All results should be identical
        let firstResult = results[0]
        for result in results {
            #expect(result.isValid == firstResult.isValid, "Validation results should be consistent")
            #expect(result.errors.count == firstResult.errors.count, "Error count should be consistent")
            #expect(result.errors == firstResult.errors, "Errors should be identical")
        }
    }

}
