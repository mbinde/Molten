//
//  MockRecipeRepositoryTests.swift
//  MoltenTests
//
//  Tests for MockRecipeRepository
//

import Testing
import Foundation
@testable import Molten

@Suite("MockRecipeRepository Tests")
@MainActor
struct MockRecipeRepositoryTests {

    @Test("Should create and fetch recipe")
    func testCreateAndFetchRecipe() async throws {
        // Arrange
        let repository = MockRecipeRepository()
        let recipe = RecipeModel(
            title: "Test Recipe",
            descriptionText: "A test",
            measurementType: .byWeight,
            ingredients: []
        )

        // Act
        let created = try await repository.createRecipe(recipe)
        let fetched = try await repository.fetchRecipe(byId: created.id)

        // Assert
        #expect(fetched != nil)
        #expect(fetched?.title == "Test Recipe")
        #expect(fetched?.measurementType == .byWeight)
    }

    @Test("Should fetch all recipes")
    func testFetchAllRecipes() async throws {
        // Arrange
        let repository = MockRecipeRepository()
        let recipe1 = RecipeModel(title: "Recipe 1", descriptionText: "", measurementType: .byWeight, ingredients: [])
        let recipe2 = RecipeModel(title: "Recipe 2", descriptionText: "", measurementType: .byRatio, ingredients: [])

        // Act
        _ = try await repository.createRecipe(recipe1)
        _ = try await repository.createRecipe(recipe2)
        let all = try await repository.fetchAllRecipes()

        // Assert
        #expect(all.count == 2)
    }

    @Test("Should update recipe")
    func testUpdateRecipe() async throws {
        // Arrange
        let repository = MockRecipeRepository()
        let recipe = RecipeModel(
            title: "Original",
            descriptionText: "Original description",
            measurementType: .byWeight,
            ingredients: []
        )
        let created = try await repository.createRecipe(recipe)

        // Act
        let updated = RecipeModel(
            id: created.id,
            title: "Updated",
            descriptionText: "Updated description",
            measurementType: .byRatio,
            ingredients: [],
            dateCreated: created.dateCreated,
            dateModified: Date()
        )
        let result = try await repository.updateRecipe(updated)

        // Assert
        #expect(result.title == "Updated")
        #expect(result.descriptionText == "Updated description")
        #expect(result.measurementType == .byRatio)
    }

    @Test("Should delete recipe")
    func testDeleteRecipe() async throws {
        // Arrange
        let repository = MockRecipeRepository()
        let recipe = RecipeModel(title: "To Delete", descriptionText: "", measurementType: .byWeight, ingredients: [])
        let created = try await repository.createRecipe(recipe)

        // Act
        try await repository.deleteRecipe(id: created.id)
        let fetched = try await repository.fetchRecipe(byId: created.id)

        // Assert
        #expect(fetched == nil)
    }

    @Test("Should search recipes by title")
    func testSearchRecipesByTitle() async throws {
        // Arrange
        let repository = MockRecipeRepository()
        _ = try await repository.createRecipe(RecipeModel(title: "Clear Glass Mix", descriptionText: "", measurementType: .byWeight, ingredients: []))
        _ = try await repository.createRecipe(RecipeModel(title: "Black Frit", descriptionText: "", measurementType: .byWeight, ingredients: []))
        _ = try await repository.createRecipe(RecipeModel(title: "Blue Clear Combo", descriptionText: "", measurementType: .byWeight, ingredients: []))

        // Act
        let results = try await repository.searchRecipes(byTitle: "clear")

        // Assert
        #expect(results.count == 2) // "Clear Glass Mix" and "Blue Clear Combo"
    }

    @Test("Should fetch recipes containing specific ingredient")
    func testFetchRecipesContainingIngredient() async throws {
        // Arrange
        let repository = MockRecipeRepository()

        let ingredient1 = RecipeIngredientModel(stableId: "bullseye-clear-001", amount: 2.0)
        let ingredient2 = RecipeIngredientModel(stableId: "bullseye-black-001", amount: 1.0)

        let recipe1 = RecipeModel(
            title: "Clear Mix",
            descriptionText: "",
            measurementType: .byRatio,
            ingredients: [ingredient1]
        )
        let recipe2 = RecipeModel(
            title: "Black Mix",
            descriptionText: "",
            measurementType: .byRatio,
            ingredients: [ingredient2]
        )
        let recipe3 = RecipeModel(
            title: "Clear and Black",
            descriptionText: "",
            measurementType: .byRatio,
            ingredients: [ingredient1, ingredient2]
        )

        _ = try await repository.createRecipe(recipe1)
        _ = try await repository.createRecipe(recipe2)
        _ = try await repository.createRecipe(recipe3)

        // Act
        let results = try await repository.fetchRecipes(containingIngredient: "bullseye-clear-001")

        // Assert
        #expect(results.count == 2) // "Clear Mix" and "Clear and Black"
    }

    @Test("Should fetch recipes by measurement type")
    func testFetchRecipesByMeasurementType() async throws {
        // Arrange
        let repository = MockRecipeRepository()
        _ = try await repository.createRecipe(RecipeModel(title: "Weight 1", descriptionText: "", measurementType: .byWeight, ingredients: []))
        _ = try await repository.createRecipe(RecipeModel(title: "Ratio 1", descriptionText: "", measurementType: .byRatio, ingredients: []))
        _ = try await repository.createRecipe(RecipeModel(title: "Weight 2", descriptionText: "", measurementType: .byWeight, ingredients: []))

        // Act
        let weightRecipes = try await repository.fetchRecipes(byMeasurementType: .byWeight)
        let ratioRecipes = try await repository.fetchRecipes(byMeasurementType: .byRatio)

        // Assert
        #expect(weightRecipes.count == 2)
        #expect(ratioRecipes.count == 1)
    }

    @Test("Should throw error when updating non-existent recipe")
    func testUpdateNonExistentRecipe() async throws {
        // Arrange
        let repository = MockRecipeRepository()
        let recipe = RecipeModel(
            id: UUID(),
            title: "Non-existent",
            descriptionText: "",
            measurementType: .byWeight,
            ingredients: [],
            dateCreated: Date(),
            dateModified: Date()
        )

        // Act & Assert
        await #expect(throws: RecipeRepositoryError.self) {
            try await repository.updateRecipe(recipe)
        }
    }

    @Test("Should throw error when deleting non-existent recipe")
    func testDeleteNonExistentRecipe() async throws {
        // Arrange
        let repository = MockRecipeRepository()
        let nonExistentId = UUID()

        // Act & Assert
        await #expect(throws: RecipeRepositoryError.self) {
            try await repository.deleteRecipe(id: nonExistentId)
        }
    }

    @Test("Should clear all recipes")
    func testClearAllRecipes() async throws {
        // Arrange
        let repository = MockRecipeRepository()
        _ = try await repository.createRecipe(RecipeModel(title: "Recipe 1", descriptionText: "", measurementType: .byWeight, ingredients: []))
        _ = try await repository.createRecipe(RecipeModel(title: "Recipe 2", descriptionText: "", measurementType: .byWeight, ingredients: []))

        // Act
        repository.clear()
        let count = await repository.count()

        // Assert
        #expect(count == 0)
    }
}
