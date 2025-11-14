//
//  CoreDataInventoryRepository+Aggregations.swift
//  Molten
//
//  Discovery, summary, and aggregation operations
//  Part of CoreDataInventoryRepository split to maintain <300 LOC per file
//

@preconcurrency import CoreData
import Foundation

// MARK: - Discovery Operations

extension CoreDataInventoryRepository {

    func getDistinctTypes() async throws -> [String] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSDictionary>(entityName: "Inventory")
                    fetchRequest.propertiesToFetch = ["type"]
                    fetchRequest.returnsDistinctResults = true
                    fetchRequest.resultType = .dictionaryResultType

                    let results = try self.context.fetch(fetchRequest)
                    let types = results.compactMap { $0["type"] as? String }.sorted()

                    self.log.debug("Found \(types.count) distinct inventory types")
                    continuation.resume(returning: types)

                } catch {
                    self.log.error("Failed to fetch distinct types: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getItemsWithInventory() async throws -> [String] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSDictionary>(entityName: "Inventory")
                    fetchRequest.propertiesToFetch = ["item_stable_id"]
                    fetchRequest.returnsDistinctResults = true
                    fetchRequest.resultType = .dictionaryResultType

                    let results = try self.context.fetch(fetchRequest)
                    let naturalKeys = results.compactMap { $0["item_stable_id"] as? String }.sorted()

                    self.log.debug("Found \(naturalKeys.count) items with inventory")
                    continuation.resume(returning: naturalKeys)

                } catch {
                    self.log.error("Failed to fetch items with inventory: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getItemsWithInventory(ofType type: String) async throws -> [String] {
        let cleanType = InventoryModel.cleanType(type)
        let predicate = NSPredicate(format: "type == %@", cleanType)
        let inventoryRecords = try await fetchInventory(matching: predicate)
        var itemStableIds = Set<String>()
        for record in inventoryRecords {
            itemStableIds.insert(await record.item_stable_id)
        }
        return Array(itemStableIds).sorted()
    }

    func getItemsWithLowInventory(threshold: Double) async throws -> [(item_stable_id: String, type: String, quantity: Double)] {
        let predicate = NSPredicate(format: "quantity > 0 AND quantity < %f", threshold)
        let inventoryRecords = try await fetchInventory(matching: predicate)

        var results: [(item_stable_id: String, type: String, quantity: Double)] = []
        for record in inventoryRecords {
            results.append((
                item_stable_id: await record.item_stable_id,
                type: await record.type,
                quantity: await record.quantity
            ))
        }
        return results.sorted { $0.quantity < $1.quantity }
    }

    func getItemsWithZeroInventory() async throws -> [String] {
        // This is conceptually tricky - items with "zero inventory" are items that
        // had inventory records but now have zero quantity. In our model, we delete
        // zero quantity records, so this would require tracking historical data.
        // For now, returning empty array as zero quantity records are deleted.
        return []
    }
}

// MARK: - Aggregation Operations

extension CoreDataInventoryRepository {

    func getInventorySummary() async throws -> [InventorySummaryModel] {
        let allInventory = try await fetchInventory(matching: nil)
        var groupedByItem: [String: [InventoryModel]] = [:]
        for inventory in allInventory {
            let key = await inventory.item_stable_id
            groupedByItem[key, default: []].append(inventory)
        }

        var results: [InventorySummaryModel] = []
        for (naturalKey, inventories) in groupedByItem {
            results.append(InventorySummaryModel(item_stable_id: naturalKey, inventories: inventories))
        }
        return results.sorted { $0.item_stable_id < $1.item_stable_id }
    }

    func getInventorySummary(forItem item_stable_id: String) async throws -> InventorySummaryModel? {
        let inventories = try await fetchInventory(forItem: item_stable_id)
        guard !inventories.isEmpty else { return nil }

        return InventorySummaryModel(item_stable_id: item_stable_id, inventories: inventories)
    }

    func estimateInventoryValue(defaultPricePerUnit: Double) async throws -> [String: Double] {
        let allInventory = try await fetchInventory(matching: nil)
        var groupedByItem: [String: [InventoryModel]] = [:]
        for inventory in allInventory {
            let key = await inventory.item_stable_id
            groupedByItem[key, default: []].append(inventory)
        }

        var result: [String: Double] = [:]
        for (key, inventories) in groupedByItem {
            var totalQuantity = 0.0
            for inventory in inventories {
                totalQuantity += await inventory.quantity
            }
            result[key] = totalQuantity * defaultPricePerUnit
        }
        return result
    }
}
