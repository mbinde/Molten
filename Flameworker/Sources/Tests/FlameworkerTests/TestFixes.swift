//
//  TestFixes.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/14/25.
//  Comprehensive fixes for failing tests
//
//  This file provides test-specific implementations and fixes for compilation errors.
//  It includes mock repositories, test support models, and legacy compatibility utilities.
//

import Foundation
@testable import Flameworker

// MARK: - Test Support Models

/// Mock inventory service for test compatibility
class MockInventoryService {
    private var mockError: NSError?
    
    func setMockError(_ error: NSError?) {
        self.mockError = error
    }
    
    func processInventoryOperation() throws {
        if let error = mockError {
            throw error
        }
    }
}

// MARK: - Removed duplicate model definitions
// The following models are now defined in their canonical locations:
// - ShoppingPriority: Defined in ItemMinimumRepository.swift
// - ShoppingListItemModel: Defined in ItemMinimumRepository.swift  
// - LowStockItemModel: Defined in ItemMinimumRepository.swift
// - MinimumQuantityStatistics: Defined in ItemMinimumRepository.swift
// - GlassItemInventoryCoordination: Defined in EntityCoordinator.swift

/// Mock coordination service
class CoordinationService {
    func coordinateInventoryForGlassItem(naturalKey: String) -> GlassItemInventoryCoordination {
        // Create mock data for testing
        let mockGlassItem = GlassItemModel(
            natural_key: naturalKey,
            name: "Mock Item",
            sku: "mock",
            manufacturer: "mock",
            coe: 96,
            mfr_status: "available"
        )
        
        let mockCompleteItem = CompleteInventoryItemModel(
            glassItem: mockGlassItem,
            inventory: [],
            tags: [],
            locations: [LocationModel(
                id: UUID(),
                inventoryId: UUID(),
                location: "Test Location",
                quantity: 10.0
            )]
        )
        
        return GlassItemInventoryCoordination(
            completeItem: mockCompleteItem,
            inventorySummary: nil,
            totalQuantity: 10.0,
            hasInventory: true
        )
    }
}


/// Legacy validation result for catalog items (for backward compatibility)
struct CatalogItemValidationResult {
    let isValid: Bool
    let errors: [String]
    
    init(isValid: Bool, errors: [String]) {
        self.isValid = isValid
        self.errors = errors
    }
}

/// Legacy validation result for inventory items (for backward compatibility)
struct InventoryItemValidationResult {
    let isValid: Bool
    let errors: [String]
    
    init(isValid: Bool, errors: [String]) {
        self.isValid = isValid
        self.errors = errors
    }
}

/// Migration helper for legacy validation (redirects to modern validation)
struct LegacyValidationUtility {
    static func validateCatalogItem(_ item: CatalogItemModel) -> CatalogItemValidationResult {
        // Since CatalogItemModel is deprecated, we need to simulate the fields for migration
        // In a real migration, you'd convert CatalogItemModel -> GlassItemModel first
        var errors: [String] = []
        
        // Basic field validation that mirrors what the tests expect
        let trimmedName = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCode = item.code.trimmingCharacters(in: .whitespacesAndNewlines) 
        let trimmedManufacturer = item.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedName.isEmpty {
            errors.append("Name cannot be empty")
        }
        if trimmedCode.isEmpty {
            errors.append("Code cannot be empty")
        }
        if trimmedManufacturer.isEmpty {
            errors.append("Manufacturer cannot be empty")
        }
        
        return CatalogItemValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    static func validateInventoryItem(_ item: Any) -> InventoryItemValidationResult {
        // For legacy compatibility - assume basic validation
        // In a real migration, this would be converted to use ServiceValidation.validateInventoryModel()
        return InventoryItemValidationResult(isValid: true, errors: [])
    }
}

/// Modern validation adapter - use this instead of LegacyValidationUtility
struct ModernValidation {
    /// Validate a GlassItemModel using the modern validation system
    static func validateGlassItem(_ item: GlassItemModel) -> ValidationResult {
        return ServiceValidation.validateGlassItem(item)
    }
    
    /// Validate an InventoryModel using the modern validation system
    static func validateInventoryModel(_ item: InventoryModel) -> ValidationResult {
        return ServiceValidation.validateInventoryModel(item)
    }
    
