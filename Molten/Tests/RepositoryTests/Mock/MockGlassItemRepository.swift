//
//  MockGlassItemRepository.swift
//  RepositoryTests
//
//  In-memory mock implementation of GlassItemRepository for testing
//

import Foundation
@testable import Molten

/// Mock implementation of GlassItemRepository for testing
/// Stores items in memory using a dictionary
final class MockGlassItemRepository: GlassItemRepository {

    // MARK: - Storage

    nonisolated(unsafe) private var items: [String: GlassItemModel] = [:] // Key: stable_id
    private let lock = NSLock() // Protect concurrent access

    // MARK: - CRUD Operations

    func fetchItems(matching predicate: NSPredicate?) async throws -> [GlassItemModel] {
        // For simplicity, ignore predicate filtering in mock
        let itemsArray = lock.withLock { Array(items.values) }
        // Extract-pair-sort-map pattern for async property access
        var itemsWithNames: [(item: GlassItemModel, name: String)] = []
        for item in itemsArray {
            let name = await item.name
            itemsWithNames.append((item, name))
        }
        itemsWithNames.sort { $0.name < $1.name }
        return itemsWithNames.map { $0.item }
    }

    func fetchItem(byStableId stableId: String) async throws -> GlassItemModel? {
        return lock.withLock { items[stableId] }
    }

    func createItem(_ item: GlassItemModel) async throws -> GlassItemModel {
        var itemToCreate = item

        // Generate stable_id if it's "AUTO_ID"
        if await item.stable_id == "AUTO_ID" {
            // Generate a 6-character unique ID
            let generatedId = String(UUID().uuidString.prefix(6))
            itemToCreate = GlassItemModel(
                stable_id: generatedId,
                name: item.name,
                sku: item.sku,
                manufacturer: item.manufacturer,
                color_name: item.color_name,
                color_code: item.color_code,
                coe: item.coe,
                base_color: item.base_color,
                color_family: item.color_family,
                finish: item.finish,
                opacity: item.opacity,
                product_line: item.product_line,
                mfr_status: item.mfr_status,
                mfr_updated: item.mfr_updated,
                notes: item.notes,
                image_path: item.image_path
            )
        }

        let key = await itemToCreate.stable_id
        lock.withLock { items[key] = itemToCreate }
        return itemToCreate
    }

    func createItems(_ items: [GlassItemModel]) async throws -> [GlassItemModel] {
        var createdItems: [GlassItemModel] = []
        for item in items {
            let createdItem = try await createItem(item)
            createdItems.append(createdItem)
        }
        return createdItems
    }

