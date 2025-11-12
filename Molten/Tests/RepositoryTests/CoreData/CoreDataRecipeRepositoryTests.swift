//
//  CoreDataRecipeRepositoryTests.swift
//  RepositoryTests
//
//  Tests for CoreDataRecipeRepository
//

import Testing
import Foundation
import CoreData
@testable import Molten

@Suite("Core Data Recipe Repository Tests")
@MainActor
struct CoreDataRecipeRepositoryTests {

    // MARK: - Test Helpers

    private func createTestRepository(controller: PersistenceController) -> CoreDataRecipeRepository {
        return CoreDataRecipeRepository(context: controller.container.viewContext)
    }

    private func createTestRecipe(
        id: UUID = UUID(),
        title: String = "Test Recipe",
        descriptionText: String = "Test description",
        measurementType: MeasurementType = .byWeight,
        ingredients: [RecipeIngredientModel] = []
    ) -> RecipeModel {
        return RecipeModel(
            id: id,
            title: title,
            descriptionText: descriptionText,
            measurementType: measurementType,
            ingredients: ingredients
        )
    }

    private func createTestIngredient(
        id: UUID = UUID(),
        stableId: String = "bullseye-001-0",
        amount: Double = 100.0
    ) -> RecipeIngredientModel {
        return RecipeIngredientModel(
            id: id,
            stableId: stableId,
            amount: amount
        )
    }

    // MARK: - CRUD Tests

    @Test("Should create a recipe")
    func testCreateRecipe() async throws {
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let ingredient = createTestIngredient()
        let recipe = createTestRecipe(ingredients: [ingredient])

        let created = try await repository.createRecipe(recipe)

        #expect(created.id == recipe.id)
        #expect(created.title == "Test Recipe")
        #expect(created.descriptionText == "Test description")
        #expect(created.measurementType == .byWeight)
        #expect(created.ingredients.count == 1)
        #expect(created.ingredients.first?.stableId == "bullseye-001-0")
    }

    @Test("Should fetch recipe by ID")
    func testFetchRecipeById() async throws {
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let ingredient = createTestIngredient()
        let recipe = createTestRecipe(ingredients: [ingredient])
        _ = try await repository.createRecipe(recipe)

        let fetched = try await repository.fetchRecipe(byId: recipe.id)

        #expect(fetched != nil)
        #expect(fetched?.id == recipe.id)
        #expect(fetched?.title == "Test Recipe")
        #expect(fetched?.ingredients.count == 1)
    }

    @Test("Should return nil for non-existent recipe")
    func testFetchNonExistentRecipe() async throws {
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let nonExistentId = UUID()
        let fetched = try await repository.fetchRecipe(byId: nonExistentId)

        #expect(fetched == nil)
    }

    @Test("Should fetch all recipes")
    func testFetchAllRecipes() async throws {
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let recipe1 = createTestRecipe(title: "Recipe 1")
        let recipe2 = createTestRecipe(title: "Recipe 2")

        _ = try await repository.createRecipe(recipe1)
        _ = try await repository.createRecipe(recipe2)

        let all = try await repository.fetchAllRecipes()

        #expect(all.count == 2)
        #expect(all.contains { $0.title == "Recipe 1" })
        #expect(all.contains { $0.title == "Recipe 2" })
    }

    @Test("Should update a recipe")
    func testUpdateRecipe() async throws {
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let recipe = createTestRecipe(title: "Original Title")
        _ = try await repository.createRecipe(recipe)

        let updated = RecipeModel(
            id: recipe.id,
            title: "Updated Title",
            descriptionText: "Updated description",
            measurementType: .byRatio,
            ingredients: recipe.ingredients
        )

        let result = try await repository.updateRecipe(updated)

        #expect(result.title == "Updated Title")
        #expect(result.descriptionText == "Updated description")
        #expect(result.measurementType == .byRatio)

        // Verify in database
        let fetched = try await repository.fetchRecipe(byId: recipe.id)
        #expect(fetched?.title == "Updated Title")
    }

