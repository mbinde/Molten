//
//  MockRecipeRepository.swift
//  Molten
//
//  Mock implementation of RecipeRepository for testing
//

import Foundation

/// Mock implementation of RecipeRepository for testing
final class MockRecipeRepository: RecipeRepository {
    private var fritRecipes: [UUID: FritRecipeModel] = [:]
    private let lock = NSLock()

    nonisolated init() {}

    // MARK: - Frit Recipe Operations

    nonisolated func fetchAllFritRecipes() async throws -> [FritRecipeModel] {
        lock.lock()
        defer { lock.unlock() }
        return Array(fritRecipes.values).sorted { $0.dateCreated > $1.dateCreated }
    }

    nonisolated func fetchFritRecipe(byId id: UUID) async throws -> FritRecipeModel? {
        lock.lock()
        defer { lock.unlock() }
        return fritRecipes[id]
    }

    nonisolated func createFritRecipe(_ recipe: FritRecipeModel) async throws -> FritRecipeModel {
        lock.lock()
        defer { lock.unlock() }
        fritRecipes[recipe.id] = recipe
        return recipe
    }

    nonisolated func updateFritRecipe(_ recipe: FritRecipeModel) async throws -> FritRecipeModel {
        lock.lock()
        defer { lock.unlock() }

        guard fritRecipes[recipe.id] != nil else {
            throw RecipeRepositoryError.recipeNotFound
        }

        let updated = recipe.withUpdatedModificationDate()
        fritRecipes[updated.id] = updated
        return updated
    }

    nonisolated func deleteFritRecipe(id: UUID) async throws {
        lock.lock()
        defer { lock.unlock() }

        guard fritRecipes[id] != nil else {
            throw RecipeRepositoryError.recipeNotFound
        }

        fritRecipes.removeValue(forKey: id)
    }

    // MARK: - Search Operations

    nonisolated func searchFritRecipes(byTitle query: String) async throws -> [FritRecipeModel] {
        lock.lock()
        defer { lock.unlock() }

        let lowercasedQuery = query.lowercased()
        return fritRecipes.values.filter {
            $0.title.lowercased().contains(lowercasedQuery)
        }
    }

    nonisolated func fetchFritRecipes(containingIngredient stableId: String) async throws -> [FritRecipeModel] {
        lock.lock()
        defer { lock.unlock() }

        return fritRecipes.values.filter { recipe in
            recipe.ingredients.contains { ingredient in
                ingredient.stableId == stableId
            }
        }
    }

    nonisolated func fetchFritRecipes(byMeasurementType measurementType: FritMeasurementType) async throws -> [FritRecipeModel] {
        lock.lock()
        defer { lock.unlock() }

        return fritRecipes.values.filter {
            $0.measurementType == measurementType
        }
    }

    // MARK: - Test Helpers

    /// Clear all recipes (for test teardown)
    nonisolated func clear() {
        lock.lock()
        defer { lock.unlock() }
        fritRecipes.removeAll()
    }

    /// Get count of recipes (for testing)
    nonisolated func count() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return fritRecipes.count
    }
}

// MARK: - Repository Errors

enum RecipeRepositoryError: Error, LocalizedError {
    case recipeNotFound
    case invalidRecipeData
    case persistenceError(String)

    var errorDescription: String? {
        switch self {
        case .recipeNotFound:
            return "Recipe not found"
        case .invalidRecipeData:
            return "Invalid recipe data"
        case .persistenceError(let message):
            return "Persistence error: \(message)"
        }
    }
}
