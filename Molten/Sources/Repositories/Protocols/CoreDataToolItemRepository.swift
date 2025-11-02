//
//  CoreDataToolItemRepository.swift
//  Molten
//
//  Core Data implementation of ToolItemRepository protocol
//

import Foundation
@preconcurrency import CoreData

/// Core Data implementation of ToolItemRepository protocol
class CoreDataToolItemRepository: @unchecked Sendable, ToolItemRepository {

    private let context: NSManagedObjectContext

    nonisolated init(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: - Basic CRUD Operations

    func fetchItems(matching predicate: NSPredicate?) async throws -> [ToolItemModel] {
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "ToolItem")
            request.predicate = predicate
            request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

            do {
                let entities = try self.context.fetch(request)

                // Extract values immediately - NO compactMap with closures (Swift 6 concurrency)
                var models: [ToolItemModel] = []
                for entity in entities {
                    if let model = self.convertToToolItemModel(entity) {
                        models.append(model)
                    }
                }
                return models
            } catch {
                throw CoreDataToolItemRepositoryError.fetchFailed(error)
            }
        }
    }

    func fetchItem(byStableId stableId: String) async throws -> ToolItemModel? {
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "ToolItem")
            request.predicate = NSPredicate(format: "stable_id == %@", stableId)
            request.fetchLimit = 1

            do {
                let entities = try self.context.fetch(request)
                let model = entities.first.flatMap { self.convertToToolItemModel($0) }
                return model
            } catch {
                throw CoreDataToolItemRepositoryError.fetchFailed(error)
            }
        }
    }

    func createItem(_ item: ToolItemModel) async throws -> ToolItemModel {
        return try await context.perform {
            // Check if item already exists
            let existingRequest = NSFetchRequest<NSManagedObject>(entityName: "ToolItem")
            existingRequest.predicate = NSPredicate(format: "stable_id == %@", item.stable_id)
            existingRequest.fetchLimit = 1

            do {
                let existing = try self.context.fetch(existingRequest)
                if let existingEntity = existing.first {
                    // Update existing instead of creating duplicate
                    self.updateEntity(existingEntity, with: item)
                    try self.context.save()
                    return self.convertToToolItemModel(existingEntity) ?? item
                }

                // Create new ToolItem entity using NSEntityDescription
                guard let entityDescription = NSEntityDescription.entity(forEntityName: "ToolItem", in: self.context) else {
                    throw CoreDataToolItemRepositoryError.createFailed("Could not find ToolItem entity description")
                }

                let entity = NSManagedObject(entity: entityDescription, insertInto: self.context)
                self.updateEntity(entity, with: item)

                try self.context.save()

                return self.convertToToolItemModel(entity) ?? item
            } catch {
                throw CoreDataToolItemRepositoryError.createFailed(error.localizedDescription)
            }
        }
    }

    func createItems(_ items: [ToolItemModel]) async throws -> [ToolItemModel] {
        return try await context.perform {
            var createdItems: [ToolItemModel] = []

            for item in items {
                do {
                    let createdItem = try self.createItemSync(item)
                    createdItems.append(createdItem)
                } catch {
                    throw CoreDataToolItemRepositoryError.batchCreateFailed("Failed to create item \(item.stable_id): \(error.localizedDescription)")
                }
            }

            try self.context.save()
            return createdItems
        }
    }

    func updateItem(_ item: ToolItemModel) async throws -> ToolItemModel {
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "ToolItem")
            request.predicate = NSPredicate(format: "stable_id == %@", item.stable_id)
            request.fetchLimit = 1

            do {
                let entities = try self.context.fetch(request)
                guard let entity = entities.first else {
                    throw CoreDataToolItemRepositoryError.itemNotFound(item.stable_id)
                }

                self.updateEntity(entity, with: item)
                try self.context.save()

                return self.convertToToolItemModel(entity) ?? item
            } catch {
                throw CoreDataToolItemRepositoryError.updateFailed(error.localizedDescription)
            }
        }
    }

    func deleteItem(stableId: String) async throws {
        try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "ToolItem")
            request.predicate = NSPredicate(format: "stable_id == %@", stableId)
            request.fetchLimit = 1

            do {
                let entities = try self.context.fetch(request)
                guard let entity = entities.first else {
                    throw CoreDataToolItemRepositoryError.itemNotFound(stableId)
                }

                self.context.delete(entity)
                try self.context.save()
            } catch {
                throw CoreDataToolItemRepositoryError.deleteFailed(error.localizedDescription)
            }
        }
    }

    func deleteItems(stableIds: [String]) async throws {
        try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "ToolItem")
            request.predicate = NSPredicate(format: "stable_id IN %@", stableIds)

            do {
                let entities = try self.context.fetch(request)
                for entity in entities {
                    self.context.delete(entity)
                }
                try self.context.save()
            } catch {
                throw CoreDataToolItemRepositoryError.deleteFailed(error.localizedDescription)
            }
        }
    }

    // MARK: - Search & Filter Operations

    func searchItems(text: String) async throws -> [ToolItemModel] {
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "ToolItem")

            // Search in name, manufacturer, and notes
            let predicates = [
                NSPredicate(format: "name CONTAINS[cd] %@", text),
                NSPredicate(format: "manufacturer CONTAINS[cd] %@", text),
                NSPredicate(format: "mfr_notes CONTAINS[cd] %@", text)
            ]
            request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
            request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

            do {
                let entities = try self.context.fetch(request)

                // Extract values immediately - NO compactMap
                var models: [ToolItemModel] = []
                for entity in entities {
                    if let model = self.convertToToolItemModel(entity) {
                        models.append(model)
                    }
                }
                return models
            } catch {
                throw CoreDataToolItemRepositoryError.searchFailed(error.localizedDescription)
            }
        }
    }

    func fetchItems(byManufacturer manufacturer: String) async throws -> [ToolItemModel] {
        let predicate = NSPredicate(format: "manufacturer == %@", manufacturer)
        return try await fetchItems(matching: predicate)
    }

    func fetchItems(byStatus status: String) async throws -> [ToolItemModel] {
        let predicate = NSPredicate(format: "mfr_status == %@", status)
        return try await fetchItems(matching: predicate)
    }

    // MARK: - Business Query Operations

    func getDistinctManufacturers() async throws -> [String] {
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "ToolItem")
            request.propertiesToFetch = ["manufacturer"]
            request.returnsDistinctResults = true
            request.resultType = .dictionaryResultType

            do {
                let results = try self.context.fetch(request) as? [[String: Any]] ?? []

                // Extract values immediately - NO compactMap
                var manufacturers: [String] = []
                for result in results {
                    if let manufacturer = result["manufacturer"] as? String {
                        manufacturers.append(manufacturer)
                    }
                }
                return manufacturers.sorted()
            } catch {
                throw CoreDataToolItemRepositoryError.queryFailed(error.localizedDescription)
            }
        }
    }

    func getDistinctStatuses() async throws -> [String] {
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "ToolItem")
            request.propertiesToFetch = ["mfr_status"]
            request.returnsDistinctResults = true
            request.resultType = .dictionaryResultType

            do {
                let results = try self.context.fetch(request) as? [[String: Any]] ?? []

                // Extract values immediately - NO compactMap
                var statuses: [String] = []
                for result in results {
                    if let status = result["mfr_status"] as? String {
                        statuses.append(status)
                    }
                }
                return statuses.sorted()
            } catch {
                throw CoreDataToolItemRepositoryError.queryFailed(error.localizedDescription)
            }
        }
    }

    func stableIdExists(_ stableId: String) async throws -> Bool {
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "ToolItem")
            request.predicate = NSPredicate(format: "stable_id == %@", stableId)
            request.fetchLimit = 1

            do {
                let count = try self.context.count(for: request)
                return count > 0
            } catch {
                throw CoreDataToolItemRepositoryError.queryFailed(error.localizedDescription)
            }
        }
    }

    func generateNextNaturalKey(manufacturer: String, sku: String?) async throws -> String {
        // Simple implementation: Generate random 6-char stable_id
        return String(format: "%06d", Int.random(in: 0...999999))
    }

    // MARK: - Private Helpers

    /// Synchronous create helper (must be called within context.perform)
    private func createItemSync(_ item: ToolItemModel) throws -> ToolItemModel {
        // Check if item already exists
        let existingRequest = NSFetchRequest<NSManagedObject>(entityName: "ToolItem")
        existingRequest.predicate = NSPredicate(format: "stable_id == %@", item.stable_id)
        existingRequest.fetchLimit = 1

        let existing = try context.fetch(existingRequest)
        if let existingEntity = existing.first {
            // Update existing instead of creating duplicate
            updateEntity(existingEntity, with: item)
            return convertToToolItemModel(existingEntity) ?? item
        }

        // Create new entity
        guard let entityDescription = NSEntityDescription.entity(forEntityName: "ToolItem", in: context) else {
            throw CoreDataToolItemRepositoryError.createFailed("Could not find ToolItem entity description")
        }

        let entity = NSManagedObject(entity: entityDescription, insertInto: context)
        updateEntity(entity, with: item)

        return convertToToolItemModel(entity) ?? item
    }

    /// Convert NSManagedObject to ToolItemModel
    private func convertToToolItemModel(_ entity: NSManagedObject) -> ToolItemModel? {
        // Extract basic properties with safe defaults using KVC
        let name = entity.value(forKey: "name") as? String ?? ""
        let sku = entity.value(forKey: "sku") as? String
        let manufacturer = entity.value(forKey: "manufacturer") as? String ?? ""

        // Get stable_id (required)
        guard let stableId = entity.value(forKey: "stable_id") as? String, !stableId.isEmpty else {
            return nil
        }

        // Extract tool-specific properties
        let mfr_notes = entity.value(forKey: "mfr_notes") as? String
        let url = entity.value(forKey: "url") as? String
        let mfr_status = entity.value(forKey: "mfr_status") as? String ?? "available"

        // Extract image fields - image_url is stored as NSURL in Core Data
        let image_url: String?
        if let imageURLObj = entity.value(forKey: "image_url") as? NSURL {
            image_url = imageURLObj.absoluteString
        } else {
            image_url = nil
        }
        let image_path = entity.value(forKey: "image_path") as? String

        return ToolItemModel(
            stable_id: stableId,
            name: name,
            sku: sku,
            manufacturer: manufacturer,
            mfr_notes: mfr_notes,
            url: url,
            mfr_status: mfr_status,
            image_url: image_url,
            image_path: image_path
        )
    }

    /// Update entity with model values
    private func updateEntity(_ entity: NSManagedObject, with model: ToolItemModel) {
        // Set primary key (stable_id is required)
        entity.setValue(model.stable_id, forKey: "stable_id")

        // Set basic properties
        entity.setValue(model.name, forKey: "name")
        entity.setValue(model.manufacturer, forKey: "manufacturer")

        // Set tool-specific properties using KVC
        entity.setValue(model.sku, forKey: "sku")
        entity.setValue(model.mfr_notes, forKey: "mfr_notes")
        entity.setValue(model.url, forKey: "url")
        entity.setValue(model.mfr_status, forKey: "mfr_status")

        // Set image fields using KVC - image_url must be converted to NSURL
        if let imageURLString = model.image_url, let imageURL = NSURL(string: imageURLString) {
            entity.setValue(imageURL, forKey: "image_url")
        } else {
            entity.setValue(nil, forKey: "image_url")
        }
        entity.setValue(model.image_path, forKey: "image_path")
    }
}

// MARK: - Error Definitions

enum CoreDataToolItemRepositoryError: Error, LocalizedError {
    case fetchFailed(Error)
    case createFailed(String)
    case batchCreateFailed(String)
    case updateFailed(String)
    case deleteFailed(String)
    case itemNotFound(String)
    case searchFailed(String)
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .fetchFailed(let error):
            return "Failed to fetch tools: \(error.localizedDescription)"
        case .createFailed(let message):
            return "Failed to create tool: \(message)"
        case .batchCreateFailed(let message):
            return "Failed to create tools: \(message)"
        case .updateFailed(let message):
            return "Failed to update tool: \(message)"
        case .deleteFailed(let message):
            return "Failed to delete tool: \(message)"
        case .itemNotFound(let stableId):
            return "Tool not found: \(stableId)"
        case .searchFailed(let message):
            return "Search failed: \(message)"
        case .queryFailed(let message):
            return "Query failed: \(message)"
        }
    }
}
