//  AdvancedTestingUtilities.swift
//  Flameworker
//
//  Created by Assistant on 10/11/25.
//

import Foundation
import CoreData
@testable import Flameworker

// MARK: - Thread Safety Utilities

class ThreadSafetyUtilities {
    private static let lock = NSLock()
    
    static func safeUserDefaultsWrite(key: String, value: String, defaults: UserDefaults) {
        lock.lock()
        defer { lock.unlock() }
        defaults.set(value, forKey: key)
    }
    
    static func safeUserDefaultsRead(key: String, defaults: UserDefaults) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return defaults.string(forKey: key)
    }
    
    static func getAllStoredValues(from defaults: UserDefaults) -> [String: Any] {
        lock.lock()
        defer { lock.unlock() }
        return defaults.dictionaryRepresentation()
    }
}

// MARK: - Concurrent Core Data Manager

class ConcurrentCoreDataManager {
    
    @MainActor
    func safeCreateItem(code: String, name: String, context: NSManagedObjectContext) async -> String? {
        do {
            // Create inventory item directly using Core Data
            let item = InventoryItem(context: context)
            item.id = UUID().uuidString
            item.catalog_code = code
            item.notes = name
            item.count = 0.0
            item.type = InventoryItemType.inventory.rawValue
            
            try CoreDataHelpers.safeSave(context: context, description: "new InventoryItem for concurrent test with ID: \(item.id ?? "unknown")")
            
            return item.id
        } catch {
            print("Error creating concurrent item: \(error)")
            return nil
        }
    }
}

// MARK: - Async Operation Manager

enum AsyncOperationError: Error {
    case timeout(TimeInterval)
    case cancelled
    case executionFailed(Error)
}

class AsyncOperationManager {
    
    func executeWithTimeout<T>(
        timeout: TimeInterval,
        operation: @escaping () async throws -> T
    ) async -> Result<T, Error> {
        do {
            let result = try await withThrowingTaskGroup(of: T.self) { group in
                // Add the main operation
                group.addTask {
                    try await operation()
                }
                
                // Add timeout task
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    throw AsyncOperationError.timeout(timeout)
                }
                
                // Return the first result (either success or timeout)
                let result = try await group.next()!
                group.cancelAll()
                return result
            }
            
            return .success(result)
        } catch {
            return .failure(error)
        }
    }
    
    func executeWithCancellation<T>(
        operation: @escaping (@escaping () -> Bool) async throws -> T
    ) async -> Result<T, Error> {
        do {
            var isCancelled = false
            
            let result = try await withTaskCancellationHandler(
                operation: {
                    try await operation { isCancelled }
                },
                onCancel: {
                    isCancelled = true
                }
            )
            return .success(result)
        } catch {
            return .failure(error)
        }
    }
}

// MARK: - Precision Calculator

class PrecisionCalculator {
    
    func safeAdd(_ a: Double, _ b: Double) -> Double {
        return a + b
    }
    
    func safeCurrencyAdd(_ a: Double, _ b: Double) -> Double {
        // Round to 2 decimal places for currency
        let result = a + b
        return Double(round(100 * result) / 100)
    }
    
    func safeWeightConversion(_ value: Double, from: WeightUnit, to: WeightUnit) -> Double {
        return from.convert(value, to: to)
    }
    
    func isEqual(_ a: Double, _ b: Double, precision: Double) -> Bool {
        return abs(a - b) < precision
    }
}

// MARK: - Advanced Form Validator

struct ComplexFormData {
    let inventoryCount: Double
    let pricePerUnit: Double
    let supplierName: String
    let notes: String
    let isActive: Bool
    let tags: [String]
    let metadata: [String: String]
}

struct ValidatedFormData {
    let inventoryCount: Double
    let pricePerUnit: Double
    let supplierName: String
    let notes: String
    let isActive: Bool
    let tags: [String]
    let metadata: [String: String]
}

struct FormValidationError: Error {
    let errors: [String]
}

class AdvancedFormValidator {
    
    func validateComplexForm(_ formData: ComplexFormData) -> Result<ValidatedFormData, FormValidationError> {
        var errors: [String] = []
        
        // Validate inventory count
        if formData.inventoryCount < 0 {
            errors.append("Inventory count cannot be negative")
        }
        
        // Validate price
        if formData.pricePerUnit < 0 {
            errors.append("Price per unit cannot be negative")
        }
        
        // Validate supplier name
        if formData.supplierName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Supplier name cannot be empty")
        }
        
        // Return errors if any
        if !errors.isEmpty {
            return .failure(FormValidationError(errors: errors))
        }
        
        // Create validated data with cleaned values
        let validatedData = ValidatedFormData(
            inventoryCount: formData.inventoryCount,
            pricePerUnit: formData.pricePerUnit,
            supplierName: formData.supplierName.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: formData.notes.trimmingCharacters(in: .whitespacesAndNewlines),
            isActive: formData.isActive,
            tags: formData.tags,
            metadata: formData.metadata
        )
        
        return .success(validatedData)
    }
}