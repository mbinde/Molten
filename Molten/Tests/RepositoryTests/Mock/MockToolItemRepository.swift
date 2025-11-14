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
final class MockToolItemRepository: ToolItemRepository {

    // MARK: - Storage

    nonisolated(unsafe) private var items: [String: ToolItemModel] = [:] // Key: stable_id

    // MARK: - CRUD Operations

    func fetchItems(matching predicate: NSPredicate?) async throws -> [ToolItemModel] {
        // For simplicity, ignore predicate filtering in mock
        return Array(items.values).sorted { $0.name < $1.name }
    }

    func fetchItem(byStableId stableId: String) async throws -> ToolItemModel? {
        return items[stableId]
    }

    func createItem(_ item: ToolItemModel) async throws -> ToolItemModel {
        items[item.stable_id] = item
        return item
    }

    func createItems(_ items: [ToolItemModel]) async throws -> [ToolItemModel] {
        for item in items {
            self.items[item.stable_id] = item
        }
        return items
    }

    func updateItem(_ item: ToolItemModel) async throws -> ToolItemModel {
        guard items[item.stable_id] != nil else {
            throw NSError(domain: "MockToolItemRepository", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Item not found: \(item.stable_id)"
            ])
        }
        items[item.stable_id] = item
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
        return items.values.filter { item in
            item.name.lowercased().contains(lowercasedText) ||
            item.manufacturer.lowercased().contains(lowercasedText) ||
            (item.mfr_notes?.lowercased().contains(lowercasedText) ?? false)
        }.sorted { $0.name < $1.name }
    }

    func fetchItems(byManufacturer manufacturer: String) async throws -> [ToolItemModel] {
        return items.values
            .filter { $0.manufacturer == manufacturer }
            .sorted { $0.name < $1.name }
    }

    func fetchItems(byStatus status: String) async throws -> [ToolItemModel] {
        return items.values
            .filter { $0.mfr_status == status }
            .sorted { $0.name < $1.name }
    }

    // MARK: - Business Query Operations

    func getDistinctManufacturers() async throws -> [String] {
        let manufacturers = Set(items.values.map { $0.manufacturer })
        return manufacturers.sorted()
    }

    func getDistinctStatuses() async throws -> [String] {
        let statuses = Set(items.values.map { $0.mfr_status })
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
