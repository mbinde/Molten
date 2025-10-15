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
struct GlassItemModel: Identifiable, Equatable, Hashable {
    let naturalKey: String
    let name: String
    let sku: String
    let manufacturer: String
    let mfrNotes: String?
    let coe: Int32
    let url: String?
    let uri: String
    let mfrStatus: String
    
    var id: String { naturalKey }
    
    /// Initialize with computed URI
    init(naturalKey: String, name: String, sku: String, manufacturer: String, 
         mfrNotes: String? = nil, coe: Int32, url: String? = nil, mfrStatus: String) {
        self.naturalKey = naturalKey
        self.name = name
        self.sku = sku
        self.manufacturer = manufacturer
        self.mfrNotes = mfrNotes
        self.coe = coe
        self.url = url
        self.uri = "moltenglass:item?\(naturalKey)"
        self.mfrStatus = mfrStatus
    }
    
    /// Parse natural key components
    /// - Returns: Tuple of (manufacturer, sku, sequence) or nil if invalid format
    static func parseNaturalKey(_ naturalKey: String) -> (manufacturer: String, sku: String, sequence: Int)? {
        let components = naturalKey.components(separatedBy: "-")
        guard components.count == 3,
              let sequence = Int(components[2]) else {
            return nil
        }
        return (manufacturer: components[0], sku: components[1], sequence: sequence)
    }
    
    /// Create natural key from components
    static func createNaturalKey(manufacturer: String, sku: String, sequence: Int) -> String {
        return "\(manufacturer.lowercased())-\(sku)-\(sequence)"
    }
    
    // Equatable conformance
    static func == (lhs: GlassItemModel, rhs: GlassItemModel) -> Bool {
        return lhs.naturalKey == rhs.naturalKey
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(naturalKey)
    }
}

/// Inventory model for tracking quantities by type
struct InventoryModel: Identifiable, Equatable, Hashable {
    let id: UUID
    let itemNaturalKey: String
    let type: String
    let quantity: Double
    
    init(id: UUID = UUID(), itemNaturalKey: String, type: String, quantity: Double) {
        self.id = id
        self.itemNaturalKey = itemNaturalKey
        self.type = Self.cleanType(type)
        self.quantity = max(0.0, quantity) // Ensure non-negative quantity
    }
    
