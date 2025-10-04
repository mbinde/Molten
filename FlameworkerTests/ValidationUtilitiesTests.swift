//  ValidationUtilitiesTests.swift
//  FlameworkerTests
//
//  Extracted from FlameworkerTests.swift on 10/3/25.
//  Copyright © 2025 Motley Woods. All rights reserved.
//

import Testing
import Foundation
@testable import Flameworker

@Suite("ValidationUtilities Tests")
struct ValidationUtilitiesTests {
    
    @Test("Validate supplier name succeeds with valid input")
    func testValidateSupplierNameSuccess() {
        let result = ValidationUtilities.validateSupplierName("Valid Supplier")
        
        switch result {
        case .success(let value):
            #expect(value == "Valid Supplier", "Should return trimmed string")
        case .failure:
            Issue.record("Should succeed with valid input")
        }
    }
    
    @Test("Validate supplier name trims whitespace")
    func testValidateSupplierNameTrimsWhitespace() {
        let result = ValidationUtilities.validateSupplierName("  Glass Co  ")
        
        switch result {
        case .success(let value):
            #expect(value == "Glass Co", "Should return trimmed string")
        case .failure:
            Issue.record("Should succeed with whitespace input")
        }
    }
    
    @Test("Validate supplier name fails with empty input")
    func testValidateSupplierNameFailsWithEmpty() {
        let result = ValidationUtilities.validateSupplierName("")
        
        switch result {
        case .success:
            Issue.record("Should fail with empty input")
        case .failure(let error):
            #expect(error.category == .validation, "Should be validation error")
            #expect(error.userMessage.contains("Supplier name"), "Should mention field name")
        }
    }
    
    @Test("Validate supplier name fails with short input")
    func testValidateSupplierNameFailsWithShortInput() {
        let result = ValidationUtilities.validateSupplierName("A")
        
        switch result {
        case .success:
            Issue.record("Should fail with short input")
        case .failure(let error):
            #expect(error.category == .validation, "Should be validation error")
            #expect(error.userMessage.contains("2 characters"), "Should mention minimum length")
        }
    }
    
    @Test("Validate purchase amount succeeds with valid input")
    func testValidatePurchaseAmountSuccess() {
        let result = ValidationUtilities.validatePurchaseAmount("123.45")
        
        switch result {
        case .success(let value):
            #expect(value == 123.45, "Should return parsed double")
        case .failure:
            Issue.record("Should succeed with valid input")
        }
    }
    
    @Test("Validate purchase amount fails with zero")
    func testValidatePurchaseAmountFailsWithZero() {
        let result = ValidationUtilities.validatePurchaseAmount("0")
        
        switch result {
        case .success:
            Issue.record("Should fail with zero input")
        case .failure(let error):
            #expect(error.category == .validation, "Should be validation error")
            #expect(error.userMessage.contains("greater than zero"), "Should mention positive requirement")
        }
    }
    
    @Test("Validate purchase amount fails with negative input")
    func testValidatePurchaseAmountFailsWithNegative() {
        let result = ValidationUtilities.validatePurchaseAmount("-10.50")
        
        switch result {
        case .success:
            Issue.record("Should fail with negative input")
        case .failure(let error):
            #expect(error.category == .validation, "Should be validation error")
        }
    }
}

@Suite("Advanced ValidationUtilities Tests")
struct AdvancedValidationUtilitiesTests {
    
    @Test("ValidationUtilities methods exist and work correctly")
    func testValidationMethodsExist() {
        // Test that the core validation methods exist and work directly
        
        // Test validateNonEmptyString
        let nonEmptyResult = ValidationUtilities.validateNonEmptyString("test", fieldName: "Test Field")
        switch nonEmptyResult {
        case .success(let value):
            #expect(value == "test", "Should return the input")
        case .failure:
            Issue.record("Should succeed with valid input")
        }
        
        // Test validateMinimumLength
        let minLengthResult = ValidationUtilities.validateMinimumLength("test", minLength: 3, fieldName: "Test Field")
        switch minLengthResult {
        case .success(let value):
            #expect(value == "test", "Should return the input")
        case .failure:
            Issue.record("Should succeed with valid input meeting minimum length")
        }
    }
    
    @Test("Error message formatting includes expected content")
    func testErrorMessageFormatting() {
        // Test that error messages contain expected content using the main public methods
        let result = ValidationUtilities.validateSupplierName("")
        
        switch result {
        case .success:
            Issue.record("Should fail with empty input")
        case .failure(let error):
            #expect(error.userMessage.contains("Supplier name"), "Should contain field name")
            #expect(error.category == .validation, "Should be validation category")
            #expect(error.severity == .warning, "Should be warning severity for validation")
            #expect(!error.suggestions.isEmpty, "Should have suggestions")
        }
    }
    
    @Test("Purchase amount validation edge cases")
    func testPurchaseAmountEdgeCases() {
        // Test various edge cases for purchase amount validation
        
        // Test with whitespace
        let whitespaceResult = ValidationUtilities.validatePurchaseAmount("  123.45  ")
        switch whitespaceResult {
        case .success(let value):
            #expect(value == 123.45, "Should parse amount correctly after trimming whitespace")
        case .failure:
            Issue.record("Should succeed with whitespace around valid number")
        }
        
        // Test with invalid format
        let invalidResult = ValidationUtilities.validatePurchaseAmount("not-a-number")
        switch invalidResult {
        case .success:
            Issue.record("Should fail with non-numeric input")
        case .failure(let error):
            #expect(error.category == .validation, "Should be validation error")
            #expect(error.userMessage.contains("valid number"), "Should mention number format")
        }
    }
}