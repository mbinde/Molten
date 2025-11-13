//
//  SharedModels.swift
//  Flameworker
//
//  Created by Assistant on 10/14/25.
//  Models shared across multiple services and repositories
//

import Foundation

// MARK: - Core Domain Models

/// Glass item model representing the main item entity
///
/// ⚠️ CRITICAL WARNING TO FUTURE DEVELOPERS (INCLUDING AI ASSISTANTS):
/// - stable_id is the ONLY primary key (6-char hash like "abc123")
/// - DO NOT add a "natural_key" field - it was deleted and should NEVER come back
/// - DO NOT create any "bullseye-001-001" format keys - those are legacy garbage
/// - If you see natural_key in old tests, DELETE IT from the tests
struct GlassItemModel: Identifiable, Equatable, Hashable, Sendable {
    let stable_id: String  // PRIMARY KEY: MANDATORY 6-char hash (e.g., "abc123")
    let name: String
    let sku: String?  // Optional - some manufacturers don't use SKUs
    let manufacturer: String
    let mfr_notes: String?
    let coe: Int32
    let url: String?
    let uri: String
    let mfr_status: String
    let image_url: String?
    let image_path: String?

    nonisolated var id: String { stable_id }

    /// Initialize with computed URI
    nonisolated init(stable_id: String, name: String, sku: String?, manufacturer: String,
         mfr_notes: String? = nil, coe: Int32, url: String? = nil, mfr_status: String,
         image_url: String? = nil, image_path: String? = nil) {
        self.stable_id = stable_id
        self.name = name
        self.sku = sku
        self.manufacturer = manufacturer
        self.mfr_notes = mfr_notes
        self.coe = coe
        self.url = url
        self.uri = "moltenglass:item?\(stable_id)"
        self.mfr_status = mfr_status
        self.image_url = image_url
        self.image_path = image_path
    }

    // Equatable conformance - based on business key (manufacturer + SKU when available, else stable_id)
    // stable_id is used as fallback when SKU is not available
    nonisolated static func == (lhs: GlassItemModel, rhs: GlassItemModel) -> Bool {
        if let lhsSku = lhs.sku, let rhsSku = rhs.sku {
            return lhs.manufacturer == rhs.manufacturer && lhsSku == rhsSku
        }
        // Fallback to stable_id comparison when SKU is missing
        return lhs.stable_id == rhs.stable_id
    }

    // Hashable conformance - based on business key (manufacturer + SKU when available, else stable_id)
    // stable_id is used as fallback when SKU is not available
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(manufacturer)
        if let sku = sku {
            hasher.combine(sku)
        } else {
            hasher.combine(stable_id)
        }
    }
}

/// Coating item model representing coatings, enamels, lusters, and mica powders
///
/// ⚠️ CRITICAL WARNING TO FUTURE DEVELOPERS (INCLUDING AI ASSISTANTS):
/// - stable_id is the ONLY primary key (6-char hash like "abc123")
/// - Unlike GlassItem, coatings do NOT have a COE value
/// - DO NOT add a "natural_key" field - it was deleted and should NEVER come back
/// - DO NOT create any "manufacturer-001-001" format keys - those are legacy garbage
/// - If you see natural_key in old tests, DELETE IT from the tests
struct CoatingItemModel: Identifiable, Equatable, Hashable, Sendable {
    let stable_id: String  // PRIMARY KEY: MANDATORY 6-char hash (e.g., "abc123")
    let name: String
    let sku: String?  // Optional - some manufacturers don't use SKUs
    let manufacturer: String
    let mfr_notes: String?
    let url: String?
    let uri: String
    let mfr_status: String
    let image_url: String?
    let image_path: String?

    nonisolated var id: String { stable_id }

