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
    
    @Test("Validate non-empty string succeeds with valid input")
    func testValidateNonEmptyStringSuccess() {
        let result = ValidationUtilities.validateNonEmptyString("Valid String", fieldName: "Test Field")
        
        switch result {
        case .success(let value):
            #expect(value == "Valid String", "Should return trimmed string")
        case .failure:
            Issue.record("Should succeed with valid input")
        }
    }
    
    @Test("Validate non-empty string trims whitespace")
    func testValidateNonEmptyStringTrimsWhitespace() {
        let result = ValidationUtilities.validateNonEmptyString("  Trimmed  ", fieldName: "Test Field")
        
        switch result {
        case .success(let value):
            #expect(value == "Trimmed", "Should return trimmed string")
        case .failure:
            Issue.record("Should succeed with whitespace input")
        }
    }
    
    @Test("Validate non-empty string fails with empty input")
    func testValidateNonEmptyStringFailsWithEmpty() {
        let result = ValidationUtilities.validateNonEmptyString("", fieldName: "Test Field")
        
        switch result {
        case .success:
            Issue.record("Should fail with empty input")
        case .failure(let error):
            #expect(error.category == .validation, "Should be validation error")
            #expect(error.userMessage.contains("Test Field"), "Should mention field name")
        }
    }
    
    @Test("Validate non-empty string fails with whitespace-only input")
    func testValidateNonEmptyStringFailsWithWhitespace() {
        let result = ValidationUtilities.validateNonEmptyString("   ", fieldName: "Test Field")
        
        switch result {
        case .success:
            Issue.record("Should fail with whitespace-only input")
        case .failure(let error):
            #expect(error.category == .validation, "Should be validation error")
        }
    }
    
    @Test("Validate minimum length succeeds with valid input")
    func testValidateMinimumLengthSuccess() {
        let result = ValidationUtilities.validateMinimumLength("Valid", minLength: 3, fieldName: "Test Field")
        
        switch result {
        case .success(let value):
            #expect(value == "Valid", "Should return valid string")
        case .failure:
            Issue.record("Should succeed with valid input")
        }
    }
    
    @Test("Validate minimum length fails with short input")
    func testValidateMinimumLengthFailsWithShortInput() {
        let result = ValidationUtilities.validateMinimumLength("Hi", minLength: 5, fieldName: "Test Field")
        
        switch result {
        case .success:
            Issue.record("Should fail with short input")
        case .failure(let error):
            #expect(error.category == .validation, "Should be validation error")
            #expect(error.userMessage.contains("5 characters"), "Should mention required length")
        }
    }
}

@Suite("Advanced ValidationUtilities Tests")
struct AdvancedValidationUtilitiesTests {
    
    @Test("String validation edge cases work correctly")
    func testStringValidationEdgeCases() {
        // Test various edge cases for string validation
        
        // Test with only whitespace
        let whitespaceResult = ValidationUtilities.validateNonEmptyString("   \t\n   ", fieldName: "Test Field")
        switch whitespaceResult {
        case .success:
            Issue.record("Should fail with whitespace-only input")
        case .failure(let error):
            #expect(error.category == .validation, "Should be validation error")
        }
        
        // Test minimum length with exact boundary
        let exactLengthResult = ValidationUtilities.validateMinimumLength("ABC", minLength: 3, fieldName: "Test Field")
        switch exactLengthResult {
        case .success(let value):
            #expect(value == "ABC", "Should succeed with exact minimum length")
        case .failure:
            Issue.record("Should succeed with exact minimum length")
        }
        
        // Test minimum length with one character short
        let shortResult = ValidationUtilities.validateMinimumLength("AB", minLength: 3, fieldName: "Test Field")
        switch shortResult {
        case .success:
            Issue.record("Should fail when one character short")
        case .failure(let error):
            #expect(error.category == .validation, "Should be validation error")
        }
    }
    
    @Test("Error message formatting works correctly")
    func testErrorMessageFormatting() {
        // Test that error messages contain expected content
        let result = ValidationUtilities.validateNonEmptyString("", fieldName: "User Name")
        
        switch result {
        case .success:
            Issue.record("Should fail with empty input")
        case .failure(let error):
            #expect(error.userMessage.contains("User Name"), "Should contain field name")
            #expect(error.category == .validation, "Should be validation category")
            #expect(error.severity == .warning, "Should be warning severity for validation")
            #expect(!error.suggestions.isEmpty, "Should have suggestions")
        }
    }
}