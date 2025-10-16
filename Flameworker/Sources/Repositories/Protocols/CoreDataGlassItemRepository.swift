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
                print("🔍 CoreData DEBUG: fetchItems found \(entities.count) entities with predicate: \(predicate?.description ?? "nil")")
                
                let models = entities.compactMap { self.convertToGlassItemModel($0) }
                print("🔍 CoreData DEBUG: converted to \(models.count) GlassItemModel instances")
                return models
            } catch {
                print("❌ CoreData ERROR: fetchItems failed: \(error)")
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
                print("🔍 CoreData DEBUG: fetchItem(naturalKey: \(naturalKey)) found: \(model?.name ?? "nil")")
                return model
            } catch {
                print("❌ CoreData ERROR: fetchItem failed: \(error)")
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
                    print("⚠️ CoreData DEBUG: Item with natural_key \(item.natural_key) already exists, updating instead")
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
                print("✅ CoreData DEBUG: Created item \(item.name) with natural_key \(item.natural_key)")
                
                return self.convertToGlassItemModel(entity) ?? item
            } catch {
                print("❌ CoreData ERROR: createItem failed: \(error)")
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
                    print("❌ CoreData ERROR: Failed to create item \(item.natural_key): \(error)")
                    throw CoreDataGlassItemRepositoryError.batchCreateFailed("Failed to create item \(item.natural_key): \(error.localizedDescription)")
                }
            }
            
            try self.context.save()
            print("✅ CoreData DEBUG: Batch created \(createdItems.count) items")
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
                
                print("✅ CoreData DEBUG: Updated item \(item.natural_key)")
                return self.convertToGlassItemModel(entity) ?? item
            } catch {
                print("❌ CoreData ERROR: updateItem failed: \(error)")
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
                print("✅ CoreData DEBUG: Deleted item \(naturalKey)")
            } catch {
                print("❌ CoreData ERROR: deleteItem failed: \(error)")
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
                    print("⚠️ CoreData WARNING: Failed to delete item \(naturalKey): \(error)")
                }
            }
            
            try self.context.save()
            print("✅ CoreData DEBUG: Batch deleted \(naturalKeys.count) items")
        }
    }
    
    // MARK: - Search & Filter Operations
    
    func searchItems(text: String) async throws -> [GlassItemModel] {
        guard !text.isEmpty else {
            // Empty search returns all items
            return try await fetchItems(matching: nil)
        }
        
        return try await context.perform {
            let searchText = text.lowercased()
            
            // Create comprehensive search predicate
            var predicates = [
                NSPredicate(format: "name CONTAINS[cd] %@", searchText),
                NSPredicate(format: "sku CONTAINS[cd] %@", searchText), 
                NSPredicate(format: "manufacturer CONTAINS[cd] %@", searchText),
                NSPredicate(format: "mfrNotes CONTAINS[cd] %@", searchText)
            ]
            
            let searchPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
            
            let request = NSFetchRequest<NSManagedObject>(entityName: "GlassItem")
            request.predicate = searchPredicate
            request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
            
            do {
                let entities = try self.context.fetch(request)
                let models = entities.compactMap { self.convertToGlassItemModel($0) }
                
                print("🔍 CoreData DEBUG: searchItems('\(text)') found \(models.count) items")
                return models
            } catch {
                print("❌ CoreData ERROR: searchItems failed: \(error)")
                throw CoreDataGlassItemRepositoryError.searchFailed(error.localizedDescription)
            }
        }
    }
    
    func fetchItems(byManufacturer manufacturer: String) async throws -> [GlassItemModel] {
        let predicate = NSPredicate(format: "manufacturer == %@", manufacturer)
        let items = try await fetchItems(matching: predicate)
        print("🔍 CoreData DEBUG: fetchItems(byManufacturer: '\(manufacturer)') found \(items.count) items")
        return items
    }
    
    func fetchItems(byCOE coe: Int32) async throws -> [GlassItemModel] {
        let predicate = NSPredicate(format: "coe == %d", coe)
        let items = try await fetchItems(matching: predicate)
        print("🔍 CoreData DEBUG: fetchItems(byCOE: \(coe)) found \(items.count) items")
        return items
    }
    
    func fetchItems(byStatus status: String) async throws -> [GlassItemModel] {
        let predicate = NSPredicate(format: "mfrStatus == %@", status)
        let items = try await fetchItems(matching: predicate)
        print("🔍 CoreData DEBUG: fetchItems(byStatus: '\(status)') found \(items.count) items")
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
                
                print("🔍 CoreData DEBUG: getDistinctManufacturers found: \(manufacturers)")
                return manufacturers
            } catch {
                print("❌ CoreData ERROR: getDistinctManufacturers failed: \(error)")
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
                
                print("🔍 CoreData DEBUG: getDistinctCOEValues found: \(coeValues)")
                return coeValues
            } catch {
                print("❌ CoreData ERROR: getDistinctCOEValues failed: \(error)")
                throw CoreDataGlassItemRepositoryError.queryFailed(error.localizedDescription)
            }
        }
    }
    
    func getDistinctStatuses() async throws -> [String] {
        return try await context.perform {
            let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "GlassItem")
            request.resultType = .dictionaryResultType
            request.propertiesToFetch = ["mfrStatus"]
            request.returnsDistinctResults = true
            
            do {
                let results = try self.context.fetch(request) as! [[String: Any]]
                let statuses = results.compactMap { $0["mfrStatus"] as? String }
                    .filter { !$0.isEmpty }
                    .sorted()
                
                print("🔍 CoreData DEBUG: getDistinctStatuses found: \(statuses)")
                return statuses
            } catch {
                print("❌ CoreData ERROR: getDistinctStatuses failed: \(error)")
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
                print("❌ CoreData ERROR: naturalKeyExists failed: \(error)")
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
                
                print("🔍 CoreData DEBUG: generateNextNaturalKey for \(manufacturer)-\(sku) = \(candidate)")
                return candidate
            } catch {
                print("❌ CoreData ERROR: generateNextNaturalKey failed: \(error)")
                throw CoreDataGlassItemRepositoryError.queryFailed(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Debug and Diagnostic Methods
    
    /// Debug method to show all data in Core Data for troubleshooting
    func debugShowAllData() async throws {
        try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "GlassItem")
            request.sortDescriptors = [NSSortDescriptor(key: "manufacturer", ascending: true)]
            
            do {
                let entities = try self.context.fetch(request)
                print("🔍 CORE DATA DEBUG: Total entities in Core Data: \(entities.count)")
                print("🔍 CORE DATA DEBUG: All items:")
                
                var manufacturerCounts: [String: Int] = [:]
                var coeCounts: [Int32: Int] = [:]
                
                for (index, entity) in entities.enumerated() {
                    let name = entity.value(forKey: "name") as? String ?? "NO_NAME"
                    let sku = entity.value(forKey: "sku") as? String ?? "NO_SKU"
                    let manufacturer = entity.value(forKey: "manufacturer") as? String ?? "NO_MFR"
                    let naturalKey = entity.value(forKey: "natural_key") as? String ?? "NO_KEY"
                    
                    // Handle COE conversion
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
                        coe = -1
                    }
                    
                    print("  \(index + 1). '\(name)' (\(sku)) - \(manufacturer) - COE:\(coe) - Key: \(naturalKey)")
                    
                    // Count by manufacturer
                    manufacturerCounts[manufacturer, default: 0] += 1
                    
                    // Count by COE
                    if coe > 0 {
                        coeCounts[coe, default: 0] += 1
                    }
                }
                
                print("🔍 CORE DATA DEBUG: Manufacturer counts:")
                for (mfr, count) in manufacturerCounts.sorted(by: { $0.key < $1.key }) {
                    print("  - \(mfr): \(count) items")
                }
                
                print("🔍 CORE DATA DEBUG: COE counts:")
                for (coe, count) in coeCounts.sorted(by: { $0.key < $1.key }) {
                    print("  - COE \(coe): \(count) items")
                }
                
            } catch {
                print("❌ CoreData ERROR: debugShowAllData failed: \(error)")
            }
        }
    }
    
    /// Debug method to check for duplicates
    func debugCheckForDuplicates() async throws {
        try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "GlassItem")
            
            do {
                let entities = try self.context.fetch(request)
                var nameGroups: [String: [NSManagedObject]] = [:]
                var naturalKeyGroups: [String: [NSManagedObject]] = [:]
                
                for entity in entities {
                    let name = entity.value(forKey: "name") as? String ?? "NO_NAME"
                    nameGroups[name, default: []].append(entity)
                    
                    let naturalKey = entity.value(forKey: "natural_key") as? String ?? "NO_KEY"
                    naturalKeyGroups[naturalKey, default: []].append(entity)
                }
                
                print("🔍 CORE DATA DUPLICATES: Checking for duplicate names:")
                for (name, items) in nameGroups where items.count > 1 {
                    print("  - '\(name)': \(items.count) copies")
                }
                
                print("🔍 CORE DATA DUPLICATES: Checking for duplicate natural keys:")
                for (key, items) in naturalKeyGroups where items.count > 1 {
                    print("  - '\(key)': \(items.count) copies")
                }
                
            } catch {
                print("❌ CoreData ERROR: debugCheckForDuplicates failed: \(error)")
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
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
        let mfrNotes = entity.value(forKey: "mfrNotes") as? String
        
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
        let mfrStatus = entity.value(forKey: "mfrStatus") as? String ?? "available"
        
        return GlassItemModel(
            natural_key: naturalKey,
            name: name,
            sku: sku,
            manufacturer: manufacturer,
            mfrNotes: mfrNotes,
            coe: coe,
            url: url,
            mfrStatus: mfrStatus
        )
    }
    
    private func updateEntity(_ entity: NSManagedObject, with model: GlassItemModel) {
        // Set basic properties using KVC
        entity.setValue(model.natural_key, forKey: "natural_key")
        entity.setValue(model.name, forKey: "name")
        entity.setValue(model.manufacturer, forKey: "manufacturer")
        entity.setValue(Date(), forKey: "dateCreated")
        
        // Set glass-specific properties using KVC
        entity.setValue(model.sku, forKey: "sku")
        entity.setValue(model.mfrNotes, forKey: "mfrNotes")
        entity.setValue(model.coe, forKey: "coe")
        entity.setValue(model.url, forKey: "url")
        entity.setValue(model.mfrStatus, forKey: "mfrStatus")
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