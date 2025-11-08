//
//  SharingManagerError.swift
//  Molten
//
//  Errors that can occur in InventorySharingManager
//

import Foundation

/// Errors related to inventory sharing management
public enum SharingManagerError: Error, LocalizedError {
    case shareAlreadyExists
    case noShareExists
    case friendShareNotFound

    public var errorDescription: String? {
        switch self {
        case .shareAlreadyExists:
            return "A share already exists. Delete the existing share first or use refresh to update it."
        case .noShareExists:
            return "No share exists. Create a share first."
        case .friendShareNotFound:
            return "Friend share not found."
        }
    }
}
