//
//  ReportingService.swift
//  Flameworker
//
//  Created by Assistant on 10/12/25.
//  Updated for GlassItem Architecture on 10/14/25.
//

import Foundation

// Note: Now using new GlassItem architecture models
// Models are defined in repository files following clean architecture principles

/// Advanced reporting service that generates reports across all entities using new architecture
class ReportingService {
    private let catalogService: CatalogService
    private let inventoryTrackingService: InventoryTrackingService
    private let shoppingListService: ShoppingListService?
    
    init(catalogService: CatalogService, 
         inventoryTrackingService: InventoryTrackingService,
         shoppingListService: ShoppingListService? = nil) {
        self.catalogService = catalogService
        self.inventoryTrackingService = inventoryTrackingService
        self.shoppingListService = shoppingListService
    }
    
    // MARK: - Comprehensive Reporting
    
    func generateComprehensiveReport(from startDate: Date = Date.distantPast, 
                                   to endDate: Date = Date.distantFuture) async throws -> ComprehensiveReport {
        
        // Gather data from all services using new architecture
        let completeItems = try await catalogService.getAllGlassItems()
        // Note: getInventorySummaries() doesn't exist, but we have the data in completeItems
        
        // Calculate totals
        let totalGlassItems = completeItems.count
        let totalInventoryRecords = completeItems.reduce(0) { $0 + $1.inventory.count }
        let totalQuantity = completeItems.reduce(0.0) { $0 + $1.totalQuantity }
        
        // Generate insights
        let inventoryByType = getInventoryByType(from: completeItems)
        let manufacturerDistribution = getManufacturerDistribution(from: completeItems)
        let coeDistribution = getCoeDistribution(from: completeItems)
        let tagAnalysis = getTagAnalysis(from: completeItems)
        let lowStockItems = try await inventoryTrackingService.getLowStockItems(threshold: 5.0)
        
        return ComprehensiveReport(
            totalGlassItems: totalGlassItems,
            totalInventoryRecords: totalInventoryRecords,
            totalQuantity: totalQuantity,
            inventoryByType: inventoryByType,
            manufacturerDistribution: manufacturerDistribution,
            coeDistribution: coeDistribution,
            tagAnalysis: tagAnalysis,
            lowStockItemsCount: lowStockItems.count,
            generatedDate: Date(),
            dateRange: DateRange(start: startDate, end: endDate)
        )
    }
    
    // MARK: - Specialized Reports
    
    func generateInventoryReport() async throws -> InventoryReport {
        let completeItems = try await catalogService.getAllGlassItems(includeWithoutInventory: false)
        // Note: Generate inventory summaries from completeItems data instead of separate service call
        let inventorySummaries = completeItems.map { item in
            InventorySummaryModel(itemNaturalKey: item.glassItem.naturalKey, inventories: item.inventory)
        }
        let lowStockItems = try await inventoryTrackingService.getLowStockItems(threshold: 5.0)
        
        // Calculate total inventory value (simplified - would need purchase price data)
        let totalQuantity = completeItems.reduce(0.0) { $0 + $1.totalQuantity }
        
        return InventoryReport(
            totalItems: completeItems.count,
            inventorySummaries: inventorySummaries,
            lowStockItems: lowStockItems,
            totalQuantity: totalQuantity,
            inventoryByType: getInventoryByType(from: completeItems),
            generatedDate: Date()
        )
    }
    
    func generateManufacturerReport() async throws -> ManufacturerReport {
        let completeItems = try await catalogService.getAllGlassItems()
        let manufacturerStats = getManufacturerStatistics(from: completeItems)
        
        return ManufacturerReport(
            manufacturerStatistics: manufacturerStats,
            totalManufacturers: Set(completeItems.map { $0.glassItem.manufacturer }).count,
            generatedDate: Date()
        )
    }
    
    func generateTagReport() async throws -> TagReport {
        let completeItems = try await catalogService.getAllGlassItems()
        let tagStats = getTagStatistics(from: completeItems)
        
        return TagReport(
            tagStatistics: tagStats,
            totalTags: Set(completeItems.flatMap { $0.tags }).count,
            generatedDate: Date()
        )
    }
    
    // MARK: - Shopping List Reports (if service available)
    
    func generateShoppingListReport() async throws -> ShoppingListReport? {
        guard let shoppingListService = shoppingListService else { return nil }
        
        // Use the available methods from ShoppingListService
        let allShoppingLists = try await shoppingListService.generateAllShoppingLists()
        let lowStockReport = try await shoppingListService.getLowStockReport()
        
        // Combine all shopping list items from all stores
        let allShoppingListItems = allShoppingLists.values.flatMap { $0.items.map { $0.shoppingListItem } }
        
        // Get low stock items as minimum items - convert from DetailedLowStockItemModel
        let minimumItems = lowStockReport.items.map { detailedLowStockItem in
            let lowStockItem = detailedLowStockItem.lowStockItem
            return ItemMinimumModel(
                id: UUID(),
                itemNaturalKey: lowStockItem.itemNaturalKey,
                quantity: lowStockItem.minimumQuantity,
                type: lowStockItem.type,
                store: "default" // You'd get this from actual minimum records
            )
        }
        
        return ShoppingListReport(
            shoppingListItems: allShoppingListItems,
            minimumItems: minimumItems,
            totalItemsToOrder: allShoppingListItems.count,
            generatedDate: Date()
        )
    }
    
