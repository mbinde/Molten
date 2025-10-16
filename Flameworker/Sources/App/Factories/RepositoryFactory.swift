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
    static var mode: RepositoryMode = .mock
    
    /// Persistent container for Core Data repositories
    static var persistentContainer: NSPersistentContainer = PersistenceController.shared.container
    
    // MARK: - Repository Creation
    
    /// Creates a GlassItemRepository based on current mode
    static func createGlassItemRepository() -> GlassItemRepository {
        switch mode {
        case .mock:
            // Create mock with explicit type annotation to avoid ambiguity
            let repo: MockGlassItemRepository = MockGlassItemRepository()
            return repo
            
        case .coreData:
            // TODO: CoreDataGlassItemRepository needs to be added to Xcode project target
            // For now, falling back to mock
            let repo: MockGlassItemRepository = MockGlassItemRepository()
            return repo
            
        case .hybrid:
            // TODO: CoreDataGlassItemRepository needs to be added to Xcode project target
            // For now, falling back to mock
            let repo: MockGlassItemRepository = MockGlassItemRepository()
            return repo
        }
    }
    
    /// Creates an InventoryRepository based on current mode
    static func createInventoryRepository() -> InventoryRepository {
        switch mode {
        case .mock:
            // Use mock for testing - explicit type annotation to avoid ambiguity
            let repo: MockInventoryRepository = MockInventoryRepository()
            return repo
            
        case .coreData:
            // Use Core Data implementation for production
            return CoreDataInventoryRepository(persistentContainer: persistentContainer)
            
        case .hybrid:
            // Use Core Data implementation when available
            return CoreDataInventoryRepository(persistentContainer: persistentContainer)
        }
    }
    
    /// Creates a LocationRepository based on current mode
    static func createLocationRepository() -> LocationRepository {
        switch mode {
        case .mock:
            // Use mock for testing - explicit type annotation to avoid ambiguity
            let repo: MockLocationRepository = MockLocationRepository()
            return repo
            
        case .coreData:
            // Use Core Data implementation for production
            return CoreDataLocationRepository(locationPersistentContainer: persistentContainer)
            
        case .hybrid:
            // Use Core Data implementation when available
            return CoreDataLocationRepository(locationPersistentContainer: persistentContainer)
        }
    }
    
    /// Creates an ItemTagsRepository based on current mode
    static func createItemTagsRepository() -> ItemTagsRepository {
        switch mode {
        case .mock, .hybrid:
            // Create mock with explicit type annotation to avoid ambiguity
            let repo: MockItemTagsRepository = MockItemTagsRepository()
            return repo
            
        case .coreData:
            // TODO: Implement CoreDataItemTagsRepository
            fatalError("CoreDataItemTagsRepository not yet implemented")
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
    
    /// Creates a CatalogService with core functionality (shopping list features disabled)
    static func createCatalogService() -> CatalogService {
        // Create a temporary ShoppingListService for CatalogService dependency
        // TODO: Refactor CatalogService to not require ShoppingListService
        let tempShoppingListService = ShoppingListService(
            itemMinimumRepository: MockItemMinimumRepository(),
            inventoryRepository: createInventoryRepository(),
            glassItemRepository: createGlassItemRepository(),
            itemTagsRepository: createItemTagsRepository()
        )
        
        return CatalogService(
            glassItemRepository: createGlassItemRepository(),
            inventoryTrackingService: createInventoryTrackingService(),
            shoppingListService: tempShoppingListService,
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
 ## How to Use RepositoryFactory - Focus on Core Features
 
 ### In Production Code:
 ```swift
 // Configure for production
 RepositoryFactory.configureForProduction()
 
 // Create core services
 let catalogService = RepositoryFactory.createCatalogService()
 let inventoryService = RepositoryFactory.createInventoryTrackingService()
 
 // Core repositories
 let glassItemRepo = RepositoryFactory.createGlassItemRepository()
 let inventoryRepo = RepositoryFactory.createInventoryRepository()
 let locationRepo = RepositoryFactory.createLocationRepository()
 ```
 
 ### In Tests:
 ```swift
 // Configure for testing
 RepositoryFactory.configureForTesting()
 
 // Create services with mock repositories
 let catalogService = RepositoryFactory.createCatalogService()
 let inventoryService = RepositoryFactory.createInventoryTrackingService()
 ```
 
 ### Custom Configuration:
 ```swift
 // Use specific container for Core Data
 let container = PersistenceController.preview.container
 RepositoryFactory.configure(persistentContainer: container)
 
 // Set mode explicitly
 RepositoryFactory.configureForDevelopment()
 ```
 
 ### Core Workflow Example:
 ```swift
 // Setup
 RepositoryFactory.configureForProduction()
 let catalogService = RepositoryFactory.createCatalogService()
 
 // Create glass item
 let item = GlassItemModel(naturalKey: "bullseye-clear", description: "Clear Glass")
 try await catalogService.createGlassItem(item)
 
 // Add inventory
 let inventoryService = RepositoryFactory.createInventoryTrackingService()
 let inventory = InventoryModel(itemNaturalKey: "bullseye-clear", quantity: 10.0, type: "rod", location: "shelf-1")
 try await inventoryService.inventoryRepository.createInventory(inventory)
 ```
*/