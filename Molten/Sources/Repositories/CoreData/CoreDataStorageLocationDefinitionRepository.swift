//
//  CoreDataStorageLocationDefinitionRepository.swift
//  Molten
//
//  Core Data implementation of StorageLocationDefinitionRepository
//

import CoreData
import Foundation
import OSLog

/// Core Data implementation of StorageLocationDefinitionRepository
class CoreDataStorageLocationDefinitionRepository: @unchecked Sendable, StorageLocationDefinitionRepository {

    // MARK: - Dependencies

    private let context: NSManagedObjectContext
    private let log = Logger(subsystem: "com.motleywoods.molten", category: "storage-location-definition-repository")

    // MARK: - Initialization

    /// Initialize with a managed object context
    /// - Parameter context: The NSManagedObjectContext to use (should be cloudContext for user data)
    nonisolated init(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: - Fetch Operations

    func fetchAll() async throws -> [StorageLocationDefinitionModel] {
        return try await CoreDataHelper.performAsync(on: context) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "StorageLocationDefinition")
            fetchRequest.predicate = NSPredicate(format: "deleted_at == nil")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.caseInsensitiveCompare(_:)))]

            let results = try context.fetch(fetchRequest)
            return results.compactMap { self.convertToModel($0) }
        }
    }

    func fetchAllIncludingDeleted() async throws -> [StorageLocationDefinitionModel] {
        return try await CoreDataHelper.performAsync(on: context) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "StorageLocationDefinition")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.caseInsensitiveCompare(_:)))]

            let results = try context.fetch(fetchRequest)
            return results.compactMap { self.convertToModel($0) }
        }
    }

    func fetch(byId id: UUID) async throws -> StorageLocationDefinitionModel? {
        return try await CoreDataHelper.performAsync(on: context) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "StorageLocationDefinition")
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            fetchRequest.fetchLimit = 1

            let results = try context.fetch(fetchRequest)
            return results.first.flatMap { self.convertToModel($0) }
        }
    }

    func fetch(byName name: String) async throws -> StorageLocationDefinitionModel? {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return try await CoreDataHelper.performAsync(on: context) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "StorageLocationDefinition")
            fetchRequest.predicate = NSPredicate(format: "name ==[c] %@ AND deleted_at == nil", normalizedName)
            fetchRequest.fetchLimit = 1

            let results = try context.fetch(fetchRequest)
            return results.first.flatMap { self.convertToModel($0) }
        }
    }

    // MARK: - Create/Update Operations

    func create(_ definition: StorageLocationDefinitionModel) async throws -> StorageLocationDefinitionModel {
        return try await CoreDataHelper.performAsync(on: context) { context in
            guard let entity = NSEntityDescription.entity(forEntityName: "StorageLocationDefinition", in: context) else {
                throw StorageLocationDefinitionRepositoryError.entityNotFound
            }

            let coreDataObject = NSManagedObject(entity: entity, insertInto: context)
            self.updateCoreDataObject(coreDataObject, with: definition)

            try context.save()
            self.log.info("Created storage location definition: \(definition.name)")

            return definition
        }
    }

    func update(_ definition: StorageLocationDefinitionModel) async throws -> StorageLocationDefinitionModel {
        return try await CoreDataHelper.performAsync(on: context) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "StorageLocationDefinition")
            fetchRequest.predicate = NSPredicate(format: "id == %@", definition.id as CVarArg)
            fetchRequest.fetchLimit = 1

            guard let coreDataObject = try context.fetch(fetchRequest).first else {
                throw StorageLocationDefinitionRepositoryError.notFound(definition.id)
            }

            // Update with new modified date
            var updatedDefinition = definition
            updatedDefinition.modifiedAt = Date()
            self.updateCoreDataObject(coreDataObject, with: updatedDefinition)

            try context.save()
            self.log.info("Updated storage location definition: \(definition.name)")

            return updatedDefinition
        }
    }

    // MARK: - Delete Operations

    func softDelete(id: UUID) async throws {
        try await CoreDataHelper.performAsyncVoid(on: context) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "StorageLocationDefinition")
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            fetchRequest.fetchLimit = 1

            guard let coreDataObject = try context.fetch(fetchRequest).first else {
                throw StorageLocationDefinitionRepositoryError.notFound(id)
            }

            coreDataObject.setValue(Date(), forKey: "deleted_at")
            coreDataObject.setValue(Date(), forKey: "modified_at")

            try context.save()
            self.log.info("Soft-deleted storage location definition: \(id)")
        }
    }

    func hardDelete(id: UUID) async throws {
        try await CoreDataHelper.performAsyncVoid(on: context) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "StorageLocationDefinition")
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            fetchRequest.fetchLimit = 1

            guard let coreDataObject = try context.fetch(fetchRequest).first else {
                throw StorageLocationDefinitionRepositoryError.notFound(id)
            }

            context.delete(coreDataObject)
            try context.save()
            self.log.info("Hard-deleted storage location definition: \(id)")
        }
    }

    func restore(id: UUID) async throws {
        try await CoreDataHelper.performAsyncVoid(on: context) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "StorageLocationDefinition")
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            fetchRequest.fetchLimit = 1

            guard let coreDataObject = try context.fetch(fetchRequest).first else {
                throw StorageLocationDefinitionRepositoryError.notFound(id)
            }

            coreDataObject.setValue(nil, forKey: "deleted_at")
            coreDataObject.setValue(Date(), forKey: "modified_at")

            try context.save()
            self.log.info("Restored storage location definition: \(id)")
        }
    }

    // MARK: - Query Operations

    func getOrCreate(name: String) async throws -> StorageLocationDefinitionModel {
        // First, try to find existing
        if let existing = try await fetch(byName: name) {
            return existing
        }

        // Create new
        let newDefinition = StorageLocationDefinitionModel(name: name)
        return try await create(newDefinition)
    }

    func nameExists(_ name: String) async throws -> Bool {
        let existing = try await fetch(byName: name)
        return existing != nil
    }

    func getUsageCount(for id: UUID) async throws -> Int {
        return try await CoreDataHelper.performAsync(on: context) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "StorageLocation")
            fetchRequest.predicate = NSPredicate(format: "storage_location_id == %@", id as CVarArg)

            let count = try context.count(for: fetchRequest)
            return count
        }
    }

    // MARK: - Private Helpers

    private nonisolated func convertToModel(_ coreDataObject: NSManagedObject) -> StorageLocationDefinitionModel? {
        guard let id = coreDataObject.value(forKey: "id") as? UUID,
              let name = coreDataObject.value(forKey: "name") as? String else {
            log.error("Failed to convert Core Data object to StorageLocationDefinitionModel - missing required fields")
            return nil
        }

        let notes = coreDataObject.value(forKey: "notes") as? String
        let createdAt = coreDataObject.value(forKey: "created_at") as? Date ?? Date()
        let modifiedAt = coreDataObject.value(forKey: "modified_at") as? Date ?? Date()
        let deletedAt = coreDataObject.value(forKey: "deleted_at") as? Date
        let workspaceId = coreDataObject.value(forKey: "workspace_id") as? UUID

        return StorageLocationDefinitionModel(
            id: id,
            name: name,
            notes: notes,
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            deletedAt: deletedAt,
            workspaceId: workspaceId
        )
    }

    private nonisolated func updateCoreDataObject(_ coreDataObject: NSManagedObject, with model: StorageLocationDefinitionModel) {
        coreDataObject.setValue(model.id, forKey: "id")
        coreDataObject.setValue(model.name, forKey: "name")
        coreDataObject.setValue(model.notes, forKey: "notes")
        coreDataObject.setValue(model.createdAt, forKey: "created_at")
        coreDataObject.setValue(model.modifiedAt, forKey: "modified_at")
        coreDataObject.setValue(model.deletedAt, forKey: "deleted_at")
        coreDataObject.setValue(model.workspaceId, forKey: "workspace_id")
    }
}

// MARK: - Errors

enum StorageLocationDefinitionRepositoryError: Error, LocalizedError {
    case entityNotFound
    case notFound(UUID)
    case duplicateName(String)

    var errorDescription: String? {
        switch self {
        case .entityNotFound:
            return "StorageLocationDefinition entity not found in Core Data model"
        case .notFound(let id):
            return "Storage location definition not found: \(id)"
        case .duplicateName(let name):
            return "A storage location with name '\(name)' already exists"
        }
    }
}