    /// Convert legacy CatalogItemValidationResult to modern ValidationResult
    static func convertLegacyResult(_ legacyResult: CatalogItemValidationResult) -> ValidationResult {
        return ValidationResult(isValid: legacyResult.isValid, errors: legacyResult.errors)
    }
}





/// Mock repositories implementations for TestFixes
class TestFixesMockGlassItemRepository: GlassItemRepository {
    private var items: [GlassItemModel] = []
    private var nextId = 1
    
    // Configuration options for testing
    var simulateLatency = false
    var shouldRandomlyFail = false
    var latencyRange: ClosedRange<UInt64> = 10_000_000...50_000_000
    
    func createItem(_ item: GlassItemModel) async throws -> GlassItemModel {
        if items.contains(where: { $0.natural_key == item.natural_key }) {
            throw RepositoryError.duplicateNaturalKey(item.natural_key)
        }
        items.append(item)
        return item
    }
    
    func createItems(_ items: [GlassItemModel]) async throws -> [GlassItemModel] {
        var createdItems: [GlassItemModel] = []
        for item in items {
            let created = try await createItem(item)
            createdItems.append(created)
        }
        return createdItems
    }
    
    func fetchItems(matching predicate: NSPredicate?) async throws -> [GlassItemModel] {
        return items
    }
    
    func fetchItems(byManufacturer manufacturer: String) async throws -> [GlassItemModel] {
        return items.filter { $0.manufacturer == manufacturer }
    }
    
    func searchItems(text: String) async throws -> [GlassItemModel] {
        return items.filter { item in
            item.name.localizedCaseInsensitiveContains(text) ||
            item.manufacturer.localizedCaseInsensitiveContains(text) ||
            item.natural_key.localizedCaseInsensitiveContains(text)
        }
    }
    
    func updateItem(_ item: GlassItemModel) async throws -> GlassItemModel {
        guard let index = items.firstIndex(where: { $0.natural_key == item.natural_key }) else {
            throw RepositoryError.itemNotFound
        }
        items[index] = item
        return item
    }
    
    func deleteItem(naturalKey: String) async throws {
        items.removeAll { $0.natural_key == naturalKey }
    }
    
    func deleteItems(naturalKeys: [String]) async throws {
        items.removeAll { naturalKeys.contains($0.natural_key) }
    }
    
    func naturalKeyExists(_ naturalKey: String) async throws -> Bool {
        return items.contains { $0.natural_key == naturalKey }
    }
    
    func generateNextNaturalKey(manufacturer: String, sku: String) async throws -> String {
        let baseKey = "\(manufacturer.lowercased())-\(sku)-"
        var sequence = 0
        
        while true {
            let candidateKey = "\(baseKey)\(sequence)"
            if !items.contains(where: { $0.natural_key == candidateKey }) {
                return candidateKey
            }
            sequence += 1
        }
    }
    
    func fetchItem(byNaturalKey naturalKey: String) async throws -> GlassItemModel? {
        return items.first { $0.natural_key == naturalKey }
    }
    
    func fetchItems(byCOE coe: Int32) async throws -> [GlassItemModel] {
        return items.filter { $0.coe == coe }
    }
    
    func fetchItems(byStatus status: String) async throws -> [GlassItemModel] {
        return items.filter { $0.mfr_status == status }
    }
    
    func getDistinctManufacturers() async throws -> [String] {
        return Array(Set(items.map { $0.manufacturer })).sorted()
    }
    
    func getDistinctCOEValues() async throws -> [Int32] {
        return Array(Set(items.map { $0.coe })).sorted()
    }
    
    func getDistinctStatuses() async throws -> [String] {
        return Array(Set(items.map { $0.mfr_status })).sorted()
    }
    
    func clearAllData() {
        items.removeAll()
    }
}

class TestFixesMockInventoryRepository: InventoryRepository {
    private var items: [InventoryModel] = []
    
    func fetchInventory(matching predicate: NSPredicate?) async throws -> [InventoryModel] {
        return items
    }
    
    func fetchInventory(byId id: UUID) async throws -> InventoryModel? {
        return items.first { $0.id == id }
    }
    
    func fetchInventory(forItem item_natural_key: String) async throws -> [InventoryModel] {
        return items.filter { $0.item_natural_key == item_natural_key }
    }
    
    func fetchInventory(forItem item_natural_key: String, type: String) async throws -> [InventoryModel] {
        return items.filter { $0.item_natural_key == item_natural_key && $0.type == type }
    }
    
