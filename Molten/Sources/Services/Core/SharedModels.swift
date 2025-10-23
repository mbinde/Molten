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
struct GlassItemModel: Identifiable, Equatable, Hashable, Sendable {
    let natural_key: String
    let stable_id: String?  // Short 6-char hash-based ID for QR codes and deep links
    let name: String
    let sku: String
    let manufacturer: String
    let mfr_notes: String?
    let coe: Int32
    let url: String?
    let uri: String
    let mfr_status: String
    let image_url: String?
    let image_path: String?

    nonisolated var id: String { natural_key }

    /// Initialize with computed URI
    nonisolated init(natural_key: String, stable_id: String? = nil, name: String, sku: String, manufacturer: String,
         mfr_notes: String? = nil, coe: Int32, url: String? = nil, mfr_status: String,
         image_url: String? = nil, image_path: String? = nil) {
        self.natural_key = natural_key
        self.stable_id = stable_id
        self.name = name
        self.sku = sku
        self.manufacturer = manufacturer
        self.mfr_notes = mfr_notes
        self.coe = coe
        self.url = url
        self.uri = "moltenglass:item?\(natural_key)"
        self.mfr_status = mfr_status
        self.image_url = image_url
        self.image_path = image_path
    }

    /// Parse natural key components
    /// - Returns: Tuple of (manufacturer, sku, sequence) or nil if invalid format
    nonisolated static func parseNaturalKey(_ naturalKey: String) -> (manufacturer: String, sku: String, sequence: Int)? {
        let components = naturalKey.components(separatedBy: "-")
        guard components.count == 3,
              let sequence = Int(components[2]) else {
            return nil
        }
        return (manufacturer: components[0], sku: components[1], sequence: sequence)
    }

    /// Create natural key from components
    nonisolated static func createNaturalKey(manufacturer: String, sku: String, sequence: Int) -> String {
        return "\(manufacturer.lowercased())-\(sku)-\(sequence)"
    }

    // Equatable conformance
    nonisolated static func == (lhs: GlassItemModel, rhs: GlassItemModel) -> Bool {
        return lhs.natural_key == rhs.natural_key
    }

    // Hashable conformance
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(natural_key)
    }
}

/// Inventory model for tracking quantities by type with optional subtypes and dimensions
struct InventoryModel: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    let item_natural_key: String
    let type: String
    let subtype: String?
    let subsubtype: String?
    let dimensions: [String: Double]?
    let quantity: Double
    let date_added: Date
    let date_modified: Date

    nonisolated init(
        id: UUID = UUID(),
        item_natural_key: String,
        type: String,
        subtype: String? = nil,
        subsubtype: String? = nil,
        dimensions: [String: Double]? = nil,
        quantity: Double,
        date_added: Date = Date(),
        date_modified: Date = Date()
    ) {
        self.id = id
        self.item_natural_key = item_natural_key
        self.type = Self.cleanType(type)
        self.subtype = subtype.map { Self.cleanType($0) }
        self.subsubtype = subsubtype.map { Self.cleanType($0) }
        self.dimensions = dimensions
        self.quantity = max(0.0, quantity) // Ensure non-negative quantity
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

/// Location model for tracking where inventory is stored
struct LocationModel: Identifiable, Sendable {
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
extension LocationModel: Equatable {
    nonisolated static func == (lhs: LocationModel, rhs: LocationModel) -> Bool {
        return lhs.id == rhs.id
    }
}

extension LocationModel: Hashable {
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Service Models

/// Complete inventory item model combining all related data
struct CompleteInventoryItemModel: Identifiable, Equatable, Hashable, Sendable {
    let glassItem: GlassItemModel
    let inventory: [InventoryModel]
    let tags: [String]  // Manufacturer/system tags
    let userTags: [String]  // User-created tags
    let locations: [LocationModel]
    let allTags: [String]  // Pre-computed combined tags for performance

    nonisolated var id: String { glassItem.natural_key }

    /// Initialize with automatic allTags computation
    nonisolated init(glassItem: GlassItemModel, inventory: [InventoryModel], tags: [String], userTags: [String], locations: [LocationModel]) {
        self.glassItem = glassItem
        self.inventory = inventory
        self.tags = tags
        self.userTags = userTags
        self.locations = locations
        // Pre-compute allTags for performance (avoid repeated computation in views)
        self.allTags = Array(Set(tags + userTags)).sorted()
    }

    /// Total quantity across all inventory records
    nonisolated var totalQuantity: Double {
        inventory.reduce(0.0) { $0 + $1.quantity }
    }

    /// Inventory grouped by type with total quantities
    nonisolated var inventoryByType: [String: Double] {
        Dictionary(grouping: inventory, by: { $0.type })
            .mapValues { inventoryRecords in
                inventoryRecords.reduce(0.0) { $0 + $1.quantity }
            }
    }

    nonisolated static func == (lhs: CompleteInventoryItemModel, rhs: CompleteInventoryItemModel) -> Bool {
        return lhs.glassItem.natural_key == rhs.glassItem.natural_key
    }

    // Hashable conformance for navigation
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(glassItem.natural_key)
    }
}

/// Inventory summary model for aggregated inventory information
struct InventorySummaryModel: Identifiable, Equatable, Sendable {
    let item_natural_key: String
    let inventories: [InventoryModel]

    nonisolated var id: String { item_natural_key }

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
        return lhs.item_natural_key == rhs.item_natural_key
    }
}


// MARK: - Enhanced Service Models

/// Request model for creating glass items with comprehensive options
struct GlassItemCreationRequest: Sendable {
    let name: String
    let sku: String
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
        sku: String,
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
    case natural_key

    nonisolated var displayName: String {
        switch self {
        case .name: return "Name"
        case .manufacturer: return "Manufacturer"
        case .coe: return "COE"
        case .totalQuantity: return "Total Quantity"
        case .natural_key: return "Natural Key"
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
}

/// Manufacturer statistics
struct ManufacturerStatisticsModel: Identifiable, Sendable {
    let name: String
    let itemCount: Int

    nonisolated var id: String { name }
}

/// Items needing attention report
struct ItemAttentionReportModel: Sendable {
    let itemsWithoutInventory: [GlassItemModel]
    let itemsWithoutTags: [GlassItemModel]
    let itemsWithInconsistentData: [GlassItemModel]
    let totalItems: Int

    /// Total items needing some kind of attention
    nonisolated var itemsNeedingAttention: Int {
        Set(itemsWithoutInventory.map { $0.natural_key })
            .union(Set(itemsWithoutTags.map { $0.natural_key }))
            .union(Set(itemsWithInconsistentData.map { $0.natural_key }))
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
