//
//  CoreDataInventoryRepository+Helpers.swift
//  Molten
//
//  Private conversion methods and error definitions
//  Part of CoreDataInventoryRepository split to maintain <300 LOC per file
//

@preconcurrency import CoreData
import Foundation

// MARK: - Private Helper Methods

extension CoreDataInventoryRepository {

    func fetchInventorySync(forItem item_stable_id: String, type: String) throws -> [InventoryModel] {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Inventory")
        fetchRequest.predicate = NSPredicate(format: "item_stable_id == %@ AND type == %@", item_stable_id, type)

        let results = try context.fetch(fetchRequest)
        return results.compactMap { convertToInventoryModel($0) }
    }

    nonisolated func fetchCoreDataItemSync(byId id: UUID) throws -> NSManagedObject? {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Inventory")
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1

        let results = try context.fetch(fetchRequest)
        return results.first
    }

    nonisolated func convertToInventoryModel(_ coreDataItem: NSManagedObject) -> InventoryModel? {
        guard let idData = coreDataItem.value(forKey: "id") as? UUID,
              let item_stable_id = coreDataItem.value(forKey: "item_stable_id") as? String,
              let type = coreDataItem.value(forKey: "type") as? String,
              let quantityNumber = coreDataItem.value(forKey: "quantity") as? NSNumber else {
            log.error("Failed to convert Core Data item to InventoryModel - missing required properties")
            return nil
        }

        // Optional fields - date_added and date_modified might not exist in older records
        let date_added = coreDataItem.value(forKey: "date_added") as? Date ?? Date()
        let date_modified = coreDataItem.value(forKey: "date_modified") as? Date ?? Date()

        // Optional new fields - subtype, subsubtype, dimensions, location
        let subtype = coreDataItem.value(forKey: "subtype") as? String
        let subsubtype = coreDataItem.value(forKey: "subsubtype") as? String
        let location = coreDataItem.value(forKey: "location") as? String

        // Deserialize dimensions from JSON string stored in dimensions_x
        var dimensions: [String: Double]? = nil
        if let dimensionsJSON = coreDataItem.value(forKey: "dimensions_x") as? String,
           !dimensionsJSON.isEmpty,
           let data = dimensionsJSON.data(using: .utf8) {
            dimensions = try? JSONDecoder().decode([String: Double].self, from: data)
        }

        return InventoryModel(
            id: idData,
            item_stable_id: item_stable_id,
            type: type,
            subtype: subtype,
            subsubtype: subsubtype,
            dimensions: dimensions,
            quantity: quantityNumber.doubleValue,
            location: location,
            date_added: date_added,
            date_modified: date_modified
        )
    }

    nonisolated func updateCoreDataEntity(_ coreDataItem: NSManagedObject, with inventory: InventoryModel) {
        coreDataItem.setValue(inventory.id, forKey: "id")
        coreDataItem.setValue(inventory.item_stable_id, forKey: "item_stable_id")
        coreDataItem.setValue(inventory.type, forKey: "type")  // Use non-optional accessor
        coreDataItem.setValue(inventory.subtype, forKey: "subtype")
        coreDataItem.setValue(inventory.subsubtype, forKey: "subsubtype")

        // Serialize dimensions to JSON string and store in dimensions_x
        if let dimensions = inventory.dimensions, !dimensions.isEmpty {
            if let jsonData = try? JSONEncoder().encode(dimensions),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                coreDataItem.setValue(jsonString, forKey: "dimensions_x")
            }
        } else {
            coreDataItem.setValue(nil, forKey: "dimensions_x")
        }

        coreDataItem.setValue(NSNumber(value: inventory.quantity), forKey: "quantity")
        coreDataItem.setValue(inventory.location, forKey: "location")
        coreDataItem.setValue(inventory.date_added, forKey: "date_added")
        coreDataItem.setValue(inventory.date_modified, forKey: "date_modified")
    }
}

// MARK: - Core Data Repository Errors

enum CoreDataInventoryRepositoryError: Error, LocalizedError {
    case entityNotFound(String)
    case entityCreationFailed(String)
    case itemNotFound(String)
    case invalidData(String)

    var errorDescription: String? {
        switch self {
        case .entityNotFound(let entityName):
            return "Core Data entity not found: \(entityName)"
        case .entityCreationFailed(let entityName):
            return "Failed to create Core Data entity: \(entityName)"
        case .itemNotFound(let identifier):
            return "Inventory item not found: \(identifier)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        }
    }
}
