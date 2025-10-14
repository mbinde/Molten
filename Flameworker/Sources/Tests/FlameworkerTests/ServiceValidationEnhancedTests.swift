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
            catalogCode: "TEST-001",
            quantity: 5.0,
            type: .inventory
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
    
    @Test("Should validate complete catalog items successfully")
    func testValidCatalogItemValidation() async throws {
        let validItem = createValidCatalogItem()
        let result = ServiceValidation.validateCatalogItem(validItem)
        
        #expect(result.isValid == true, "Valid catalog item should pass validation")
        #expect(result.errors.isEmpty, "Valid catalog item should have no errors")
    }
    
    @Test("Should detect single field validation failures")
    func testCatalogItemSingleFieldFailures() async throws {
        // Test missing name only - need to use full constructor to ensure truly empty name
        let noNameItem = CatalogItemModel(
            id: UUID().uuidString,
            id2: UUID(),
            parent_id: UUID(),
            item_type: "rod",
            item_subtype: nil,
            stock_type: nil,
            manufacturer_url: nil,
            image_path: nil,
            image_url: nil,
            name: "", // Empty name
            code: "VALID-CORP-001", // Valid code
            manufacturer: "Valid Corp", // Valid manufacturer
            tags: [],
            units: 1
        )
        
        let noNameResult = ServiceValidation.validateCatalogItem(noNameItem)
        #expect(noNameResult.isValid == false, "Item with no name should fail validation")
        #expect(noNameResult.errors.count == 1, "Should have exactly one error")
        if !noNameResult.errors.isEmpty {
            #expect(noNameResult.errors[0].contains("name"), "Error should mention name")
        }
        
        // Test missing code only - need to use full constructor to ensure truly empty code
        let noCodeItem = CatalogItemModel(
            id: UUID().uuidString,
            id2: UUID(),
            parent_id: UUID(),
            item_type: "rod",
            item_subtype: nil,
            stock_type: nil,
            manufacturer_url: nil,
            image_path: nil,
            image_url: nil,
            name: "Valid Glass", // Valid name
            code: "", // Empty code
            manufacturer: "Valid Corp", // Valid manufacturer
            tags: [],
            units: 1
        )
        
        let noCodeResult = ServiceValidation.validateCatalogItem(noCodeItem)
        #expect(noCodeResult.isValid == false, "Item with no code should fail validation")
        #expect(noCodeResult.errors.count == 1, "Should have exactly one error")
        if !noCodeResult.errors.isEmpty {
            #expect(noCodeResult.errors[0].contains("code"), "Error should mention code")
        }
        
        // Test missing manufacturer only - need to use full constructor to ensure truly empty manufacturer
        let noManufacturerItem = CatalogItemModel(
            id: UUID().uuidString,
            id2: UUID(),
            parent_id: UUID(),
            item_type: "rod",
            item_subtype: nil,
            stock_type: nil,
            manufacturer_url: nil,
            image_path: nil,
            image_url: nil,
            name: "Valid Glass", // Valid name
            code: "VALID-001", // Valid code
            manufacturer: "", // Empty manufacturer
            tags: [],
            units: 1
        )
        
        let noManufacturerResult = ServiceValidation.validateCatalogItem(noManufacturerItem)
        #expect(noManufacturerResult.isValid == false, "Item with no manufacturer should fail validation")
        #expect(noManufacturerResult.errors.count == 1, "Should have exactly one error")
        if !noManufacturerResult.errors.isEmpty {
            #expect(noManufacturerResult.errors[0].contains("manufacturer"), "Error should mention manufacturer")
        }
    }
    
    @Test("Should detect multiple field validation failures")
    func testCatalogItemMultipleFieldFailures() async throws {
        // Test all fields missing - use full constructor to ensure truly empty fields
        let allMissingItem = CatalogItemModel(
            id: UUID().uuidString,
            id2: UUID(),
            parent_id: UUID(),
            item_type: "rod",
            item_subtype: nil,
            stock_type: nil,
            manufacturer_url: nil,
            image_path: nil,
            image_url: nil,
            name: "", // Empty name
            code: "", // Empty code
            manufacturer: "", // Empty manufacturer
            tags: [],
            units: 1
        )
        
        let allMissingResult = ServiceValidation.validateCatalogItem(allMissingItem)
        #expect(allMissingResult.isValid == false, "Item with all fields missing should fail validation")
        #expect(allMissingResult.errors.count == 3, "Should have three errors")
        
        let errorText = allMissingResult.errors.joined(separator: " ").lowercased()
        #expect(errorText.contains("name"), "Errors should mention name")
        #expect(errorText.contains("code"), "Errors should mention code")
        #expect(errorText.contains("manufacturer"), "Errors should mention manufacturer")
        
        // Test two fields missing - use full constructor
        let twoMissingItem = CatalogItemModel(
            id: UUID().uuidString,
            id2: UUID(),
            parent_id: UUID(),
            item_type: "rod",
            item_subtype: nil,
            stock_type: nil,
            manufacturer_url: nil,
            image_path: nil,
            image_url: nil,
            name: "Valid Glass", // Valid name
            code: "", // Empty code
            manufacturer: "", // Empty manufacturer
            tags: [],
            units: 1
        )
        
        let twoMissingResult = ServiceValidation.validateCatalogItem(twoMissingItem)
        #expect(twoMissingResult.isValid == false, "Item with two fields missing should fail validation")
        #expect(twoMissingResult.errors.count == 2, "Should have exactly two errors")
    }
    
    @Test("Should handle whitespace-only field validation")
    func testCatalogItemWhitespaceValidation() async throws {
        // Test whitespace-only fields - use full constructor
        let whitespaceItem = CatalogItemModel(
            id: UUID().uuidString,
            id2: UUID(),
            parent_id: UUID(),
            item_type: "rod",
            item_subtype: nil,
            stock_type: nil,
            manufacturer_url: nil,
            image_path: nil,
            image_url: nil,
            name: "   \t\n   ", // Whitespace-only name
            code: "  ", // Whitespace-only code
            manufacturer: "\t\t", // Whitespace-only manufacturer
            tags: [],
            units: 1
        )
        
        let whitespaceResult = ServiceValidation.validateCatalogItem(whitespaceItem)
        #expect(whitespaceResult.isValid == false, "Item with whitespace-only fields should fail validation")
        #expect(whitespaceResult.errors.count == 3, "Should detect all three whitespace-only fields")
        
        // Test mixed valid and whitespace fields - use full constructor  
        let mixedItem = CatalogItemModel(
            id: UUID().uuidString,
            id2: UUID(),
            parent_id: UUID(),
            item_type: "rod",
            item_subtype: nil,
            stock_type: nil,
            manufacturer_url: nil,
            image_path: nil,
            image_url: nil,
            name: "Valid Name", // Valid name
            code: "   ", // Whitespace-only code
            manufacturer: "Valid Manufacturer", // Valid manufacturer
            tags: [],
            units: 1
        )
        
        let mixedResult = ServiceValidation.validateCatalogItem(mixedItem)
        #expect(mixedResult.isValid == false, "Item with mixed valid/whitespace fields should fail validation")
        #expect(mixedResult.errors.count == 1, "Should have one error for whitespace code")
        if !mixedResult.errors.isEmpty {
            #expect(mixedResult.errors[0].contains("code"), "Error should mention code field")
        }
    }
    
    @Test("Should handle edge case catalog item values")
    func testCatalogItemEdgeCases() async throws {
        // Test very long field values
        let longName = String(repeating: "Very Long Name ", count: 100)
        let longCode = String(repeating: "CODE", count: 50)
        let longManufacturer = String(repeating: "Manufacturer Corp ", count: 20)
        
        let longItem = CatalogItemModel(
            name: longName,
            rawCode: longCode,
            manufacturer: longManufacturer
        )
        
        let longResult = ServiceValidation.validateCatalogItem(longItem)
        #expect(longResult.isValid == true, "Item with very long fields should still be valid")
        
        // Test single character fields
        let shortItem = CatalogItemModel(
            name: "A",
            rawCode: "B",
            manufacturer: "C"
        )
        
        let shortResult = ServiceValidation.validateCatalogItem(shortItem)
        #expect(shortResult.isValid == true, "Item with single character fields should be valid")
        
        // Test special characters
        let specialItem = CatalogItemModel(
            name: "Glass-Rod (Special) [Test]",
            rawCode: "GR-001/SP",
            manufacturer: "Corp & Co."
        )
        
        let specialResult = ServiceValidation.validateCatalogItem(specialItem)
        #expect(specialResult.isValid == true, "Item with special characters should be valid")
    }
    
    // MARK: - InventoryItem Validation Tests
    
    @Test("Should validate complete inventory items successfully")
    func testValidInventoryItemValidation() async throws {
        let validItem = createValidInventoryItem()
        let result = ServiceValidation.validateInventoryItem(validItem)
        
        #expect(result.isValid == true, "Valid inventory item should pass validation")
        #expect(result.errors.isEmpty, "Valid inventory item should have no errors")
    }
    
    @Test("Should detect inventory item catalog code validation failures")
    func testInventoryItemCatalogCodeValidation() async throws {
        // Test empty catalog code
        let emptyCodeItem = InventoryItemModel(
            catalogCode: "",
            quantity: 5.0,
            type: .inventory
        )
        
        let emptyResult = ServiceValidation.validateInventoryItem(emptyCodeItem)
        #expect(emptyResult.isValid == false, "Item with empty catalog code should fail")
        #expect(emptyResult.errors.count == 1, "Should have one error")
        if !emptyResult.errors.isEmpty {
            #expect(emptyResult.errors[0].contains("Catalog code"), "Error should mention catalog code")
        }
        
        // Test whitespace-only catalog code
        let whitespaceCodeItem = InventoryItemModel(
            catalogCode: "   \t\n   ",
            quantity: 5.0,
            type: .inventory
        )
        
        let whitespaceResult = ServiceValidation.validateInventoryItem(whitespaceCodeItem)
        #expect(whitespaceResult.isValid == false, "Item with whitespace catalog code should fail")
        #expect(whitespaceResult.errors.count == 1, "Should have one error")
    }
    
    @Test("Should detect inventory item quantity validation failures")
    func testInventoryItemQuantityValidation() async throws {
        // Test negative quantity
        let negativeItem = InventoryItemModel(
            catalogCode: "TEST-001",
            quantity: -5.0,
            type: .inventory
        )
        
        let negativeResult = ServiceValidation.validateInventoryItem(negativeItem)
        #expect(negativeResult.isValid == false, "Item with negative quantity should fail")
        #expect(negativeResult.errors.count == 1, "Should have one error")
        if !negativeResult.errors.isEmpty {
            #expect(negativeResult.errors[0].contains("negative"), "Error should mention negative quantity")
        }
        
        // Test very large negative quantity
        let veryNegativeItem = InventoryItemModel(
            catalogCode: "TEST-001",
            quantity: -999999.99,
            type: .inventory
        )
        
        let veryNegativeResult = ServiceValidation.validateInventoryItem(veryNegativeItem)
        #expect(veryNegativeResult.isValid == false, "Item with very large negative quantity should fail")
        
        // Test zero quantity (should be valid)
        let zeroItem = InventoryItemModel(
            catalogCode: "TEST-001",
            quantity: 0.0,
            type: .inventory
        )
        
        let zeroResult = ServiceValidation.validateInventoryItem(zeroItem)
        #expect(zeroResult.isValid == true, "Item with zero quantity should be valid")
    }
    
    @Test("Should handle inventory item edge case quantities")
    func testInventoryItemQuantityEdgeCases() async throws {
        // Test very small positive quantity
        let tinyItem = InventoryItemModel(
            catalogCode: "TEST-001",
            quantity: 0.0001,
            type: .inventory
        )
        
        let tinyResult = ServiceValidation.validateInventoryItem(tinyItem)
        #expect(tinyResult.isValid == true, "Item with tiny positive quantity should be valid")
        
        // Test very large positive quantity
        let largeItem = InventoryItemModel(
            catalogCode: "TEST-001",
            quantity: 999999999.99,
            type: .inventory
        )
        
        let largeResult = ServiceValidation.validateInventoryItem(largeItem)
        #expect(largeResult.isValid == true, "Item with large positive quantity should be valid")
        
        // Test fractional quantities
        let fractionalItem = InventoryItemModel(
            catalogCode: "TEST-001",
            quantity: 3.14159,
            type: .inventory
        )
        
        let fractionalResult = ServiceValidation.validateInventoryItem(fractionalItem)
        #expect(fractionalResult.isValid == true, "Item with fractional quantity should be valid")
    }
    
    @Test("Should validate inventory items with different types")
    func testInventoryItemTypeValidation() async throws {
        let catalogCode = "TEST-TYPE"
        let quantity = 5.0
        let types: [InventoryItemType] = [.inventory, .buy, .sell]
        
        for type in types {
            let item = InventoryItemModel(
                catalogCode: catalogCode,
                quantity: quantity,
                type: type
            )
            
            let result = ServiceValidation.validateInventoryItem(item)
            #expect(result.isValid == true, "Item with type \(type) should be valid")
            #expect(result.errors.isEmpty, "Item with type \(type) should have no errors")
        }
    }
    
    @Test("Should handle multiple inventory item validation failures")
    func testInventoryItemMultipleFailures() async throws {
        // Test both catalog code and quantity failures
        let multipleFailuresItem = InventoryItemModel(
            catalogCode: "",
            quantity: -10.0,
            type: .inventory
        )
        
        let result = ServiceValidation.validateInventoryItem(multipleFailuresItem)
        #expect(result.isValid == false, "Item with multiple failures should fail validation")
        #expect(result.errors.count == 2, "Should have two errors")
        
        let errorText = result.errors.joined(separator: " ").lowercased()
        #expect(errorText.contains("catalog"), "Errors should mention catalog code")
        #expect(errorText.contains("negative"), "Errors should mention negative quantity")
    }
    
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
    
    // MARK: - Complex Validation Scenarios
    
    @Test("Should handle batch validation of catalog items")  
    func testBatchCatalogItemValidation() async throws {
        // Create items that will actually fail validation
        // We need to create items with truly empty processed fields, not empty raw inputs
        
        var items: [CatalogItemModel] = []
        
        // Item 1: Valid item
        items.append(CatalogItemModel(name: "Valid 1", rawCode: "V1", manufacturer: "Corp1"))
        
        // Item 2: Invalid - empty name (using full constructor to force empty name)
        let invalidNameItem = CatalogItemModel(
            id: UUID().uuidString,
            id2: UUID(),
            parent_id: UUID(),
            item_type: "rod",
            item_subtype: nil,
            stock_type: nil,
            manufacturer_url: nil,
            image_path: nil,
            image_url: nil,
            name: "", // Empty name
            code: "CORP2-V2", // Valid code
            manufacturer: "Corp2", // Valid manufacturer
            tags: [],
            units: 1
        )
        items.append(invalidNameItem)
        
        // Item 3: Invalid - empty code (using full constructor to force empty code)
        let invalidCodeItem = CatalogItemModel(
            id: UUID().uuidString,
            id2: UUID(),
            parent_id: UUID(),
            item_type: "rod",
            item_subtype: nil,
            stock_type: nil,
            manufacturer_url: nil,
            image_path: nil,
            image_url: nil,
            name: "Valid 3", // Valid name
            code: "", // Empty code
            manufacturer: "Corp3", // Valid manufacturer
            tags: [],
            units: 1
        )
        items.append(invalidCodeItem)
        
        // Item 4: Invalid - empty manufacturer (using full constructor to force empty manufacturer)
        let invalidManufacturerItem = CatalogItemModel(
            id: UUID().uuidString,
            id2: UUID(),
            parent_id: UUID(),
            item_type: "rod",
            item_subtype: nil,
            stock_type: nil,
            manufacturer_url: nil,
            image_path: nil,
            image_url: nil,
            name: "Valid 4", // Valid name
            code: "CORP4-V4", // Valid code
            manufacturer: "", // Empty manufacturer
            tags: [],
            units: 1
        )
        items.append(invalidManufacturerItem)
        
        // Item 5: Valid item
        items.append(CatalogItemModel(name: "Valid 5", rawCode: "V5", manufacturer: "Corp5"))
        
        var validCount = 0
        var invalidCount = 0
        var totalErrors = 0
        
        for item in items {
            let result = ServiceValidation.validateCatalogItem(item)
            if result.isValid {
                validCount += 1
            } else {
                invalidCount += 1
                totalErrors += result.errors.count
            }
        }
        
        #expect(validCount == 2, "Should have 2 valid items")
        #expect(invalidCount == 3, "Should have 3 invalid items") 
        #expect(totalErrors == 3, "Should have 3 total errors (one per invalid item)")
    }
    
    @Test("Should handle batch validation of inventory items")
    func testBatchInventoryItemValidation() async throws {
        let items = [
            InventoryItemModel(catalogCode: "VALID-1", quantity: 5.0, type: .inventory),
            InventoryItemModel(catalogCode: "", quantity: 3.0, type: .buy),           // Invalid: no catalog code
            InventoryItemModel(catalogCode: "VALID-3", quantity: -2.0, type: .sell), // Invalid: negative quantity
            InventoryItemModel(catalogCode: "", quantity: -1.0, type: .inventory),   // Invalid: both issues
            InventoryItemModel(catalogCode: "VALID-5", quantity: 0.0, type: .buy)    // Valid: zero is allowed
        ]
        
        var validCount = 0
        var invalidCount = 0
        var totalErrors = 0
        
        for item in items {
            let result = ServiceValidation.validateInventoryItem(item)
            if result.isValid {
                validCount += 1
            } else {
                invalidCount += 1
                totalErrors += result.errors.count
            }
        }
        
        #expect(validCount == 2, "Should have 2 valid items")
        #expect(invalidCount == 3, "Should have 3 invalid items")
        #expect(totalErrors == 4, "Should have 4 total errors (item 4 has 2 errors)")
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
    
    // MARK: - Performance Tests
    
    @Test("Should perform validation efficiently")
    func testValidationPerformance() async throws {
        let startTime = Date()
        
        // Run many validations
        for i in 1...1000 {
            let item = CatalogItemModel(
                name: "Item \(i)",
                rawCode: "CODE-\(i)",
                manufacturer: "Corp \(i % 10)"
            )
            let _ = ServiceValidation.validateCatalogItem(item)
        }
        
        let endTime = Date()
        let executionTime = endTime.timeIntervalSince(startTime)
        
        #expect(executionTime < 0.5, "1000 validations should complete within 500ms")
    }
    
}
