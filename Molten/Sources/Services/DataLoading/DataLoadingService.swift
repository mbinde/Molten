//
//  DataLoadingService.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/27/25.
//  Enhanced by Assistant on 10/14/25.
//  Updated for GlassItem Architecture on 10/14/25.
//

// ✅ UPDATED FOR GLASS ITEM SYSTEM (October 2025)
//
// This service now works with the new GlassItem architecture:
// - Uses CatalogService for glass item operations
// - Integrates with RepositoryFactory for dependency injection
// - Provides basic data loading functionality
// - Simplified architecture focused on available services

import Foundation
import OSLog

#if canImport(CoreData)
import CoreData
#endif

class DataLoadingService {
    static let shared = DataLoadingService()
    
    private let logger = Logger(subsystem: "com.flameworker.dataLoading", category: "DataLoadingService")
    private let catalogService: CatalogService
    
    private init() {
        // Use RepositoryFactory for shared instance
        RepositoryFactory.configureForTesting()
        self.catalogService = RepositoryFactory.createCatalogService()
    }
    
    /// Initialize with services (dependency injection)
    init(catalogService: CatalogService) {
        self.catalogService = catalogService
    }
    
    // MARK: - Public API
    
    /// Load catalog items from the available system
    /// - Returns: Results indicating the outcome
    func loadCatalogItems() async throws -> BasicDataLoadingResult {
        logger.info("Loading catalog items using CatalogService")
        
        let items = try await catalogService.getAllGlassItems()
        
        return BasicDataLoadingResult(
            itemsLoaded: items.count,
            success: true,
            details: "Successfully loaded \(items.count) glass items"
        )
    }
    
    /// Check if the system has data
    /// - Returns: True if items exist, false if empty
    func hasExistingData() async throws -> Bool {
        let items = try await catalogService.getAllGlassItems()
        return !items.isEmpty
    }
    
    /// Get system overview
    /// - Returns: Overview of the current system state
    func getSystemOverview() async throws -> SystemOverview {
        let items = try await catalogService.getAllGlassItems()
        let manufacturers = Set(items.map { $0.glassItem.manufacturer })
        let totalInventory = items.reduce(0.0) { $0 + $1.totalQuantity }
        
        return SystemOverview(
            totalItems: items.count,
            totalManufacturers: manufacturers.count,
            totalInventoryQuantity: totalInventory,
            systemType: "GlassItem Architecture"
        )
    }
    
    /// Search for specific glass items
    /// - Parameter searchText: Text to search for
    /// - Returns: Matching items
    func searchGlassItems(searchText: String) async throws -> [CompleteInventoryItemModel] {
        logger.info("Searching glass items for: \(searchText)")
        
        let searchRequest = GlassItemSearchRequest(searchText: searchText)
        let searchResult = try await catalogService.searchGlassItems(request: searchRequest)
        
        return searchResult.items
    }
    
    /// Get items by manufacturer
    /// - Parameter manufacturer: Manufacturer name
    /// - Returns: Items from that manufacturer
    func getItemsByManufacturer(_ manufacturer: String) async throws -> [CompleteInventoryItemModel] {
        let searchRequest = GlassItemSearchRequest(manufacturers: [manufacturer])
        let searchResult = try await catalogService.searchGlassItems(request: searchRequest)
        
        return searchResult.items
    }
    
    // MARK: - Private Helper Methods
    
    /// Helper function to log errors with detailed information
    private func logError(_ error: Error) {
        logger.error("Error details:")
        logger.error("   Description: \(error.localizedDescription)")
        
        // If it's an NSError, log additional details
        if let nsError = error as NSError? {
            logger.error("   Domain: \(nsError.domain)")
            logger.error("   Code: \(nsError.code)")
            logger.error("   User Info: \(String(describing: nsError.userInfo))")
        }
    }
}

// MARK: - Result Models

/// Basic result model for data loading operations
struct BasicDataLoadingResult {
    let itemsLoaded: Int
    let success: Bool
    let details: String
    let timestamp: Date
    
    init(itemsLoaded: Int, success: Bool, details: String) {
        self.itemsLoaded = itemsLoaded
        self.success = success
        self.details = details
        self.timestamp = Date()
    }
}

/// System overview model
struct SystemOverview {
    let totalItems: Int
    let totalManufacturers: Int
    let totalInventoryQuantity: Double
    let systemType: String
    let timestamp: Date
    
    init(totalItems: Int, totalManufacturers: Int, totalInventoryQuantity: Double, systemType: String) {
        self.totalItems = totalItems
        self.totalManufacturers = totalManufacturers
        self.totalInventoryQuantity = totalInventoryQuantity
        self.systemType = systemType
        self.timestamp = Date()
    }
    
    var summary: String {
        return """
        System Overview:
        - Total Items: \(totalItems)
        - Manufacturers: \(totalManufacturers)
        - Total Inventory: \(String(format: "%.1f", totalInventoryQuantity)) units
        - System: \(systemType)
        - Generated: \(timestamp.formatted())
        """
    }
}

// MARK: - Enhanced Errors

enum DataLoadingServiceError: Error, LocalizedError {
    case noDataAvailable
    case searchFailed(String)
    case systemUnavailable
    
    var errorDescription: String? {
        switch self {
        case .noDataAvailable:
            return "No data available in the system"
        case .searchFailed(let reason):
            return "Search failed: \(reason)"
        case .systemUnavailable:
            return "Data loading system is unavailable"
        }
    }
}

// MARK: - Factory Methods

extension DataLoadingService {
    /// Create DataLoadingService with RepositoryFactory
    static func createWithRepositoryFactory() -> DataLoadingService {
        RepositoryFactory.configureForTesting()
        let catalogService = RepositoryFactory.createCatalogService()
        
        return DataLoadingService(catalogService: catalogService)
    }
    
    /// Create DataLoadingService for production
    static func createForProduction() -> DataLoadingService {
        RepositoryFactory.configureForProduction()
        let catalogService = RepositoryFactory.createCatalogService()
        
        return DataLoadingService(catalogService: catalogService)
    }
}

// MARK: - Convenience Extensions

extension DataLoadingService {
    /// Check if system is ready for use
    var isSystemReady: Bool {
        // System is ready if we can create a catalog service
        return true
    }
    
    /// Get available manufacturers asynchronously
    func getAvailableManufacturers() async throws -> [String] {
        let items = try await catalogService.getAllGlassItems()
        let manufacturers = Set(items.map { $0.glassItem.manufacturer })
        return Array(manufacturers).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
    
    /// Get available COE values asynchronously
    func getAvailableCOEValues() async throws -> [Int32] {
        let items = try await catalogService.getAllGlassItems()
        let coeValues = Set(items.map { $0.glassItem.coe })
        return Array(coeValues).sorted()
    }
}



