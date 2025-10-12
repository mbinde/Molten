//
//  ServiceValidation.swift
//  Flameworker
//
//  Created by Assistant on 10/11/25.
//

import Foundation
import CoreData

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
    
    /// Validates an entity before saving to Core Data
    /// - Parameter entity: The NSManagedObject to validate
    /// - Returns: ValidationResult indicating success or failure with error details
    static func validateBeforeSave(entity: NSManagedObject) -> ValidationResult {
        var errors: [String] = []
        
        // Validate CatalogItem entities using entity name check
        if entity.entity.name == "CatalogItem" {
            errors.append(contentsOf: validateCatalogItemEntity(entity))
        }
        
        // Add validation for other entity types as needed
        
        if errors.isEmpty {
            return ValidationResult.success()
        } else {
            return ValidationResult.failure(errors: errors)
        }
    }
    
    /// Validates CatalogItem specific requirements using KVC
    /// - Parameter entity: The NSManagedObject representing a CatalogItem
    /// - Returns: Array of validation error messages
    private static func validateCatalogItemEntity(_ entity: NSManagedObject) -> [String] {
        var errors: [String] = []
        
        // Check required name field using KVC
        let name = entity.value(forKey: "name") as? String
        if name?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty != false {
            errors.append("CatalogItem name is required and cannot be empty")
        }
        
        // Check required code field using KVC
        let code = entity.value(forKey: "code") as? String
        if code?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty != false {
            errors.append("CatalogItem code is required and cannot be empty")
        }
        
        // Check required manufacturer field using KVC
        let manufacturer = entity.value(forKey: "manufacturer") as? String
        if manufacturer?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty != false {
            errors.append("CatalogItem manufacturer is required and cannot be empty")
        }
        
        return errors
    }
}