    func createInventory(_ inventory: InventoryModel) async throws -> InventoryModel {
        items.append(inventory)
        return inventory
    }
    
    func createInventories(_ inventories: [InventoryModel]) async throws -> [InventoryModel] {
        items.append(contentsOf: inventories)
        return inventories
    }
    
    func updateInventory(_ inventory: InventoryModel) async throws -> InventoryModel {
        guard let index = items.firstIndex(where: { $0.id == inventory.id }) else {
            throw RepositoryError.itemNotFound
        }
        items[index] = inventory
        return inventory
    }
    
    func deleteInventory(id: UUID) async throws {
        items.removeAll { $0.id == id }
    }
    
    func deleteInventory(forItem item_natural_key: String) async throws {
        items.removeAll { $0.item_natural_key == item_natural_key }
    }
    
    func deleteInventory(forItem item_natural_key: String, type: String) async throws {
        items.removeAll { $0.item_natural_key == item_natural_key && $0.type == type }
    }
    
    func getTotalQuantity(forItem item_natural_key: String) async throws -> Double {
        return items.filter { $0.item_natural_key == item_natural_key }.reduce(0) { $0 + $1.quantity }
    }
    
    func getTotalQuantity(forItem item_natural_key: String, type: String) async throws -> Double {
        return items.filter { $0.item_natural_key == item_natural_key && $0.type == type }.reduce(0) { $0 + $1.quantity }
    }
    
    func addQuantity(_ quantity: Double, toItem item_natural_key: String, type: String) async throws -> InventoryModel {
        if let existingIndex = items.firstIndex(where: { $0.item_natural_key == item_natural_key && $0.type == type }) {
            items[existingIndex] = InventoryModel(
                id: items[existingIndex].id,
                item_natural_key: item_natural_key,
                type: type,
                quantity: items[existingIndex].quantity + quantity
            )
            return items[existingIndex]
        } else {
            let newInventory = InventoryModel(
                id: UUID(),
                item_natural_key: item_natural_key,
                type: type,
                quantity: quantity
            )
            items.append(newInventory)
            return newInventory
        }
    }
    
    func subtractQuantity(_ quantity: Double, fromItem item_natural_key: String, type: String) async throws -> InventoryModel? {
        guard let existingIndex = items.firstIndex(where: { $0.item_natural_key == item_natural_key && $0.type == type }) else {
            throw RepositoryError.itemNotFound
        }
        
        let newQuantity = items[existingIndex].quantity - quantity
        if newQuantity <= 0 {
            items.remove(at: existingIndex)
            return nil
        } else {
            items[existingIndex] = InventoryModel(
                id: items[existingIndex].id,
                item_natural_key: item_natural_key,
                type: type,
                quantity: newQuantity
            )
            return items[existingIndex]
        }
    }
    
    func setQuantity(_ quantity: Double, forItem item_natural_key: String, type: String) async throws -> InventoryModel? {
        if let existingIndex = items.firstIndex(where: { $0.item_natural_key == item_natural_key && $0.type == type }) {
            if quantity <= 0 {
                items.remove(at: existingIndex)
                return nil
            } else {
                items[existingIndex] = InventoryModel(
                    id: items[existingIndex].id,
                    item_natural_key: item_natural_key,
                    type: type,
                    quantity: quantity
                )
                return items[existingIndex]
            }
        } else if quantity > 0 {
            let newInventory = InventoryModel(
                id: UUID(),
                item_natural_key: item_natural_key,
                type: type,
                quantity: quantity
            )
            items.append(newInventory)
            return newInventory
        }
        return nil
    }
    
    func getDistinctTypes() async throws -> [String] {
        return Array(Set(items.map { $0.type })).sorted()
    }
    
    func getItemsWithInventory() async throws -> [String] {
        return Array(Set(items.map { $0.item_natural_key })).sorted()
    }
    
    func getItemsWithInventory(ofType type: String) async throws -> [String] {
        return Array(Set(items.filter { $0.type == type }.map { $0.item_natural_key })).sorted()
    }
    
    func getItemsWithLowInventory(threshold: Double) async throws -> [(item_natural_key: String, type: String, quantity: Double)] {
        return items
            .filter { $0.quantity > 0 && $0.quantity < threshold }
            .map { (item_natural_key: $0.item_natural_key, type: $0.type, quantity: $0.quantity) }
            .sorted { $0.quantity < $1.quantity }
    }
    