    /// Clean and normalize inventory type string
    static func cleanType(_ type: String) -> String {
        return type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    
    // Equatable conformance
    static func == (lhs: InventoryModel, rhs: InventoryModel) -> Bool {
        return lhs.id == rhs.id
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Location model for tracking where inventory is stored
struct LocationModel: Identifiable, Equatable, Hashable {
    let id: UUID
    let inventoryId: UUID
    let location: String
    let quantity: Double
    
    init(id: UUID = UUID(), inventoryId: UUID, location: String, quantity: Double) {
        self.id = id
        self.inventoryId = inventoryId
        self.location = location.trimmingCharacters(in: .whitespacesAndNewlines)
        self.quantity = max(0.0, quantity) // Ensure non-negative quantity
    }
    
    // Equatable conformance
    static func == (lhs: LocationModel, rhs: LocationModel) -> Bool {
        return lhs.id == rhs.id
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    /// Validates that a location name string is valid
    /// - Parameter location: The location name string to validate
    /// - Returns: True if valid, false otherwise
    static func isValidLocationName(_ location: String) -> Bool {
        let trimmed = location.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 50
    }
    
    /// Cleans and normalizes a location name string
    /// - Parameter location: The raw location string
    /// - Returns: Cleaned location string suitable for storage
    static func cleanLocationName(_ location: String) -> String {
        return location.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Shorthand alias for cleanLocationName (for backward compatibility)
    /// - Parameter location: The raw location string
    /// - Returns: Cleaned location string suitable for storage
    static func cleanLocation(_ location: String) -> String {
        return cleanLocationName(location)
    }
}

// MARK: - Service Models

/// Complete inventory item model combining all related data
struct CompleteInventoryItemModel: Identifiable, Equatable, Hashable {
    let glassItem: GlassItemModel
    let inventory: [InventoryModel]
    let tags: [String]
    let locations: [LocationModel]
    
    var id: String { glassItem.naturalKey }
    
    /// Total quantity across all inventory records
    var totalQuantity: Double {
        inventory.reduce(0.0) { $0 + $1.quantity }
    }
    
    /// Inventory grouped by type with total quantities
    var inventoryByType: [String: Double] {
        Dictionary(grouping: inventory, by: { $0.type })
            .mapValues { inventoryRecords in
                inventoryRecords.reduce(0.0) { $0 + $1.quantity }
            }
    }
    
    static func == (lhs: CompleteInventoryItemModel, rhs: CompleteInventoryItemModel) -> Bool {
        return lhs.glassItem.naturalKey == rhs.glassItem.naturalKey
    }
    
    // Hashable conformance for navigation
    func hash(into hasher: inout Hasher) {
        hasher.combine(glassItem.naturalKey)
    }
}

/// Inventory summary model for aggregated inventory information
struct InventorySummaryModel: Identifiable, Equatable {
    let itemNaturalKey: String
    let inventories: [InventoryModel]
    
    var id: String { itemNaturalKey }
    
    /// Total quantity across all inventory records
    var totalQuantity: Double {
        inventories.reduce(0.0) { $0 + $1.quantity }
    }
    
    /// Inventory grouped by type with total quantities
    var inventoryByType: [String: Double] {
        Dictionary(grouping: inventories, by: { $0.type })
            .mapValues { inventoryRecords in
                inventoryRecords.reduce(0.0) { $0 + $1.quantity }
            }
    }
    
    /// Available inventory types
    var availableTypes: [String] {
        Array(Set(inventories.map { $0.type })).sorted()
    }
    
    static func == (lhs: InventorySummaryModel, rhs: InventorySummaryModel) -> Bool {
        return lhs.itemNaturalKey == rhs.itemNaturalKey
    }
}


// MARK: - Enhanced Service Models

/// Request model for creating glass items with comprehensive options
struct GlassItemCreationRequest {
    let name: String
    let sku: String
    let manufacturer: String
    let mfrNotes: String?
    let coe: Int32
    let url: String?
    let mfrStatus: String
    let customNaturalKey: String? // Optional custom natural key
    let initialInventory: [InventoryModel]
    let tags: [String]
    
    init(
        name: String,
        sku: String,
        manufacturer: String,
        mfrNotes: String? = nil,
        coe: Int32,
        url: String? = nil,
        mfrStatus: String = "available",
        customNaturalKey: String? = nil,
        initialInventory: [InventoryModel] = [],
        tags: [String] = []
    ) {
        self.name = name
        self.sku = sku
        self.manufacturer = manufacturer
        self.mfrNotes = mfrNotes
        self.coe = coe
        self.url = url
        self.mfrStatus = mfrStatus
        self.customNaturalKey = customNaturalKey
        self.initialInventory = initialInventory
        self.tags = tags
    }
}

/// Enhanced search request model with comprehensive filtering
struct GlassItemSearchRequest {
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
    
    init(
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
    
    func getAppliedFiltersDescription() -> String {
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
struct GlassItemSearchResult {
    let items: [CompleteInventoryItemModel]
    let totalCount: Int
    let hasMore: Bool
    let appliedFilters: String
}

/// Sort options for glass items
enum GlassItemSortOption: CaseIterable {
    case name
    case manufacturer
    case coe
    case totalQuantity
    case naturalKey
    
    var displayName: String {
        switch self {
        case .name: return "Name"
        case .manufacturer: return "Manufacturer" 
        case .coe: return "COE"
        case .totalQuantity: return "Total Quantity"
        case .naturalKey: return "Natural Key"
        }
    }
}

/// System status model
struct SystemStatusModel {
    let itemCount: Int
    let hasData: Bool
    let systemType: String
}

/// Migration status model
struct MigrationStatusModel {
    let migrationStage: MigrationStage
    let legacyItemCount: Int
    let newItemCount: Int
    let canMigrate: Bool
    let canRollback: Bool
    
    var description: String {
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
enum MigrationStage {
    case empty
    case legacyOnly
    case transitional
    case newSystemOnly
}

/// Catalog operations for system validation
enum CatalogOperation {
    case legacyRead
    case legacyWrite
    case newRead
    case newWrite
    case migration
    case rollback
}

/// Catalog overview statistics
struct CatalogOverviewModel {
    let totalItems: Int
    let totalManufacturers: Int
    let totalTags: Int
    let itemsWithInventory: Int
    let lowStockItems: Int
    let systemType: String
}

/// Manufacturer statistics
struct ManufacturerStatisticsModel: Identifiable {
    let name: String
    let itemCount: Int
    
    var id: String { name }
}

/// Items needing attention report
struct ItemAttentionReportModel {
    let itemsWithoutInventory: [GlassItemModel]
    let itemsWithoutTags: [GlassItemModel]
    let itemsWithInconsistentData: [GlassItemModel]
    let totalItems: Int
    
    /// Total items needing some kind of attention
    var itemsNeedingAttention: Int {
        Set(itemsWithoutInventory.map { $0.naturalKey })
            .union(Set(itemsWithoutTags.map { $0.naturalKey }))
            .union(Set(itemsWithInconsistentData.map { $0.naturalKey }))
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