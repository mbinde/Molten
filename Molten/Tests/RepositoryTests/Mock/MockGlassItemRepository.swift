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

    // MARK: - CRUD Operations

    func fetchItems(matching predicate: NSPredicate?) async throws -> [GlassItemModel] {
        // For simplicity, ignore predicate filtering in mock
        let itemsArray = Array(items.values)
        return itemsArray.sorted { (a: GlassItemModel, b: GlassItemModel) in
            let aName = a.name
            let bName = b.name
            return aName < bName
        }
    }

    func fetchItem(byStableId stableId: String) async throws -> GlassItemModel? {
        return items[stableId]
    }

    func createItem(_ item: GlassItemModel) async throws -> GlassItemModel {
        let key = item.stable_id
        items[key] = item
        return item
    }

    func createItems(_ items: [GlassItemModel]) async throws -> [GlassItemModel] {
        for item in items {
            let key = item.stable_id
            self.items[key] = item
        }
        return items
    }

    func updateItem(_ item: GlassItemModel) async throws -> GlassItemModel {
        let key = item.stable_id
        guard items[key] != nil else {
            throw NSError(domain: "MockGlassItemRepository", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Item not found: \(key)"
            ])
        }
        items[key] = item
        return item
    }

    func deleteItem(stableId: String) async throws {
        guard items[stableId] != nil else {
            throw NSError(domain: "MockGlassItemRepository", code: 404, userInfo: [
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

    func searchItems(text: String) async throws -> [GlassItemModel] {
        let lowercasedText = text.lowercased()
        let itemsArray = Array(items.values)
        return itemsArray.filter { (item: GlassItemModel) in
            let name = item.name
            let manufacturer = item.manufacturer
            let notes = item.notes
            return name.lowercased().contains(lowercasedText) ||
                   manufacturer.lowercased().contains(lowercasedText) ||
                   (notes?.lowercased().contains(lowercasedText) ?? false)
        }.sorted { (a: GlassItemModel, b: GlassItemModel) in
            let aName = a.name
            let bName = b.name
            return aName < bName
        }
    }

    func fetchItems(byManufacturer manufacturer: String) async throws -> [GlassItemModel] {
        let itemsArray = Array(items.values)
        return itemsArray.filter { (item: GlassItemModel) in
            let itemManufacturer = item.manufacturer
            return itemManufacturer == manufacturer
        }.sorted { (a: GlassItemModel, b: GlassItemModel) in
            let aName = a.name
            let bName = b.name
            return aName < bName
        }
    }

    func fetchItems(byCOE coe: Int32) async throws -> [GlassItemModel] {
        let itemsArray = Array(items.values)
        return itemsArray.filter { (item: GlassItemModel) in
            let itemCOE = item.coe
            return itemCOE == coe
        }.sorted { (a: GlassItemModel, b: GlassItemModel) in
            let aName = a.name
            let bName = b.name
            return aName < bName
        }
    }

    func fetchItems(byStatus status: String) async throws -> [GlassItemModel] {
        let itemsArray = Array(items.values)
        return itemsArray.filter { (item: GlassItemModel) in
            let itemStatus = item.mfr_status
            return itemStatus == status
        }.sorted { (a: GlassItemModel, b: GlassItemModel) in
            let aName = a.name
            let bName = b.name
            return aName < bName
        }
    }

    // MARK: - Business Query Operations

    func getDistinctManufacturers() async throws -> [String] {
        let itemsArray = Array(items.values)
        let manufacturers = Set(itemsArray.map { (item: GlassItemModel) in
            let manufacturer = item.manufacturer
            return manufacturer
        })
        return manufacturers.sorted()
    }

    func getDistinctCOEValues() async throws -> [Int32] {
        let itemsArray = Array(items.values)
        let coes = Set(itemsArray.map { (item: GlassItemModel) in
            let coe = item.coe
            return coe
        })
        return coes.sorted()
    }

    func getDistinctStatuses() async throws -> [String] {
        let itemsArray = Array(items.values)
        let statuses = Set(itemsArray.map { (item: GlassItemModel) in
            let status = item.mfr_status
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

    // MARK: - Kiln Schedule Relationship Operations

    nonisolated(unsafe) private var recommendedSchedules: [String: [UUID]] = [:] // Key: stable_id

    func getRecommendedSchedules(forGlassItem stableId: String) async throws -> [UUID] {
        return recommendedSchedules[stableId] ?? []
    }

    func addRecommendedSchedule(scheduleId: UUID, toGlassItem stableId: String) async throws {
        if recommendedSchedules[stableId] == nil {
            recommendedSchedules[stableId] = []
        }
        if !recommendedSchedules[stableId]!.contains(scheduleId) {
            recommendedSchedules[stableId]!.append(scheduleId)
        }
    }

    func removeRecommendedSchedule(scheduleId: UUID, fromGlassItem stableId: String) async throws {
        recommendedSchedules[stableId]?.removeAll { $0 == scheduleId }
    }

    // MARK: - Test Helpers

    /// Configuration flags for testing
    var simulateLatency: Bool = false
    var shouldRandomlyFail: Bool = false
    var suppressVerboseLogging: Bool = true

    /// Get count of stored items (test helper)
    func getItemCount() async -> Int {
        return items.count
    }

    /// Clear all items (test helper)
    func clearAll() async {
        items.removeAll()
        recommendedSchedules.removeAll()
    }

    /// Clear all data (test helper, alias for clearAll for consistency with other mocks)
    func clearAllData() {
        items.removeAll()
        recommendedSchedules.removeAll()
    }
}