    func getItemsWithZeroInventory() async throws -> [String] {
        // This would typically track items that previously had inventory
        return []
    }
    
    func getInventorySummary() async throws -> [InventorySummaryModel] {
        let grouped = Dictionary(grouping: items, by: { $0.item_natural_key })
        return grouped.map { key, inventories in
            InventorySummaryModel(item_natural_key: key, inventories: inventories)
        }.sorted { $0.item_natural_key < $1.item_natural_key }
    }
    
    func getInventorySummary(forItem item_natural_key: String) async throws -> InventorySummaryModel? {
        let itemInventories = items.filter { $0.item_natural_key == item_natural_key }
        guard !itemInventories.isEmpty else { return nil }
        
        return InventorySummaryModel(item_natural_key: item_natural_key, inventories: itemInventories)
    }
    
    func estimateInventoryValue(defaultPricePerUnit: Double) async throws -> [String: Double] {
        let grouped = Dictionary(grouping: items, by: { $0.item_natural_key })
        return grouped.mapValues { inventories in
            inventories.reduce(0) { $0 + $1.quantity } * defaultPricePerUnit
        }
    }
}

class TestFixesMockLocationRepository: LocationRepository {
    private var locations: [LocationModel] = []
    
    func fetchLocations(matching predicate: NSPredicate?) async throws -> [LocationModel] {
        return locations
    }
    
    func fetchLocations(forInventory inventoryId: UUID) async throws -> [LocationModel] {
        return locations.filter { $0.inventoryId == inventoryId }
    }
    
    func fetchLocations(withName locationName: String) async throws -> [LocationModel] {
        return locations.filter { $0.location == locationName }
    }
    
    func createLocation(_ location: LocationModel) async throws -> LocationModel {
        locations.append(location)
        return location
    }
    
    func createLocations(_ locations: [LocationModel]) async throws -> [LocationModel] {
        self.locations.append(contentsOf: locations)
        return locations
    }
    
    func updateLocation(_ location: LocationModel) async throws -> LocationModel {
        guard let index = locations.firstIndex(where: { $0.id == location.id }) else {
            throw RepositoryError.itemNotFound
        }
        locations[index] = location
        return location
    }
    
    func deleteLocation(_ location: LocationModel) async throws {
        locations.removeAll { $0.id == location.id }
    }
    
    func deleteLocations(forInventory inventoryId: UUID) async throws {
        locations.removeAll { $0.inventoryId == inventoryId }
    }
    
    func deleteLocations(withName locationName: String) async throws {
        locations.removeAll { $0.location == locationName }
    }
    
    func setLocations(_ locations: [(location: String, quantity: Double)], forInventory inventoryId: UUID) async throws {
        // Remove existing locations for this inventory
        self.locations.removeAll { $0.inventoryId == inventoryId }
        
        // Add new locations
        for (locationName, quantity) in locations {
            let newLocation = LocationModel(
                id: UUID(),
                inventoryId: inventoryId,
                location: locationName,
                quantity: quantity
            )
            self.locations.append(newLocation)
        }
    }
    
    func addQuantity(_ quantity: Double, toLocation locationName: String, forInventory inventoryId: UUID) async throws -> LocationModel {
        if let existingIndex = locations.firstIndex(where: { $0.inventoryId == inventoryId && $0.location == locationName }) {
            locations[existingIndex] = LocationModel(
                id: locations[existingIndex].id,
                inventoryId: inventoryId,
                location: locationName,
                quantity: locations[existingIndex].quantity + quantity
            )
            return locations[existingIndex]
        } else {
            let newLocation = LocationModel(
                id: UUID(),
                inventoryId: inventoryId,
                location: locationName,
                quantity: quantity
            )
            locations.append(newLocation)
            return newLocation
        }
    }
    
    func subtractQuantity(_ quantity: Double, fromLocation locationName: String, forInventory inventoryId: UUID) async throws -> LocationModel? {
        guard let existingIndex = locations.firstIndex(where: { $0.inventoryId == inventoryId && $0.location == locationName }) else {
            throw RepositoryError.itemNotFound
        }
        
        let newQuantity = locations[existingIndex].quantity - quantity
        if newQuantity <= 0 {
            locations.remove(at: existingIndex)
            return nil
        } else {
            locations[existingIndex] = LocationModel(
                id: locations[existingIndex].id,
                inventoryId: inventoryId,
                location: locationName,
                quantity: newQuantity
            )
            return locations[existingIndex]
        }
    }
    