    @Test("Should throw when updating non-existent recipe")
    func testUpdateNonExistentRecipe() async throws {
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let recipe = createTestRecipe()

        await #expect(throws: RecipeRepositoryError.self) {
            _ = try await repository.updateRecipe(recipe)
        }
    }

    @Test("Should delete a recipe")
    func testDeleteRecipe() async throws {
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let recipe = createTestRecipe()
        _ = try await repository.createRecipe(recipe)

        try await repository.deleteRecipe(id: recipe.id)

        let fetched = try await repository.fetchRecipe(byId: recipe.id)
        #expect(fetched == nil)
    }

    @Test("Should throw when deleting non-existent recipe")
    func testDeleteNonExistentRecipe() async throws {
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let nonExistentId = UUID()

        await #expect(throws: RecipeRepositoryError.self) {
            try await repository.deleteRecipe(id: nonExistentId)
        }
    }

    // MARK: - Search Tests

    @Test("Should search recipes by title")
    func testSearchRecipesByTitle() async throws {
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let recipe1 = createTestRecipe(title: "Clear Frit Mix")
        let recipe2 = createTestRecipe(title: "Blue Powder")
        let recipe3 = createTestRecipe(title: "Clear Glass Base")

        _ = try await repository.createRecipe(recipe1)
        _ = try await repository.createRecipe(recipe2)
        _ = try await repository.createRecipe(recipe3)

        let results = try await repository.searchRecipes(byTitle: "Clear")

        #expect(results.count == 2)
        #expect(results.contains { $0.title == "Clear Frit Mix" })
        #expect(results.contains { $0.title == "Clear Glass Base" })
    }

    @Test("Should search recipes case-insensitively")
    func testSearchRecipesCaseInsensitive() async throws {
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let recipe = createTestRecipe(title: "Blue Powder")
        _ = try await repository.createRecipe(recipe)

        let results = try await repository.searchRecipes(byTitle: "blue")

        #expect(results.count == 1)
        #expect(results.first?.title == "Blue Powder")
    }

    @Test("Should fetch recipes by measurement type")
    func testFetchRecipesByMeasurementType() async throws {
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let recipe1 = createTestRecipe(title: "Weight Recipe", measurementType: .byWeight)
        let recipe2 = createTestRecipe(title: "Ratio Recipe", measurementType: .byRatio)
        let recipe3 = createTestRecipe(title: "Another Weight", measurementType: .byWeight)

        _ = try await repository.createRecipe(recipe1)
        _ = try await repository.createRecipe(recipe2)
        _ = try await repository.createRecipe(recipe3)

        let weightRecipes = try await repository.fetchRecipes(byMeasurementType: .byWeight)
        let ratioRecipes = try await repository.fetchRecipes(byMeasurementType: .byRatio)

        #expect(weightRecipes.count == 2)
        #expect(ratioRecipes.count == 1)
        #expect(ratioRecipes.first?.title == "Ratio Recipe")
    }

    @Test("Should fetch recipes containing specific ingredient")
    func testFetchRecipesContainingIngredient() async throws {
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let bullseyeIngredient = createTestIngredient(stableId: "bullseye-001-0")
        let spectrumIngredient = createTestIngredient(stableId: "spectrum-030-0")

        let recipe1 = createTestRecipe(title: "Recipe 1", ingredients: [bullseyeIngredient])
        let recipe2 = createTestRecipe(title: "Recipe 2", ingredients: [spectrumIngredient])
        let recipe3 = createTestRecipe(title: "Recipe 3", ingredients: [bullseyeIngredient, spectrumIngredient])

        _ = try await repository.createRecipe(recipe1)
        _ = try await repository.createRecipe(recipe2)
        _ = try await repository.createRecipe(recipe3)

        let bullseyeRecipes = try await repository.fetchRecipes(containingIngredient: "bullseye-001-0")

        #expect(bullseyeRecipes.count == 2)
        #expect(bullseyeRecipes.contains { $0.title == "Recipe 1" })
        #expect(bullseyeRecipes.contains { $0.title == "Recipe 3" })
    }

    // MARK: - Ingredient Tests

    @Test("Should handle recipes with multiple ingredients")
    func testMultipleIngredients() async throws {
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let ingredients = [
            createTestIngredient(stableId: "bullseye-001-0", amount: 50.0),
            createTestIngredient(stableId: "bullseye-100-0", amount: 30.0),
            createTestIngredient(stableId: "spectrum-030-0", amount: 20.0)
        ]

        let recipe = createTestRecipe(ingredients: ingredients)
        _ = try await repository.createRecipe(recipe)

        let fetched = try await repository.fetchRecipe(byId: recipe.id)

        #expect(fetched?.ingredients.count == 3)
        #expect(fetched?.ingredients.contains { $0.stableId == "bullseye-001-0" && $0.amount == 50.0 } == true)
    }

    @Test("Should update recipe ingredients")
    func testUpdateRecipeIngredients() async throws {
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let ingredient1 = createTestIngredient(stableId: "bullseye-001-0")
        let recipe = createTestRecipe(ingredients: [ingredient1])
        _ = try await repository.createRecipe(recipe)

        let ingredient2 = createTestIngredient(stableId: "spectrum-030-0")
        let updatedRecipe = RecipeModel(
            id: recipe.id,
            title: recipe.title,
            descriptionText: recipe.descriptionText,
            measurementType: recipe.measurementType,
            ingredients: [ingredient1, ingredient2]
        )

        _ = try await repository.updateRecipe(updatedRecipe)

        let fetched = try await repository.fetchRecipe(byId: recipe.id)
        #expect(fetched?.ingredients.count == 2)
    }

    // MARK: - Edge Cases

    @Test("Should handle empty ingredients list")
    func testEmptyIngredientsList() async throws {
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let recipe = createTestRecipe(ingredients: [])
        let created = try await repository.createRecipe(recipe)

        #expect(created.ingredients.isEmpty)

        let fetched = try await repository.fetchRecipe(byId: recipe.id)
        #expect(fetched?.ingredients.isEmpty == true)
    }

    @Test("Should handle empty search results")
    func testEmptySearchResults() async throws {
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let results = try await repository.searchRecipes(byTitle: "NonExistent")

        #expect(results.isEmpty)
    }

    @Test("Should handle fetching all recipes when none exist")
    func testFetchAllRecipesEmpty() async throws {
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let all = try await repository.fetchAllRecipes()

        #expect(all.isEmpty)
    }
}
