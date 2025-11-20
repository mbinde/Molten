//
//  CoreDataInventoryRepository+Locations.swift
//  Molten
//
//  Location queries and utilization operations
//  Part of CoreDataInventoryRepository split to maintain <300 LOC per file
//

@preconcurrency import CoreData
import Foundation
import OSLog

// MARK: - Location Operations

extension CoreDataInventoryRepository {

    func fetchInventory(atLocation location: String) async throws -> [InventoryModel] {
        let cleanLocation = StorageLocationModel.cleanLocationName(location)
        let predicate = NSPredicate(format: "location == %@", cleanLocation)
        return try await fetchInventory(matching: predicate)
    }

    func getDistinctLocations() async throws -> [String] {
        return try await CoreDataHelper.performAsync(on: context) { context in
            let fetchRequest = NSFetchRequest<NSDictionary>(entityName: "Inventory")
            fetchRequest.propertiesToFetch = ["location"]
            fetchRequest.returnsDistinctResults = true
            fetchRequest.resultType = .dictionaryResultType
            fetchRequest.predicate = NSPredicate(format: "location != nil")

            let results = try context.fetch(fetchRequest)
            let locations = results.compactMap { $0["location"] as? String }.sorted()

            self.log.debug("Found \(locations.count) distinct locations")
            return locations
        }
    }

    func getLocationNames(withPrefix prefix: String) async throws -> [String] {
        let cleanPrefix = StorageLocationModel.cleanLocationName(prefix)

        return try await CoreDataHelper.performAsync(on: context) { context in
            let fetchRequest = NSFetchRequest<NSDictionary>(entityName: "Inventory")
            fetchRequest.propertiesToFetch = ["location"]
            fetchRequest.returnsDistinctResults = true
            fetchRequest.resultType = .dictionaryResultType
            fetchRequest.predicate = NSPredicate(format: "location BEGINSWITH[c] %@", cleanPrefix)

            let results = try context.fetch(fetchRequest)
            let locations = results.compactMap { $0["location"] as? String }.sorted()

            self.log.debug("Found \(locations.count) locations with prefix: \(cleanPrefix)")
            return locations
        }
    }

    func getLocationUtilization(for location: String) async throws -> [String: Double] {
        let inventoryAtLocation = try await fetchInventory(atLocation: location)
        var groupedByItem: [String: [InventoryModel]] = [:]
        for inventory in inventoryAtLocation {
            let key = await inventory.item_stable_id
            groupedByItem[key, default: []].append(inventory)
        }

        var result: [String: Double] = [:]
        for (key, inventories) in groupedByItem {
            var total = 0.0
            for inventory in inventories {
                total += await inventory.quantity
            }
            result[key] = total
        }
        return result
    }

    func getAllLocationUtilization() async throws -> [String: Double] {
        let allInventory = try await fetchInventory(matching: NSPredicate(format: "location != nil"))
        var groupedByLocation: [String: [InventoryModel]] = [:]
        for inventory in allInventory {
            if let location = await inventory.location {
                groupedByLocation[location, default: []].append(inventory)
            }
        }

        var result: [String: Double] = [:]
        for (location, inventories) in groupedByLocation {
            var total = 0.0
            for inventory in inventories {
                total += await inventory.quantity
            }
            result[location] = total
        }
        return result
    }
}
