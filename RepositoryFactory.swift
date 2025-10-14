//
//  RepositoryFactory.swift
//  Flameworker
//
//  Created by Assistant on 10/14/25.
//

import Foundation
import CoreData

/// Factory for creating repository implementations
/// Allows switching between mock and Core Data implementations
struct RepositoryFactory {
    
    // MARK: - Configuration
    
    /// Environment setting to control repository implementation
    enum RepositoryMode {
        case mock      // Use mock implementations (for testing/development)
        case coreData  // Use Core Data implementations (production)
        case hybrid    // Mix of implementations based on availability
    }
    
    /// Current repository mode
    static var mode: RepositoryMode = .hybrid
    
    /// Persistent container for Core Data repositories
    static var persistentContainer: NSPersistentContainer = PersistenceController.shared.container
    
    // MARK: - Repository Creation
    
    /// Creates a GlassItemRepository based on current mode
    static func createGlassItemRepository() -> GlassItemRepository {
        switch mode {
        case .mock:
            return MockGlassItemRepository()
            
        case .coreData:
            // TODO: CoreDataGlassItemRepository needs to be added to Xcode project target
            // For now, falling back to mock
            return MockGlassItemRepository()
            
        case .hybrid:
            // TODO: CoreDataGlassItemRepository needs to be added to Xcode project target
            // For now, falling back to mock
            return MockGlassItemRepository()
        }
    }
    
    /// Creates an InventoryRepository based on current mode
    static func createInventoryRepository() -> InventoryRepository {
        switch mode {
        case .mock:
            // Use mock for testing
            return MockInventoryRepository()
            
        case .coreData:
            // TODO: CoreDataInventoryRepository needs to be added to Xcode project target
            // For now, falling back to mock
            return MockInventoryRepository()
            
        case .hybrid:
            // TODO: CoreDataInventoryRepository needs to be added to Xcode project target
            // For now, falling back to mock
            return MockInventoryRepository()
        }
    }
    
    /// Creates a LocationRepository based on current mode
    static func createLocationRepository() -> LocationRepository {
        switch mode {
        case .mock, .hybrid:
            // For now, always use mock until we implement Core Data version
            return MockLocationRepository()
            
        case .coreData:
            // TODO: Implement CoreDataLocationRepository
            fatalError("CoreDataLocationRepository not yet implemented")
        }
    }
    
    /// Creates an ItemTagsRepository based on current mode
    static func createItemTagsRepository() -> ItemTagsRepository {
        switch mode {
        case .mock, .hybrid:
            // For now, always use mock until we implement Core Data version
            return MockItemTagsRepository()
            
        case .coreData:
            // TODO: Implement CoreDataItemTagsRepository
            fatalError("CoreDataItemTagsRepository not yet implemented")
        }
    }
    
    /// Creates an ItemMinimumRepository based on current mode
    static func createItemMinimumRepository() -> ItemMinimumRepository {
        switch mode {
        case .mock, .hybrid:
            // For now, always use mock until we implement Core Data version
            return MockItemMinimumRepository()
            
        case .coreData:
            // TODO: Implement CoreDataItemMinimumRepository
            fatalError("CoreDataItemMinimumRepository not yet implemented")
        }
    }
    
    // MARK: - Service Creation (Convenience)
    
    /// Creates a complete InventoryTrackingService with all dependencies
    static func createInventoryTrackingService() -> InventoryTrackingService {
        return InventoryTrackingService(
            glassItemRepository: createGlassItemRepository(),
            inventoryRepository: createInventoryRepository(),
            locationRepository: createLocationRepository(),
            itemTagsRepository: createItemTagsRepository()
        )
    }
    
    /// Creates a CatalogService with new GlassItem system
    static func createCatalogService() -> CatalogService {
        return CatalogService(
            glassItemRepository: createGlassItemRepository(),
            inventoryTrackingService: createInventoryTrackingService(),
            shoppingListService: createShoppingListService(),
            itemTagsRepository: createItemTagsRepository()
        )
    }
    
    /// Creates a ShoppingListService
    static func createShoppingListService() -> ShoppingListService {
        return ShoppingListService(
            itemMinimumRepository: createItemMinimumRepository(),
            inventoryRepository: createInventoryRepository(),
            glassItemRepository: createGlassItemRepository(),
            itemTagsRepository: createItemTagsRepository()
        )
    }
    
    // MARK: - Configuration Helpers
    
    /// Configure factory for testing with all mocks
    static func configureForTesting() {
        mode = .mock
    }
    
    /// Configure factory for production with Core Data
    static func configureForProduction() {
        mode = .coreData
    }
    
    /// Configure factory for development with hybrid approach
    static func configureForDevelopment() {
        mode = .hybrid
    }
    
    /// Configure with custom persistent container
    static func configure(persistentContainer: NSPersistentContainer) {
        self.persistentContainer = persistentContainer
    }
}

// MARK: - Usage Examples

/*
 ## How to Use RepositoryFactory
 
 ### In Production Code:
 ```swift
 // Configure for production
 RepositoryFactory.configureForProduction()
 
 // Create services
 let catalogService = RepositoryFactory.createCatalogService()
 let inventoryService = RepositoryFactory.createInventoryTrackingService()
 ```
 
 ### In Tests:
 ```swift
 // Configure for testing
 RepositoryFactory.configureForTesting()
 
 // Create services with mock repositories
 let catalogService = RepositoryFactory.createCatalogService()
 ```
 
 ### Custom Configuration:
 ```swift
 // Use specific container
 let container = PersistenceController.preview.container
 RepositoryFactory.configure(persistentContainer: container)
 
 // Create repositories individually
 let glassItemRepo = RepositoryFactory.createGlassItemRepository()
 let inventoryRepo = RepositoryFactory.createInventoryRepository()
 ```
*/