    /// Initialize with computed URI
    nonisolated init(stable_id: String, name: String, sku: String?, manufacturer: String,
         mfr_notes: String? = nil, url: String? = nil, mfr_status: String,
         image_url: String? = nil, image_path: String? = nil) {
        self.stable_id = stable_id
        self.name = name
        self.sku = sku
        self.manufacturer = manufacturer
        self.mfr_notes = mfr_notes
        self.url = url
        self.uri = "moltenglass:coating?\(stable_id)"
        self.mfr_status = mfr_status
        self.image_url = image_url
        self.image_path = image_path
    }

    // Equatable conformance - based on business key (manufacturer + SKU when available, else stable_id)
    // stable_id is used as fallback when SKU is not available
    nonisolated static func == (lhs: CoatingItemModel, rhs: CoatingItemModel) -> Bool {
        if let lhsSku = lhs.sku, let rhsSku = rhs.sku {
            return lhs.manufacturer == rhs.manufacturer && lhsSku == rhsSku
        }
        // Fallback to stable_id comparison when SKU is missing
        return lhs.stable_id == rhs.stable_id
    }

    // Hashable conformance - based on business key (manufacturer + SKU when available, else stable_id)
    // stable_id is used as fallback when SKU is not available
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(manufacturer)
        if let sku = sku {
            hasher.combine(sku)
        } else {
            hasher.combine(stable_id)
        }
    }
}

/// Tool item model representing tools, supports, and equipment
///
/// ⚠️ CRITICAL WARNING TO FUTURE DEVELOPERS (INCLUDING AI ASSISTANTS):
/// - stable_id is the ONLY primary key (6-char hash like "abc123")
/// - Unlike GlassItem, tools do NOT have a COE value
/// - DO NOT add a "natural_key" field - it was deleted and should NEVER come back
/// - DO NOT create any "manufacturer-001-001" format keys - those are legacy garbage
/// - If you see natural_key in old tests, DELETE IT from the tests
struct ToolItemModel: Identifiable, Equatable, Hashable, Sendable {
    let stable_id: String  // PRIMARY KEY: MANDATORY 6-char hash (e.g., "abc123")
    let name: String
    let sku: String?  // Optional - some manufacturers don't use SKUs
    let manufacturer: String
    let mfr_notes: String?
    let url: String?
    let uri: String
    let mfr_status: String
    let image_url: String?
    let image_path: String?

    nonisolated var id: String { stable_id }

    /// Initialize with computed URI
    nonisolated init(stable_id: String, name: String, sku: String?, manufacturer: String,
         mfr_notes: String? = nil, url: String? = nil, mfr_status: String,
         image_url: String? = nil, image_path: String? = nil) {
        self.stable_id = stable_id
        self.name = name
        self.sku = sku
        self.manufacturer = manufacturer
        self.mfr_notes = mfr_notes
        self.url = url
        self.uri = "moltenglass:tool?\(stable_id)"
        self.mfr_status = mfr_status
        self.image_url = image_url
        self.image_path = image_path
    }

    // Equatable conformance - based on business key (manufacturer + SKU when available, else stable_id)
    // stable_id is used as fallback when SKU is not available
    nonisolated static func == (lhs: ToolItemModel, rhs: ToolItemModel) -> Bool {
        if let lhsSku = lhs.sku, let rhsSku = rhs.sku {
            return lhs.manufacturer == rhs.manufacturer && lhsSku == rhsSku
        }
        // Fallback to stable_id comparison when SKU is missing
        return lhs.stable_id == rhs.stable_id
    }

    // Hashable conformance - based on business key (manufacturer + SKU when available, else stable_id)
    // stable_id is used as fallback when SKU is not available
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(manufacturer)
        if let sku = sku {
            hasher.combine(sku)
        } else {
            hasher.combine(stable_id)
        }
    }
}

