//
//  RecipeServiceTests.swift
//  MoltenTests
//
//  Tests for RecipeService
//

import Testing
import Foundation
@testable import Molten

@Suite("RecipeService Tests")
@MainActor
struct RecipeServiceTests {

    @Test("Should create recipe with valid title")
    func testCreateRecipeWithValidTitle() async throws {
        // Arrange
        let repository = MockRecipeRepository()
        let service = RecipeService(repository: repository)
        let recipe = RecipeModel(
            title: "Valid Recipe",
            descriptionText: "A valid recipe",
            measurementType: .byWeight,
            ingredients: []
        )

        // Act
        let created = try await service.createRecipe(recipe)

        // Assert
        #expect(created.title == "Valid Recipe")
    }

    @Test("Should reject recipe with empty title")
    func testCreateRecipeWithEmptyTitle() async throws {
        // Arrange
        let repository = MockRecipeRepository()
        let service = RecipeService(repository: repository)
        let recipe = RecipeModel(
            title: "",
            descriptionText: "Invalid",
            measurementType: .byWeight,
            ingredients: []
        )

        // Act & Assert
        await #expect(throws: RecipeServiceError.self) {
            try await service.createRecipe(recipe)
        }
    }

    @Test("Should reject recipe with too long title")
    func testCreateRecipeWithTooLongTitle() async throws {
        // Arrange
        let repository = MockRecipeRepository()
        let service = RecipeService(repository: repository)
        let recipe = RecipeModel(
            title: String(repeating: "a", count: 101),
            descriptionText: "Invalid",
            measurementType: .byWeight,
            ingredients: []
        )

        // Act & Assert
        await #expect(throws: RecipeServiceError.self) {
            try await service.createRecipe(recipe)
        }
    }

    @Test("Should get all recipes")
    func testGetAllRecipes() async throws {
        // Arrange
        let repository = MockRecipeRepository()
        let service = RecipeService(repository: repository)
        _ = try await service.createRecipe(RecipeModel(title: "Recipe 1", descriptionText: "", measurementType: .byWeight, ingredients: []))
        _ = try await service.createRecipe(RecipeModel(title: "Recipe 2", descriptionText: "", measurementType: .byRatio, ingredients: []))

        // Act
        let all = try await service.getAllRecipes()

        // Assert
        #expect(all.count == 2)
    }

    @Test("Should update recipe")
    func testUpdateRecipe() async throws {
        // Arrange
        let repository = MockRecipeRepository()
        let service = RecipeService(repository: repository)
        let recipe = RecipeModel(title: "Original", descriptionText: "Original", measurementType: .byWeight, ingredients: [])
        let created = try await service.createRecipe(recipe)

        // Act
        let updated = RecipeModel(
            id: created.id,
            title: "Updated",
            descriptionText: "Updated desc",
            measurementType: .byRatio,
            ingredients: [],
            dateCreated: created.dateCreated,
            dateModified: Date()
        )
        let result = try await service.updateRecipe(updated)

        // Assert
        #expect(result.title == "Updated")
        #expect(result.measurementType == .byRatio)
    }

    @Test("Should delete recipe")
    func testDeleteRecipe() async throws {
        // Arrange
        let repository = MockRecipeRepository()
        let service = RecipeService(repository: repository)
        let recipe = RecipeModel(title: "To Delete", descriptionText: "", measurementType: .byWeight, ingredients: [])
        let created = try await service.createRecipe(recipe)

        // Act
        try await service.deleteRecipe(id: created.id)
        let fetched = try await service.getRecipe(byId: created.id)

        // Assert
        #expect(fetched == nil)
    }

    @Test("Should search recipes by title")
    func testSearchRecipesByTitle() async throws {
        // Arrange
        let repository = MockRecipeRepository()
        let service = RecipeService(repository: repository)
        _ = try await service.createRecipe(RecipeModel(title: "Clear Mix", descriptionText: "", measurementType: .byWeight, ingredients: []))
        _ = try await service.createRecipe(RecipeModel(title: "Black Mix", descriptionText: "", measurementType: .byWeight, ingredients: []))
        _ = try await service.createRecipe(RecipeModel(title: "Clear and Black", descriptionText: "", measurementType: .byWeight, ingredients: []))

        // Act
        let results = try await service.searchRecipes(byTitle: "clear")

        // Assert
        #expect(results.count == 2)
    }

    @Test("Should return all recipes when search is empty")
    func testSearchWithEmptyQuery() async throws {
        // Arrange
        let repository = MockRecipeRepository()
        let service = RecipeService(repository: repository)
        _ = try await service.createRecipe(RecipeModel(title: "Recipe 1", descriptionText: "", measurementType: .byWeight, ingredients: []))
        _ = try await service.createRecipe(RecipeModel(title: "Recipe 2", descriptionText: "", measurementType: .byWeight, ingredients: []))

        // Act
        let results = try await service.searchRecipes(byTitle: "")

        // Assert
        #expect(results.count == 2)
    }

    @Test("Should get recipes containing specific ingredient")
    func testGetRecipesContainingIngredient() async throws {
        // Arrange
        let repository = MockRecipeRepository()
        let service = RecipeService(repository: repository)

        let ingredient1 = RecipeIngredientModel(stableId: "bullseye-clear-001", amount: 2.0)
        let ingredient2 = RecipeIngredientModel(stableId: "bullseye-black-001", amount: 1.0)

        _ = try await service.createRecipe(RecipeModel(
            title: "Clear Only",
            descriptionText: "",
            measurementType: .byRatio,
            ingredients: [ingredient1]
        ))
        _ = try await service.createRecipe(RecipeModel(
            title: "Both",
            descriptionText: "",
            measurementType: .byRatio,
            ingredients: [ingredient1, ingredient2]
        ))

        // Act
        let results = try await service.getRecipes(containingGlassItem: "bullseye-clear-001")

        // Assert
        #expect(results.count == 2)
    }

    @Test("Should get recipes by measurement type")
    func testGetRecipesByMeasurementType() async throws {
        // Arrange
        let repository = MockRecipeRepository()
        let service = RecipeService(repository: repository)
        _ = try await service.createRecipe(RecipeModel(title: "Weight", descriptionText: "", measurementType: .byWeight, ingredients: []))
        _ = try await service.createRecipe(RecipeModel(title: "Ratio", descriptionText: "", measurementType: .byRatio, ingredients: []))

        // Act
        let weightRecipes = try await service.getRecipes(byMeasurementType: .byWeight)
        let ratioRecipes = try await service.getRecipes(byMeasurementType: .byRatio)

        // Assert
        #expect(weightRecipes.count == 1)
        #expect(ratioRecipes.count == 1)
    }

    @Test("Should validate title correctly")
    func testIsValidTitle() async throws {
        // Arrange
        let repository = MockRecipeRepository()
        let service = RecipeService(repository: repository)

        // Act & Assert
        #expect(service.isValidTitle("Valid Title") == true)
        #expect(service.isValidTitle("") == false)
        #expect(service.isValidTitle("   ") == false)
        #expect(service.isValidTitle(String(repeating: "a", count: 100)) == true)
        #expect(service.isValidTitle(String(repeating: "a", count: 101)) == false)
    }

    @Test("Should get recipe count")
    func testGetRecipeCount() async throws {
        // Arrange
        let repository = MockRecipeRepository()
        let service = RecipeService(repository: repository)
        _ = try await service.createRecipe(RecipeModel(title: "Recipe 1", descriptionText: "", measurementType: .byWeight, ingredients: []))
        _ = try await service.createRecipe(RecipeModel(title: "Recipe 2", descriptionText: "", measurementType: .byWeight, ingredients: []))

        // Act
        let count = try await service.getRecipeCount()

        // Assert
        #expect(count == 2)
    }

    @Test("Should group recipes by measurement type")
    func testGetRecipesByMeasurementTypeGrouped() async throws {
        // Arrange
        let repository = MockRecipeRepository()
        let service = RecipeService(repository: repository)
        _ = try await service.createRecipe(RecipeModel(title: "Weight 1", descriptionText: "", measurementType: .byWeight, ingredients: []))
        _ = try await service.createRecipe(RecipeModel(title: "Weight 2", descriptionText: "", measurementType: .byWeight, ingredients: []))
        _ = try await service.createRecipe(RecipeModel(title: "Ratio 1", descriptionText: "", measurementType: .byRatio, ingredients: []))

        // Act
        let grouped = try await service.getRecipesByMeasurementType()

        // Assert
        #expect(grouped[.byWeight]?.count == 2)
        #expect(grouped[.byRatio]?.count == 1)
    }

    @Test("Should get most used ingredients")
    func testGetMostUsedIngredients() async throws {
        // Arrange
        let repository = MockRecipeRepository()
        let service = RecipeService(repository: repository)

        let clear = RecipeIngredientModel(stableId: "bullseye-clear-001", amount: 1.0)
        let black = RecipeIngredientModel(stableId: "bullseye-black-001", amount: 1.0)
        let red = RecipeIngredientModel(stableId: "bullseye-red-001", amount: 1.0)

        _ = try await service.createRecipe(RecipeModel(title: "Recipe 1", descriptionText: "", measurementType: .byRatio, ingredients: [clear, black]))
        _ = try await service.createRecipe(RecipeModel(title: "Recipe 2", descriptionText: "", measurementType: .byRatio, ingredients: [clear, red]))
        _ = try await service.createRecipe(RecipeModel(title: "Recipe 3", descriptionText: "", measurementType: .byRatio, ingredients: [clear]))

        // Act
        let mostUsed = try await service.getMostUsedIngredients(limit: 3)

        // Assert
        #expect(mostUsed.count == 3)
        #expect(mostUsed[0].stableId == "bullseye-clear-001")
        #expect(mostUsed[0].count == 3)
        #expect(mostUsed[1].count == 1)
        #expect(mostUsed[2].count == 1)
    }
}
