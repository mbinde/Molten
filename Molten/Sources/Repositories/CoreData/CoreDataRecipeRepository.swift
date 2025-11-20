//
//  CoreDataRecipeRepository.swift
//  Molten
//
//  Core Data implementation of RecipeRepository
//

@preconcurrency import CoreData
import Foundation
import OSLog

/// Core Data implementation of RecipeRepository
/// Provides persistent storage for recipes using Core Data with CloudKit sync
class CoreDataRecipeRepository: @unchecked Sendable, RecipeRepository {

    // MARK: - Dependencies

    private let context: NSManagedObjectContext
    private let log = Logger(subsystem: "com.molten.app", category: "recipe-repository")

    // MARK: - Initialization

    /// Initialize with a managed object context
    /// - Parameter context: The NSManagedObjectContext to use for data operations
    /// - Note: In production, pass PersistenceController.shared.cloudContext (user data)
    nonisolated init(context: NSManagedObjectContext) {
        self.context = context
        self.context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
    }

    // MARK: - Frit Recipe Operations

    func fetchAllRecipes() async throws -> [RecipeModel] {
        return try await CoreDataHelper.performAsync(on: context) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Recipe")
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(key: "date_created", ascending: false)
            ]

            let coreDataRecipes = try context.fetch(fetchRequest)
            let recipes = coreDataRecipes.compactMap { self.convertToRecipeModel($0) }

