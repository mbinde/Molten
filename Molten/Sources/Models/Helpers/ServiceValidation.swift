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
    
    /// Validates a GlassItemModel before saving
    /// - Parameter model: The GlassItemModel to validate
    /// - Returns: ValidationResult indicating success or failure with error details
    static func validateGlassItem(_ model: GlassItemModel) -> ValidationResult {
        var errors: [String] = []
        
        // Check required name field
        if model.name.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
            errors.append("GlassItem name is required and cannot be empty")
        }
        
        // Check required natural key field
        if model.natural_key.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
            errors.append("GlassItem natural key is required and cannot be empty")
        }
        
        // Check required manufacturer field
        if model.manufacturer.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
            errors.append("GlassItem manufacturer is required and cannot be empty")
        }
        
        // Check required SKU field
        if model.sku.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
            errors.append("GlassItem SKU is required and cannot be empty")
        }
        
        // Check COE is within reasonable range
        if model.coe < 80 || model.coe > 120 {
            errors.append("COE value should be between 80 and 120")
        }
        
        if errors.isEmpty {
            return ValidationResult.success()
        } else {
            return ValidationResult.failure(errors: errors)
        }
    }
    
    /// Legacy method for backward compatibility
    /// - Parameter model: The legacy CatalogItemModel to validate (if still exists)
    /// - Returns: ValidationResult indicating success or failure with error details
    @available(*, deprecated, message: "Use validateGlassItem instead")
    static func validateCatalogItem(_ model: Any) -> ValidationResult {
        // This is kept for backward compatibility but should not be used
        return ValidationResult.failure(errors: ["Legacy CatalogItemModel validation is deprecated. Use GlassItem validation instead."])
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
    
    /// Validates an InventoryModel before saving
    /// - Parameter model: The InventoryModel to validate
    /// - Returns: ValidationResult indicating success or failure with error details
    static func validateInventoryModel(_ model: InventoryModel) -> ValidationResult {
        var errors: [String] = []
        
        // Check required item natural key
        if model.item_natural_key.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
            errors.append("Item natural key is required and cannot be empty")
        }
        
        // Check required type
        if model.type.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
            errors.append("Inventory type is required and cannot be empty")
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
    
    /// Validates a CompleteInventoryItemModel (contains GlassItem + Inventory data)
    /// - Parameter model: The CompleteInventoryItemModel to validate
    /// - Returns: ValidationResult indicating success or failure with error details
    static func validateCompleteInventoryItem(_ model: CompleteInventoryItemModel) -> ValidationResult {
        // Validate the embedded GlassItem
        let glassItemValidation = validateGlassItem(model.glassItem)
        if !glassItemValidation.isValid {
            return glassItemValidation
        }
        
        // Validate each inventory record
        for inventoryRecord in model.inventory {
            let inventoryValidation = validateInventoryModel(inventoryRecord)
            if !inventoryValidation.isValid {
                return inventoryValidation
            }
        }
        
        // Additional validation for the complete model
        var errors: [String] = []
        
        // Check that all inventory records belong to the same item
        for inventoryRecord in model.inventory {
            if inventoryRecord.item_natural_key != model.glassItem.natural_key {
                errors.append("Inventory record natural key (\(inventoryRecord.item_natural_key)) does not match GlassItem natural key (\(model.glassItem.natural_key))")
            }
        }
        
        if errors.isEmpty {
            return ValidationResult.success()
        } else {
            return ValidationResult.failure(errors: errors)
        }
    }
    
    /// Legacy method for backward compatibility
    /// - Parameter model: The legacy InventoryItemModel to validate (if still exists)
    /// - Returns: ValidationResult indicating success or failure with error details
    @available(*, deprecated, message: "Use validateInventoryModel instead")
    static func validateInventoryItem(_ model: Any) -> ValidationResult {
        // This is kept for backward compatibility but should not be used
        return ValidationResult.failure(errors: ["Legacy InventoryItemModel validation is deprecated. Use InventoryModel validation instead."])
    }
}
