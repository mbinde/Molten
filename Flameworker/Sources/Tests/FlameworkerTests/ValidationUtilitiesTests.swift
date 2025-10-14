//
//  ValidationUtilitiesTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/9/25.
//

import Foundation
@testable import Flameworker

// Standard test framework imports pattern - use in all test files
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

#if canImport(Testing)

@Suite("ValidationUtilities Tests")
struct ValidationUtilitiesTests {
    
    @Test("validateNonEmptyString should return success for valid strings")
    func testValidateNonEmptyStringSuccess() throws {
        // Act
        let result = ValidationUtilities.validateNonEmptyString("Valid Input", fieldName: "Test Field")
        
        // Assert
        switch result {
        case .success(let value):
            #expect(value == "Valid Input", "Should return the trimmed input value")
        case .failure:
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Expected success but got failure"])
        }
    }
    
    @Test("validateNonEmptyString should trim whitespace and return success")
    func testValidateNonEmptyStringTrimsWhitespace() throws {
        // Act
        let result = ValidationUtilities.validateNonEmptyString("  Trimmed Value  ", fieldName: "Test Field")
        
        // Assert
        switch result {
        case .success(let value):
            #expect(value == "Trimmed Value", "Should return trimmed value without leading/trailing spaces")
        case .failure:
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Expected success but got failure"])
        }
    }
    
    @Test("validateNonEmptyString should return failure for empty strings")
    func testValidateNonEmptyStringFailureEmpty() throws {
        // Act
        let result = ValidationUtilities.validateNonEmptyString("", fieldName: "Test Field")
        
        // Assert
        switch result {
        case .success:
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Expected failure but got success"])
        case .failure(let error):
            let appError = error as? AppError
            #expect(appError != nil, "Should return AppError")
            #expect(appError?.category == .validation, "Should be validation error")
            #expect(appError?.severity == .warning, "Should be warning severity")
            #expect(appError?.userMessage.contains("cannot be empty") == true, "Should contain empty error message")
        }
    }
    
    @Test("validateNonEmptyString should return failure for whitespace-only strings")
    func testValidateNonEmptyStringFailureWhitespace() throws {
        // Act
        let result = ValidationUtilities.validateNonEmptyString("   \n\t   ", fieldName: "Test Field")
        
        // Assert
        switch result {
        case .success:
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Expected failure but got success"])
        case .failure(let error):
            let appError = error as? AppError
            #expect(appError != nil, "Should return AppError")
            #expect(appError?.userMessage.contains("Test Field") == true, "Should include field name in error message")
            #expect(appError?.suggestions.isEmpty == false, "Should provide suggestions")
        }
    }
    
    @Test("validateMinimumLength should return success for strings meeting minimum length")
    func testValidateMinimumLengthSuccess() throws {
        // Act
        let result = ValidationUtilities.validateMinimumLength("ValidLength", minLength: 5, fieldName: "Product Name")
        
        // Assert
        switch result {
        case .success(let value):
            #expect(value == "ValidLength", "Should return the trimmed input value")
        case .failure:
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Expected success but got failure"])
        }
    }
    
    @Test("validateMinimumLength should return failure for strings too short")
    func testValidateMinimumLengthFailure() throws {
        // Act
        let result = ValidationUtilities.validateMinimumLength("Hi", minLength: 5, fieldName: "Product Name")
        
        // Assert
        switch result {
        case .success:
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Expected failure but got success"])
        case .failure(let error):
            let appError = error as? AppError
            #expect(appError != nil, "Should return AppError")
            #expect(appError?.userMessage.contains("at least 5 characters") == true, "Should include minimum length in error message")
            #expect(appError?.userMessage.contains("Product Name") == true, "Should include field name in error message")
        }
    }
    
    @Test("validateDouble should return success for valid numbers")
    func testValidateDoubleSuccess() throws {
        // Act
        let result = ValidationUtilities.validateDouble("25.50", fieldName: "Price")
        
        // Assert
        switch result {
        case .success(let value):
            #expect(value == 25.50, "Should return correct double value")
        case .failure:
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Expected success but got failure"])
        }
    }
    
