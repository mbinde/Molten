//
//  InventoryRepositoryError.swift
//  Flameworker
//
//  Created by Assistant on 10/13/25.
//

import Foundation

/// Structured error types for inventory repository operations
enum InventoryRepositoryError: Error, LocalizedError {
    case itemNotFound(String)
    case invalidData(String)
    case persistenceFailure(String)
    case concurrencyConflict
    
    var errorDescription: String? {
        switch self {
        case .itemNotFound(let id):
            return "Inventory item with id '\(id)' was not found"
        case .invalidData(let message):
            return "Invalid inventory data: \(message)"
        case .persistenceFailure(let message):
            return "Failed to save inventory data: \(message)"
        case .concurrencyConflict:
            return "Inventory data was modified by another process"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .itemNotFound:
            return "The requested inventory item does not exist in the database"
        case .invalidData:
            return "The inventory item data does not meet validation requirements"
        case .persistenceFailure:
            return "Core Data was unable to save the inventory item"
        case .concurrencyConflict:
            return "Another process modified the inventory item while this operation was in progress"
        }
    }
}