            self.log.debug("Fetched \(recipes.count) frit recipes")
            return recipes
        }
    }

    func fetchRecipe(byId id: UUID) async throws -> RecipeModel? {
        return try await CoreDataHelper.performAsync(on: context) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Recipe")
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            fetchRequest.fetchLimit = 1

            let results = try context.fetch(fetchRequest)
            let recipe = results.first.flatMap { self.convertToRecipeModel($0) }

            if recipe != nil {
                self.log.debug("Found frit recipe with ID: \(id)")
            } else {
                self.log.debug("Frit recipe not found with ID: \(id)")
            }

            return recipe
        }
    }

    func createRecipe(_ recipe: RecipeModel) async throws -> RecipeModel {
        return try await CoreDataHelper.performAsync(on: context) { context in
            // Create new Core Data entity
            guard let entity = NSEntityDescription.entity(forEntityName: "Recipe", in: context) else {
                throw RecipeRepositoryError.persistenceError("FritRecipe entity not found")
            }
            let coreDataRecipe = NSManagedObject(entity: entity, insertInto: context)

            // Set properties
            self.updateCoreDataFritRecipe(coreDataRecipe, with: recipe)

            // Save context
            try CoreDataErrorHandler.save(context: context)

            self.log.info("Created frit recipe: \(recipe.title)")
            return recipe
        }
    }

    func updateRecipe(_ recipe: RecipeModel) async throws -> RecipeModel {
        return try await CoreDataHelper.performAsync(on: context) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Recipe")
            fetchRequest.predicate = NSPredicate(format: "id == %@", recipe.id as CVarArg)
            fetchRequest.fetchLimit = 1

            guard let coreDataRecipe = try context.fetch(fetchRequest).first else {
                throw RecipeRepositoryError.recipeNotFound
            }

            // Update with new modification date
            let updated = recipe.withUpdatedModificationDate()
            self.updateCoreDataFritRecipe(coreDataRecipe, with: updated)

            // Save context
            try CoreDataErrorHandler.save(context: context)

            self.log.info("Updated frit recipe: \(updated.title)")
            return updated
        }
    }

    func deleteRecipe(id: UUID) async throws {
        try await CoreDataHelper.performAsyncVoid(on: context) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Recipe")
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            fetchRequest.fetchLimit = 1

            guard let coreDataRecipe = try context.fetch(fetchRequest).first else {
                throw RecipeRepositoryError.recipeNotFound
            }

            context.delete(coreDataRecipe)
            try CoreDataErrorHandler.save(context: context)

            self.log.info("Deleted frit recipe with ID: \(id)")
        }
    }

    // MARK: - Search Operations

    func searchRecipes(byTitle query: String) async throws -> [RecipeModel] {
        return try await CoreDataHelper.performAsync(on: context) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Recipe")
            fetchRequest.predicate = NSPredicate(format: "title CONTAINS[cd] %@", query)
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]

            let coreDataRecipes = try context.fetch(fetchRequest)
            let recipes = coreDataRecipes.compactMap { self.convertToRecipeModel($0) }

            self.log.debug("Search '\(query)' found \(recipes.count) recipes")
            return recipes
        }
    }

    func fetchRecipes(containingIngredient stableId: String) async throws -> [RecipeModel] {
        return try await CoreDataHelper.performAsync(on: context) { context in
            // Fetch all ingredients with this stable_id
            let ingredientFetch = NSFetchRequest<NSManagedObject>(entityName: "RecipeIngredient")
            ingredientFetch.predicate = NSPredicate(format: "stable_id == %@", stableId)

            let ingredients = try context.fetch(ingredientFetch)

            // Get unique recipe IDs from ingredients
            let recipeIds = ingredients.compactMap { ingredient -> UUID? in
                guard let recipe = ingredient.value(forKey: "recipe") as? NSManagedObject,
                      let id = recipe.value(forKey: "id") as? UUID else {
                    return nil
                }
                return id
            }

            // Fetch recipes with those IDs
            if recipeIds.isEmpty {
                return []
            }

            let recipeFetch = NSFetchRequest<NSManagedObject>(entityName: "Recipe")
            recipeFetch.predicate = NSPredicate(format: "id IN %@", recipeIds)

            let coreDataRecipes = try context.fetch(recipeFetch)
            let recipes = coreDataRecipes.compactMap { self.convertToRecipeModel($0) }

            self.log.debug("Found \(recipes.count) recipes containing ingredient \(stableId)")
            return recipes
        }
    }

    func fetchRecipes(byMeasurementType measurementType: MeasurementType) async throws -> [RecipeModel] {
        return try await CoreDataHelper.performAsync(on: context) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Recipe")
            fetchRequest.predicate = NSPredicate(format: "measurement_type == %@", measurementType.rawValue)
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]

            let coreDataRecipes = try context.fetch(fetchRequest)
            let recipes = coreDataRecipes.compactMap { self.convertToRecipeModel($0) }

            self.log.debug("Found \(recipes.count) recipes with measurement type \(measurementType.rawValue)")
            return recipes
        }
    }

    // MARK: - Private Conversion Methods

    private func convertToRecipeModel(_ coreDataRecipe: NSManagedObject) -> RecipeModel? {
        guard let id = coreDataRecipe.value(forKey: "id") as? UUID,
              let title = coreDataRecipe.value(forKey: "title") as? String,
              let dateCreated = coreDataRecipe.value(forKey: "date_created") as? Date,
              let dateModified = coreDataRecipe.value(forKey: "date_modified") as? Date else {
            log.error("Missing required fields in FritRecipe Core Data object")
            return nil
        }

        let descriptionText = coreDataRecipe.value(forKey: "description_text") as? String ?? ""
        let measurementTypeStr = coreDataRecipe.value(forKey: "measurement_type") as? String ?? "weight"
        let measurementType = MeasurementType(rawValue: measurementTypeStr) ?? .byWeight

        // Convert ingredients
        let ingredientsSet = coreDataRecipe.value(forKey: "ingredients") as? NSSet
        let ingredients = ingredientsSet?.allObjects.compactMap { obj -> RecipeIngredientModel? in
            guard let ingredient = obj as? NSManagedObject else { return nil }
            return self.convertToRecipeIngredientModel(ingredient)
        } ?? []

        return RecipeModel(
            id: id,
            title: title,
            descriptionText: descriptionText,
            measurementType: measurementType,
            ingredients: ingredients,
            dateCreated: dateCreated,
            dateModified: dateModified
        )
    }

    private func convertToRecipeIngredientModel(_ coreDataIngredient: NSManagedObject) -> RecipeIngredientModel? {
        guard let id = coreDataIngredient.value(forKey: "id") as? UUID,
              let stableId = coreDataIngredient.value(forKey: "stable_id") as? String else {
            log.error("Missing required fields in FritIngredient Core Data object")
            return nil
        }

        let amount = coreDataIngredient.value(forKey: "amount") as? Double ?? 0.0

        return RecipeIngredientModel(
            id: id,
            stableId: stableId,
            amount: amount
        )
    }

    private func updateCoreDataFritRecipe(_ coreDataRecipe: NSManagedObject, with model: RecipeModel) {
        coreDataRecipe.setValue(model.id, forKey: "id")
        coreDataRecipe.setValue(model.title, forKey: "title")
        coreDataRecipe.setValue(model.descriptionText, forKey: "description_text")
        coreDataRecipe.setValue(model.measurementType.rawValue, forKey: "measurement_type")
        coreDataRecipe.setValue(model.dateCreated, forKey: "date_created")
        coreDataRecipe.setValue(model.dateModified, forKey: "date_modified")

        // Delete existing ingredients
        if let existingIngredients = coreDataRecipe.value(forKey: "ingredients") as? NSSet {
            for case let ingredient as NSManagedObject in existingIngredients {
                context.delete(ingredient)
            }
        }

        // Create new ingredients
        // Use parent's mutableSetValue to add children, letting Core Data handle inverse relationship
        let ingredientsSet = coreDataRecipe.mutableSetValue(forKey: "ingredients")
        for ingredientModel in model.ingredients {
            guard let entity = NSEntityDescription.entity(forEntityName: "RecipeIngredient", in: context) else {
                log.error("FritIngredient entity not found")
                continue
            }
            let coreDataIngredient = NSManagedObject(entity: entity, insertInto: context)
            coreDataIngredient.setValue(ingredientModel.id, forKey: "id")
            coreDataIngredient.setValue(ingredientModel.stableId, forKey: "stable_id")
            coreDataIngredient.setValue(ingredientModel.amount, forKey: "amount")

            // Add to parent's collection instead of setting child's parent property
            // This avoids KVC issues with auto-generated Core Data classes
            ingredientsSet.add(coreDataIngredient)
        }
    }
}
