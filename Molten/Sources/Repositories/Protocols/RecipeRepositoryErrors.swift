//
//  RecipeRepositoryErrors.swift
//  Molten
//
//  Errors for Recipe repository operations
//

import Foundation

enum RecipeRepositoryError: Error, LocalizedError, Equatable {
    case recipeNotFound
    case persistenceError(String)
    case invalidData(String)
    case saveFailed(String)
    case deleteFailed(String)

    var errorDescription: String? {
        switch self {
        case .recipeNotFound:
            return "Recipe not found"
        case .persistenceError(let reason):
            return "Persistence error: \(reason)"
        case .invalidData(let reason):
            return "Invalid data: \(reason)"
        case .saveFailed(let reason):
            return "Save failed: \(reason)"
        case .deleteFailed(let reason):
            return "Delete failed: \(reason)"
        }
    }
}
