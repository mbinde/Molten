//
//  CoreDataCatalogRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/13/25.
//

import Foundation
import CoreData

/// Core Data implementation of CatalogItemRepository
class CoreDataCatalogRepository: CatalogItemRepository {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // MARK: - CatalogItemRepository Implementation
    
    func fetchItems(matching predicate: NSPredicate?) async throws -> [CatalogItemModel] {
        return try await context.perform {
            let request: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
            request.predicate = predicate
            request.sortDescriptors = [NSSortDescriptor(keyPath: \CatalogItem.name, ascending: true)]
            
            let entities = try self.context.fetch(request)
            return entities.compactMap { self.convertToModel($0) }
        }
    }
    
    func createItem(_ item: CatalogItemModel) async throws -> CatalogItemModel {
        return try await context.perform {
            guard let entity = PersistenceController.createCatalogItem(in: self.context) else {
                throw CoreDataError.contextSaveError(NSError(domain: "CoreDataCatalogRepository", code: 1, 
                                                            userInfo: [NSLocalizedDescriptionKey: "Failed to create CatalogItem"]))
            }
            
            self.updateEntity(entity, with: item)
            
            try self.context.save()
            return self.convertToModel(entity) ?? item
        }
    }
    
    func updateItem(_ item: CatalogItemModel) async throws -> CatalogItemModel {
        return try await context.perform {
            let request: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", item.id)
            request.fetchLimit = 1
            
            // If we can't find by ID, try to find an existing item to update
            // This handles the case where the entity might not have an ID field yet
            let entities = try self.context.fetch(request)
            let entity: CatalogItem
            
            if let existingEntity = entities.first {
                entity = existingEntity
            } else {
                // Create new entity if not found
                guard let newEntity = PersistenceController.createCatalogItem(in: self.context) else {
                    throw CoreDataError.contextSaveError(NSError(domain: "CoreDataCatalogRepository", code: 1, 
                                                                userInfo: [NSLocalizedDescriptionKey: "Failed to create CatalogItem for update"]))
                }
                entity = newEntity
            }
            
            self.updateEntity(entity, with: item)
            try self.context.save()
            
            return self.convertToModel(entity) ?? item
        }
    }
    
    func deleteItem(id: String) async throws {
        try await context.perform {
            let request: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id)
            request.fetchLimit = 1
            
            let entities = try self.context.fetch(request)
            guard let entity = entities.first else {
                throw CoreDataError.itemNotFound
            }
            
            self.context.delete(entity)
            try self.context.save()
        }
    }
    
    func searchItems(text: String) async throws -> [CatalogItemModel] {
        let predicate = createSearchPredicate(for: text)
        return try await fetchItems(matching: predicate)
    }
    
    // MARK: - Private Helper Methods
    
    private func convertToModel(_ entity: CatalogItem) -> CatalogItemModel? {
        // Use objectID as fallback for ID if entity doesn't have id field yet
        let entityId = (entity.value(forKey: "id") as? String) ?? entity.objectID.uriRepresentation().absoluteString
        
        let name = entity.name ?? ""
        let code = entity.code ?? ""
        let manufacturer = entity.manufacturer ?? ""
        
        // Handle tags if the entity supports them, otherwise default to empty
        let tags: [String]
        if let tagString = entity.value(forKey: "tags") as? String {
            tags = CatalogItemModel.stringToTags(tagString)
        } else {
            tags = []
        }
        
        // Handle units if the entity supports them, otherwise default to 1
        let units: Int16
        if let unitsValue = entity.value(forKey: "units") as? Int16 {
            units = unitsValue
        } else {
            units = 1
        }
        
        return CatalogItemModel(
            id: entityId,
            name: name,
            code: code,
            manufacturer: manufacturer,
            tags: tags,
            units: units
        )
    }
    
    private func updateEntity(_ entity: CatalogItem, with model: CatalogItemModel) {
        // Set basic properties that we know exist
        entity.name = model.name
        entity.code = model.code
        entity.manufacturer = model.manufacturer
        
        // Set optional properties if the entity supports them
        if entity.responds(to: Selector(("setId:"))) {
            entity.setValue(model.id, forKey: "id")
        }
        
        if entity.responds(to: Selector(("setTags:"))) {
            entity.setValue(CatalogItemModel.tagsToString(model.tags), forKey: "tags")
        }
        
        if entity.responds(to: Selector(("setUnits:"))) {
            entity.setValue(model.units, forKey: "units")
        }
        
        if entity.responds(to: Selector(("setDateCreated:"))) {
            entity.setValue(Date(), forKey: "dateCreated")
        }
    }
    
    private func createSearchPredicate(for text: String) -> NSPredicate {
        guard !text.isEmpty else {
            return NSPredicate(value: true)
        }
        
        let searchText = text.lowercased()
        
        // Search across name, code, manufacturer, and tags (if available)
        var predicates = [
            NSPredicate(format: "name CONTAINS[cd] %@", searchText),
            NSPredicate(format: "code CONTAINS[cd] %@", searchText),
            NSPredicate(format: "manufacturer CONTAINS[cd] %@", searchText)
        ]
        
        // Add tags search if the entity supports it
        let sampleEntity = NSEntityDescription.entity(forEntityName: "CatalogItem", in: context)
        if sampleEntity?.attributesByName["tags"] != nil {
            predicates.append(NSPredicate(format: "tags CONTAINS[cd] %@", searchText))
        }
        
        return NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
    }
}

// MARK: - Core Data to Model Conversion (Backward Compatibility)

extension CatalogItem {
    func toModel() -> CatalogItemModel {
        // This provides backward compatibility for existing code
        let entityId = (self.value(forKey: "id") as? String) ?? self.objectID.uriRepresentation().absoluteString
        
        return CatalogItemModel(
            id: entityId,
            name: self.name ?? "",
            code: self.code ?? "",
            manufacturer: self.manufacturer ?? "",
            tags: [], // Default for backward compatibility
            units: 1   // Default for backward compatibility
        )
    }
}

/// Core Data specific errors
enum CoreDataError: Error {
    case itemNotFound
    case contextSaveError(Error)
}