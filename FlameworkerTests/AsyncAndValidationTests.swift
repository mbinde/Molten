//
//  AsyncAndValidationTests.swift
//  FlameworkerTests
//
//  Created by Melissa Binde on 10/3/25.
//  Copyright © 2025 Motley Woods. All rights reserved.
//

import Testing
import Foundation
import SwiftUI
import CoreData
import os
@testable import Flameworker

@Suite("Async Operation Error Handling Tests")
struct AsyncOperationErrorHandlingTests {
    
    @Test("Async error handling pattern works correctly")
    func testAsyncErrorHandlingPattern() async {
        // Test the pattern for handling async operations and errors
        
        // Success case
        do {
            let result = try await performAsyncOperation(shouldFail: false)
            #expect(result == "Success", "Should return success value")
        } catch {
            Issue.record("Should not throw for successful operation")
        }
        
        // Failure case
        do {
            let _ = try await performAsyncOperation(shouldFail: true)
            Issue.record("Should throw for failing operation")
        } catch is TestAsyncError {
            // Expected error - test passes
            #expect(Bool(true), "Should catch the expected error type")
        } catch {
            Issue.record("Should catch the specific error type")
        }
    }
    
    @Test("Result type for async operations works correctly")
    func testAsyncResultPattern() async {
        // Test Result type pattern for async operations
        
        let successResult = await safeAsyncOperation(shouldFail: false)
        switch successResult {
        case .success(let value):
            #expect(value == "Success", "Should return success value")
        case .failure:
            Issue.record("Should not fail for valid async operation")
        }
        
        let failureResult = await safeAsyncOperation(shouldFail: true)
        switch failureResult {
        case .success:
            Issue.record("Should not succeed for failing async operation")
        case .failure(let error):
            #expect(error is TestAsyncError, "Should return the thrown error")
        }
    }
    
    // Helper functions for testing
    private func performAsyncOperation(shouldFail: Bool) async throws -> String {
        try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        if shouldFail {
            throw TestAsyncError()
        }
        return "Success"
    }
    
    private func safeAsyncOperation(shouldFail: Bool) async -> Result<String, Error> {
        do {
            let result = try await performAsyncOperation(shouldFail: shouldFail)
            return .success(result)
        } catch {
            return .failure(error)
        }
    }
    
    private struct TestAsyncError: Error {}
}

@Suite("Simple Form Validation Tests")
struct SimpleFormValidationTests {
    
    @Test("Basic validation helper works correctly")
    func testBasicValidationHelper() {
        var successValue: String?
        var errorValue: Flameworker.AppError?
        
        // Simulate a validation helper pattern
        let validation = ValidationUtilities.validateNonEmptyString("Valid", fieldName: "Test")
        
        switch validation {
        case .success(let value):
            successValue = value
        case .failure(let error):
            errorValue = error
        }
        
        #expect(successValue == "Valid", "Should execute success path with correct value")
        #expect(errorValue == nil, "Should not have error on success")
    }
    
    @Test("Error handling helper works correctly") 
    func testErrorHandlingHelper() {
        var successValue: String?
        var errorValue: Flameworker.AppError?
        
        // Simulate a validation helper pattern with error
        let validation = ValidationUtilities.validateNonEmptyString("", fieldName: "Test")
        
        switch validation {
        case .success(let value):
            successValue = value
        case .failure(let error):
            errorValue = error
        }
        
        #expect(successValue == nil, "Should not have success value on error")
        #expect(errorValue != nil, "Should have error value")
        #expect(errorValue?.category == .validation, "Should have correct error category")
    }
}

@Suite("Simple Form Field Logic Tests")
struct SimpleFormFieldLogicTests {
    
    @Test("Basic form field validation state works correctly")
    func testBasicFormFieldValidation() {
        // Test basic form field state logic without requiring specific classes
        
        struct MockFormField {
            var value: String = ""
            var isValid: Bool = true
            var errorMessage: String?
            var hasBeenTouched: Bool = false
            
            mutating func setValue(_ newValue: String) {
                value = newValue
                hasBeenTouched = true
                validateField()
            }
            
            mutating func validateField() {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    isValid = false
                    errorMessage = "Field cannot be empty"
                } else {
                    isValid = true
                    errorMessage = nil
                }
            }
            
            var shouldShowError: Bool {
                return hasBeenTouched && !isValid
            }
        }
        
        var field = MockFormField()
        
        // Test initial state
        #expect(field.isValid == true, "Should start as valid")
        #expect(field.hasBeenTouched == false, "Should start as untouched")
        #expect(field.shouldShowError == false, "Should not show error initially")
        
        // Test setting empty value
        field.setValue("")
        #expect(field.isValid == false, "Should be invalid with empty value")
        #expect(field.hasBeenTouched == true, "Should be touched after setting value")
        #expect(field.shouldShowError == true, "Should show error for empty touched field")
        
