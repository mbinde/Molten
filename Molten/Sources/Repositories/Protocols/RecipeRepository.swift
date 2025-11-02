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

    // MARK: - Frit Recipe Operations

    /// Fetch all frit recipes
    /// - Returns: Array of FritRecipeModel instances
    func fetchAllFritRecipes() async throws -> [FritRecipeModel]

    /// Fetch a single frit recipe by its ID
    /// - Parameter id: The UUID of the recipe
    /// - Returns: FritRecipeModel if found, nil otherwise
    func fetchFritRecipe(byId id: UUID) async throws -> FritRecipeModel?

    /// Create a new frit recipe
    /// - Parameter recipe: The FritRecipeModel to create
    /// - Returns: The created FritRecipeModel
    func createFritRecipe(_ recipe: FritRecipeModel) async throws -> FritRecipeModel

    /// Update an existing frit recipe
    /// - Parameter recipe: The FritRecipeModel with updated values
    /// - Returns: The updated FritRecipeModel
    func updateFritRecipe(_ recipe: FritRecipeModel) async throws -> FritRecipeModel

    /// Delete a frit recipe by ID
    /// - Parameter id: The UUID of the recipe to delete
    func deleteFritRecipe(id: UUID) async throws

    // MARK: - Search Operations

    /// Search frit recipes by title (case-insensitive)
    /// - Parameter query: The search query
    /// - Returns: Array of matching FritRecipeModel instances
    func searchFritRecipes(byTitle query: String) async throws -> [FritRecipeModel]

    /// Fetch frit recipes that contain a specific glass item ingredient
    /// - Parameter stableId: The stable_id of the glass item
    /// - Returns: Array of FritRecipeModel instances containing this ingredient
    func fetchFritRecipes(containingIngredient stableId: String) async throws -> [FritRecipeModel]

    /// Fetch frit recipes by measurement type
    /// - Parameter measurementType: The measurement type to filter by
    /// - Returns: Array of FritRecipeModel instances with this measurement type
    func fetchFritRecipes(byMeasurementType measurementType: FritMeasurementType) async throws -> [FritRecipeModel]
}
