//
//  ServiceValidation.swift
//  Flameworker
//
//  Created by Assistant on 10/11/25.
//

import Foundation

// MARK: - Validation Result

struct ValidationResult {
    let isValid: Bool
    let errors: [String]
    
    init(isValid: Bool, errors: [String] = []) {
        self.isValid = isValid
        self.errors = errors
    }
    
    static func success() -> ValidationResult {
        return ValidationResult(isValid: true, errors: [])
    }
    
    static func failure(errors: [String]) -> ValidationResult {
        return ValidationResult(isValid: false, errors: errors)
    }
}

// MARK: - Service Validation

class ServiceValidation {
    
    /// Validates a CatalogItemModel before saving
    /// - Parameter model: The CatalogItemModel to validate
    /// - Returns: ValidationResult indicating success or failure with error details
    static func validateCatalogItem(_ model: CatalogItemModel) -> ValidationResult {
        var errors: [String] = []
        
        // Check required name field
        if model.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("CatalogItem name is required and cannot be empty")
        }
        
        // Check required code field
        if model.code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("CatalogItem code is required and cannot be empty")
        }
        
        // Check required manufacturer field
        if model.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("CatalogItem manufacturer is required and cannot be empty")
        }
        
        if errors.isEmpty {
            return ValidationResult.success()
        } else {
            return ValidationResult.failure(errors: errors)
        }
    }
    
    /// Validates a PurchaseRecordModel before saving
    /// - Parameter model: The PurchaseRecordModel to validate
    /// - Returns: ValidationResult indicating success or failure with error details
    static func validatePurchaseRecord(_ model: PurchaseRecordModel) -> ValidationResult {
        // Use the model's built-in validation
        if model.isValid {
            return ValidationResult.success()
        } else {
            return ValidationResult.failure(errors: model.validationErrors)
        }
    }
    
    /// Validates an InventoryItemModel before saving
    /// - Parameter model: The InventoryItemModel to validate
    /// - Returns: ValidationResult indicating success or failure with error details
    static func validateInventoryItem(_ model: InventoryItemModel) -> ValidationResult {
        var errors: [String] = []
        
        // Check required catalog code
        if model.catalogCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Catalog code is required and cannot be empty")
        }
        
        // Check quantity is non-negative
        if model.quantity < 0 {
            errors.append("Quantity cannot be negative")
        }
        
        if errors.isEmpty {
            return ValidationResult.success()
        } else {
            return ValidationResult.failure(errors: errors)
        }
    }
}