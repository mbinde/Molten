//
//  CoreDataUserNotesRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/16/25.
//

@preconcurrency import CoreData
import Foundation
import OSLog

/// Core Data implementation of UserNotesRepository
/// Provides persistent storage for user notes using Core Data
class CoreDataUserNotesRepository: @unchecked Sendable, UserNotesRepository {

    // MARK: - Dependencies

    private let context: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext
    private let log = Logger(subsystem: "com.motleywoods.molten", category: "usernotes-repository")

    // MARK: - Initialization

    /// Initialize CoreDataUserNotesRepository with a Core Data persistent container
    /// - Parameter context: The NSManagedObjectContext to use for user notes operations
    /// - Note: In production, pass PersistenceController.shared.cloudContext (user data)
    nonisolated init(context: NSManagedObjectContext) {
        self.context = context
        self.context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        self.backgroundContext = context
        self.backgroundContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
    }

    // MARK: - Basic CRUD Operations

    func createNotes(_ notes: UserNotesModel) async throws -> UserNotesModel {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
                    // Validate notes
                    guard notes.isValid else {
                        throw CoreDataUserNotesRepositoryError.invalidData(notes.validationErrors.joined(separator: ", "))
                    }

                    // Check if notes already exist
                    if try self.fetchNotesSync(forItem: notes.item_stable_id) != nil {
                        throw CoreDataUserNotesRepositoryError.notesAlreadyExist(notes.item_stable_id)
                    }

                    // Create new Core Data entity
                    guard let entity = NSEntityDescription.entity(forEntityName: "UserNotes", in: context) else {
                        throw CoreDataUserNotesRepositoryError.entityNotFound("UserNotes")
                    }
                    let coreDataItem = NSManagedObject(entity: entity, insertInto: context)

                    // Set properties
                    coreDataItem.setValue(notes.id, forKey: "id")
                    coreDataItem.setValue(notes.item_stable_id, forKey: "item_stable_id")
                    coreDataItem.setValue(notes.notes, forKey: "notes")

                    // Save context
                    try context.save()

                    self.log.info("Created user notes for item: \(notes.item_stable_id)")
                    return notes
        }
    }

    func fetchNotes(forItem item_stable_id: String) async throws -> UserNotesModel? {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
                    let result = try self.fetchNotesSync(forItem: item_stable_id)
                    return result
        }
    }

    func updateNotes(_ notes: UserNotesModel) async throws -> UserNotesModel {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
                    // Validate notes
                    guard notes.isValid else {
                        throw CoreDataUserNotesRepositoryError.invalidData(notes.validationErrors.joined(separator: ", "))
                    }

                    // Find existing item
                    guard let coreDataItem = try self.fetchCoreDataItemSync(forItem: notes.item_stable_id) else {
                        self.log.warning("Attempted to update non-existent notes: \(notes.item_stable_id)")
                        throw CoreDataUserNotesRepositoryError.notesNotFound(notes.item_stable_id)
                    }

                    // Update properties (only notes can change, item_stable_id is the key)
                    coreDataItem.setValue(notes.notes, forKey: "notes")

                    // Save context
                    try context.save()

                    self.log.info("Updated user notes for item: \(notes.item_stable_id)")
                    return notes
        }
    }

    func deleteNotes(forItem item_stable_id: String) async throws {
        try await CoreDataHelper.performAsyncVoid(on: backgroundContext) { context in
                    // Find existing item
                    guard let coreDataItem = try self.fetchCoreDataItemSync(forItem: item_stable_id) else {
                        self.log.warning("Attempted to delete non-existent notes: \(item_stable_id)")
                        // Not throwing error - idempotent delete
                                                return
                    }

                    // Delete item
                    context.delete(coreDataItem)

                    // Save context
                    try context.save()

                    self.log.info("Deleted user notes for item: \(item_stable_id)")
                            }
    }

    func deleteNotes(byId id: UUID) async throws {
        try await CoreDataHelper.performAsyncVoid(on: backgroundContext) { context in
                    // Find item by UUID
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserNotes")
                    fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

                    guard let coreDataItem = try context.fetch(fetchRequest).first else {
                        self.log.warning("Attempted to delete non-existent notes with id: \(id)")
                        // Not throwing error - idempotent delete
                                                return
                    }

                    // Delete item
                    context.delete(coreDataItem)

                    // Save context
                    try context.save()

                    self.log.info("Deleted user notes with id: \(id)")
                            }
    }

    // MARK: - Query Operations

    func fetchAllNotes() async throws -> [UserNotesModel] {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserNotes")
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "item_stable_id", ascending: true)]

                    let coreDataItems = try context.fetch(fetchRequest)
                    let notes = coreDataItems.compactMap { self.convertToUserNotesModel($0) }

                    return notes
        }
    }

    func fetchNotes(forItems item_stable_ids: [String]) async throws -> [String: UserNotesModel] {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserNotes")
                    fetchRequest.predicate = NSPredicate(format: "item_stable_id IN %@", item_stable_ids)

                    let coreDataItems = try context.fetch(fetchRequest)
                    var result: [String: UserNotesModel] = [:]

                    for item in coreDataItems {
                        if let notes = self.convertToUserNotesModel(item) {
                            result[notes.item_stable_id] = notes
                        }
                    }

                    return result
        }
    }

    func searchNotes(containing searchText: String) async throws -> [UserNotesModel] {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserNotes")
                    fetchRequest.predicate = NSPredicate(
                        format: "notes CONTAINS[cd] %@ OR item_stable_id CONTAINS[cd] %@",
                        searchText, searchText
                    )
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "item_stable_id", ascending: true)]

                    let coreDataItems = try context.fetch(fetchRequest)
                    let notes = coreDataItems.compactMap { self.convertToUserNotesModel($0) }

                    self.log.debug("Found \(notes.count) notes matching search text")
                    return notes
        }
    }

    func notesExist(forItem item_stable_id: String) async throws -> Bool {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
                    let exists = try self.fetchNotesSync(forItem: item_stable_id) != nil
                    return exists
        }
    }

    // MARK: - Batch Operations

    func setNotes(_ notes: UserNotesModel) async throws -> UserNotesModel {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
                    // Validate notes
                    guard notes.isValid else {
                        throw CoreDataUserNotesRepositoryError.invalidData(notes.validationErrors.joined(separator: ", "))
                    }

                    // Check if notes already exist
                    if let existingItem = try self.fetchCoreDataItemSync(forItem: notes.item_stable_id) {
                        // Update existing
                        existingItem.setValue(notes.notes, forKey: "notes")
                        try context.save()

                        self.log.info("Updated existing user notes for item: \(notes.item_stable_id)")
                        return notes
                    } else {
                        // Create new
                        guard let entity = NSEntityDescription.entity(forEntityName: "UserNotes", in: context) else {
                            throw CoreDataUserNotesRepositoryError.entityNotFound("UserNotes")
                        }
                        let coreDataItem = NSManagedObject(entity: entity, insertInto: context)

                        // Set properties (no id in Core Data)
                        coreDataItem.setValue(notes.item_stable_id, forKey: "item_stable_id")
                        coreDataItem.setValue(notes.notes, forKey: "notes")
                        try context.save()

                        self.log.info("Created new user notes for item: \(notes.item_stable_id)")
                        return notes
                    }
        }
    }

    func deleteAllNotes() async throws {
        try await CoreDataHelper.performAsyncVoid(on: backgroundContext) { context in
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserNotes")
                    let allNotes = try context.fetch(fetchRequest)

                    for note in allNotes {
                        context.delete(note)
                    }

                    if !allNotes.isEmpty {
                        try context.save()
                    }

                    self.log.info("Deleted all \(allNotes.count) user notes")
                            }
    }

    func getNotesCount() async throws -> Int {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserNotes")
                    let count = try context.count(for: fetchRequest)

                    return count
        }
    }

    // MARK: - Private Helper Methods

    private nonisolated func fetchNotesSync(forItem item_stable_id: String) throws -> UserNotesModel? {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserNotes")
        fetchRequest.predicate = NSPredicate(format: "item_stable_id == %@", item_stable_id)
        fetchRequest.fetchLimit = 1

        let results = try backgroundContext.fetch(fetchRequest)
        return results.first.flatMap { convertToUserNotesModel($0) }
    }

    private nonisolated func fetchCoreDataItemSync(forItem item_stable_id: String) throws -> NSManagedObject? {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserNotes")
        fetchRequest.predicate = NSPredicate(format: "item_stable_id == %@", item_stable_id)
        fetchRequest.fetchLimit = 1

        let results = try backgroundContext.fetch(fetchRequest)
        return results.first
    }

    private nonisolated func convertToUserNotesModel(_ coreDataItem: NSManagedObject) -> UserNotesModel? {
        guard let item_stable_id = coreDataItem.value(forKey: "item_stable_id") as? String,
              let notes = coreDataItem.value(forKey: "notes") as? String else {
            log.error("Failed to convert Core Data item to UserNotesModel - missing required properties")
            return nil
        }

        // Get UUID from Core Data, or generate new one for legacy data
        let id: UUID
        if let storedId = coreDataItem.value(forKey: "id") as? UUID {
            id = storedId
        } else {
            // Legacy data without UUID - generate one
            id = UUID()
            log.warning("UserNotes record missing UUID for item \(item_stable_id) - generating new one")
        }

        return UserNotesModel(
            id: id,
            item_stable_id: item_stable_id,
            notes: notes
        )
    }
}

// MARK: - Core Data Repository Errors

enum CoreDataUserNotesRepositoryError: Error, LocalizedError {
    case entityNotFound(String)
    case notesNotFound(String)
    case notesAlreadyExist(String)
    case invalidData(String)

    var errorDescription: String? {
        switch self {
        case .entityNotFound(let entityName):
            return "Core Data entity not found: \(entityName)"
        case .notesNotFound(let itemKey):
            return "User notes not found for item: \(itemKey)"
        case .notesAlreadyExist(let itemKey):
            return "User notes already exist for item: \(itemKey)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        }
    }
}
