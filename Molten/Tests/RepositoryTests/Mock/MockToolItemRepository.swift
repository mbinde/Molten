//
//  MockToolItemRepository.swift
//  RepositoryTests
//
//  In-memory mock implementation of ToolItemRepository for testing
//

import Foundation
@testable import Molten

/// Mock implementation of ToolItemRepository for testing
/// Stores items in memory using a dictionary
@MainActor
final class MockToolItemRepository: CatalogItemRepository {
    typealias ItemType = ToolItemModel

    // MARK: - Storage

    nonisolated(unsafe) private var items: [String: ToolItemModel] = [:] // Key: stable_id

    // MARK: - CRUD Operations

    func fetchItems(matching predicate: NSPredicate?) async throws -> [ToolItemModel] {
        // For simplicity, ignore predicate filtering in mock
        let itemsArray = Array(items.values)

        // Extract names and pair with items for sorting
        var itemsWithNames: [(item: ToolItemModel, name: String)] = []
        for item in itemsArray {
            let name = await item.name
            itemsWithNames.append((item, name))
        }

        // Sort by name ascending
        itemsWithNames.sort { $0.name < $1.name }

        return itemsWithNames.map { $0.item }
    }

    func fetchItem(byStableId stableId: String) async throws -> ToolItemModel? {
        return items[stableId]
    }

    func createItem(_ item: ToolItemModel) async throws -> ToolItemModel {
        let stableId = await item.stable_id
        items[stableId] = item
        return item
    }

    func createItems(_ items: [ToolItemModel]) async throws -> [ToolItemModel] {
        for item in items {
            let stableId = await item.stable_id
            self.items[stableId] = item
        }
        return items
    }

    func updateItem(_ item: ToolItemModel) async throws -> ToolItemModel {
        let key = await item.stable_id
        guard items[key] != nil else {
            throw NSError(domain: "MockToolItemRepository", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Item not found: \(key)"
            ])
        }
        items[key] = item
        return item
    }

    func deleteItem(stableId: String) async throws {
        guard items[stableId] != nil else {
            throw NSError(domain: "MockToolItemRepository", code: 404, userInfo: [
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

    func searchItems(text: String) async throws -> [ToolItemModel] {
        let lowercasedText = text.lowercased()
        var filtered: [ToolItemModel] = []

        for item in items.values {
            let name = await item.name
            let manufacturer = await item.manufacturer
            let notes = await item.mfr_notes

            if name.lowercased().contains(lowercasedText) ||
               manufacturer.lowercased().contains(lowercasedText) ||
               (notes?.lowercased().contains(lowercasedText) ?? false) {
                filtered.append(item)
            }
        }

        // Extract names and pair with items for sorting
        var itemsWithNames: [(item: ToolItemModel, name: String)] = []
        for item in filtered {
            let name = await item.name
            itemsWithNames.append((item, name))
        }

        // Sort by name ascending
        itemsWithNames.sort { $0.name < $1.name }

        return itemsWithNames.map { $0.item }
    }

    func fetchItems(byManufacturer manufacturer: String) async throws -> [ToolItemModel] {
        var filtered: [ToolItemModel] = []

        for item in items.values {
            let itemManufacturer = await item.manufacturer
            if itemManufacturer == manufacturer {
                filtered.append(item)
            }
        }

        // Extract names and pair with items for sorting
        var itemsWithNames: [(item: ToolItemModel, name: String)] = []
        for item in filtered {
            let name = await item.name
            itemsWithNames.append((item, name))
        }

        // Sort by name ascending
        itemsWithNames.sort { $0.name < $1.name }

        return itemsWithNames.map { $0.item }
    }

    func fetchItems(byStatus status: String) async throws -> [ToolItemModel] {
        var filtered: [ToolItemModel] = []

        for item in items.values {
            let itemStatus = await item.mfr_status
            if itemStatus == status {
                filtered.append(item)
            }
        }

        // Extract names and pair with items for sorting
        var itemsWithNames: [(item: ToolItemModel, name: String)] = []
        for item in filtered {
            let name = await item.name
            itemsWithNames.append((item, name))
        }

        // Sort by name ascending
        itemsWithNames.sort { $0.name < $1.name }

        return itemsWithNames.map { $0.item }
    }

    // MARK: - Business Query Operations

    func getDistinctManufacturers() async throws -> [String] {
        let itemsArray = Array(items.values)
        var manufacturers: Set<String> = []
        for item in itemsArray {
            let manufacturer = await item.manufacturer
            manufacturers.insert(manufacturer)
        }
        return manufacturers.sorted()
    }

    func getDistinctStatuses() async throws -> [String] {
        let itemsArray = Array(items.values)
        var statuses: Set<String> = []
        for item in itemsArray {
            let status = await item.mfr_status
            statuses.insert(status)
        }
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
