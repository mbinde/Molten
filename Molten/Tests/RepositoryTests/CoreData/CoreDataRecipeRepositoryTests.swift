//
//  CoreDataRecipeRepositoryTests.swift
//  RepositoryTests
//
//  Tests for CoreDataRecipeRepository - manages frit recipes
//

import Testing
import Foundation
import CoreData
@testable import Molten

@Suite("Core Data Recipe Repository Tests")
@MainActor
struct CoreDataRecipeRepositoryTests {

    // MARK: - Create Tests

    @Test("Should create recipe")
    func testCreateRecipe() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let recipe = RecipeModel(
            title: "Test Recipe",
            technique: .fusing,
            notes: "Test notes"
        )

        // Test
        let created = try await repository.createRecipe(recipe)

        // Verify
        #expect(created.title == "Test Recipe")
        #expect(created.technique == .fusing)
        #expect(created.notes == "Test notes")
    }

    @Test("Should create recipe with minimal data")
    func testCreateRecipeMinimal() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let recipe = RecipeModel(
            title: "Minimal Recipe"
        )

        // Test
        let created = try await repository.createRecipe(recipe)

        // Verify
        #expect(created.title == "Minimal Recipe")
    }

    // MARK: - Read Tests

    @Test("Should fetch recipe by ID")
    func testFetchRecipeById() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let recipeId = UUID()
        let recipe = RecipeModel(
            id: recipeId,
            title: "Test Recipe"
        )
        _ = try await repository.createRecipe(recipe)

        // Test
        let fetched = try await repository.fetchRecipe(byId: recipeId)

        // Verify
        #expect(fetched != nil)
        #expect(fetched?.id == recipeId)
        #expect(fetched?.title == "Test Recipe")
    }

    @Test("Should return nil for non-existent recipe")
    func testFetchNonExistentRecipe() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        // Test
        let fetched = try await repository.fetchRecipe(byId: UUID())

        // Verify
        #expect(fetched == nil)
    }

    @Test("Should fetch all recipes")
    func testFetchAllRecipes() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        _ = try await repository.createRecipe(RecipeModel(title: "Recipe 1"))
        _ = try await repository.createRecipe(RecipeModel(title: "Recipe 2"))

        // Test
        let recipes = try await repository.fetchAllRecipes()

        // Verify
        #expect(recipes.count == 2)
    }

    @Test("Should fetch recipes sorted by date created")
    func testFetchRecipesSortedByDate() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let date1 = Date(timeIntervalSince1970: 1000)
        let date2 = Date(timeIntervalSince1970: 2000)

        _ = try await repository.createRecipe(RecipeModel(
            title: "Older Recipe",
            dateCreated: date1
        ))
        _ = try await repository.createRecipe(RecipeModel(
            title: "Newer Recipe",
            dateCreated: date2
        ))

        // Test
        let recipes = try await repository.fetchAllRecipes()

        // Verify - should be sorted newest first
        #expect(recipes.count == 2)
        #expect(recipes[0].title == "Newer Recipe")
        #expect(recipes[1].title == "Older Recipe")
    }

    // MARK: - Update Tests

    @Test("Should update existing recipe")
    func testUpdateRecipe() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let recipeId = UUID()
        let original = RecipeModel(
            id: recipeId,
            title: "Original Title"
        )
        _ = try await repository.createRecipe(original)

        // Test
        let updated = RecipeModel(
            id: recipeId,
            title: "Updated Title",
            notes: "Updated notes"
        )
        _ = try await repository.updateRecipe(updated)

        // Verify
        let fetched = try await repository.fetchRecipe(byId: recipeId)
        #expect(fetched?.title == "Updated Title")
        #expect(fetched?.notes == "Updated notes")
    }

    @Test("Should throw error when updating non-existent recipe")
    func testUpdateNonExistentRecipe() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let recipe = RecipeModel(title: "Test Recipe")

        // Test & Verify
        do {
            _ = try await repository.updateRecipe(recipe)
            Issue.record("Expected error for updating non-existent recipe")
        } catch {
            // Expected error
        }
    }

    // MARK: - Delete Tests

    @Test("Should delete recipe")
    func testDeleteRecipe() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let recipeId = UUID()
        let recipe = RecipeModel(
            id: recipeId,
            title: "Test Recipe"
        )
        _ = try await repository.createRecipe(recipe)

        // Test
        try await repository.deleteRecipe(id: recipeId)

        // Verify
        let fetched = try await repository.fetchRecipe(byId: recipeId)
        #expect(fetched == nil)
    }

    @Test("Should delete all recipes")
    func testDeleteAllRecipes() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        _ = try await repository.createRecipe(RecipeModel(title: "Recipe 1"))
        _ = try await repository.createRecipe(RecipeModel(title: "Recipe 2"))

        // Test
        try await repository.deleteAllRecipes()

        // Verify
        let recipes = try await repository.fetchAllRecipes()
        #expect(recipes.isEmpty)
    }

    // MARK: - Search Tests

    @Test("Should search recipes by title")
    func testSearchRecipesByTitle() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        _ = try await repository.createRecipe(RecipeModel(
            title: "Fusing Recipe"
        ))
        _ = try await repository.createRecipe(RecipeModel(
            title: "Casting Recipe"
        ))

        // Test
        let results = try await repository.searchRecipes(query: "Fusing")

        // Verify
        #expect(results.count == 1)
        #expect(results[0].title == "Fusing Recipe")
    }

    @Test("Should search recipes by notes")
    func testSearchRecipesByNotes() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        _ = try await repository.createRecipe(RecipeModel(
            title: "Recipe 1",
            notes: "Special technique"
        ))
        _ = try await repository.createRecipe(RecipeModel(
            title: "Recipe 2",
            notes: "Standard process"
        ))

        // Test
        let results = try await repository.searchRecipes(query: "Special")

        // Verify
        #expect(results.count == 1)
        #expect(results[0].notes == "Special technique")
    }

    // MARK: - Filter Tests

    @Test("Should get recipes by technique")
    func testGetRecipesByTechnique() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        _ = try await repository.createRecipe(RecipeModel(
            title: "Fusing Recipe",
            technique: .fusing
        ))
        _ = try await repository.createRecipe(RecipeModel(
            title: "Casting Recipe",
            technique: .casting
        ))

        // Test
        let fusingRecipes = try await repository.getRecipes(byTechnique: .fusing)

        // Verify
        #expect(fusingRecipes.count == 1)
        #expect(fusingRecipes[0].title == "Fusing Recipe")
    }

    @Test("Should get recipes sorted by title")
    func testGetRecipesSortedByTitle() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        _ = try await repository.createRecipe(RecipeModel(title: "Z Recipe"))
        _ = try await repository.createRecipe(RecipeModel(title: "A Recipe"))
        _ = try await repository.createRecipe(RecipeModel(title: "M Recipe"))

        // Test
        let recipes = try await repository.getRecipesSortedByTitle()

        // Verify
        #expect(recipes.count == 3)
        #expect(recipes[0].title == "A Recipe")
        #expect(recipes[1].title == "M Recipe")
        #expect(recipes[2].title == "Z Recipe")
    }

    // MARK: - Count Tests

    @Test("Should get recipe count")
    func testGetRecipeCount() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        _ = try await repository.createRecipe(RecipeModel(title: "Recipe 1"))
        _ = try await repository.createRecipe(RecipeModel(title: "Recipe 2"))

        // Test
        let count = try await repository.getRecipeCount()

        // Verify
        #expect(count == 2)
    }

    // MARK: - Helper Methods

    private func createTestRepository(controller: PersistenceController) -> CoreDataRecipeRepository {
        RepositoryFactory.configureForTestingWithCoreData(controller: controller)
        return CoreDataRecipeRepository(context: controller.container.viewContext)
    }
}
