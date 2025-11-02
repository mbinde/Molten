//
//  RecipeModelTests.swift
//  MoltenTests
//
//  Tests for Recipe domain models
//

import Testing
import Foundation
@testable import Molten

@Suite("RecipeModel Tests")
struct RecipeModelTests {

    @Test("FritIngredientModel should initialize with required properties")
    func testFritIngredientModelInitialization() async throws {
        // Arrange & Act
        let ingredient = FritIngredientModel(
            id: UUID(),
            stableId: "bullseye-clear-001",
            amount: 2.5
        )

        // Assert
        #expect(ingredient.stableId == "bullseye-clear-001")
        #expect(ingredient.amount == 2.5)
    }

    @Test("FritIngredientModel should be equatable")
    func testFritIngredientModelEquatable() async throws {
        // Arrange
        let id = UUID()
        let ingredient1 = FritIngredientModel(
            id: id,
            stableId: "bullseye-clear-001",
            amount: 2.5
        )
        let ingredient2 = FritIngredientModel(
            id: id,
            stableId: "bullseye-clear-001",
            amount: 2.5
        )
        let ingredient3 = FritIngredientModel(
            id: UUID(),
            stableId: "bullseye-clear-001",
            amount: 2.5
        )

        // Assert
        #expect(ingredient1 == ingredient2)
        #expect(ingredient1 != ingredient3)
    }

    @Test("FritRecipeModel should initialize with required properties")
    func testFritRecipeModelInitialization() async throws {
        // Arrange & Act
        let id = UUID()
        let now = Date()
        let recipe = FritRecipeModel(
            id: id,
            title: "Test Frit Recipe",
            descriptionText: "A test recipe",
            measurementType: .byWeight,
            ingredients: [],
            dateCreated: now,
            dateModified: now
        )

        // Assert
        #expect(recipe.id == id)
        #expect(recipe.title == "Test Frit Recipe")
        #expect(recipe.descriptionText == "A test recipe")
        #expect(recipe.measurementType == .byWeight)
        #expect(recipe.ingredients.isEmpty)
        #expect(recipe.dateCreated == now)
        #expect(recipe.dateModified == now)
    }

    @Test("FritRecipeModel should support byRatio measurement type")
    func testFritRecipeModelByRatio() async throws {
        // Arrange & Act
        let recipe = FritRecipeModel(
            id: UUID(),
            title: "Ratio Recipe",
            descriptionText: "Uses ratios",
            measurementType: .byRatio,
            ingredients: [],
            dateCreated: Date(),
            dateModified: Date()
        )

        // Assert
        #expect(recipe.measurementType == .byRatio)
    }

    @Test("FritRecipeModel should store multiple ingredients")
    func testFritRecipeModelWithIngredients() async throws {
        // Arrange
        let ingredient1 = FritIngredientModel(
            id: UUID(),
            stableId: "bullseye-clear-001",
            amount: 2.0
        )
        let ingredient2 = FritIngredientModel(
            id: UUID(),
            stableId: "bullseye-black-001",
            amount: 1.0
        )

        // Act
        let recipe = FritRecipeModel(
            id: UUID(),
            title: "Two Color Frit",
            descriptionText: "Clear and black",
            measurementType: .byRatio,
            ingredients: [ingredient1, ingredient2],
            dateCreated: Date(),
            dateModified: Date()
        )

        // Assert
        #expect(recipe.ingredients.count == 2)
        #expect(recipe.ingredients[0].stableId == "bullseye-clear-001")
        #expect(recipe.ingredients[1].stableId == "bullseye-black-001")
    }

    @Test("FritRecipeModel should validate title is not empty")
    func testFritRecipeModelValidation() async throws {
        // This test validates that business rules exist for recipe creation
        // The model should enforce non-empty titles

        let emptyTitleRecipe = FritRecipeModel(
            id: UUID(),
            title: "",
            descriptionText: "Test",
            measurementType: .byWeight,
            ingredients: [],
            dateCreated: Date(),
            dateModified: Date()
        )

        #expect(!FritRecipeModel.isValidTitle(emptyTitleRecipe.title))
    }

    @Test("FritRecipeModel should validate title length")
    func testFritRecipeModelTitleLength() async throws {
        let tooLongTitle = String(repeating: "a", count: 101)
        let validTitle = "Valid Recipe Title"

        #expect(!FritRecipeModel.isValidTitle(tooLongTitle))
        #expect(FritRecipeModel.isValidTitle(validTitle))
    }

    @Test("FritMeasurementType should have correct raw values")
    func testFritMeasurementTypeRawValues() async throws {
        #expect(FritMeasurementType.byWeight.rawValue == "weight")
        #expect(FritMeasurementType.byRatio.rawValue == "ratio")
    }

    @Test("FritMeasurementType should have display names")
    func testFritMeasurementTypeDisplayNames() async throws {
        #expect(FritMeasurementType.byWeight.displayName == "By Weight")
        #expect(FritMeasurementType.byRatio.displayName == "By Ratio")
    }
}
