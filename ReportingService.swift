//
//  ReportingService.swift
//  Flameworker
//
//  Created by Assistant on 10/12/25.
//

import Foundation

/// Advanced reporting service that generates reports across all entities
class ReportingService {
    private let catalogService: CatalogService
    private let inventoryService: InventoryService
    private let purchaseService: PurchaseService
    
    init(catalogService: CatalogService, 
         inventoryService: InventoryService,
         purchaseService: PurchaseService) {
        self.catalogService = catalogService
        self.inventoryService = inventoryService
        self.purchaseService = purchaseService
    }
    
    // MARK: - Comprehensive Reporting
    
    func generateComprehensiveReport(from startDate: Date = Date.distantPast, 
                                   to endDate: Date = Date.distantFuture) async throws -> ComprehensiveReport {
        
        // Gather data from all services
        let catalogItems = try await catalogService.getAllItems()
        let inventoryItems = try await inventoryService.getAllItems()
        let purchaseRecords = try await purchaseService.getAllRecords(from: startDate, to: endDate)
        
        // Calculate totals
        let totalCatalogItems = catalogItems.count
        let totalInventoryItems = inventoryItems.count
        let totalPurchases = purchaseRecords.count
        let totalSpending = purchaseRecords.reduce(0.0) { $0 + $1.price }
        
        // Calculate inventory value (simplified - uses average purchase price)
        let averagePurchasePrice = totalPurchases > 0 ? totalSpending / Double(totalPurchases) : 0.0
        let totalInventoryQuantity = inventoryItems.reduce(0) { $0 + $1.quantity }
        let inventoryValue = Double(totalInventoryQuantity) * averagePurchasePrice
        
        // Generate insights
        let topSuppliers = try await getTopSuppliers(from: purchaseRecords)
        let inventoryDistribution = getInventoryDistribution(from: inventoryItems)
        let catalogCoverage = getCatalogCoverage(catalogItems: catalogItems, inventoryItems: inventoryItems)
        
        return ComprehensiveReport(
            totalCatalogItems: totalCatalogItems,
            totalInventoryItems: totalInventoryItems,
            totalPurchases: totalPurchases,
            totalSpending: totalSpending,
            inventoryValue: inventoryValue,
            topSuppliers: topSuppliers,
            inventoryDistribution: inventoryDistribution,
            catalogCoverage: catalogCoverage,
            generatedDate: Date(),
            dateRange: DateRange(start: startDate, end: endDate)
        )
    }
    
    // MARK: - Specialized Reports
    
    func generateInventoryReport() async throws -> InventoryReport {
        let inventoryItems = try await inventoryService.getAllItems()
        let consolidatedItems = try await inventoryService.getConsolidatedItems()
        
        return InventoryReport(
            totalItems: inventoryItems.count,
            consolidatedItems: consolidatedItems,
            lowStockItems: inventoryItems.filter { $0.quantity <= 5 },
            totalValue: 0.0, // Would need purchase price correlation
            generatedDate: Date()
        )
    }
    
    func generatePurchaseReport(from startDate: Date, to endDate: Date) async throws -> PurchaseReport {
        let purchaseRecords = try await purchaseService.getAllRecords(from: startDate, to: endDate)
        let spendingBySupplier = try await purchaseService.getSpendingBySupplier(from: startDate, to: endDate)
        
        return PurchaseReport(
            totalPurchases: purchaseRecords.count,
            totalSpending: purchaseRecords.reduce(0.0) { $0 + $1.price },
            spendingBySupplier: spendingBySupplier,
            averagePurchaseAmount: purchaseRecords.isEmpty ? 0.0 : purchaseRecords.reduce(0.0) { $0 + $1.price } / Double(purchaseRecords.count),
            dateRange: DateRange(start: startDate, end: endDate),
            generatedDate: Date()
        )
    }
    
    // MARK: - Private Helper Methods
    
    private func getTopSuppliers(from purchases: [PurchaseRecordModel]) async throws -> [SupplierSpending] {
        let spendingBySupplier = Dictionary(grouping: purchases) { $0.supplier }
            .mapValues { records in
                records.reduce(0.0) { $0 + $1.price }
            }
        
        return spendingBySupplier.map { SupplierSpending(supplier: $0.key, totalSpent: $0.value) }
            .sorted { $0.totalSpent > $1.totalSpent }
            .prefix(5)
            .map { $0 }
    }
    
    private func getInventoryDistribution(from items: [InventoryItemModel]) -> InventoryDistribution {
        let byType = Dictionary(grouping: items) { $0.type }
        
        return InventoryDistribution(
            inventoryCount: byType[.inventory]?.count ?? 0,
            buyCount: byType[.buy]?.count ?? 0,
            sellCount: byType[.sell]?.count ?? 0
        )
    }
    
    private func getCatalogCoverage(catalogItems: [CatalogItemModel], inventoryItems: [InventoryItemModel]) -> CatalogCoverage {
        let catalogCodes = Set(catalogItems.map { $0.code })
        let inventoryCodes = Set(inventoryItems.map { $0.catalogCode })
        
        let coveredItems = catalogCodes.intersection(inventoryCodes).count
        let coveragePercentage = catalogItems.isEmpty ? 0.0 : Double(coveredItems) / Double(catalogItems.count) * 100.0
        
        return CatalogCoverage(
            totalCatalogItems: catalogItems.count,
            itemsWithInventory: coveredItems,
            coveragePercentage: coveragePercentage
        )
    }
}

// MARK: - Report Data Models

struct ComprehensiveReport {
    let totalCatalogItems: Int
    let totalInventoryItems: Int
    let totalPurchases: Int
    let totalSpending: Double
    let inventoryValue: Double
    let topSuppliers: [SupplierSpending]
    let inventoryDistribution: InventoryDistribution
    let catalogCoverage: CatalogCoverage
    let generatedDate: Date
    let dateRange: DateRange
}

struct InventoryReport {
    let totalItems: Int
    let consolidatedItems: [ConsolidatedInventoryModel]
    let lowStockItems: [InventoryItemModel]
    let totalValue: Double
    let generatedDate: Date
}

struct PurchaseReport {
    let totalPurchases: Int
    let totalSpending: Double
    let spendingBySupplier: [String: Double]
    let averagePurchaseAmount: Double
    let dateRange: DateRange
    let generatedDate: Date
}

struct SupplierSpending {
    let supplier: String
    let totalSpent: Double
}

struct InventoryDistribution {
    let inventoryCount: Int
    let buyCount: Int
    let sellCount: Int
}

struct CatalogCoverage {
    let totalCatalogItems: Int
    let itemsWithInventory: Int
    let coveragePercentage: Double
}

struct DateRange {
    let start: Date
    let end: Date
}