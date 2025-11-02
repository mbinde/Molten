//
//  MockRecipeRepository.swift
//  Molten
//
//  Mock implementation of RecipeRepository for testing
//

@preconcurrency import Foundation

/// Mock implementation of RecipeRepository for testing
final class MockRecipeRepository: @unchecked Sendable, RecipeRepository {
    nonisolated(unsafe) private var recipes: [UUID: RecipeModel] = [:]
    private let queue = DispatchQueue(label: "mock.recipe.repository", attributes: .concurrent)

    nonisolated init() {}

    // MARK: - Recipe Operations

    nonisolated func fetchAllRecipes() async throws -> [RecipeModel] {
        return await withCheckedContinuation { continuation in
            queue.async {
                let sorted = Array(self.recipes.values).sorted { $0.dateCreated > $1.dateCreated }
                continuation.resume(returning: sorted)
            }
        }
    }

    nonisolated func fetchRecipe(byId id: UUID) async throws -> RecipeModel? {
        return await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.recipes[id])
            }
        }
    }

    nonisolated func createRecipe(_ recipe: RecipeModel) async throws -> RecipeModel {
        return await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                self.recipes[recipe.id] = recipe
                continuation.resume(returning: recipe)
            }
        }
    }

    nonisolated func updateRecipe(_ recipe: RecipeModel) async throws -> RecipeModel {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async(flags: .barrier) {
                guard self.recipes[recipe.id] != nil else {
                    continuation.resume(throwing: RecipeRepositoryError.recipeNotFound)
                    return
                }

                let updated = recipe.withUpdatedModificationDate()
                self.recipes[updated.id] = updated
                continuation.resume(returning: updated)
            }
        }
    }

    nonisolated func deleteRecipe(id: UUID) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async(flags: .barrier) {
                guard self.recipes[id] != nil else {
                    continuation.resume(throwing: RecipeRepositoryError.recipeNotFound)
                    return
                }

                self.recipes.removeValue(forKey: id)
                continuation.resume()
            }
        }
    }

    // MARK: - Search Operations

    nonisolated func searchRecipes(byTitle query: String) async throws -> [RecipeModel] {
        return await withCheckedContinuation { continuation in
            queue.async {
                let lowercasedQuery = query.lowercased()
                let results = self.recipes.values.filter {
                    $0.title.lowercased().contains(lowercasedQuery)
                }
                continuation.resume(returning: results)
            }
        }
    }

    nonisolated func fetchRecipes(containingIngredient stableId: String) async throws -> [RecipeModel] {
        return await withCheckedContinuation { continuation in
            queue.async {
                let results = self.recipes.values.filter { recipe in
                    recipe.ingredients.contains { ingredient in
                        ingredient.stableId == stableId
                    }
                }
                continuation.resume(returning: results)
            }
        }
    }

    nonisolated func fetchRecipes(byMeasurementType measurementType: MeasurementType) async throws -> [RecipeModel] {
        return await withCheckedContinuation { continuation in
            queue.async {
                let results = self.recipes.values.filter {
                    $0.measurementType == measurementType
                }
                continuation.resume(returning: results)
            }
        }
    }

    // MARK: - Test Helpers

    /// Clear all recipes (for test teardown)
    nonisolated func clear() {
        queue.async(flags: .barrier) {
            self.recipes.removeAll()
        }
    }

    /// Get count of recipes (for testing)
    nonisolated func count() async -> Int {
        return await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.recipes.count)
            }
        }
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
