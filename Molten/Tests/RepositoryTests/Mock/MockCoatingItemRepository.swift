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
final class MockCoatingItemRepository: CatalogItemRepository {
    typealias ItemType = CoatingItemModel

    // MARK: - Storage

    nonisolated(unsafe) private var items: [String: CoatingItemModel] = [:] // Key: stable_id

    // MARK: - CRUD Operations

    func fetchItems(matching predicate: NSPredicate?) async throws -> [CoatingItemModel] {
        // For simplicity, ignore predicate filtering in mock
        let itemsArray = Array(items.values)
        // Extract-pair-sort-map pattern for async property access
        var itemsWithNames: [(item: CoatingItemModel, name: String)] = []
        for item in itemsArray {
            let name = await item.name
            itemsWithNames.append((item, name))
        }
        itemsWithNames.sort { $0.name < $1.name }
        return itemsWithNames.map { $0.item }
    }

    func fetchItem(byStableId stableId: String) async throws -> CoatingItemModel? {
        return items[stableId]
    }

    func createItem(_ item: CoatingItemModel) async throws -> CoatingItemModel {
        let stableId = await item.stable_id
        items[stableId] = item
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

        // Filter items
        var filtered: [CoatingItemModel] = []
        for item in itemsArray {
            let name = await item.name
            let manufacturer = await item.manufacturer
            let notes = await item.mfr_notes
            if name.lowercased().contains(lowercasedText) ||
               manufacturer.lowercased().contains(lowercasedText) ||
               (notes?.lowercased().contains(lowercasedText) ?? false) {
                filtered.append(item)
            }
        }

        // Sort results - extract-pair-sort-map pattern
        var filteredWithNames: [(item: CoatingItemModel, name: String)] = []
        for item in filtered {
            let name = await item.name
            filteredWithNames.append((item, name))
        }
        filteredWithNames.sort { $0.name < $1.name }
        return filteredWithNames.map { $0.item }
    }

    func fetchItems(byManufacturer manufacturer: String) async throws -> [CoatingItemModel] {
        let itemsArray = Array(items.values)

        // Filter by manufacturer
        var filtered: [CoatingItemModel] = []
        for item in itemsArray {
            let itemManufacturer = await item.manufacturer
            if itemManufacturer == manufacturer {
                filtered.append(item)
            }
        }

        // Sort results - extract-pair-sort-map pattern
        var filteredWithNames: [(item: CoatingItemModel, name: String)] = []
        for item in filtered {
            let name = await item.name
            filteredWithNames.append((item, name))
        }
        filteredWithNames.sort { $0.name < $1.name }
        return filteredWithNames.map { $0.item }
    }

    func fetchItems(byStatus status: String) async throws -> [CoatingItemModel] {
        let itemsArray = Array(items.values)

        // Filter by status
        var filtered: [CoatingItemModel] = []
        for item in itemsArray {
            let itemStatus = await item.mfr_status
            if itemStatus == status {
                filtered.append(item)
            }
        }

        // Sort results - extract-pair-sort-map pattern
        var filteredWithNames: [(item: CoatingItemModel, name: String)] = []
        for item in filtered {
            let name = await item.name
            filteredWithNames.append((item, name))
        }
        filteredWithNames.sort { $0.name < $1.name }
        return filteredWithNames.map { $0.item }
    }

    // MARK: - Business Query Operations

    func getDistinctManufacturers() async throws -> [String] {
        let itemsArray = Array(items.values)

        // Extract manufacturers
        var manufacturers: Set<String> = []
        for item in itemsArray {
            let manufacturer = await item.manufacturer
            manufacturers.insert(manufacturer)
        }

        return manufacturers.sorted()
    }

    func getDistinctStatuses() async throws -> [String] {
        let itemsArray = Array(items.values)

        // Extract statuses
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
