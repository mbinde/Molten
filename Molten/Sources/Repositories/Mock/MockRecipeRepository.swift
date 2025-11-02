//
//  MockRecipeRepository.swift
//  Molten
//
//  Mock implementation of RecipeRepository for testing
//

@preconcurrency import Foundation

/// Mock implementation of RecipeRepository for testing
final class MockRecipeRepository: @unchecked Sendable, RecipeRepository {
    nonisolated(unsafe) private var fritRecipes: [UUID: FritRecipeModel] = [:]
    private let queue = DispatchQueue(label: "mock.recipe.repository", attributes: .concurrent)

    nonisolated init() {}

    // MARK: - Frit Recipe Operations

    nonisolated func fetchAllFritRecipes() async throws -> [FritRecipeModel] {
        return await withCheckedContinuation { continuation in
            queue.async {
                let sorted = Array(self.fritRecipes.values).sorted { $0.dateCreated > $1.dateCreated }
                continuation.resume(returning: sorted)
            }
        }
    }

    nonisolated func fetchFritRecipe(byId id: UUID) async throws -> FritRecipeModel? {
        return await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.fritRecipes[id])
            }
        }
    }

    nonisolated func createFritRecipe(_ recipe: FritRecipeModel) async throws -> FritRecipeModel {
        return await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                self.fritRecipes[recipe.id] = recipe
                continuation.resume(returning: recipe)
            }
        }
    }

    nonisolated func updateFritRecipe(_ recipe: FritRecipeModel) async throws -> FritRecipeModel {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async(flags: .barrier) {
                guard self.fritRecipes[recipe.id] != nil else {
                    continuation.resume(throwing: RecipeRepositoryError.recipeNotFound)
                    return
                }

                let updated = recipe.withUpdatedModificationDate()
                self.fritRecipes[updated.id] = updated
                continuation.resume(returning: updated)
            }
        }
    }

    nonisolated func deleteFritRecipe(id: UUID) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async(flags: .barrier) {
                guard self.fritRecipes[id] != nil else {
                    continuation.resume(throwing: RecipeRepositoryError.recipeNotFound)
                    return
                }

                self.fritRecipes.removeValue(forKey: id)
                continuation.resume()
            }
        }
    }

    // MARK: - Search Operations

    nonisolated func searchFritRecipes(byTitle query: String) async throws -> [FritRecipeModel] {
        return await withCheckedContinuation { continuation in
            queue.async {
                let lowercasedQuery = query.lowercased()
                let results = self.fritRecipes.values.filter {
                    $0.title.lowercased().contains(lowercasedQuery)
                }
                continuation.resume(returning: results)
            }
        }
    }

    nonisolated func fetchFritRecipes(containingIngredient stableId: String) async throws -> [FritRecipeModel] {
        return await withCheckedContinuation { continuation in
            queue.async {
                let results = self.fritRecipes.values.filter { recipe in
                    recipe.ingredients.contains { ingredient in
                        ingredient.stableId == stableId
                    }
                }
                continuation.resume(returning: results)
            }
        }
    }

    nonisolated func fetchFritRecipes(byMeasurementType measurementType: FritMeasurementType) async throws -> [FritRecipeModel] {
        return await withCheckedContinuation { continuation in
            queue.async {
                let results = self.fritRecipes.values.filter {
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
            self.fritRecipes.removeAll()
        }
    }

    /// Get count of recipes (for testing)
    nonisolated func count() async -> Int {
        return await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.fritRecipes.count)
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
