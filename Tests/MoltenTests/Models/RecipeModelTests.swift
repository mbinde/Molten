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
@MainActor
struct RecipeModelTests {

    @Test("RecipeIngredientModel should initialize with required properties")
    func testRecipeIngredientModelInitialization() async throws {
        // Arrange & Act
        let ingredient = RecipeIngredientModel(
            id: UUID(),
            stableId: "bullseye-clear-001",
            amount: 2.5
        )

        // Assert
        #expect(ingredient.stableId == "bullseye-clear-001")
        #expect(ingredient.amount == 2.5)
    }

    @Test("RecipeIngredientModel should be equatable")
    func testRecipeIngredientModelEquatable() async throws {
        // Arrange
        let id = UUID()
        let ingredient1 = RecipeIngredientModel(
            id: id,
            stableId: "bullseye-clear-001",
            amount: 2.5
        )
        let ingredient2 = RecipeIngredientModel(
            id: id,
            stableId: "bullseye-clear-001",
            amount: 2.5
        )
        let ingredient3 = RecipeIngredientModel(
            id: UUID(),
            stableId: "bullseye-clear-001",
            amount: 2.5
        )

        // Assert
        #expect(ingredient1 == ingredient2)
        #expect(ingredient1 != ingredient3)
    }

    @Test("RecipeModel should initialize with required properties")
    func testRecipeModelInitialization() async throws {
        // Arrange & Act
        let id = UUID()
        let now = Date()
        let recipe = RecipeModel(
            id: id,
            title: "Test Recipe",
            descriptionText: "A test recipe",
            measurementType: .byWeight,
            ingredients: [],
            dateCreated: now,
            dateModified: now
        )

        // Assert
        #expect(recipe.id == id)
        #expect(recipe.title == "Test Recipe")
        #expect(recipe.descriptionText == "A test recipe")
        #expect(recipe.measurementType == .byWeight)
        #expect(recipe.ingredients.isEmpty)
        #expect(recipe.dateCreated == now)
        #expect(recipe.dateModified == now)
    }

    @Test("RecipeModel should support byRatio measurement type")
    func testRecipeModelByRatio() async throws {
        // Arrange & Act
        let recipe = RecipeModel(
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

    @Test("RecipeModel should store multiple ingredients")
    func testRecipeModelWithIngredients() async throws {
        // Arrange
        let ingredient1 = RecipeIngredientModel(
            id: UUID(),
            stableId: "bullseye-clear-001",
            amount: 2.0
        )
        let ingredient2 = RecipeIngredientModel(
            id: UUID(),
            stableId: "bullseye-black-001",
            amount: 1.0
        )

        // Act
        let recipe = RecipeModel(
            id: UUID(),
            title: "Two Color Mix",
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

    @Test("RecipeModel should validate title is not empty")
    func testRecipeModelValidation() async throws {
        // This test validates that business rules exist for recipe creation
        // The model should enforce non-empty titles

        let emptyTitleRecipe = RecipeModel(
            id: UUID(),
            title: "",
            descriptionText: "Test",
            measurementType: .byWeight,
            ingredients: [],
            dateCreated: Date(),
            dateModified: Date()
        )

        #expect(!RecipeModel.isValidTitle(emptyTitleRecipe.title))
    }

    @Test("RecipeModel should validate title length")
    func testRecipeModelTitleLength() async throws {
        let tooLongTitle = String(repeating: "a", count: 101)
        let validTitle = "Valid Recipe Title"

        #expect(!RecipeModel.isValidTitle(tooLongTitle))
        #expect(RecipeModel.isValidTitle(validTitle))
    }

    @Test("MeasurementType should have correct raw values")
    func testMeasurementTypeRawValues() async throws {
        #expect(MeasurementType.byWeight.rawValue == "weight")
        #expect(MeasurementType.byRatio.rawValue == "ratio")
    }

    @Test("MeasurementType should have display names")
    func testMeasurementTypeDisplayNames() async throws {
        #expect(MeasurementType.byWeight.displayName == "By Weight")
        #expect(MeasurementType.byRatio.displayName == "By Ratio")
    }
}
