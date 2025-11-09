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
    case shareDeletedByOwner

    public var errorDescription: String? {
        switch self {
        case .shareAlreadyExists:
            return "A share already exists. Delete the existing share first or use refresh to update it."
        case .noShareExists:
            return "No share exists. Create a share first."
        case .friendShareNotFound:
            return "Friend share not found."
        case .shareDeletedByOwner:
            return "This share is no longer available. The owner may have deleted it."
        }
    }
}