    // MARK: - Private Helper Methods
    
    private func getInventoryByType(from items: [CompleteInventoryItemModel]) -> [String: InventoryTypeStats] {
        var typeStats: [String: InventoryTypeStats] = [:]
        
        for item in items {
            for inventory in item.inventory {
                let existing = typeStats[inventory.type] ?? InventoryTypeStats(type: inventory.type, count: 0, totalQuantity: 0.0)
                typeStats[inventory.type] = InventoryTypeStats(
                    type: inventory.type,
                    count: existing.count + 1,
                    totalQuantity: existing.totalQuantity + inventory.quantity
                )
            }
        }
        
        return typeStats
    }
    
    private func getManufacturerDistribution(from items: [CompleteInventoryItemModel]) -> [ManufacturerStats] {
        let byManufacturer = Dictionary(grouping: items) { $0.glassItem.manufacturer }
        
        return byManufacturer.map { manufacturer, items in
            ManufacturerStats(
                name: manufacturer,
                itemCount: items.count,
                totalQuantity: items.reduce(0.0) { $0 + $1.totalQuantity },
                uniqueCoes: Set(items.map { $0.glassItem.coe }).sorted()
            )
        }
        .sorted { $0.itemCount > $1.itemCount }
    }
    
    private func getCoeDistribution(from items: [CompleteInventoryItemModel]) -> [CoeStats] {
        let byCoe = Dictionary(grouping: items) { $0.glassItem.coe }
        
        return byCoe.map { coe, items in
            CoeStats(
                coe: coe,
                itemCount: items.count,
                totalQuantity: items.reduce(0.0) { $0 + $1.totalQuantity },
                manufacturers: Set(items.map { $0.glassItem.manufacturer }).sorted()
            )
        }
        .sorted { $0.coe < $1.coe }
    }
    
    private func getTagAnalysis(from items: [CompleteInventoryItemModel]) -> TagAnalysis {
        let allTags = items.flatMap { $0.tags }
        let tagCounts = Dictionary(grouping: allTags) { $0 }
            .mapValues { $0.count }
        
        let topTags = tagCounts.sorted { $0.value > $1.value }
            .prefix(10)
            .map { TagStats(tag: $0.key, count: $0.value) }
        
        return TagAnalysis(
            totalUniqueTags: tagCounts.count,
            totalTagAssignments: allTags.count,
            averageTagsPerItem: items.isEmpty ? 0.0 : Double(allTags.count) / Double(items.count),
            topTags: topTags
        )
    }
    
    private func getManufacturerStatistics(from items: [CompleteInventoryItemModel]) -> [ManufacturerStats] {
        return getManufacturerDistribution(from: items)
    }
    
    private func getTagStatistics(from items: [CompleteInventoryItemModel]) -> [TagStats] {
        let allTags = items.flatMap { $0.tags }
        let tagCounts = Dictionary(grouping: allTags) { $0 }
            .mapValues { $0.count }
        
        return tagCounts.map { TagStats(tag: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
}

// MARK: - Report Data Models

struct ComprehensiveReport {
    let totalGlassItems: Int
    let totalInventoryRecords: Int
    let totalQuantity: Double
    let inventoryByType: [String: InventoryTypeStats]
    let manufacturerDistribution: [ManufacturerStats]
    let coeDistribution: [CoeStats]
    let tagAnalysis: TagAnalysis
    let lowStockItemsCount: Int
    let generatedDate: Date
    let dateRange: DateRange
}

struct InventoryReport {
    let totalItems: Int
    let inventorySummaries: [InventorySummaryModel]
    let lowStockItems: [LowStockDetailModel]
    let totalQuantity: Double
    let inventoryByType: [String: InventoryTypeStats]
    let generatedDate: Date
}

struct ManufacturerReport {
    let manufacturerStatistics: [ManufacturerStats]
    let totalManufacturers: Int
    let generatedDate: Date
}

struct TagReport {
    let tagStatistics: [TagStats]
    let totalTags: Int
    let generatedDate: Date
}

struct ShoppingListReport {
    let shoppingListItems: [ShoppingListItemModel]
    let minimumItems: [ItemMinimumModel]
    let totalItemsToOrder: Int
    let generatedDate: Date
}

// MARK: - Statistics Models

struct InventoryTypeStats {
    let type: String
    let count: Int
    let totalQuantity: Double
}

struct ManufacturerStats {
    let name: String
    let itemCount: Int
    let totalQuantity: Double
    let uniqueCoes: [Int32]
}

struct CoeStats {
    let coe: Int32
    let itemCount: Int
    let totalQuantity: Double
    let manufacturers: [String]
}

struct TagStats {
    let tag: String
    let count: Int
}

struct TagAnalysis {
    let totalUniqueTags: Int
    let totalTagAssignments: Int
    let averageTagsPerItem: Double
    let topTags: [TagStats]
}

struct DateRange {
    let start: Date
    let end: Date
}

// MARK: - Factory Methods

extension ReportingService {
    /// Create ReportingService using RepositoryFactory
    static func createWithRepositoryFactory() -> ReportingService {
        RepositoryFactory.configureForTesting()
        let catalogService = RepositoryFactory.createCatalogService()
        let inventoryTrackingService = RepositoryFactory.createInventoryTrackingService()
        
        return ReportingService(
            catalogService: catalogService,
            inventoryTrackingService: inventoryTrackingService
        )
    }
}
