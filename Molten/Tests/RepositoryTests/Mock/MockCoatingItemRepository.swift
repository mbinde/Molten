//
//  MockCoatingItemRepository.swift
//  RepositoryTests
//
//  In-memory mock implementation of CoatingItemRepository for testing
//

import Foundation
@testable import Molten

/// Mock implementation of CoatingItemRepository for testing
/// Stores items in memory using a dictionary
final class MockCoatingItemRepository: CoatingItemRepository {

    // MARK: - Storage

    nonisolated(unsafe) private var items: [String: CoatingItemModel] = [:] // Key: stable_id

    // MARK: - CRUD Operations

    func fetchItems(matching predicate: NSPredicate?) async throws -> [CoatingItemModel] {
        // For simplicity, ignore predicate filtering in mock
        return Array(items.values).sorted { $0.name < $1.name }
    }

    func fetchItem(byStableId stableId: String) async throws -> CoatingItemModel? {
        return items[stableId]
    }

    func createItem(_ item: CoatingItemModel) async throws -> CoatingItemModel {
        let stableId = await item.stable_id; items[stableId] = item
        return item
    }

    func createItems(_ items: [CoatingItemModel]) async throws -> [CoatingItemModel] {
        for item in items {
            let stableId = await item.stable_id
            self.items[stableId] = item
        }
        return items
    }

    func updateItem(_ item: CoatingItemModel) async throws -> CoatingItemModel {
        let stableId = await item.stable_id
        guard items[stableId] != nil else {
            throw NSError(domain: "MockCoatingItemRepository", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Item not found: \(stableId)"
            ])
        }
        items[stableId] = item
        return item
    }

    func deleteItem(stableId: String) async throws {
        guard items[stableId] != nil else {
            throw NSError(domain: "MockCoatingItemRepository", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Item not found: \(stableId)"
            ])
        }
        items.removeValue(forKey: stableId)
    }

    func deleteItems(stableIds: [String]) async throws {
        for stableId in stableIds {
            items.removeValue(forKey: stableId)
        }
    }

    // MARK: - Search & Filter Operations

    func searchItems(text: String) async throws -> [CoatingItemModel] {
        let lowercasedText = text.lowercased()
        let itemsArray = Array(items.values)
        return itemsArray.filter { (item: CoatingItemModel) in
            let name = await item.name
            let manufacturer = await item.manufacturer
            let notes = await item.mfr_notes
            return name.lowercased().contains(lowercasedText) ||
                   manufacturer.lowercased().contains(lowercasedText) ||
                   (notes?.lowercased().contains(lowercasedText) ?? false)
        }.sorted { (a: CoatingItemModel, b: CoatingItemModel) in
            let aName = await a.name
            let bName = await b.name
            return aName < bName
        }
    }

    func fetchItems(byManufacturer manufacturer: String) async throws -> [CoatingItemModel] {
        let itemsArray = Array(items.values)
        return itemsArray.filter { (item: CoatingItemModel) in
            let itemManufacturer = await item.manufacturer
            return itemManufacturer == manufacturer
        }.sorted { (a: CoatingItemModel, b: CoatingItemModel) in
            let aName = await a.name
            let bName = await b.name
            return aName < bName
        }
    }

    func fetchItems(byStatus status: String) async throws -> [CoatingItemModel] {
        let itemsArray = Array(items.values)
        return itemsArray.filter { (item: CoatingItemModel) in
            let itemStatus = await item.mfr_status
            return itemStatus == status
        }.sorted { (a: CoatingItemModel, b: CoatingItemModel) in
            let aName = await a.name
            let bName = await b.name
            return aName < bName
        }
    }

    // MARK: - Business Query Operations

    func getDistinctManufacturers() async throws -> [String] {
        let itemsArray = Array(items.values)
        let manufacturers = Set(itemsArray.map { (item: CoatingItemModel) in
            let manufacturer = await item.manufacturer
            return manufacturer
        })
        return manufacturers.sorted()
    }

    func getDistinctStatuses() async throws -> [String] {
        let itemsArray = Array(items.values)
        let statuses = Set(itemsArray.map { (item: CoatingItemModel) in
            let status = await item.mfr_status
            return status
        })
        return statuses.sorted()
    }

    func stableIdExists(_ stableId: String) async throws -> Bool {
        return items[stableId] != nil
    }

    func generateNextNaturalKey(manufacturer: String, sku: String?) async throws -> String {
        // Simple implementation: generate a random 6-char hash
        let chars = "abcdefghijklmnopqrstuvwxyz0123456789"
        var result = ""
        for _ in 0..<6 {
            result.append(chars.randomElement()!)
        }
        return result
    }

    // MARK: - Test Helpers

    /// Get count of stored items (test helper)
    func getItemCount() async -> Int {
        return items.count
    }

    /// Clear all items (test helper)
    func clearAll() async {
        items.removeAll()
    }
}
