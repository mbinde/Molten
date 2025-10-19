//
//  CoreDataGlassItemRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/15/25.
//  Core Data implementation of the new GlassItemRepository protocol
//

import Foundation
import CoreData

/// Core Data implementation of GlassItemRepository protocol
/// Migrated from the legacy CatalogItem system to the new GlassItem architecture
class CoreDataGlassItemRepository: GlassItemRepository {
    
    private let persistentContainer: NSPersistentContainer
    private let context: NSManagedObjectContext
    
    init(persistentContainer: NSPersistentContainer) {
        self.persistentContainer = persistentContainer
        self.context = persistentContainer.viewContext
    }
    
    // MARK: - Basic CRUD Operations
    
    func fetchItems(matching predicate: NSPredicate?) async throws -> [GlassItemModel] {
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "GlassItem")
            request.predicate = predicate
            request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
            
            do {
                let entities = try self.context.fetch(request)
                let models = entities.compactMap { self.convertToGlassItemModel($0) }
                return models
            } catch {
                throw CoreDataGlassItemRepositoryError.fetchFailed(error)
            }
        }
    }
    
    func fetchItem(byNaturalKey naturalKey: String) async throws -> GlassItemModel? {
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "GlassItem")
            request.predicate = NSPredicate(format: "natural_key == %@", naturalKey)
            request.fetchLimit = 1
            
            do {
                let entities = try self.context.fetch(request)
                let model = entities.first.flatMap { self.convertToGlassItemModel($0) }
                return model
            } catch {
                throw CoreDataGlassItemRepositoryError.fetchFailed(error)
            }
        }
    }
    
    func createItem(_ item: GlassItemModel) async throws -> GlassItemModel {
        return try await context.perform {
            // Check if item already exists
            let existingRequest = NSFetchRequest<NSManagedObject>(entityName: "GlassItem")
            existingRequest.predicate = NSPredicate(format: "natural_key == %@", item.natural_key)
            existingRequest.fetchLimit = 1
            
            do {
                let existing = try self.context.fetch(existingRequest)
                if let existingEntity = existing.first {
                    self.updateEntity(existingEntity, with: item)
                    try self.context.save()
                    return self.convertToGlassItemModel(existingEntity) ?? item
                }
                
                // Create new GlassItem entity using NSEntityDescription
                guard let entityDescription = NSEntityDescription.entity(forEntityName: "GlassItem", in: self.context) else {
                    throw CoreDataGlassItemRepositoryError.createFailed("Could not find GlassItem entity description")
                }
                
                let entity = NSManagedObject(entity: entityDescription, insertInto: self.context)
                self.updateEntity(entity, with: item)
                
                try self.context.save()
                
                return self.convertToGlassItemModel(entity) ?? item
            } catch {
                throw CoreDataGlassItemRepositoryError.createFailed(error.localizedDescription)
            }
        }
    }
    
    func createItems(_ items: [GlassItemModel]) async throws -> [GlassItemModel] {
        return try await context.perform {
            var createdItems: [GlassItemModel] = []
            
            for item in items {
                do {
                    let createdItem = try self.createItemSync(item)
                    createdItems.append(createdItem)
                } catch {
                    throw CoreDataGlassItemRepositoryError.batchCreateFailed("Failed to create item \(item.natural_key): \(error.localizedDescription)")
                }
            }
            
            try self.context.save()
            return createdItems
        }
    }
    
    func updateItem(_ item: GlassItemModel) async throws -> GlassItemModel {
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "GlassItem")
            request.predicate = NSPredicate(format: "natural_key == %@", item.natural_key)
            request.fetchLimit = 1
            
            do {
                let entities = try self.context.fetch(request)
                guard let entity = entities.first else {
                    throw CoreDataGlassItemRepositoryError.itemNotFound(item.natural_key)
                }
                
                self.updateEntity(entity, with: item)
                try self.context.save()
                
                return self.convertToGlassItemModel(entity) ?? item
            } catch {
                throw CoreDataGlassItemRepositoryError.updateFailed(error.localizedDescription)
            }
        }
    }
    
    func deleteItem(naturalKey: String) async throws {
        try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "GlassItem")
            request.predicate = NSPredicate(format: "natural_key == %@", naturalKey)
            request.fetchLimit = 1
            
            do {
                let entities = try self.context.fetch(request)
                guard let entity = entities.first else {
                    throw CoreDataGlassItemRepositoryError.itemNotFound(naturalKey)
                }
                
                self.context.delete(entity)
                try self.context.save()
            } catch {
                throw CoreDataGlassItemRepositoryError.deleteFailed(error.localizedDescription)
            }
        }
    }
    
    func deleteItems(naturalKeys: [String]) async throws {
        try await context.perform {
            for naturalKey in naturalKeys {
                let request = NSFetchRequest<NSManagedObject>(entityName: "GlassItem")
                request.predicate = NSPredicate(format: "naturalKey == %@", naturalKey)
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
    
    func searchItems(text: String) async throws -> [GlassItemModel] {
        guard !text.isEmpty else {
            // Empty search returns all items
            return try await fetchItems(matching: nil)
        }

        return try await context.perform {
            // Parse search text to determine search mode
            let searchMode = SearchTextParser.parseSearchText(text)

            // Build predicate based on search mode
            let searchPredicate = self.buildSearchPredicate(for: searchMode)

            let request = NSFetchRequest<NSManagedObject>(entityName: "GlassItem")
            request.predicate = searchPredicate
            request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

            do {
                let entities = try self.context.fetch(request)
                let models = entities.compactMap { self.convertToGlassItemModel($0) }

                return models
            } catch {
                throw CoreDataGlassItemRepositoryError.searchFailed(error.localizedDescription)
            }
        }
    }
    
    func fetchItems(byManufacturer manufacturer: String) async throws -> [GlassItemModel] {
        let predicate = NSPredicate(format: "manufacturer == %@", manufacturer)
        let items = try await fetchItems(matching: predicate)
        return items
    }
    
    func fetchItems(byCOE coe: Int32) async throws -> [GlassItemModel] {
        let predicate = NSPredicate(format: "coe == %d", coe)
        let items = try await fetchItems(matching: predicate)
        return items
    }
    
    func fetchItems(byStatus status: String) async throws -> [GlassItemModel] {
        let predicate = NSPredicate(format: "mfr_status == %@", status)
        let items = try await fetchItems(matching: predicate)
        return items
    }
    
    // MARK: - Business Query Operations
    
    func getDistinctManufacturers() async throws -> [String] {
        return try await context.perform {
            let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "GlassItem")
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
                throw CoreDataGlassItemRepositoryError.queryFailed(error.localizedDescription)
            }
        }
    }
    
    func getDistinctCOEValues() async throws -> [Int32] {
        return try await context.perform {
            let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "GlassItem")
            request.resultType = .dictionaryResultType
            request.propertiesToFetch = ["coe"]
            request.returnsDistinctResults = true
            
            do {
                let results = try self.context.fetch(request) as! [[String: Any]]
                let coeValues = results.compactMap { result in
                    if let coeValue = result["coe"] as? Int32 {
                        return coeValue
                    } else if let coeValue = result["coe"] as? Int16 {
                        return Int32(coeValue)
                    } else if let coeValue = result["coe"] as? Int {
                        return Int32(coeValue)
                    }
                    return nil
                }.sorted()
                
                return coeValues
            } catch {
                throw CoreDataGlassItemRepositoryError.queryFailed(error.localizedDescription)
            }
        }
    }
    
    func getDistinctStatuses() async throws -> [String] {
        return try await context.perform {
            let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "GlassItem")
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
                throw CoreDataGlassItemRepositoryError.queryFailed(error.localizedDescription)
            }
        }
    }
    
    func naturalKeyExists(_ naturalKey: String) async throws -> Bool {
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "GlassItem")
            request.predicate = NSPredicate(format: "natural_key == %@", naturalKey)
            request.fetchLimit = 1
            
            do {
                let count = try self.context.count(for: request)
                return count > 0
            } catch {
                throw CoreDataGlassItemRepositoryError.queryFailed(error.localizedDescription)
            }
        }
    }
    
    func generateNextNaturalKey(manufacturer: String, sku: String) async throws -> String {
        return try await context.perform {
            let baseKey = GlassItemModel.createNaturalKey(manufacturer: manufacturer, sku: sku, sequence: 0)
            let prefix = "\(manufacturer.lowercased())-\(sku)-"
            
            let request = NSFetchRequest<NSManagedObject>(entityName: "GlassItem")
            request.predicate = NSPredicate(format: "natural_key BEGINSWITH %@", prefix)
            
            do {
                let entities = try self.context.fetch(request)
                let existingKeys = entities.compactMap { entity in
                    entity.value(forKey: "natural_key") as? String
                }
                
                var sequence = 0
                var candidate = GlassItemModel.createNaturalKey(manufacturer: manufacturer, sku: sku, sequence: sequence)
                
                while existingKeys.contains(candidate) {
                    sequence += 1
                    candidate = GlassItemModel.createNaturalKey(manufacturer: manufacturer, sku: sku, sequence: sequence)
                }
                
                return candidate
            } catch {
                throw CoreDataGlassItemRepositoryError.queryFailed(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Private Helper Methods

    /// Build a search predicate based on the search mode
    private func buildSearchPredicate(for mode: SearchMode) -> NSPredicate {
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

    private func createItemSync(_ item: GlassItemModel) throws -> GlassItemModel {
        // Synchronous version for use within context.perform blocks
        let existingRequest = NSFetchRequest<NSManagedObject>(entityName: "GlassItem")
        existingRequest.predicate = NSPredicate(format: "natural_key == %@", item.natural_key)
        existingRequest.fetchLimit = 1
        
        let existing = try context.fetch(existingRequest)
        if let existingEntity = existing.first {
            updateEntity(existingEntity, with: item)
            return convertToGlassItemModel(existingEntity) ?? item
        }
        
        // Create new GlassItem entity using NSEntityDescription
        guard let entityDescription = NSEntityDescription.entity(forEntityName: "GlassItem", in: context) else {
            throw CoreDataGlassItemRepositoryError.createFailed("Could not find GlassItem entity description")
        }
        
        let entity = NSManagedObject(entity: entityDescription, insertInto: context)
        updateEntity(entity, with: item)
        
        return convertToGlassItemModel(entity) ?? item
    }
    
    private func convertToGlassItemModel(_ entity: NSManagedObject) -> GlassItemModel? {
        // Extract basic properties with safe defaults using KVC
        let name = entity.value(forKey: "name") as? String ?? ""
        let sku = entity.value(forKey: "sku") as? String ?? ""
        let manufacturer = entity.value(forKey: "manufacturer") as? String ?? ""
        
        // Get natural key, generate if missing
        let naturalKey: String
        if let existingKey = entity.value(forKey: "natural_key") as? String, !existingKey.isEmpty {
            naturalKey = existingKey
        } else {
            // Generate natural key from components
            naturalKey = GlassItemModel.createNaturalKey(manufacturer: manufacturer, sku: sku, sequence: 0)
        }
        
        // Extract glass-specific properties with safe defaults
        let mfr_notes = entity.value(forKey: "mfr_notes") as? String
        
        // Handle COE conversion with multiple type checks
        let coe: Int32
        if let coeValue = entity.value(forKey: "coe") as? Int32 {
            coe = coeValue
        } else if let coeValue = entity.value(forKey: "coe") as? Int16 {
            coe = Int32(coeValue)
        } else if let coeValue = entity.value(forKey: "coe") as? Int {
            coe = Int32(coeValue)
        } else if let coeValue = entity.value(forKey: "coe") as? NSNumber {
            coe = coeValue.int32Value
        } else {
            coe = 96 // Default COE
        }
        
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

        return GlassItemModel(
            natural_key: naturalKey,
            name: name,
            sku: sku,
            manufacturer: manufacturer,
            mfr_notes: mfr_notes,
            coe: coe,
            url: url,
            mfr_status: mfr_status,
            image_url: image_url,
            image_path: image_path
        )
    }
    
    private func updateEntity(_ entity: NSManagedObject, with model: GlassItemModel) {
        // Set basic properties using KVC
        entity.setValue(model.natural_key, forKey: "natural_key")
        entity.setValue(model.name, forKey: "name")
        entity.setValue(model.manufacturer, forKey: "manufacturer")

        // Set glass-specific properties using KVC
        entity.setValue(model.sku, forKey: "sku")
        entity.setValue(model.mfr_notes, forKey: "mfr_notes")
        entity.setValue(model.coe, forKey: "coe")
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

enum CoreDataGlassItemRepositoryError: Error, LocalizedError {
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
            return "Failed to fetch items: \(error.localizedDescription)"
        case .createFailed(let message):
            return "Failed to create item: \(message)"
        case .batchCreateFailed(let message):
            return "Failed to create items in batch: \(message)"
        case .updateFailed(let message):
            return "Failed to update item: \(message)"
        case .deleteFailed(let message):
            return "Failed to delete item: \(message)"
        case .itemNotFound(let naturalKey):
            return "Item not found with natural key: \(naturalKey)"
        case .searchFailed(let message):
            return "Search failed: \(message)"
        case .queryFailed(let message):
            return "Query failed: \(message)"
        }
    }
}
