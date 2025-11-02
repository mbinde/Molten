//
//  RecipeRepository.swift
//  Molten
//
//  Repository protocol for Recipe data persistence operations
//

import Foundation

/// Repository protocol for Recipe data persistence operations
/// Handles CRUD operations for recipes and their ingredients
nonisolated protocol RecipeRepository: Sendable {

    // MARK: - Recipe Operations

    /// Fetch all recipes
    /// - Returns: Array of RecipeModel instances
    func fetchAllRecipes() async throws -> [RecipeModel]

    /// Fetch a single recipe by its ID
    /// - Parameter id: The UUID of the recipe
    /// - Returns: RecipeModel if found, nil otherwise
    func fetchRecipe(byId id: UUID) async throws -> RecipeModel?

    /// Create a new recipe
    /// - Parameter recipe: The RecipeModel to create
    /// - Returns: The created RecipeModel
    func createRecipe(_ recipe: RecipeModel) async throws -> RecipeModel

    /// Update an existing recipe
    /// - Parameter recipe: The RecipeModel with updated values
    /// - Returns: The updated RecipeModel
    func updateRecipe(_ recipe: RecipeModel) async throws -> RecipeModel

    /// Delete a recipe by ID
    /// - Parameter id: The UUID of the recipe to delete
    func deleteRecipe(id: UUID) async throws

    // MARK: - Search Operations

    /// Search recipes by title (case-insensitive)
    /// - Parameter query: The search query
    /// - Returns: Array of matching RecipeModel instances
    func searchRecipes(byTitle query: String) async throws -> [RecipeModel]

    /// Fetch recipes that contain a specific glass item ingredient
    /// - Parameter stableId: The stable_id of the glass item
    /// - Returns: Array of RecipeModel instances containing this ingredient
    func fetchRecipes(containingIngredient stableId: String) async throws -> [RecipeModel]

    /// Fetch recipes by measurement type
    /// - Parameter measurementType: The measurement type to filter by
    /// - Returns: Array of RecipeModel instances with this measurement type
    func fetchRecipes(byMeasurementType measurementType: MeasurementType) async throws -> [RecipeModel]
}
