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

    // MARK: -  Recipe CRUD Operations

    /// Get all frit recipes
    func getAllRecipes() async throws -> [RecipeModel] {
        return try await repository.fetchAllRecipes()
    }

    /// Get a single frit recipe by ID
    func getRecipe(byId id: UUID) async throws -> RecipeModel? {
        return try await repository.fetchRecipe(byId: id)
    }

    /// Create a new frit recipe
    /// - Parameter recipe: The recipe to create
    /// - Returns: The created recipe with generated ID and timestamps
    func createRecipe(_ recipe: RecipeModel) async throws -> RecipeModel {
        // Validate title before creating
        guard RecipeModel.isValidTitle(recipe.title) else {
            throw RecipeServiceError.invalidTitle
        }

        return try await repository.createRecipe(recipe)
    }

    /// Update an existing frit recipe
    /// - Parameter recipe: The recipe with updated values
    /// - Returns: The updated recipe with new modification timestamp
    func updateRecipe(_ recipe: RecipeModel) async throws -> RecipeModel {
        // Validate title before updating
        guard RecipeModel.isValidTitle(recipe.title) else {
            throw RecipeServiceError.invalidTitle
        }

        return try await repository.updateRecipe(recipe)
    }

    /// Delete a frit recipe
    /// - Parameter id: The UUID of the recipe to delete
    func deleteRecipe(id: UUID) async throws {
        try await repository.deleteRecipe(id: id)
    }

    // MARK: - Search & Filter Operations

    /// Search frit recipes by title
    /// - Parameter query: The search query (case-insensitive)
    /// - Returns: Array of matching recipes
    func searchRecipes(byTitle query: String) async throws -> [RecipeModel] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            // If search is empty, return all recipes
            return try await getAllRecipes()
        }
        return try await repository.searchRecipes(byTitle: trimmed)
    }

    /// Find frit recipes that use a specific glass item
    /// - Parameter stableId: The stable_id of the glass item
    /// - Returns: Array of recipes containing this ingredient
    func getRecipes(containingGlassItem stableId: String) async throws -> [RecipeModel] {
        return try await repository.fetchRecipes(containingIngredient: stableId)
    }

    /// Get frit recipes filtered by measurement type
    /// - Parameter measurementType: The measurement type to filter by
    /// - Returns: Array of recipes with this measurement type
    func getRecipes(byMeasurementType measurementType: MeasurementType) async throws -> [RecipeModel] {
        return try await repository.fetchRecipes(byMeasurementType: measurementType)
    }

    // MARK: - Recipe Validation

    /// Check if a recipe title is valid
    /// - Parameter title: The title to validate
    /// - Returns: True if valid, false otherwise
    nonisolated func isValidTitle(_ title: String) -> Bool {
        return RecipeModel.isValidTitle(title)
    }

    // MARK: - Recipe Analytics

    /// Get count of all frit recipes
    func getRecipeCount() async throws -> Int {
        let recipes = try await getAllRecipes()
        return recipes.count
    }

    /// Get recipes grouped by measurement type
    func getRecipesByMeasurementType() async throws -> [MeasurementType: [RecipeModel]] {
        let allRecipes = try await getAllRecipes()
        return Dictionary(grouping: allRecipes) { $0.measurementType }
    }

    /// Get the most commonly used glass items across all recipes
    /// - Parameter limit: Maximum number of items to return
    /// - Returns: Array of (stableId, count) tuples sorted by usage frequency
    func getMostUsedIngredients(limit: Int = 10) async throws -> [(stableId: String, count: Int)] {
        let allRecipes = try await getAllRecipes()

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