        // Test setting valid value
        field.setValue("Valid Value")
        #expect(field.isValid == true, "Should be valid with non-empty value")
        #expect(field.shouldShowError == false, "Should not show error for valid field")
    }
    
    @Test("Numeric field validation works correctly")
    func testNumericFieldValidation() {
        struct MockNumericField {
            var stringValue: String = ""
            var numericValue: Double? = nil
            var isValid: Bool = true
            var errorMessage: String?
            
            mutating func setValue(_ newValue: String) {
                stringValue = newValue
                validateField()
            }
            
            mutating func validateField() {
                let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if trimmed.isEmpty {
                    isValid = false
                    errorMessage = "Value cannot be empty"
                    numericValue = nil
                    return
                }
                
                guard let parsed = Double(trimmed) else {
                    isValid = false
                    errorMessage = "Must be a valid number"
                    numericValue = nil
                    return
                }
                
                if parsed < 0 {
                    isValid = false
                    errorMessage = "Value cannot be negative"
                    numericValue = nil
                    return
                }
                
                isValid = true
                errorMessage = nil
                numericValue = parsed
            }
        }
        
        var field = MockNumericField()
        
        // Test valid number
        field.setValue("25.5")
        #expect(field.isValid == true, "Should be valid for positive number")
        #expect(field.numericValue == 25.5, "Should parse numeric value correctly")
        
        // Test invalid format
        field.setValue("not-a-number")
        #expect(field.isValid == false, "Should be invalid for non-numeric input")
        #expect(field.numericValue == nil, "Should have nil numeric value for invalid input")
        
        // Test negative number
        field.setValue("-10")
        #expect(field.isValid == false, "Should be invalid for negative number")
    }
}

@Suite("Data Model Validation Tests")
struct DataModelValidationTests {
    
    @Test("Enum initialization safety patterns work correctly")
    func testEnumInitializationSafety() {
        // Test the safety patterns used in enum initialization
        
        enum MockEnum: Int, CaseIterable {
            case first = 0
            case second = 1  
            case third = 2
            
            static func from(rawValue: Int) -> MockEnum {
                return MockEnum(rawValue: rawValue) ?? .first
            }
        }
        
        // Test valid values
        #expect(MockEnum.from(rawValue: 0) == .first, "Should return correct enum for valid value")
        #expect(MockEnum.from(rawValue: 1) == .second, "Should return correct enum for valid value")
        #expect(MockEnum.from(rawValue: 2) == .third, "Should return correct enum for valid value")
        
        // Test invalid values fallback
        #expect(MockEnum.from(rawValue: -1) == .first, "Should fallback to first for negative value")
        #expect(MockEnum.from(rawValue: 999) == .first, "Should fallback to first for out-of-range value")
        #expect(MockEnum.from(rawValue: 10) == .first, "Should fallback to first for invalid value")
    }
    
    @Test("Optional string validation patterns work correctly")
    func testOptionalStringValidationPatterns() {
        // Test the patterns used to validate optional strings
        
        func isValidOptionalString(_ value: String?) -> Bool {
            guard let value = value else { return false }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty
        }
        
        #expect(isValidOptionalString("Valid") == true, "Should accept valid string")
        #expect(isValidOptionalString("  Valid  ") == true, "Should accept string with whitespace")
        #expect(isValidOptionalString(nil) == false, "Should reject nil")
        #expect(isValidOptionalString("") == false, "Should reject empty string")
        #expect(isValidOptionalString("   ") == false, "Should reject whitespace-only string")
    }
    
    @Test("Numeric value validation patterns work correctly")
    func testNumericValueValidationPatterns() {
        // Test patterns for validating numeric values
        
        func isValidPositiveDouble(_ value: Double) -> Bool {
            return value > 0 && value.isFinite && !value.isNaN
        }
        
        func isValidNonNegativeDouble(_ value: Double) -> Bool {
            return value >= 0 && value.isFinite && !value.isNaN
        }
        
        // Test positive validation
        #expect(isValidPositiveDouble(5.0) == true, "Should accept positive value")
        #expect(isValidPositiveDouble(0.1) == true, "Should accept small positive value")
        #expect(isValidPositiveDouble(0.0) == false, "Should reject zero")
        #expect(isValidPositiveDouble(-1.0) == false, "Should reject negative value")
        #expect(isValidPositiveDouble(.nan) == false, "Should reject NaN")
        #expect(isValidPositiveDouble(.infinity) == false, "Should reject infinity")
        
        // Test non-negative validation
        #expect(isValidNonNegativeDouble(5.0) == true, "Should accept positive value")
        #expect(isValidNonNegativeDouble(0.0) == true, "Should accept zero")
        #expect(isValidNonNegativeDouble(-1.0) == false, "Should reject negative value")
        #expect(isValidNonNegativeDouble(.nan) == false, "Should reject NaN")
    }
    
    @Test("Collection safety patterns work correctly")
    func testCollectionSafetyPatterns() {
        // Test patterns for safe collection operations
        
        func safeElementAt<T>(_ index: Int, in array: [T]) -> T? {
            guard index >= 0 && index < array.count else { return nil }
            return array[index]
        }
        
        let testArray = ["first", "second", "third"]
        
        #expect(safeElementAt(0, in: testArray) == "first", "Should return element at valid index")
        #expect(safeElementAt(1, in: testArray) == "second", "Should return element at valid index")
        #expect(safeElementAt(2, in: testArray) == "third", "Should return element at valid index")
        #expect(safeElementAt(-1, in: testArray) == nil, "Should return nil for negative index")
        #expect(safeElementAt(3, in: testArray) == nil, "Should return nil for out-of-bounds index")
        #expect(safeElementAt(100, in: testArray) == nil, "Should return nil for way out-of-bounds index")
        
        // Test empty array
        let emptyArray: [String] = []
        #expect(safeElementAt(0, in: emptyArray) == nil, "Should return nil for any index in empty array")
    }
}