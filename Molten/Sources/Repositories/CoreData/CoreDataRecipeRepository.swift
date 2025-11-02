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

    func fetchAllFritRecipes() async throws -> [FritRecipeModel] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[FritRecipeModel], Error>) in
            context.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "FritRecipe")
                    fetchRequest.sortDescriptors = [
                        NSSortDescriptor(key: "date_created", ascending: false)
                    ]

                    let coreDataRecipes = try self.context.fetch(fetchRequest)
                    let recipes = coreDataRecipes.compactMap { self.convertToFritRecipeModel($0) }

                    self.log.debug("Fetched \(recipes.count) frit recipes")
                    continuation.resume(returning: recipes)

                } catch {
                    self.log.error("Failed to fetch frit recipes: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchFritRecipe(byId id: UUID) async throws -> FritRecipeModel? {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<FritRecipeModel?, Error>) in
            context.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "FritRecipe")
                    fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                    fetchRequest.fetchLimit = 1

                    let results = try self.context.fetch(fetchRequest)
                    let recipe = results.first.flatMap { self.convertToFritRecipeModel($0) }

                    if recipe != nil {
                        self.log.debug("Found frit recipe with ID: \(id)")
                    } else {
                        self.log.debug("Frit recipe not found with ID: \(id)")
                    }

                    continuation.resume(returning: recipe)

                } catch {
                    self.log.error("Failed to fetch frit recipe by ID: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func createFritRecipe(_ recipe: FritRecipeModel) async throws -> FritRecipeModel {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<FritRecipeModel, Error>) in
            context.perform {
                do {
                    // Create new Core Data entity
                    guard let entity = NSEntityDescription.entity(forEntityName: "FritRecipe", in: self.context) else {
                        throw RecipeRepositoryError.persistenceError("FritRecipe entity not found")
                    }
                    let coreDataRecipe = NSManagedObject(entity: entity, insertInto: self.context)

                    // Set properties
                    self.updateCoreDataFritRecipe(coreDataRecipe, with: recipe)

                    // Save context
                    try self.context.save()

                    self.log.info("Created frit recipe: \(recipe.title)")
                    continuation.resume(returning: recipe)

                } catch {
                    self.log.error("Failed to create frit recipe: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func updateFritRecipe(_ recipe: FritRecipeModel) async throws -> FritRecipeModel {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<FritRecipeModel, Error>) in
            context.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "FritRecipe")
                    fetchRequest.predicate = NSPredicate(format: "id == %@", recipe.id as CVarArg)
                    fetchRequest.fetchLimit = 1

                    guard let coreDataRecipe = try self.context.fetch(fetchRequest).first else {
                        throw RecipeRepositoryError.recipeNotFound
                    }

                    // Update with new modification date
                    let updated = recipe.withUpdatedModificationDate()
                    self.updateCoreDataFritRecipe(coreDataRecipe, with: updated)

                    // Save context
                    try self.context.save()

                    self.log.info("Updated frit recipe: \(updated.title)")
                    continuation.resume(returning: updated)

                } catch {
                    self.log.error("Failed to update frit recipe: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func deleteFritRecipe(id: UUID) async throws {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "FritRecipe")
                    fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                    fetchRequest.fetchLimit = 1

                    guard let coreDataRecipe = try self.context.fetch(fetchRequest).first else {
                        throw RecipeRepositoryError.recipeNotFound
                    }

                    self.context.delete(coreDataRecipe)
                    try self.context.save()

                    self.log.info("Deleted frit recipe with ID: \(id)")
                    continuation.resume()

                } catch {
                    self.log.error("Failed to delete frit recipe: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Search Operations

    func searchFritRecipes(byTitle query: String) async throws -> [FritRecipeModel] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[FritRecipeModel], Error>) in
            context.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "FritRecipe")
                    fetchRequest.predicate = NSPredicate(format: "title CONTAINS[cd] %@", query)
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]

                    let coreDataRecipes = try self.context.fetch(fetchRequest)
                    let recipes = coreDataRecipes.compactMap { self.convertToFritRecipeModel($0) }

                    self.log.debug("Search '\(query)' found \(recipes.count) recipes")
                    continuation.resume(returning: recipes)

                } catch {
                    self.log.error("Failed to search frit recipes: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchFritRecipes(containingIngredient stableId: String) async throws -> [FritRecipeModel] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[FritRecipeModel], Error>) in
            context.perform {
                do {
                    // Fetch all ingredients with this stable_id
                    let ingredientFetch = NSFetchRequest<NSManagedObject>(entityName: "FritIngredient")
                    ingredientFetch.predicate = NSPredicate(format: "stable_id == %@", stableId)

                    let ingredients = try self.context.fetch(ingredientFetch)

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
                        continuation.resume(returning: [])
                        return
                    }

                    let recipeFetch = NSFetchRequest<NSManagedObject>(entityName: "FritRecipe")
                    recipeFetch.predicate = NSPredicate(format: "id IN %@", recipeIds)

                    let coreDataRecipes = try self.context.fetch(recipeFetch)
                    let recipes = coreDataRecipes.compactMap { self.convertToFritRecipeModel($0) }

                    self.log.debug("Found \(recipes.count) recipes containing ingredient \(stableId)")
                    continuation.resume(returning: recipes)

                } catch {
                    self.log.error("Failed to fetch recipes by ingredient: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchFritRecipes(byMeasurementType measurementType: FritMeasurementType) async throws -> [FritRecipeModel] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[FritRecipeModel], Error>) in
            context.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "FritRecipe")
                    fetchRequest.predicate = NSPredicate(format: "measurement_type == %@", measurementType.rawValue)
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]

                    let coreDataRecipes = try self.context.fetch(fetchRequest)
                    let recipes = coreDataRecipes.compactMap { self.convertToFritRecipeModel($0) }

                    self.log.debug("Found \(recipes.count) recipes with measurement type \(measurementType.rawValue)")
                    continuation.resume(returning: recipes)

                } catch {
                    self.log.error("Failed to fetch recipes by measurement type: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Private Conversion Methods

    private func convertToFritRecipeModel(_ coreDataRecipe: NSManagedObject) -> FritRecipeModel? {
        guard let id = coreDataRecipe.value(forKey: "id") as? UUID,
              let title = coreDataRecipe.value(forKey: "title") as? String,
              let dateCreated = coreDataRecipe.value(forKey: "date_created") as? Date,
              let dateModified = coreDataRecipe.value(forKey: "date_modified") as? Date else {
            log.error("Missing required fields in FritRecipe Core Data object")
            return nil
        }

        let descriptionText = coreDataRecipe.value(forKey: "description_text") as? String ?? ""
        let measurementTypeStr = coreDataRecipe.value(forKey: "measurement_type") as? String ?? "weight"
        let measurementType = FritMeasurementType(rawValue: measurementTypeStr) ?? .byWeight

        // Convert ingredients
        let ingredientsSet = coreDataRecipe.value(forKey: "ingredients") as? NSSet
        let ingredients = ingredientsSet?.allObjects.compactMap { obj -> FritIngredientModel? in
            guard let ingredient = obj as? NSManagedObject else { return nil }
            return self.convertToFritIngredientModel(ingredient)
        } ?? []

        return FritRecipeModel(
            id: id,
            title: title,
            descriptionText: descriptionText,
            measurementType: measurementType,
            ingredients: ingredients,
            dateCreated: dateCreated,
            dateModified: dateModified
        )
    }

    private func convertToFritIngredientModel(_ coreDataIngredient: NSManagedObject) -> FritIngredientModel? {
        guard let id = coreDataIngredient.value(forKey: "id") as? UUID,
              let stableId = coreDataIngredient.value(forKey: "stable_id") as? String else {
            log.error("Missing required fields in FritIngredient Core Data object")
            return nil
        }

        let amount = coreDataIngredient.value(forKey: "amount") as? Double ?? 0.0

        return FritIngredientModel(
            id: id,
            stableId: stableId,
            amount: amount
        )
    }

    private func updateCoreDataFritRecipe(_ coreDataRecipe: NSManagedObject, with model: FritRecipeModel) {
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
        for ingredientModel in model.ingredients {
            guard let entity = NSEntityDescription.entity(forEntityName: "FritIngredient", in: context) else {
                log.error("FritIngredient entity not found")
                continue
            }
            let coreDataIngredient = NSManagedObject(entity: entity, insertInto: context)
            coreDataIngredient.setValue(ingredientModel.id, forKey: "id")
            coreDataIngredient.setValue(ingredientModel.stableId, forKey: "stable_id")
            coreDataIngredient.setValue(ingredientModel.amount, forKey: "amount")
            coreDataIngredient.setValue(coreDataRecipe, forKey: "recipe")
        }
    }
}