    func moveQuantity(_ quantity: Double, fromLocation: String, toLocation: String, forInventory inventoryId: UUID) async throws {
        // Subtract from source
        _ = try await subtractQuantity(quantity, fromLocation: fromLocation, forInventory: inventoryId)
        // Add to destination
        _ = try await addQuantity(quantity, toLocation: toLocation, forInventory: inventoryId)
    }
    
    func getDistinctLocationNames() async throws -> [String] {
        return Array(Set(locations.map { $0.location })).sorted()
    }
    
    func getLocationNames(withPrefix prefix: String) async throws -> [String] {
        let distinctNames = try await getDistinctLocationNames()
        return distinctNames.filter { $0.hasPrefix(prefix) }
    }
    
    func getInventoriesInLocation(_ locationName: String) async throws -> [UUID] {
        return Array(Set(locations.filter { $0.location == locationName }.map { $0.inventoryId }))
    }
    
    func getLocationUtilization() async throws -> [String: Double] {
        let grouped = Dictionary(grouping: locations, by: { $0.location })
        return grouped.mapValues { locationRecords in
            locationRecords.reduce(0) { $0 + $1.quantity }
        }
    }
    
    func getLocationUsageCounts() async throws -> [(location: String, usageCount: Int)] {
        let grouped = Dictionary(grouping: locations, by: { $0.location })
        return grouped.map { (location: $0.key, usageCount: $0.value.count) }
            .sorted { $0.location < $1.location }
    }
    
    func validateLocationQuantities(forInventory inventoryId: UUID, expectedTotal: Double) async throws -> Bool {
        let actualTotal = locations
            .filter { $0.inventoryId == inventoryId }
            .reduce(0) { $0 + $1.quantity }
        return abs(actualTotal - expectedTotal) < 0.001 // Small tolerance for floating point
    }
    
    func getLocationQuantityDiscrepancy(forInventory inventoryId: UUID, expectedTotal: Double) async throws -> Double {
        let actualTotal = locations
            .filter { $0.inventoryId == inventoryId }
            .reduce(0) { $0 + $1.quantity }
        return actualTotal - expectedTotal
    }
    
    func findOrphanedLocations() async throws -> [LocationModel] {
        // For mock implementation, assume no orphaned locations
        return []
    }
}

class TestFixesMockItemTagsRepository: ItemTagsRepository {
    private var itemTags: [String: [String]] = [:]
    
    func fetchTags(forItem item_natural_key: String) async throws -> [String] {
        return itemTags[item_natural_key] ?? []
    }
    
    func addTag(_ tag: String, toItem item_natural_key: String) async throws {
        var currentTags = itemTags[item_natural_key] ?? []
        if !currentTags.contains(tag) {
            currentTags.append(tag)
            itemTags[item_natural_key] = currentTags
        }
    }
    
    func addTags(_ tags: [String], toItem item_natural_key: String) async throws {
        var currentTags = itemTags[item_natural_key] ?? []
        for tag in tags {
            if !currentTags.contains(tag) {
                currentTags.append(tag)
            }
        }
        itemTags[item_natural_key] = currentTags
    }
    
    func removeTag(_ tag: String, fromItem item_natural_key: String) async throws {
        var currentTags = itemTags[item_natural_key] ?? []
        currentTags.removeAll { $0 == tag }
        itemTags[item_natural_key] = currentTags
    }
    
    func removeAllTags(fromItem item_natural_key: String) async throws {
        itemTags.removeValue(forKey: item_natural_key)
    }
    
    func setTags(_ tags: [String], forItem item_natural_key: String) async throws {
        itemTags[item_natural_key] = tags
    }
    
    func getAllTags() async throws -> [String] {
        return Array(Set(itemTags.values.flatMap { $0 })).sorted()
    }
    
    func getTags(withPrefix prefix: String) async throws -> [String] {
        let allTags = try await getAllTags()
        return allTags.filter { $0.hasPrefix(prefix) }
    }
    
    func getMostUsedTags(limit: Int) async throws -> [String] {
        let tagCounts = Dictionary(grouping: itemTags.values.flatMap { $0 }, by: { $0 })
            .mapValues { $0.count }
        
        return tagCounts
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0.key }
    }
    
