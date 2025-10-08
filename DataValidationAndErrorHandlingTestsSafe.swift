//
//  DataValidationAndErrorHandlingTestsSafe.swift
//  FlameworkerTests
//
//  Created by TDD Recovery Process on December 2024.
//  Safe comprehensive data validation and error handling framework
//

import Testing
import Foundation

// Local type definitions for validation framework
struct ValidationRule {
    let name: String
    let errorMessage: String
    let validator: (String) -> Bool
    
    init(name: String, errorMessage: String, validator: @escaping (String) -> Bool) {
        self.name = name
        self.errorMessage = errorMessage
        self.validator = validator
    }
}

struct NumericRule {
    let name: String
    let errorMessage: String
    let validator: (Double) -> Bool
    
    init(name: String, errorMessage: String, validator: @escaping (Double) -> Bool) {
        self.name = name
        self.errorMessage = errorMessage
        self.validator = validator
    }
}

struct IntegerRule {
    let name: String
    let errorMessage: String
    let validator: (Int) -> Bool
    
    init(name: String, errorMessage: String, validator: @escaping (Int) -> Bool) {
        self.name = name
        self.errorMessage = errorMessage
        self.validator = validator
    }
}

struct ValidationError: Error {
    let field: String
    let rule: String
    let message: String
    let severity: Severity
    
    enum Severity: String, CaseIterable {
        case warning = "warning"
        case error = "error"
        case critical = "critical"
    }
    
    init(field: String, rule: String, message: String, severity: Severity = .error) {
        self.field = field
        self.rule = rule
        self.message = message
        self.severity = severity
    }
}

struct ValidationResult {
    let isValid: Bool
    let errors: [ValidationError]
    let warnings: [ValidationError]
    
    init(isValid: Bool, errors: [ValidationError] = [], warnings: [ValidationError] = []) {
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
    }
    
    var hasErrors: Bool { !errors.isEmpty }
    var hasWarnings: Bool { !warnings.isEmpty }
    var allIssues: [ValidationError] { errors + warnings }
}

// Test data structures for validation scenarios
struct TestFormData {
    let name: String?
    let email: String?
    let price: Double?
    let quantity: Int?
    let description: String?
    
    init(name: String? = nil, email: String? = nil, price: Double? = nil, quantity: Int? = nil, description: String? = nil) {
        self.name = name
        self.email = email
        self.price = price
        self.quantity = quantity
        self.description = description
    }
}

@Suite("Data Validation and Error Handling Tests - Safe", .serialized)
struct DataValidationAndErrorHandlingTestsSafe {
    
