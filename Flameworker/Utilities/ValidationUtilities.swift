//
//  ValidationUtilities.swift
//  Flameworker
//
//  Created by Assistant on 9/30/25.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Validation Utilities

struct ValidationUtilities {
    
    // MARK: - String Validation
    
    /// Safely trim and validate string is not empty
    static func validateNonEmptyString(_ value: String, fieldName: String = "Field") -> Result<String, AppError> {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            return .failure(ErrorHandler.shared.createValidationError(
                "\(fieldName) cannot be empty",
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
                return .failure(ErrorHandler.shared.createValidationError(
                    "\(fieldName) must be at least \(minLength) characters",
                    suggestions: ["Add more characters", "Current length: \(trimmed.count)"]
                ))
            }
            return .success(trimmed)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    // MARK: - Number Validation
    
    /// Validate and parse double value
    static func validateDouble(_ value: String, fieldName: String = "Amount") -> Result<Double, AppError> {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            return .failure(ErrorHandler.shared.createValidationError(
                "\(fieldName) cannot be empty",
                suggestions: ["Enter a number", "Use format like 25.50"]
            ))
        }
        
        guard let doubleValue = Double(trimmed) else {
            return .failure(ErrorHandler.shared.createValidationError(
                "Please enter a valid number for \(fieldName.lowercased())",
                suggestions: ["Use only numbers and decimal point", "Example: 25.50"]
            ))
        }
        
        return .success(doubleValue)
    }
    
    /// Validate positive double value
    static func validatePositiveDouble(_ value: String, fieldName: String = "Amount") -> Result<Double, AppError> {
        switch validateDouble(value, fieldName: fieldName) {
        case .success(let doubleValue):
            guard doubleValue > 0 else {
                return .failure(ErrorHandler.shared.createValidationError(
                    "\(fieldName) must be greater than zero",
                    suggestions: ["Enter a positive number", "Example: 25.50"]
                ))
            }
            return .success(doubleValue)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    /// Validate non-negative double value
    static func validateNonNegativeDouble(_ value: String, fieldName: String = "Amount") -> Result<Double, AppError> {
        switch validateDouble(value, fieldName: fieldName) {
        case .success(let doubleValue):
            guard doubleValue >= 0 else {
                return .failure(ErrorHandler.shared.createValidationError(
                    "\(fieldName) cannot be negative",
                    suggestions: ["Enter zero or a positive number", "Example: 0 or 25.50"]
                ))
            }
            return .success(doubleValue)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    // MARK: - Email Validation
    
    /// Validate email format (basic)
    static func validateEmail(_ value: String) -> Result<String, AppError> {
        switch validateNonEmptyString(value, fieldName: "Email") {
        case .success(let trimmed):
            let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
            let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
            
            guard predicate.evaluate(with: trimmed) else {
                return .failure(ErrorHandler.shared.createValidationError(
                    "Please enter a valid email address",
                    suggestions: ["Use format: name@example.com", "Check for typos"]
                ))
            }
            
            return .success(trimmed)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    // MARK: - Combined Validations
    
    /// Validate supplier name (common pattern)
    static func validateSupplierName(_ value: String) -> Result<String, AppError> {
        return validateMinimumLength(value, minLength: 2, fieldName: "Supplier name")
    }
    
    /// Validate purchase amount (common pattern)
    static func validatePurchaseAmount(_ value: String) -> Result<Double, AppError> {
        return validatePositiveDouble(value, fieldName: "Purchase amount")
    }
    
    /// Validate inventory count (can be zero)
    static func validateInventoryCount(_ value: String) -> Result<Double, AppError> {
        return validateNonNegativeDouble(value, fieldName: "Inventory count")
    }
    
    // MARK: - Validation Result Helpers
    
    /// Execute validation and handle errors automatically
    static func validate<T>(
        _ validation: () -> Result<T, AppError>,
        onSuccess: (T) -> Void,
        onError: (AppError) -> Void
    ) {
        switch validation() {
        case .success(let value):
            onSuccess(value)
        case .failure(let error):
            onError(error)
        }
    }
    
    /// Validate multiple fields and return first error or success
    static func validateAll<T>(
        _ validations: [() -> Result<T, AppError>]
    ) -> Result<[T], AppError> {
        var results: [T] = []
        
        for validation in validations {
            switch validation() {
            case .success(let value):
                results.append(value)
            case .failure(let error):
                return .failure(error)
            }
        }
        
        return .success(results)
    }
}

// MARK: - Form Validation State

@MainActor
final class FormValidationState: ObservableObject {
    @Published var isValid = false
    @Published var errors: [String: AppError] = [:]
    
    private var fields: [String: () -> Result<Any, AppError>] = [:]
    
    /// Register a field validation
    func registerField<T>(_ key: String, validation: @escaping () -> Result<T, AppError>) {
        fields[key] = {
            switch validation() {
            case .success(let value):
                return .success(value as Any)
            case .failure(let error):
                return .failure(error)
            }
        }
    }
    
    /// Validate all registered fields
    func validateAll() {
        errors.removeAll()
        
        for (key, validation) in fields {
            switch validation() {
            case .success:
                errors.removeValue(forKey: key)
            case .failure(let error):
                errors[key] = error
            }
        }
        
        isValid = errors.isEmpty
    }
    
    /// Get error message for specific field
    func errorMessage(for key: String) -> String? {
        return errors[key]?.userMessage
    }
    
    /// Check if specific field has error
    func hasError(for key: String) -> Bool {
        return errors[key] != nil
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Validation Examples") {
    struct ValidationExampleView: View {
        @State private var supplierText = ""
        @State private var amountText = ""
        @State private var emailText = ""
        @StateObject private var validationState = FormValidationState()
        @StateObject private var errorState = ErrorAlertState()
        
        var body: some View {
            Form {
                Section("Validation Test") {
                    TextField("Supplier Name", text: $supplierText)
                        .foregroundColor(validationState.hasError(for: "supplier") ? .red : .primary)
                    
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                        .foregroundColor(validationState.hasError(for: "amount") ? .red : .primary)
                    
                    TextField("Email", text: $emailText)
                        .keyboardType(.emailAddress)
                        .foregroundColor(validationState.hasError(for: "email") ? .red : .primary)
                    
                    Button("Validate All") {
                        testValidation()
                    }
                    .disabled(!validationState.isValid)
                }
            }
            .onAppear {
                setupValidations()
            }
            .onChange(of: supplierText) { _, _ in validationState.validateAll() }
            .onChange(of: amountText) { _, _ in validationState.validateAll() }
            .onChange(of: emailText) { _, _ in validationState.validateAll() }
            .errorAlert(errorState)
        }
        
        private func setupValidations() {
            validationState.registerField("supplier") {
                ValidationUtilities.validateSupplierName(supplierText)
            }
            
            validationState.registerField("amount") {
                ValidationUtilities.validatePurchaseAmount(amountText)
            }
            
            validationState.registerField("email") {
                ValidationUtilities.validateEmail(emailText)
            }
        }
        
        private func testValidation() {
            let firstError = validationState.errors.values.first
            if let error = firstError {
                errorState.show(error: error)
            }
        }
    }
    
    return ValidationExampleView()
}
#endif