//
//  ValidationUtilities.swift
//  Flameworker
//
//  Created by Assistant on 10/3/25.
//

import Foundation

/// Simple utilities for validating user input in forms
struct ValidationUtilities {
    
    /// Validates supplier name input
    static func validateSupplierName(_ input: String) -> Result<String, AppError> {
        return validateMinimumLength(input, minLength: 2, fieldName: "Supplier name")
    }
    
    /// Validates purchase amount input and converts to Double
    static func validatePurchaseAmount(_ input: String) -> Result<Double, AppError> {
        return validatePositiveDouble(input, fieldName: "Purchase amount")
    }
    
    /// Safely trim and validate string is not empty
    static func validateNonEmptyString(_ value: String, fieldName: String = "Field") -> Result<String, AppError> {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            return .failure(AppError(
                category: .validation,
                severity: .warning,
                userMessage: "\(fieldName) cannot be empty",
                suggestions: ["Enter a value for \(fieldName.lowercased())", "Remove extra spaces"]
            ))
        }
        
        return .success(trimmed)
    }
    
    /// Validate string has minimum length
    static func validateMinimumLength(_ value: String, minLength: Int, fieldName: String = "Field") -> Result<String, AppError> {
        switch validateNonEmptyString(value, fieldName: fieldName) {
        case .success(let trimmed):
            guard trimmed.count >= minLength else {
                return .failure(AppError(
                    category: .validation,
                    severity: .warning,
                    userMessage: "\(fieldName) must be at least \(minLength) characters",
                    suggestions: ["Add more characters", "Current length: \(trimmed.count)"]
                ))
            }
            return .success(trimmed)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    /// Validate and parse double value
    static func validateDouble(_ value: String, fieldName: String = "Amount") -> Result<Double, AppError> {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            return .failure(AppError(
                category: .validation,
                severity: .warning,
                userMessage: "\(fieldName) cannot be empty",
                suggestions: ["Enter a number", "Use format like 25.50"]
            ))
        }
        
        guard let doubleValue = Double(trimmed) else {
            return .failure(AppError(
                category: .validation,
                severity: .warning,
                userMessage: "Please enter a valid number for \(fieldName.lowercased())",
                suggestions: ["Use only numbers and decimal point", "Example: 25.50"]
            ))
        }
        
        // Check for NaN and infinity values
        guard doubleValue.isFinite else {
            return .failure(AppError(
                category: .validation,
                severity: .warning,
                userMessage: "Please enter a valid number for \(fieldName.lowercased())",
                suggestions: ["Use only numbers and decimal point", "Example: 25.50"]
            ))
        }
        
        return .success(doubleValue)
    }
    
    /// Safe numeric validation that ensures finite, non-NaN values
    static func safeValidateDouble(_ value: String, fieldName: String = "Amount") -> Result<Double, AppError> {
        return validateDouble(value, fieldName: fieldName)
    }
    
    /// Validate positive double value
    static func validatePositiveDouble(_ value: String, fieldName: String = "Amount") -> Result<Double, AppError> {
        switch validateDouble(value, fieldName: fieldName) {
        case .success(let doubleValue):
            guard doubleValue > 0 else {
                return .failure(AppError(
                    category: .validation,
                    severity: .warning,
                    userMessage: "\(fieldName) must be greater than zero",
                    suggestions: ["Enter a positive number", "Example: 25.50"]
                ))
            }
            return .success(doubleValue)
        case .failure(let error):
            return .failure(error)
        }
    }
}