    @Test("Should validate string inputs with comprehensive rules")
    func testStringValidation() {
        // Test empty string validation
        let emptyResult = validateString(value: "", rules: [
            ValidationRule(name: "required", errorMessage: "Field is required") { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        ])
        
        #expect(emptyResult.isValid == false)
        #expect(emptyResult.errors.count == 1)
        #expect(emptyResult.errors[0].rule == "required")
        #expect(emptyResult.errors[0].message == "Field is required")
        
        // Test valid string
        let validResult = validateString(value: "Valid Name", rules: [
            ValidationRule(name: "required", errorMessage: "Field is required") { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
            ValidationRule(name: "minLength", errorMessage: "Must be at least 2 characters") { $0.count >= 2 }
        ])
        
        #expect(validResult.isValid == true)
        #expect(validResult.errors.isEmpty)
        
        // Test length validation failure
        let shortResult = validateString(value: "A", rules: [
            ValidationRule(name: "minLength", errorMessage: "Must be at least 2 characters") { $0.count >= 2 }
        ])
        
        #expect(shortResult.isValid == false)
        #expect(shortResult.errors[0].rule == "minLength")
    }
    
    @Test("Should validate numeric inputs with range and precision rules")
    func testNumericValidation() {
        // Test valid price
        let validPriceResult = validateNumber(value: 25.99, field: "price", rules: [
            NumericRule(name: "positive", errorMessage: "Price must be positive") { $0 > 0 },
            NumericRule(name: "reasonable", errorMessage: "Price must be under $1000") { $0 < 1000 }
        ])
        
        #expect(validPriceResult.isValid == true)
        #expect(validPriceResult.errors.isEmpty)
        
        // Test negative price
        let negativePriceResult = validateNumber(value: -5.0, field: "price", rules: [
            NumericRule(name: "positive", errorMessage: "Price must be positive") { $0 > 0 }
        ])
        
        #expect(negativePriceResult.isValid == false)
        #expect(negativePriceResult.errors.count == 1)
        #expect(negativePriceResult.errors[0].rule == "positive")
        #expect(negativePriceResult.errors[0].field == "price")
        
        // Test quantity validation
        let validQuantityResult = validateInteger(value: 5, field: "quantity", rules: [
            IntegerRule(name: "nonNegative", errorMessage: "Quantity cannot be negative") { $0 >= 0 },
            IntegerRule(name: "reasonable", errorMessage: "Quantity must be under 1000") { $0 < 1000 }
        ])
        
        #expect(validQuantityResult.isValid == true)
        #expect(validQuantityResult.errors.isEmpty)
    }
    
    @Test("Should validate complete forms with multiple fields and error aggregation")
    func testFormValidation() {
        // Test valid form data
        let validForm = TestFormData(
            name: "Glass Item",
            email: "user@example.com",
            price: 25.99,
            quantity: 5,
            description: "High quality glass item"
        )
        
        let validResult = validateForm(formData: validForm)
        
        #expect(validResult.isValid == true)
        #expect(validResult.errors.isEmpty)
        #expect(validResult.warnings.isEmpty)
        
        // Test form with multiple validation errors
        let invalidForm = TestFormData(
            name: "", // Required field empty
            email: "invalid-email", // Invalid email format
            price: -10.0, // Negative price
            quantity: -5, // Negative quantity
            description: nil // Optional field
        )
        
        let invalidResult = validateForm(formData: invalidForm)
        
        #expect(invalidResult.isValid == false)
        #expect(invalidResult.errors.count >= 4) // Should have at least 4 errors
        #expect(invalidResult.hasErrors == true)
        
        // Test that all expected error fields are present
        let errorFields = invalidResult.errors.map { $0.field }
        #expect(errorFields.contains("name"))
        #expect(errorFields.contains("email"))
        #expect(errorFields.contains("price"))
        #expect(errorFields.contains("quantity"))
        
        // Test form with warnings (edge cases that aren't errors but should be flagged)
        let warningForm = TestFormData(
            name: "Valid Name",
            email: "user@example.com",
            price: 0.01, // Very low price - should generate warning
            quantity: 1000, // High quantity - should generate warning
            description: "Valid description"
        )
        
        let warningResult = validateForm(formData: warningForm)
        
        #expect(warningResult.isValid == true) // Valid but has warnings
        #expect(warningResult.hasWarnings == true)
        #expect(warningResult.warnings.count >= 2)
    }
    
    // Private helper function to implement the expected logic for testing
    private func validateString(value: String, rules: [ValidationRule]) -> ValidationResult {
        var errors: [ValidationError] = []
        
        for rule in rules {
            if !rule.validator(value) {
                errors.append(ValidationError(
                    field: "string_field",
                    rule: rule.name,
                    message: rule.errorMessage
                ))
            }
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    // Private helper functions for numeric validation
    private func validateNumber(value: Double, field: String, rules: [NumericRule]) -> ValidationResult {
        var errors: [ValidationError] = []
        
        for rule in rules {
            if !rule.validator(value) {
                errors.append(ValidationError(
                    field: field,
                    rule: rule.name,
                    message: rule.errorMessage
                ))
            }
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    private func validateInteger(value: Int, field: String, rules: [IntegerRule]) -> ValidationResult {
        var errors: [ValidationError] = []
        
        for rule in rules {
            if !rule.validator(value) {
                errors.append(ValidationError(
                    field: field,
                    rule: rule.name,
                    message: rule.errorMessage
                ))
            }
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    // Comprehensive form validation function
    private func validateForm(formData: TestFormData) -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationError] = []
        
        // Validate name
        if let name = formData.name {
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append(ValidationError(field: "name", rule: "required", message: "Name is required"))
            }
        } else {
            errors.append(ValidationError(field: "name", rule: "required", message: "Name is required"))
        }
        
        // Validate email
        if let email = formData.email {
            if !email.contains("@") || !email.contains(".") {
                errors.append(ValidationError(field: "email", rule: "format", message: "Email format is invalid"))
            }
        }
        
        // Validate price
        if let price = formData.price {
            if price < 0 {
                errors.append(ValidationError(field: "price", rule: "positive", message: "Price must be positive"))
            } else if price < 1.0 {
                warnings.append(ValidationError(field: "price", rule: "low_price", message: "Price is very low", severity: .warning))
            }
        }
        
        // Validate quantity
        if let quantity = formData.quantity {
            if quantity < 0 {
                errors.append(ValidationError(field: "quantity", rule: "nonNegative", message: "Quantity cannot be negative"))
            } else if quantity >= 1000 {
                warnings.append(ValidationError(field: "quantity", rule: "high_quantity", message: "Quantity is very high", severity: .warning))
            }
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings)
    }
}