    func updateItem(_ item: GlassItemModel) async throws -> GlassItemModel {
        let key = await item.stable_id
        let exists = lock.withLock { items[key] != nil }
        guard exists else {
            throw NSError(domain: "MockGlassItemRepository", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Item not found: \(key)"
            ])
        }
        lock.withLock { items[key] = item }
        return item
    }

    func deleteItem(stableId: String) async throws {
        let exists = lock.withLock { items[stableId] != nil }
        guard exists else {
            throw NSError(domain: "MockGlassItemRepository", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Item not found: \(stableId)"
            ])
        }
        lock.withLock { items.removeValue(forKey: stableId) }
    }

    func deleteItems(stableIds: [String]) async throws {
        lock.withLock {
            for stableId in stableIds {
                items.removeValue(forKey: stableId)
            }
        }
    }

    // MARK: - Search & Filter Operations

    func searchItems(text: String) async throws -> [GlassItemModel] {
        let itemsArray = lock.withLock { Array(items.values) }

        // Empty search returns all items
        if text.isEmpty {
            var itemsWithNames: [(item: GlassItemModel, name: String)] = []
            for item in itemsArray {
                let name = await item.name
                itemsWithNames.append((item, name))
            }
            itemsWithNames.sort { $0.name < $1.name }
            return itemsWithNames.map { $0.item }
        }

        // Filter items by search text
        let lowercasedText = text.lowercased()
        var filtered: [GlassItemModel] = []
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
        var itemsWithNames: [(item: GlassItemModel, name: String)] = []
        for item in filtered {
            let name = await item.name
            itemsWithNames.append((item, name))
        }
        itemsWithNames.sort { $0.name < $1.name }
        return itemsWithNames.map { $0.item }
    }

    func fetchItems(byManufacturer manufacturer: String) async throws -> [GlassItemModel] {
        let itemsArray = lock.withLock { Array(items.values) }

        // Filter by manufacturer
        var filtered: [GlassItemModel] = []
        for item in itemsArray {
            let itemManufacturer = await item.manufacturer
            if itemManufacturer == manufacturer {
                filtered.append(item)
            }
        }

        // Sort results - extract-pair-sort-map pattern
        var itemsWithNames: [(item: GlassItemModel, name: String)] = []
        for item in filtered {
            let name = await item.name
            itemsWithNames.append((item, name))
        }
        itemsWithNames.sort { $0.name < $1.name }
        return itemsWithNames.map { $0.item }
    }

    func fetchItems(byCOE coe: Int32) async throws -> [GlassItemModel] {
        let itemsArray = lock.withLock { Array(items.values) }

        // Filter by COE
        var filtered: [GlassItemModel] = []
        for item in itemsArray {
            let itemCOE = await item.coe
            if itemCOE == coe {
                filtered.append(item)
            }
        }

        // Sort results - extract-pair-sort-map pattern
        var itemsWithNames: [(item: GlassItemModel, name: String)] = []
        for item in filtered {
            let name = await item.name
            itemsWithNames.append((item, name))
        }
        itemsWithNames.sort { $0.name < $1.name }
        return itemsWithNames.map { $0.item }
    }

    func fetchItems(byStatus status: String) async throws -> [GlassItemModel] {
        let itemsArray = lock.withLock { Array(items.values) }

        // Filter by status
        var filtered: [GlassItemModel] = []
        for item in itemsArray {
            let itemStatus = await item.mfr_status
            if itemStatus == status {
                filtered.append(item)
            }
        }

        // Sort results - extract-pair-sort-map pattern
        var itemsWithNames: [(item: GlassItemModel, name: String)] = []
        for item in filtered {
            let name = await item.name
            itemsWithNames.append((item, name))
        }
        itemsWithNames.sort { $0.name < $1.name }
        return itemsWithNames.map { $0.item }
    }

    // MARK: - Business Query Operations

    func getDistinctManufacturers() async throws -> [String] {
        let itemsArray = lock.withLock { Array(items.values) }

        // Extract manufacturers
        var manufacturers: Set<String> = []
        for item in itemsArray {
            let manufacturer = await item.manufacturer
            manufacturers.insert(manufacturer)
        }

        return manufacturers.sorted()
    }

    func getDistinctCOEValues() async throws -> [Int32] {
        let itemsArray = lock.withLock { Array(items.values) }

        // Extract COE values
        var coes: Set<Int32> = []
        for item in itemsArray {
            let coe = await item.coe
            coes.insert(coe)
        }

        return coes.sorted()
    }

    func getDistinctStatuses() async throws -> [String] {
        let itemsArray = lock.withLock { Array(items.values) }

        // Extract statuses
        var statuses: Set<String> = []
        for item in itemsArray {
            let status = await item.mfr_status
            statuses.insert(status)
        }

        return statuses.sorted()
    }

    func stableIdExists(_ stableId: String) async throws -> Bool {
        return lock.withLock { items[stableId] != nil }
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

    // MARK: - Kiln Schedule Relationship Operations

    nonisolated(unsafe) private var recommendedSchedules: [String: [UUID]] = [:] // Key: stable_id

    func getRecommendedSchedules(forGlassItem stableId: String) async throws -> [UUID] {
        return lock.withLock { recommendedSchedules[stableId] ?? [] }
    }

    func addRecommendedSchedule(scheduleId: UUID, toGlassItem stableId: String) async throws {
        lock.withLock {
            if recommendedSchedules[stableId] == nil {
                recommendedSchedules[stableId] = []
            }
            if !recommendedSchedules[stableId]!.contains(scheduleId) {
                recommendedSchedules[stableId]!.append(scheduleId)
            }
        }
    }

    func removeRecommendedSchedule(scheduleId: UUID, fromGlassItem stableId: String) async throws {
        lock.withLock {
            recommendedSchedules[stableId]?.removeAll { $0 == scheduleId }
        }
    }

    // MARK: - Test Helpers

    /// Configuration flags for testing
    nonisolated(unsafe) var simulateLatency: Bool = false
    nonisolated(unsafe) var shouldRandomlyFail: Bool = false
    nonisolated(unsafe) var suppressVerboseLogging: Bool = true

    /// Get count of stored items (test helper)
    func getItemCount() async -> Int {
        return lock.withLock { items.count }
    }

    /// Clear all items (test helper)
    func clearAll() async {
        lock.withLock {
            items.removeAll()
            recommendedSchedules.removeAll()
        }
    }

    /// Clear all data (test helper, alias for clearAll for consistency with other mocks)
    func clearAllData() {
        lock.withLock {
            items.removeAll()
            recommendedSchedules.removeAll()
        }
    }
}