/// Inventory model for tracking quantities by type with optional subtypes and dimensions
struct InventoryModel: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    let item_stable_id: String
    let type: String
    let subtype: String?
    let subsubtype: String?
    let dimensions: [String: Double]?
    let quantity: Double
    let location: String?
    let date_added: Date
    let date_modified: Date

    nonisolated init(
        id: UUID = UUID(),
        item_stable_id: String,
        type: String,
        subtype: String? = nil,
        subsubtype: String? = nil,
        dimensions: [String: Double]? = nil,
        quantity: Double,
        location: String? = nil,
        date_added: Date = Date(),
        date_modified: Date = Date()
    ) {
        self.id = id
        self.item_stable_id = item_stable_id
        self.type = Self.cleanType(type)
        self.subtype = subtype.map { Self.cleanType($0) }
        self.subsubtype = subsubtype.map { Self.cleanType($0) }
        self.dimensions = dimensions
        self.quantity = max(0.0, quantity) // Business rule: Ensure non-negative quantity
        self.location = location.map { StorageLocationModel.cleanLocationName($0) }
        self.date_added = date_added
        self.date_modified = date_modified
    }

    /// Clean and normalize inventory type string
    nonisolated static func cleanType(_ type: String) -> String {
        return type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Get a display-friendly description of this inventory record
    nonisolated var typeDescription: String {
        GlassItemTypeSystem.shortDescription(type: type, subtype: subtype, dimensions: dimensions)
    }

    /// Get full type path (type/subtype/subsubtype)
    nonisolated var fullTypePath: String {
        var path = type
        if let sub = subtype {
            path += "/\(sub)"
            if let subsub = subsubtype {
                path += "/\(subsub)"
            }
        }
        return path
    }

    // Equatable conformance
    nonisolated static func == (lhs: InventoryModel, rhs: InventoryModel) -> Bool {
        return lhs.id == rhs.id
    }

    // Hashable conformance
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Storage location model for tracking where inventory is stored (warehouse locations, shelves, bins, etc.)
struct StorageLocationModel: Identifiable, Sendable {
    let id: UUID
    let inventory_id: UUID
    let location: String
    let quantity: Double

    nonisolated init(id: UUID = UUID(), inventory_id: UUID, location: String, quantity: Double) {
        self.id = id
        self.inventory_id = inventory_id
        self.location = location.trimmingCharacters(in: .whitespacesAndNewlines)
        self.quantity = max(0.0, quantity) // Ensure non-negative quantity
    }

    /// Validates that a location name string is valid
    /// - Parameter location: The location name string to validate
    /// - Returns: True if valid, false otherwise
    nonisolated static func isValidLocationName(_ location: String) -> Bool {
        let trimmed = location.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 50
    }

    /// Cleans and normalizes a location name string
    /// - Parameter location: The raw location string
    /// - Returns: Cleaned location string suitable for storage
    nonisolated static func cleanLocationName(_ location: String) -> String {
        return location.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Shorthand alias for cleanLocationName (for backward compatibility)
    /// - Parameter location: The raw location string
    /// - Returns: Cleaned location string suitable for storage
    nonisolated static func cleanLocation(_ location: String) -> String {
        return cleanLocationName(location)
    }
}

// Explicit conformances to Equatable and Hashable
extension StorageLocationModel: Equatable {
    nonisolated static func == (lhs: StorageLocationModel, rhs: StorageLocationModel) -> Bool {
        return lhs.id == rhs.id
    }
}

extension StorageLocationModel: Hashable {
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Service Models

/// Catalog item type discriminator for CompleteInventoryItemModel
enum CatalogItemType: String, Sendable {
    case glass
    case coating
    case tool
}

/// Unified catalog item that can represent glass, coatings, or tools
struct UnifiedCatalogItem: Identifiable, Equatable, Hashable, Sendable {
    let stable_id: String
    let name: String
    let sku: String?
    let manufacturer: String
    let mfr_notes: String?
    let url: String?
    let uri: String
    let mfr_status: String
    let image_url: String?
    let image_path: String?
    let itemType: CatalogItemType
    let coe: Int32?  // Only for glass items

    nonisolated var id: String { stable_id }

    /// Initialize from GlassItemModel
    nonisolated init(glassItem: GlassItemModel) {
        self.stable_id = glassItem.stable_id
        self.name = glassItem.name
        self.sku = glassItem.sku
        self.manufacturer = glassItem.manufacturer
        self.mfr_notes = glassItem.mfr_notes
        self.url = glassItem.url
        self.uri = glassItem.uri
        self.mfr_status = glassItem.mfr_status
        self.image_url = glassItem.image_url
        self.image_path = glassItem.image_path
        self.itemType = .glass
        self.coe = glassItem.coe
    }

    /// Initialize from CoatingItemModel
    nonisolated init(coatingItem: CoatingItemModel) {
        self.stable_id = coatingItem.stable_id
        self.name = coatingItem.name
        self.sku = coatingItem.sku
        self.manufacturer = coatingItem.manufacturer
        self.mfr_notes = coatingItem.mfr_notes
        self.url = coatingItem.url
        self.uri = coatingItem.uri
        self.mfr_status = coatingItem.mfr_status
        self.image_url = coatingItem.image_url
        self.image_path = coatingItem.image_path
        self.itemType = .coating
        self.coe = nil  // Coatings don't have COE
    }

    /// Initialize from ToolItemModel
    nonisolated init(toolItem: ToolItemModel) {
        self.stable_id = toolItem.stable_id
        self.name = toolItem.name
        self.sku = toolItem.sku
        self.manufacturer = toolItem.manufacturer
        self.mfr_notes = toolItem.mfr_notes
        self.url = toolItem.url
        self.uri = toolItem.uri
        self.mfr_status = toolItem.mfr_status
        self.image_url = toolItem.image_url
        self.image_path = toolItem.image_path
        self.itemType = .tool
        self.coe = nil  // Tools don't have COE
    }

    // Equatable conformance - based on stable_id
    nonisolated static func == (lhs: UnifiedCatalogItem, rhs: UnifiedCatalogItem) -> Bool {
        return lhs.stable_id == rhs.stable_id
    }

    // Hashable conformance - based on stable_id
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(stable_id)
    }
}

/// CompleteInventoryItemModel moved to Models/Domain/CompleteInventoryItemModel.swift for proper architecture layering

/// Inventory summary model for aggregated inventory information
struct InventorySummaryModel: Identifiable, Equatable, Sendable {
    let item_stable_id: String
    let inventories: [InventoryModel]

    nonisolated var id: String { item_stable_id }

    /// Total quantity across all inventory records
    nonisolated var totalQuantity: Double {
        inventories.reduce(0.0) { $0 + $1.quantity }
    }

    /// Inventory grouped by type with total quantities
    nonisolated var inventoryByType: [String: Double] {
        Dictionary(grouping: inventories, by: { $0.type })
            .mapValues { inventoryRecords in
                inventoryRecords.reduce(0.0) { $0 + $1.quantity }
            }
    }

    /// Available inventory types
    nonisolated var availableTypes: [String] {
        Array(Set(inventories.map { $0.type })).sorted()
    }

    nonisolated static func == (lhs: InventorySummaryModel, rhs: InventorySummaryModel) -> Bool {
        return lhs.item_stable_id == rhs.item_stable_id
    }
}


// MARK: - Enhanced Service Models

/// Request model for creating glass items with comprehensive options
struct GlassItemCreationRequest: Sendable {
    let name: String
    let sku: String?  // Optional - some manufacturers don't use SKUs
    let manufacturer: String
    let mfr_notes: String?
    let coe: Int32
    let url: String?
    let mfr_status: String
    let customNaturalKey: String? // Optional custom natural key
    let initialInventory: [InventoryModel]
    let tags: [String]
    let image_url: String?
    let image_path: String?

    nonisolated init(
        name: String,
        sku: String?,
        manufacturer: String,
        mfr_notes: String? = nil,
        coe: Int32,
        url: String? = nil,
        mfr_status: String = "available",
        customNaturalKey: String? = nil,
        initialInventory: [InventoryModel] = [],
        tags: [String] = [],
        image_url: String? = nil,
        image_path: String? = nil
    ) {
        self.name = name
        self.sku = sku
        self.manufacturer = manufacturer
        self.mfr_notes = mfr_notes
        self.coe = coe
        self.url = url
        self.mfr_status = mfr_status
        self.customNaturalKey = customNaturalKey
        self.initialInventory = initialInventory
        self.tags = tags
        self.image_url = image_url
        self.image_path = image_path
    }
}

/// Enhanced search request model with comprehensive filtering
struct GlassItemSearchRequest: Sendable {
    let searchText: String?
    let tags: [String]
    let manufacturers: [String]
    let coeValues: [Int32]
    let manufacturerStatuses: [String]
    let hasInventory: Bool?
    let inventoryTypes: [String]
    let sortBy: GlassItemSortOption
    let offset: Int?
    let limit: Int?

    nonisolated init(
        searchText: String? = nil,
        tags: [String] = [],
        manufacturers: [String] = [],
        coeValues: [Int32] = [],
        manufacturerStatuses: [String] = [],
        hasInventory: Bool? = nil,
        inventoryTypes: [String] = [],
        sortBy: GlassItemSortOption = .name,
        offset: Int? = nil,
        limit: Int? = nil
    ) {
        self.searchText = searchText
        self.tags = tags
        self.manufacturers = manufacturers
        self.coeValues = coeValues
        self.manufacturerStatuses = manufacturerStatuses
        self.hasInventory = hasInventory
        self.inventoryTypes = inventoryTypes
        self.sortBy = sortBy
        self.offset = offset
        self.limit = limit
    }

    nonisolated func getAppliedFiltersDescription() -> String {
        var filters: [String] = []

        if let text = searchText, !text.isEmpty {
            filters.append("Text: '\(text)'")
        }
        if !tags.isEmpty {
            filters.append("Tags: \(tags.joined(separator: ", "))")
        }
        if !manufacturers.isEmpty {
            filters.append("Manufacturers: \(manufacturers.joined(separator: ", "))")
        }
        if !coeValues.isEmpty {
            filters.append("COE: \(coeValues.map(String.init).joined(separator: ", "))")
        }
        if !manufacturerStatuses.isEmpty {
            filters.append("Status: \(manufacturerStatuses.joined(separator: ", "))")
        }
        if let hasInv = hasInventory {
            filters.append("Has Inventory: \(hasInv ? "Yes" : "No")")
        }
        if !inventoryTypes.isEmpty {
            filters.append("Inventory Types: \(inventoryTypes.joined(separator: ", "))")
        }

        return filters.isEmpty ? "No filters applied" : filters.joined(separator: "; ")
    }
}

// MARK: - Business Logic (Filtering)

extension GlassItemSearchRequest {
    /// Business Logic: Filter items based on search request criteria
    ///
    /// - Parameters:
    ///   - items: Items to filter
    ///   - itemsWithTags: Closure that returns stable_ids of items having all requested tags
    ///   - itemsWithInventory: Closure that returns true if item has inventory
    /// - Returns: Filtered items matching all criteria
    ///
    /// Business rules:
    /// - All filters are AND operations (must match ALL criteria)
    /// - Empty filter arrays mean "no filtering" for that criterion
    /// - Tags filter uses closure to coordinate with repository
    /// - Inventory filter uses closure to coordinate with repository
    nonisolated func filter(
        _ items: [CompleteInventoryItemModel],
        itemsWithTags: ([String]) -> [String],
        itemsWithInventory: (String) -> Bool
    ) -> [CompleteInventoryItemModel] {
        var filtered = items

        // Filter by tags (uses closure for repository coordination)
        if !tags.isEmpty {
            let stableIdsWithTags = Set(itemsWithTags(tags))
            filtered = filtered.filter { stableIdsWithTags.contains($0.glassItem.stable_id) }
        }

        // Filter by manufacturers
        if !manufacturers.isEmpty {
            filtered = filtered.filter { manufacturers.contains($0.glassItem.manufacturer) }
        }

        // Filter by COE values
        if !coeValues.isEmpty {
            filtered = filtered.filter { coeValues.contains($0.glassItem.coe) }
        }

        // Filter by manufacturer status
        if !manufacturerStatuses.isEmpty {
            filtered = filtered.filter { manufacturerStatuses.contains($0.glassItem.mfr_status) }
        }

        // Filter by inventory presence (uses closure for repository coordination)
        if let hasInventory = hasInventory {
            filtered = filtered.filter { item in
                itemsWithInventory(item.glassItem.stable_id) == hasInventory
            }
        }

        return filtered
    }
}

/// Search result model with metadata
struct GlassItemSearchResult: Sendable {
    let items: [CompleteInventoryItemModel]
    let totalCount: Int
    let hasMore: Bool
    let appliedFilters: String
}

/// Sort options for glass items
enum GlassItemSortOption: CaseIterable, Sendable {
    case name
    case manufacturer
    case coe
    case totalQuantity

    nonisolated var displayName: String {
        switch self {
        case .name: return "Name"
        case .manufacturer: return "Manufacturer"
        case .coe: return "COE"
        case .totalQuantity: return "Total Quantity"
        }
    }
}

// MARK: - Sorting Logic (Business Rules)

extension GlassItemSortOption {
    /// Sort items according to this sort option's business rules
    /// Business rules:
    /// - name: Sort by name (case-insensitive, ascending)
    /// - manufacturer: Sort by manufacturer, then name (both ascending)
    /// - coe: Sort by COE, then name (ascending)
    /// - totalQuantity: Sort by quantity (descending), then name (ascending)
    nonisolated func sort(_ items: [CompleteInventoryItemModel]) -> [CompleteInventoryItemModel] {
        switch self {
        case .name:
            return items.sorted { (item1, item2) -> Bool in
                item1.glassItem.name.localizedCaseInsensitiveCompare(item2.glassItem.name) == .orderedAscending
            }
        case .manufacturer:
            return items.sorted { (item1, item2) -> Bool in
                if item1.glassItem.manufacturer != item2.glassItem.manufacturer {
                    return item1.glassItem.manufacturer.localizedCaseInsensitiveCompare(item2.glassItem.manufacturer) == .orderedAscending
                }
                return item1.glassItem.name.localizedCaseInsensitiveCompare(item2.glassItem.name) == .orderedAscending
            }
        case .coe:
            return items.sorted { (item1, item2) -> Bool in
                if item1.glassItem.coe != item2.glassItem.coe {
                    return item1.glassItem.coe < item2.glassItem.coe
                }
                return item1.glassItem.name.localizedCaseInsensitiveCompare(item2.glassItem.name) == .orderedAscending
            }
        case .totalQuantity:
            return items.sorted { (item1, item2) -> Bool in
                if item1.totalQuantity != item2.totalQuantity {
                    return item1.totalQuantity > item2.totalQuantity // Descending for quantity
                }
                return item1.glassItem.name.localizedCaseInsensitiveCompare(item2.glassItem.name) == .orderedAscending
            }
        }
    }
}

/// System status model
struct SystemStatusModel: Sendable {
    let itemCount: Int
    let hasData: Bool
    let systemType: String
}

/// Migration status model
struct MigrationStatusModel: Sendable {
    let migrationStage: MigrationStage
    let legacyItemCount: Int
    let newItemCount: Int
    let canMigrate: Bool
    let canRollback: Bool

    nonisolated var description: String {
        switch migrationStage {
        case .empty:
            return "No data in either system"
        case .legacyOnly:
            return "Legacy system only (\(legacyItemCount) items)"
        case .transitional:
            return "Both systems active (Legacy: \(legacyItemCount), New: \(newItemCount))"
        case .newSystemOnly:
            return "New system only (\(newItemCount) items)"
        }
    }
}

/// Migration stages
enum MigrationStage: Sendable {
    case empty
    case legacyOnly
    case transitional
    case newSystemOnly
}

/// Catalog operations for system validation
enum CatalogOperation: Sendable {
    case legacyRead
    case legacyWrite
    case newRead
    case newWrite
    case migration
    case rollback
}

/// Catalog overview statistics
struct CatalogOverviewModel: Sendable {
    let totalItems: Int
    let totalManufacturers: Int
    let totalTags: Int
    let itemsWithInventory: Int
    let lowStockItems: Int
    let systemType: String

    /// Business Logic: Aggregate catalog statistics into overview model
    /// - Parameters:
    ///   - totalItems: Total number of catalog items
    ///   - totalManufacturers: Number of distinct manufacturers
    ///   - totalTags: Total number of tags
    ///   - itemsWithInventory: Number of items that have inventory
    ///   - lowStockItems: Number of items below minimum threshold
    ///   - systemType: Type of catalog system (e.g., "GlassItem")
    /// - Returns: Overview model with aggregated statistics
    nonisolated static func from(
        totalItems: Int,
        totalManufacturers: Int,
        totalTags: Int,
        itemsWithInventory: Int,
        lowStockItems: Int,
        systemType: String
    ) -> CatalogOverviewModel {
        return CatalogOverviewModel(
            totalItems: totalItems,
            totalManufacturers: totalManufacturers,
            totalTags: totalTags,
            itemsWithInventory: itemsWithInventory,
            lowStockItems: lowStockItems,
            systemType: systemType
        )
    }
}

/// Manufacturer statistics
struct ManufacturerStatisticsModel: Identifiable, Sendable {
    let name: String
    let itemCount: Int

    nonisolated var id: String { name }
}

// MARK: - Sorting Logic (Business Rules)

extension ManufacturerStatisticsModel: Comparable {
    /// Sort manufacturers by itemCount (descending)
    /// Business rule: Manufacturers with most items should appear first
    static func < (lhs: ManufacturerStatisticsModel, rhs: ManufacturerStatisticsModel) -> Bool {
        // Higher itemCount is "less than" for descending sort
        return lhs.itemCount > rhs.itemCount
    }

    static func == (lhs: ManufacturerStatisticsModel, rhs: ManufacturerStatisticsModel) -> Bool {
        return lhs.name == rhs.name
    }
}

/// Items needing attention report
struct ItemAttentionReportModel: Sendable {
    let itemsWithoutInventory: [GlassItemModel]
    let itemsWithoutTags: [GlassItemModel]
    let itemsWithInconsistentData: [GlassItemModel]
    let totalItems: Int

    /// Total items needing some kind of attention
    nonisolated var itemsNeedingAttention: Int {
        Set(itemsWithoutInventory.map { $0.stable_id })
            .union(Set(itemsWithoutTags.map { $0.stable_id }))
            .union(Set(itemsWithInconsistentData.map { $0.stable_id }))
            .count
    }
}

// MARK: - Enhanced Service Errors

/// Errors that can occur in CatalogService
enum CatalogServiceError: Error, LocalizedError {
    case itemNotFound
    case legacySystemNotAvailable
    case newSystemNotAvailable
    case invalidOperation(String)
    case naturalKeyAlreadyExists(String)
    case invalidNaturalKeyFormat(String)
    case systemNotReadyForOperation(CatalogOperation, String)
    case migrationFailed(String)
    case validationFailed([String])
    
    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "Catalog item not found"
        case .legacySystemNotAvailable:
            return "Legacy catalog system not initialized"
        case .newSystemNotAvailable:
            return "New GlassItem system not initialized"
        case .invalidOperation(let message):
            return "Invalid catalog operation: \(message)"
        case .naturalKeyAlreadyExists(let naturalKey):
            return "Natural key already exists: \(naturalKey)"
        case .invalidNaturalKeyFormat(let naturalKey):
            return "Invalid natural key format: \(naturalKey)"
        case .systemNotReadyForOperation(let operation, let reason):
            return "System not ready for \(operation): \(reason)"
        case .migrationFailed(let reason):
            return "Migration failed: \(reason)"
        case .validationFailed(let errors):
            return "Validation failed: \(errors.joined(separator: "; "))"
        }
    }
}