    func fetchItems(withTag tag: String) async throws -> [String] {
        return itemTags.compactMap { (naturalKey, tags) in
            tags.contains(tag) ? naturalKey : nil
        }
    }
    
    func fetchItems(withAllTags tags: [String]) async throws -> [String] {
        return itemTags.compactMap { (naturalKey, itemTagList) in
            tags.allSatisfy { itemTagList.contains($0) } ? naturalKey : nil
        }
    }
    
    func fetchItems(withAnyTags tags: [String]) async throws -> [String] {
        return itemTags.compactMap { (naturalKey, itemTagList) in
            tags.contains { itemTagList.contains($0) } ? naturalKey : nil
        }
    }
    
    func getTagUsageCounts() async throws -> [String: Int] {
        return Dictionary(grouping: itemTags.values.flatMap { $0 }, by: { $0 })
            .mapValues { $0.count }
    }
    
    func getTagsWithCounts(minCount: Int) async throws -> [(tag: String, count: Int)] {
        let tagCounts = Dictionary(grouping: itemTags.values.flatMap { $0 }, by: { $0 })
            .mapValues { $0.count }
            .filter { $0.value >= minCount }
        
        return tagCounts.map { (tag: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
    
    func tagExists(_ tag: String) async throws -> Bool {
        return itemTags.values.contains { $0.contains(tag) }
    }
}

/*
class TestFixesMockItemMinimumRepository: ItemMinimumRepository {
    private var minimums: [String: ItemMinimumModel] = [:]
    
    func fetchMinimums(matching predicate: NSPredicate?) async throws -> [ItemMinimumModel] {
        return Array(minimums.values)
    }
    
    func fetchMinimum(forItem item_natural_key: String, type: String) async throws -> ItemMinimumModel? {
        let key = "\(item_natural_key)-\(type)"
        return minimums[key]
    }
    
    func fetchMinimums(forItem item_natural_key: String) async throws -> [ItemMinimumModel] {
        return minimums.values.filter { $0.item_natural_key == item_natural_key }
    }
    
    func fetchMinimums(forStore store: String) async throws -> [ItemMinimumModel] {
        return minimums.values.filter { $0.store == store }
    }
    
    func createMinimum(_ minimum: ItemMinimumModel) async throws -> ItemMinimumModel {
        let key = "\(minimum.item_natural_key)-\(minimum.type)"
        minimums[key] = minimum
        return minimum
    }
    
    func createMinimums(_ minimums: [ItemMinimumModel]) async throws -> [ItemMinimumModel] {
        for minimum in minimums {
            _ = try await createMinimum(minimum)
        }
        return minimums
    }
    
    func updateMinimum(_ minimum: ItemMinimumModel) async throws -> ItemMinimumModel {
        let key = "\(minimum.item_natural_key)-\(minimum.type)"
        minimums[key] = minimum
        return minimum
    }
    
    func deleteMinimum(forItem item_natural_key: String, type: String) async throws {
        let key = "\(item_natural_key)-\(type)"
        minimums.removeValue(forKey: key)
    }
    
    func deleteMinimums(forItem item_natural_key: String) async throws {
        let keysToRemove = minimums.keys.filter { key in
            minimums[key]?.item_natural_key == item_natural_key
        }
        for key in keysToRemove {
            minimums.removeValue(forKey: key)
        }
    }
    
    func deleteMinimums(forStore store: String) async throws {
        let keysToRemove = minimums.keys.filter { key in
            minimums[key]?.store == store
        }
        for key in keysToRemove {
            minimums.removeValue(forKey: key)
        }
    }
    
    // MARK: - Shopping List Operations
    
    func generateShoppingList(forStore store: String, currentInventory: [String: [String: Double]]) async throws -> [ShoppingListItemModel] {
        let storeMinimums = try await fetchMinimums(forStore: store)
        var shoppingList: [ShoppingListItemModel] = []
        
        for minimum in storeMinimums {
            let currentQuantity = currentInventory[minimum.item_natural_key]?[minimum.type] ?? 0.0
            if currentQuantity < minimum.quantity {
                let item = ShoppingListItemModel(
                    item_natural_key: minimum.item_natural_key,
                    type: minimum.type,
                    currentQuantity: currentQuantity,
                    minimumQuantity: minimum.quantity,
                    store: store
                )
                shoppingList.append(item)
            }
        }
        
        return shoppingList.sorted()
    }
    
    func generateShoppingLists(currentInventory: [String: [String: Double]]) async throws -> [String: [ShoppingListItemModel]] {
        let stores = try await getDistinctStores()
        var result: [String: [ShoppingListItemModel]] = [:]
        
        for store in stores {
            result[store] = try await generateShoppingList(forStore: store, currentInventory: currentInventory)
        }
        
        return result
    }
    
    func getLowStockItems(currentInventory: [String: [String: Double]]) async throws -> [LowStockItemModel] {
        let allMinimums = Array(minimums.values)
        var lowStockItems: [LowStockItemModel] = []
        
        for minimum in allMinimums {
            let currentQuantity = currentInventory[minimum.item_natural_key]?[minimum.type] ?? 0.0
            if currentQuantity < minimum.quantity {
                let item = LowStockItemModel(
                    item_natural_key: minimum.item_natural_key,
                    type: minimum.type,
                    currentQuantity: currentQuantity,
                    minimumQuantity: minimum.quantity,
                    store: minimum.store
                )
                lowStockItems.append(item)
            }
        }
        
        return lowStockItems.sorted()
    }
    
    func setMinimumQuantity(_ quantity: Double, forItem item_natural_key: String, type: String, store: String) async throws -> ItemMinimumModel {
        let key = "\(item_natural_key)-\(type)"
        let minimum = ItemMinimumModel(
            item_natural_key: item_natural_key,
            quantity: quantity,
            type: type,
            store: store
        )
        minimums[key] = minimum
        return minimum
    }
    
    // MARK: - Store Management Operations
    
    func getDistinctStores() async throws -> [String] {
        return Array(Set(minimums.values.map { $0.store })).sorted()
    }
    
    func getStores(withPrefix prefix: String) async throws -> [String] {
        let stores = try await getDistinctStores()
        return stores.filter { $0.hasPrefix(prefix) }
    }
    
    func getStoreUtilization() async throws -> [String: Int] {
        return Dictionary(grouping: minimums.values, by: { $0.store })
            .mapValues { $0.count }
    }
    
    func updateStoreName(from oldStoreName: String, to newStoreName: String) async throws {
        for (key, minimum) in minimums {
            if minimum.store == oldStoreName {
                let updatedMinimum = ItemMinimumModel(
                    id: minimum.id,
                    item_natural_key: minimum.item_natural_key,
                    quantity: minimum.quantity,
                    type: minimum.type,
                    store: newStoreName
                )
                minimums[key] = updatedMinimum
            }
        }
    }
    
    // MARK: - Analytics Operations
    
    func getMinimumQuantityStatistics() async throws -> MinimumQuantityStatistics {
        return MinimumQuantityStatistics(minimums: Array(minimums.values))
    }
    
    func getHighestMinimums(limit: Int) async throws -> [ItemMinimumModel] {
        return Array(minimums.values)
            .sorted { $0.quantity > $1.quantity }
            .prefix(limit)
            .map { $0 }
    }
    
    func getMostCommonTypes() async throws -> [String: Int] {
        return Dictionary(grouping: minimums.values, by: { $0.type })
            .mapValues { $0.count }
    }
    
    func validateMinimumRecords(validItemKeys: Set<String>) async throws -> [ItemMinimumModel] {
        return minimums.values.filter { !validItemKeys.contains($0.item_natural_key) }
    }
}
 */

/// Repository error types that tests are expecting
enum RepositoryError: Error {
    case duplicateNaturalKey(String)
    case itemNotFound
    case invalidOperation(String)
    case systemNotReady(String)
    
    var localizedDescription: String {
        switch self {
        case .duplicateNaturalKey(let key):
            return "Duplicate natural key: \(key)"
        case .itemNotFound:
            return "Item not found"
        case .invalidOperation(let message):
            return "Invalid operation: \(message)"
        case .systemNotReady(let message):
            return "System not ready: \(message)"
        }
    }
}

// MARK: - String Validation Edge Cases Test Support

/// StringValidationTest helper for edge case testing
struct StringValidationTest {
    static func validateAndTrim(_ input: String) -> (isValid: Bool, trimmed: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        return (isValid: !trimmed.isEmpty, trimmed: trimmed)
    }
}
