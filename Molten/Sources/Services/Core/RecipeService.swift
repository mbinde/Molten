//
//  RecipeService.swift
//  Molten
//
//  Service layer that handles recipe business logic using repository pattern
//

import Foundation

/// Service layer for recipe management
/// Coordinates recipe operations and provides business logic layer
actor RecipeService {
    private let repository: RecipeRepository

    init(repository: RecipeRepository) {
        self.repository = repository
    }

    // MARK: - Frit Recipe CRUD Operations

    /// Get all frit recipes
    func getAllFritRecipes() async throws -> [FritRecipeModel] {
        return try await repository.fetchAllFritRecipes()
    }

    /// Get a single frit recipe by ID
    func getFritRecipe(byId id: UUID) async throws -> FritRecipeModel? {
        return try await repository.fetchFritRecipe(byId: id)
    }

    /// Create a new frit recipe
    /// - Parameter recipe: The recipe to create
    /// - Returns: The created recipe with generated ID and timestamps
    func createFritRecipe(_ recipe: FritRecipeModel) async throws -> FritRecipeModel {
        // Validate title before creating
        guard FritRecipeModel.isValidTitle(recipe.title) else {
            throw RecipeServiceError.invalidTitle
        }

        return try await repository.createFritRecipe(recipe)
    }

    /// Update an existing frit recipe
    /// - Parameter recipe: The recipe with updated values
    /// - Returns: The updated recipe with new modification timestamp
    func updateFritRecipe(_ recipe: FritRecipeModel) async throws -> FritRecipeModel {
        // Validate title before updating
        guard FritRecipeModel.isValidTitle(recipe.title) else {
            throw RecipeServiceError.invalidTitle
        }

        return try await repository.updateFritRecipe(recipe)
    }

    /// Delete a frit recipe
    /// - Parameter id: The UUID of the recipe to delete
    func deleteFritRecipe(id: UUID) async throws {
        try await repository.deleteFritRecipe(id: id)
    }

    // MARK: - Search & Filter Operations

    /// Search frit recipes by title
    /// - Parameter query: The search query (case-insensitive)
    /// - Returns: Array of matching recipes
    func searchFritRecipes(byTitle query: String) async throws -> [FritRecipeModel] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            // If search is empty, return all recipes
            return try await getAllFritRecipes()
        }
        return try await repository.searchFritRecipes(byTitle: trimmed)
    }

    /// Find frit recipes that use a specific glass item
    /// - Parameter stableId: The stable_id of the glass item
    /// - Returns: Array of recipes containing this ingredient
    func getFritRecipes(containingGlassItem stableId: String) async throws -> [FritRecipeModel] {
        return try await repository.fetchFritRecipes(containingIngredient: stableId)
    }

    /// Get frit recipes filtered by measurement type
    /// - Parameter measurementType: The measurement type to filter by
    /// - Returns: Array of recipes with this measurement type
    func getFritRecipes(byMeasurementType measurementType: FritMeasurementType) async throws -> [FritRecipeModel] {
        return try await repository.fetchFritRecipes(byMeasurementType: measurementType)
    }

    // MARK: - Recipe Validation

    /// Check if a recipe title is valid
    /// - Parameter title: The title to validate
    /// - Returns: True if valid, false otherwise
    func isValidTitle(_ title: String) -> Bool {
        return FritRecipeModel.isValidTitle(title)
    }

    // MARK: - Recipe Analytics

    /// Get count of all frit recipes
    func getFritRecipeCount() async throws -> Int {
        let recipes = try await getAllFritRecipes()
        return recipes.count
    }

    /// Get recipes grouped by measurement type
    func getRecipesByMeasurementType() async throws -> [FritMeasurementType: [FritRecipeModel]] {
        let allRecipes = try await getAllFritRecipes()
        return Dictionary(grouping: allRecipes) { $0.measurementType }
    }

    /// Get the most commonly used glass items across all recipes
    /// - Parameter limit: Maximum number of items to return
    /// - Returns: Array of (stableId, count) tuples sorted by usage frequency
    func getMostUsedIngredients(limit: Int = 10) async throws -> [(stableId: String, count: Int)] {
        let allRecipes = try await getAllFritRecipes()

        // Count occurrences of each ingredient
        var ingredientCounts: [String: Int] = [:]
        for recipe in allRecipes {
            for ingredient in recipe.ingredients {
                ingredientCounts[ingredient.stableId, default: 0] += 1
            }
        }

        // Sort by count descending and take top N
        return ingredientCounts
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { (stableId: $0.key, count: $0.value) }
    }
}

// MARK: - Service Errors

enum RecipeServiceError: Error, LocalizedError {
    case invalidTitle
    case recipeNotFound
    case invalidIngredient

    var errorDescription: String? {
        switch self {
        case .invalidTitle:
            return "Recipe title is invalid (must be 1-100 characters)"
        case .recipeNotFound:
            return "Recipe not found"
        case .invalidIngredient:
            return "Invalid ingredient data"
        }
    }
}
