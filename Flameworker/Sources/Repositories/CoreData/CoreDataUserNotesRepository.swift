//
//  CoreDataUserNotesRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/16/25.
//

import CoreData
import Foundation
import OSLog

/// Core Data implementation of UserNotesRepository
/// Provides persistent storage for user notes using Core Data
class CoreDataUserNotesRepository: UserNotesRepository {

    // MARK: - Dependencies

    private let persistentContainer: NSPersistentContainer
    private let backgroundContext: NSManagedObjectContext
    private let log = Logger(subsystem: "com.flameworker.app", category: "usernotes-repository")

    // MARK: - Initialization

    /// Initialize CoreDataUserNotesRepository with a Core Data persistent container
    /// - Parameter persistentContainer: The NSPersistentContainer to use for user notes operations
    /// - Note: In production, pass PersistenceController.shared.container
    init(userNotesPersistentContainer persistentContainer: NSPersistentContainer) {
        self.persistentContainer = persistentContainer
        self.backgroundContext = persistentContainer.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy

    }

    // MARK: - Basic CRUD Operations

    func createNotes(_ notes: UserNotesModel) async throws -> UserNotesModel {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UserNotesModel, Error>) in
            backgroundContext.perform {
                do {
                    // Validate notes
                    guard notes.isValid else {
                        throw CoreDataUserNotesRepositoryError.invalidData(notes.validationErrors.joined(separator: ", "))
                    }

                    // Check if notes already exist
                    if let existing = try self.fetchNotesSync(forItem: notes.item_natural_key) {
                        throw CoreDataUserNotesRepositoryError.notesAlreadyExist(notes.item_natural_key)
                    }

                    // Create new Core Data entity
                    guard let entity = NSEntityDescription.entity(forEntityName: "UserNotes", in: self.backgroundContext) else {
                        throw CoreDataUserNotesRepositoryError.entityNotFound("UserNotes")
                    }
                    let coreDataItem = NSManagedObject(entity: entity, insertInto: self.backgroundContext)

                    // Set properties (no id in Core Data)
                    coreDataItem.setValue(notes.item_natural_key, forKey: "item_natural_key")
                    coreDataItem.setValue(notes.notes, forKey: "notes")

                    // Save context
                    try self.backgroundContext.save()

                    self.log.info("Created user notes for item: \(notes.item_natural_key)")
                    continuation.resume(returning: notes)

                } catch {
                    self.log.error("Failed to create user notes: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchNotes(forItem itemNaturalKey: String) async throws -> UserNotesModel? {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UserNotesModel?, Error>) in
            backgroundContext.perform {
                do {
                    let result = try self.fetchNotesSync(forItem: itemNaturalKey)
                    continuation.resume(returning: result)
                } catch {
                    self.log.error("Failed to fetch user notes: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func updateNotes(_ notes: UserNotesModel) async throws -> UserNotesModel {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UserNotesModel, Error>) in
            backgroundContext.perform {
                do {
                    // Validate notes
                    guard notes.isValid else {
                        throw CoreDataUserNotesRepositoryError.invalidData(notes.validationErrors.joined(separator: ", "))
                    }

                    // Find existing item
                    guard let coreDataItem = try self.fetchCoreDataItemSync(forItem: notes.item_natural_key) else {
                        self.log.warning("Attempted to update non-existent notes: \(notes.item_natural_key)")
                        throw CoreDataUserNotesRepositoryError.notesNotFound(notes.item_natural_key)
                    }

                    // Update properties (only notes can change, item_natural_key is the key)
                    coreDataItem.setValue(notes.notes, forKey: "notes")

                    // Save context
                    try self.backgroundContext.save()

                    self.log.info("Updated user notes for item: \(notes.item_natural_key)")
                    continuation.resume(returning: notes)

                } catch {
                    self.log.error("Failed to update user notes: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func deleteNotes(forItem itemNaturalKey: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            backgroundContext.perform {
                do {
                    // Find existing item
                    guard let coreDataItem = try self.fetchCoreDataItemSync(forItem: itemNaturalKey) else {
                        self.log.warning("Attempted to delete non-existent notes: \(itemNaturalKey)")
                        // Not throwing error - idempotent delete
                        continuation.resume()
                        return
                    }

                    // Delete item
                    self.backgroundContext.delete(coreDataItem)

                    // Save context
                    try self.backgroundContext.save()

                    self.log.info("Deleted user notes for item: \(itemNaturalKey)")
                    continuation.resume()

                } catch {
                    self.log.error("Failed to delete user notes: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func deleteNotes(byId id: String) async throws {
        // Since we don't store id in Core Data, we can't delete by id
        // This method exists for protocol conformance but isn't used
        // Log a warning and do nothing
        log.warning("deleteNotes(byId:) called but UserNotes entity doesn't have id field - ignoring")
    }

    // MARK: - Query Operations

    func fetchAllNotes() async throws -> [UserNotesModel] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[UserNotesModel], Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserNotes")
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "item_natural_key", ascending: true)]

                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)
                    let notes = coreDataItems.compactMap { self.convertToUserNotesModel($0) }

                    continuation.resume(returning: notes)

                } catch {
                    self.log.error("Failed to fetch all user notes: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchNotes(forItems itemNaturalKeys: [String]) async throws -> [String: UserNotesModel] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String: UserNotesModel], Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserNotes")
                    fetchRequest.predicate = NSPredicate(format: "item_natural_key IN %@", itemNaturalKeys)

                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)
                    var result: [String: UserNotesModel] = [:]

                    for item in coreDataItems {
                        if let notes = self.convertToUserNotesModel(item) {
                            result[notes.item_natural_key] = notes
                        }
                    }

                    continuation.resume(returning: result)

                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func searchNotes(containing searchText: String) async throws -> [UserNotesModel] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[UserNotesModel], Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserNotes")
                    fetchRequest.predicate = NSPredicate(
                        format: "notes CONTAINS[cd] %@ OR item_natural_key CONTAINS[cd] %@",
                        searchText, searchText
                    )
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "item_natural_key", ascending: true)]

                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)
                    let notes = coreDataItems.compactMap { self.convertToUserNotesModel($0) }

                    self.log.debug("Found \(notes.count) notes matching search text")
                    continuation.resume(returning: notes)

                } catch {
                    self.log.error("Failed to search user notes: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func notesExist(forItem itemNaturalKey: String) async throws -> Bool {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            backgroundContext.perform {
                do {
                    let exists = try self.fetchNotesSync(forItem: itemNaturalKey) != nil
                    continuation.resume(returning: exists)
                } catch {
                    self.log.error("Failed to check if notes exist: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Batch Operations

    func setNotes(_ notes: UserNotesModel) async throws -> UserNotesModel {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UserNotesModel, Error>) in
            backgroundContext.perform {
                do {
                    // Validate notes
                    guard notes.isValid else {
                        throw CoreDataUserNotesRepositoryError.invalidData(notes.validationErrors.joined(separator: ", "))
                    }

                    // Check if notes already exist
                    if let existingItem = try self.fetchCoreDataItemSync(forItem: notes.item_natural_key) {
                        // Update existing
                        existingItem.setValue(notes.notes, forKey: "notes")
                        try self.backgroundContext.save()

                        self.log.info("Updated existing user notes for item: \(notes.item_natural_key)")
                        continuation.resume(returning: notes)
                    } else {
                        // Create new
                        guard let entity = NSEntityDescription.entity(forEntityName: "UserNotes", in: self.backgroundContext) else {
                            throw CoreDataUserNotesRepositoryError.entityNotFound("UserNotes")
                        }
                        let coreDataItem = NSManagedObject(entity: entity, insertInto: self.backgroundContext)

                        // Set properties (no id in Core Data)
                        coreDataItem.setValue(notes.item_natural_key, forKey: "item_natural_key")
                        coreDataItem.setValue(notes.notes, forKey: "notes")
                        try self.backgroundContext.save()

                        self.log.info("Created new user notes for item: \(notes.item_natural_key)")
                        continuation.resume(returning: notes)
                    }

                } catch {
                    self.log.error("Failed to set user notes: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func deleteAllNotes() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserNotes")
                    let allNotes = try self.backgroundContext.fetch(fetchRequest)

                    for note in allNotes {
                        self.backgroundContext.delete(note)
                    }

                    if !allNotes.isEmpty {
                        try self.backgroundContext.save()
                    }

                    self.log.info("Deleted all \(allNotes.count) user notes")
                    continuation.resume()

                } catch {
                    self.log.error("Failed to delete all user notes: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getNotesCount() async throws -> Int {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int, Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserNotes")
                    let count = try self.backgroundContext.count(for: fetchRequest)

                    continuation.resume(returning: count)

                } catch {
                    self.log.error("Failed to get notes count: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Private Helper Methods

    private func fetchNotesSync(forItem itemNaturalKey: String) throws -> UserNotesModel? {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserNotes")
        fetchRequest.predicate = NSPredicate(format: "item_natural_key == %@", itemNaturalKey)
        fetchRequest.fetchLimit = 1

        let results = try backgroundContext.fetch(fetchRequest)
        return results.first.flatMap { convertToUserNotesModel($0) }
    }

    private func fetchCoreDataItemSync(forItem itemNaturalKey: String) throws -> NSManagedObject? {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserNotes")
        fetchRequest.predicate = NSPredicate(format: "item_natural_key == %@", itemNaturalKey)
        fetchRequest.fetchLimit = 1

        let results = try backgroundContext.fetch(fetchRequest)
        return results.first
    }

    private func convertToUserNotesModel(_ coreDataItem: NSManagedObject) -> UserNotesModel? {
        guard let item_natural_key = coreDataItem.value(forKey: "item_natural_key") as? String,
              let notes = coreDataItem.value(forKey: "notes") as? String else {
            log.error("Failed to convert Core Data item to UserNotesModel - missing required properties")
            return nil
        }

        // Generate a unique id for the model (not stored in Core Data)
        // Use item_natural_key as the id since it's unique
        return UserNotesModel(
            id: item_natural_key,
            item_natural_key: item_natural_key,
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