    @Test("validateDouble should return failure for invalid numbers")
    func testValidateDoubleFailure() throws {
        // Act
        let result = ValidationUtilities.validateDouble("not_a_number", fieldName: "Price")
        
        // Assert
        switch result {
        case .success:
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Expected failure but got success"])
        case .failure(let error):
            let appError = error as? AppError
            #expect(appError != nil, "Should return AppError")
            #expect(appError?.userMessage.contains("valid number") == true, "Should mention valid number in error message")
            #expect(appError?.suggestions.contains("Use only numbers and decimal point") == true, "Should provide helpful suggestions")
        }
    }
    
    @Test("validatePositiveDouble should return success for positive numbers")
    func testValidatePositiveDoubleSuccess() throws {
        // Act
        let result = ValidationUtilities.validatePositiveDouble("99.99", fieldName: "Amount")
        
        // Assert
        switch result {
        case .success(let value):
            #expect(value == 99.99, "Should return correct positive double value")
        case .failure:
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Expected success but got failure"])
        }
    }
    
    @Test("validatePositiveDouble should return failure for zero and negative numbers")
    func testValidatePositiveDoubleFailure() throws {
        // Test zero
        let zeroResult = ValidationUtilities.validatePositiveDouble("0", fieldName: "Amount")
        switch zeroResult {
        case .success:
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Expected failure for zero but got success"])
        case .failure(let error):
            let appError = error as? AppError
            #expect(appError?.userMessage.contains("greater than zero") == true, "Should mention greater than zero requirement")
        }
        
        // Test negative
        let negativeResult = ValidationUtilities.validatePositiveDouble("-5.50", fieldName: "Amount")
        switch negativeResult {
        case .success:
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Expected failure for negative but got success"])
        case .failure(let error):
            let appError = error as? AppError
            #expect(appError?.userMessage.contains("greater than zero") == true, "Should mention greater than zero requirement")
        }
    }
    
    @Test("validateSupplierName should return success for valid supplier names")
    func testValidateSupplierNameSuccess() throws {
        // Act
        let result = ValidationUtilities.validateSupplierName("ACME Glass Co")
        
        // Assert
        switch result {
        case .success(let value):
            #expect(value == "ACME Glass Co", "Should return the validated supplier name")
        case .failure:
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Expected success but got failure"])
        }
    }
    
    @Test("validateSupplierName should return failure for names too short")
    func testValidateSupplierNameFailure() throws {
        // Act
        let result = ValidationUtilities.validateSupplierName("A")
        
        // Assert
        switch result {
        case .success:
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Expected failure but got success"])
        case .failure(let error):
            let appError = error as? AppError
            #expect(appError != nil, "Should return AppError")
            #expect(appError?.userMessage.contains("Supplier name") == true, "Should include 'Supplier name' in error message")
            #expect(appError?.userMessage.contains("at least 2 characters") == true, "Should mention 2 character minimum")
        }
    }
    
    @Test("validatePurchaseAmount should return success for valid amounts")
    func testValidatePurchaseAmountSuccess() throws {
        // Act
        let result = ValidationUtilities.validatePurchaseAmount("150.75")
        
        // Assert
        switch result {
        case .success(let value):
            #expect(value == 150.75, "Should return the validated purchase amount")
        case .failure:
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Expected success but got failure"])
        }
    }
    
    @Test("validatePurchaseAmount should return failure for invalid amounts")
    func testValidatePurchaseAmountFailure() throws {
        // Test invalid string
        let invalidResult = ValidationUtilities.validatePurchaseAmount("invalid_amount")
        switch invalidResult {
        case .success:
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Expected failure for invalid string but got success"])
        case .failure(let error):
            let appError = error as? AppError
            #expect(appError?.userMessage.contains("Purchase amount") == true, "Should include 'Purchase amount' in error message")
        }
        
        // Test zero amount
        let zeroResult = ValidationUtilities.validatePurchaseAmount("0")
        switch zeroResult {
        case .success:
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Expected failure for zero amount but got success"])
        case .failure(let error):
            let appError = error as? AppError
            #expect(appError?.userMessage.contains("greater than zero") == true, "Should mention greater than zero requirement")
        }
    }
}

#endif
