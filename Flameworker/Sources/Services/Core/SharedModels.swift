//
//  SharedModels.swift
//  Flameworker
//
//  Created by Assistant on 10/14/25.
//  Models shared across multiple services and repositories
//

import Foundation

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