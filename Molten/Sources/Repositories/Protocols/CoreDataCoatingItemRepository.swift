//
//  CoreDataCoatingItemRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/29/25.
//  Core Data implementation of the new CoatingItemRepository protocol
//

import Foundation
@preconcurrency import CoreData

/// Core Data implementation of CoatingItemRepository protocol
/// Migrated from the legacy CatalogItem system to the new CoatingItem architecture
class CoreDataCoatingItemRepository: @unchecked Sendable, CoatingItemRepository {

    private let persistentContainer: NSPersistentContainer
    private let context: NSManagedObjectContext

    nonisolated init(persistentContainer: NSPersistentContainer) {
        self.persistentContainer = persistentContainer
        self.context = persistentContainer.viewContext
    }

    // MARK: - Basic CRUD Operations

    func fetchItems(matching predicate: NSPredicate?) async throws -> [CoatingItemModel] {
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CoatingItem")
            request.predicate = predicate
            request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

            do {
                let entities = try self.context.fetch(request)
                let models = entities.compactMap { self.convertToCoatingItemModel($0) }
                return models
            } catch {
                throw CoreDataCoatingItemRepositoryError.fetchFailed(error)
            }
        }
    }

    func fetchItem(byStableId stableId: String) async throws -> CoatingItemModel? {
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CoatingItem")
            request.predicate = NSPredicate(format: "stable_id == %@", stableId)
            request.fetchLimit = 1

            do {
                let entities = try self.context.fetch(request)
                let model = entities.first.flatMap { self.convertToCoatingItemModel($0) }
                return model
            } catch {
                throw CoreDataCoatingItemRepositoryError.fetchFailed(error)
            }
        }
    }

    func createItem(_ item: CoatingItemModel) async throws -> CoatingItemModel {
        return try await context.perform {
            // Check if item already exists
            let existingRequest = NSFetchRequest<NSManagedObject>(entityName: "CoatingItem")
            existingRequest.predicate = NSPredicate(format: "stable_id == %@", item.stable_id)
            existingRequest.fetchLimit = 1

            do {
                let existing = try self.context.fetch(existingRequest)
                if let existingEntity = existing.first {
                    self.updateEntity(existingEntity, with: item)
                    try self.context.save()
                    return self.convertToCoatingItemModel(existingEntity) ?? item
                }

                // Create new CoatingItem entity using NSEntityDescription
                guard let entityDescription = NSEntityDescription.entity(forEntityName: "CoatingItem", in: self.context) else {
                    throw CoreDataCoatingItemRepositoryError.createFailed("Could not find CoatingItem entity description")
                }

                let entity = NSManagedObject(entity: entityDescription, insertInto: self.context)
                self.updateEntity(entity, with: item)

                try self.context.save()

                return self.convertToCoatingItemModel(entity) ?? item
            } catch {
                throw CoreDataCoatingItemRepositoryError.createFailed(error.localizedDescription)
            }
        }
    }

    func createItems(_ items: [CoatingItemModel]) async throws -> [CoatingItemModel] {
        return try await context.perform {
            var createdItems: [CoatingItemModel] = []

            for item in items {
                do {
                    let createdItem = try self.createItemSync(item)
                    createdItems.append(createdItem)
                } catch {
                    throw CoreDataCoatingItemRepositoryError.batchCreateFailed("Failed to create item \(item.stable_id): \(error.localizedDescription)")
                }
            }

            try self.context.save()
            return createdItems
        }
    }

    func updateItem(_ item: CoatingItemModel) async throws -> CoatingItemModel {
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CoatingItem")
            request.predicate = NSPredicate(format: "stable_id == %@", item.stable_id)
            request.fetchLimit = 1

            do {
                let entities = try self.context.fetch(request)
                guard let entity = entities.first else {
                    throw CoreDataCoatingItemRepositoryError.itemNotFound(item.stable_id)
                }

                self.updateEntity(entity, with: item)
                try self.context.save()

                return self.convertToCoatingItemModel(entity) ?? item
            } catch {
                throw CoreDataCoatingItemRepositoryError.updateFailed(error.localizedDescription)
            }
        }
    }

    func deleteItem(stableId: String) async throws {
        try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CoatingItem")
            request.predicate = NSPredicate(format: "stable_id == %@", stableId)
            request.fetchLimit = 1

            do {
                let entities = try self.context.fetch(request)
                guard let entity = entities.first else {
                    throw CoreDataCoatingItemRepositoryError.itemNotFound(stableId)
                }

                self.context.delete(entity)
                try self.context.save()
            } catch {
                throw CoreDataCoatingItemRepositoryError.deleteFailed(error.localizedDescription)
            }
        }
    }

    func deleteItems(stableIds: [String]) async throws {
        try await context.perform {
            for stableId in stableIds {
                let request = NSFetchRequest<NSManagedObject>(entityName: "CoatingItem")
                request.predicate = NSPredicate(format: "stable_id == %@", stableId)
                request.fetchLimit = 1

                do {
                    let entities = try self.context.fetch(request)
                    if let entity = entities.first {
                        self.context.delete(entity)
                    }
                } catch {
                    // Continue with other deletions even if one fails
                }
            }

            try self.context.save()
        }
    }

    // MARK: - Search & Filter Operations

    func searchItems(text: String) async throws -> [CoatingItemModel] {
        guard !text.isEmpty else {
            // Empty search returns all items
            return try await fetchItems(matching: nil)
        }

        return try await context.perform {
            // Parse search text to determine search mode
            let searchMode = SearchTextParser.parseSearchText(text)

            // Build predicate based on search mode
            let searchPredicate = self.buildSearchPredicate(for: searchMode)

            let request = NSFetchRequest<NSManagedObject>(entityName: "CoatingItem")
            request.predicate = searchPredicate
            request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

            do {
                let entities = try self.context.fetch(request)
                let models = entities.compactMap { self.convertToCoatingItemModel($0) }

                return models
            } catch {
                throw CoreDataCoatingItemRepositoryError.searchFailed(error.localizedDescription)
            }
        }
    }

    func fetchItems(byManufacturer manufacturer: String) async throws -> [CoatingItemModel] {
        let predicate = NSPredicate(format: "manufacturer == %@", manufacturer)
        let items = try await fetchItems(matching: predicate)
        return items
    }

    func fetchItems(byStatus status: String) async throws -> [CoatingItemModel] {
        let predicate = NSPredicate(format: "mfr_status == %@", status)
        let items = try await fetchItems(matching: predicate)
        return items
    }

    // MARK: - Business Query Operations

    func getDistinctManufacturers() async throws -> [String] {
        return try await context.perform {
            let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "CoatingItem")
            request.resultType = .dictionaryResultType
            request.propertiesToFetch = ["manufacturer"]
            request.returnsDistinctResults = true

            do {
                let results = try self.context.fetch(request) as! [[String: Any]]
                let manufacturers = results.compactMap { $0["manufacturer"] as? String }
                    .filter { !$0.isEmpty }
                    .sorted()

                return manufacturers
            } catch {
                throw CoreDataCoatingItemRepositoryError.queryFailed(error.localizedDescription)
            }
        }
    }

    func getDistinctStatuses() async throws -> [String] {
        return try await context.perform {
            let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "CoatingItem")
            request.resultType = .dictionaryResultType
            request.propertiesToFetch = ["mfr_status"]
            request.returnsDistinctResults = true

            do {
                let results = try self.context.fetch(request) as! [[String: Any]]
                let statuses = results.compactMap { $0["mfr_status"] as? String }
                    .filter { !$0.isEmpty }
                    .sorted()

                return statuses
            } catch {
                throw CoreDataCoatingItemRepositoryError.queryFailed(error.localizedDescription)
            }
        }
    }

    func stableIdExists(_ stableId: String) async throws -> Bool {
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CoatingItem")
            request.predicate = NSPredicate(format: "stable_id == %@", stableId)
            request.fetchLimit = 1

            do {
                let count = try self.context.count(for: request)
                return count > 0
            } catch {
                throw CoreDataCoatingItemRepositoryError.queryFailed(error.localizedDescription)
            }
        }
    }

    func generateNextNaturalKey(manufacturer: String, sku: String?) async throws -> String {
        // DEPRECATED: natural_key has been removed
        // This method now generates a stable_id-compatible string for backward compatibility
        // stable_id is a 6-char hash, not a sequential key
        return String(format: "%06d", Int.random(in: 0...999999))
    }

    // MARK: - Private Helper Methods

    /// Build a search predicate based on the search mode
    private nonisolated func buildSearchPredicate(for mode: SearchMode) -> NSPredicate {
        let fields = ["name", "sku", "manufacturer", "mfr_notes"]

        switch mode {
        case .singleTerm(let term):
            // Single term: OR search across all fields
            let predicates = fields.map { field in
                NSPredicate(format: "%K CONTAINS[cd] %@", field, term)
            }
            return NSCompoundPredicate(orPredicateWithSubpredicates: predicates)

        case .multipleTerms(let terms):
            // Multiple terms: Each term must appear in at least one field (AND of ORs)
            let termPredicates = terms.map { term in
                let fieldPredicates = fields.map { field in
                    NSPredicate(format: "%K CONTAINS[cd] %@", field, term)
                }
                return NSCompoundPredicate(orPredicateWithSubpredicates: fieldPredicates)
            }
            return NSCompoundPredicate(andPredicateWithSubpredicates: termPredicates)

        case .exactPhrase(let phrase):
            // Exact phrase: OR search across all fields
            let predicates = fields.map { field in
                NSPredicate(format: "%K CONTAINS[cd] %@", field, phrase)
            }
            return NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        }
    }

    private func createItemSync(_ item: CoatingItemModel) throws -> CoatingItemModel {
        // Synchronous version for use within context.perform blocks
        let existingRequest = NSFetchRequest<NSManagedObject>(entityName: "CoatingItem")
        existingRequest.predicate = NSPredicate(format: "stable_id == %@", item.stable_id)
        existingRequest.fetchLimit = 1

        let existing = try context.fetch(existingRequest)
        if let existingEntity = existing.first {
            updateEntity(existingEntity, with: item)
            return convertToCoatingItemModel(existingEntity) ?? item
        }

        // Create new CoatingItem entity using NSEntityDescription
        guard let entityDescription = NSEntityDescription.entity(forEntityName: "CoatingItem", in: context) else {
            throw CoreDataCoatingItemRepositoryError.createFailed("Could not find CoatingItem entity description")
        }

        let entity = NSManagedObject(entity: entityDescription, insertInto: context)
        updateEntity(entity, with: item)

        return convertToCoatingItemModel(entity) ?? item
    }

    private func convertToCoatingItemModel(_ entity: NSManagedObject) -> CoatingItemModel? {
        // Extract basic properties with safe defaults using KVC
        let name = entity.value(forKey: "name") as? String ?? ""
        let sku = entity.value(forKey: "sku") as? String ?? ""
        let manufacturer = entity.value(forKey: "manufacturer") as? String ?? ""

        // Get stable_id (required), generate if missing
        let stableId: String
        if let existingId = entity.value(forKey: "stable_id") as? String, !existingId.isEmpty {
            stableId = existingId
        } else {
            // Generate stable_id for legacy data
            // This handles migration from older data models that didn't have stable_id
            print("⚠️ Generating stable_id for legacy coating item: \(manufacturer)-\(sku)")
            stableId = String(format: "%06d", Int.random(in: 0...999999))
            // Update the entity with the generated stable_id
            entity.setValue(stableId, forKey: "stable_id")
        }

        // Extract coating-specific properties with safe defaults
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

        return CoatingItemModel(
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

    private func updateEntity(_ entity: NSManagedObject, with model: CoatingItemModel) {
        // Set primary key (stable_id is required)
        entity.setValue(model.stable_id, forKey: "stable_id")

        // Set basic properties
        entity.setValue(model.name, forKey: "name")
        entity.setValue(model.manufacturer, forKey: "manufacturer")

        // Set coating-specific properties using KVC
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

// MARK: - Error Types

enum CoreDataCoatingItemRepositoryError: Error, LocalizedError {
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
            return "Failed to fetch coating items: \(error.localizedDescription)"
        case .createFailed(let message):
            return "Failed to create coating item: \(message)"
        case .batchCreateFailed(let message):
            return "Failed to create coating items in batch: \(message)"
        case .updateFailed(let message):
            return "Failed to update coating item: \(message)"
        case .deleteFailed(let message):
            return "Failed to delete coating item: \(message)"
        case .itemNotFound(let naturalKey):
            return "Coating item not found with natural key: \(naturalKey)"
        case .searchFailed(let message):
            return "Coating search failed: \(message)"
        case .queryFailed(let message):
            return "Coating query failed: \(message)"
        }
    }
}
