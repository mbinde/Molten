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
    
    /// Current repository mode - defaults to mock for safety (tests won't pollute production data)
    /// Production code should explicitly call configureForProduction()
    /// DO NOT CHANGE THIS -- solve production another way, we really don't want to pollute our tests with core data
    static var mode: RepositoryMode = .mock

    /// Persistent container for Core Data repositories
    /// IMPORTANT: Made optional and lazy to prevent automatic initialization of PersistenceController.shared
    /// This prevents Core Data from initializing during unit test startup
    static var persistentContainer: NSPersistentContainer? = nil
    
    // MARK: - Repository Creation
    
    /// Creates a GlassItemRepository based on current mode
    static func createGlassItemRepository() -> GlassItemRepository {
        switch mode {
        case .mock:
            // Create mock with explicit type annotation to avoid ambiguity
            let repo: MockGlassItemRepository = MockGlassItemRepository()
            return repo

        case .coreData:
            // Use the new CoreDataGlassItemRepository
            // Get or initialize the persistent container
            let container = persistentContainer ?? PersistenceController.shared.container
            return CoreDataGlassItemRepository(persistentContainer: container)

        case .hybrid:
            // Use Core Data implementation when available
            let container = persistentContainer ?? PersistenceController.shared.container
            return CoreDataGlassItemRepository(persistentContainer: container)
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
            let container = persistentContainer ?? PersistenceController.shared.container
            return CoreDataInventoryRepository(persistentContainer: container)

        case .hybrid:
            // Use Core Data implementation when available
            let container = persistentContainer ?? PersistenceController.shared.container
            return CoreDataInventoryRepository(persistentContainer: container)
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
            let container = persistentContainer ?? PersistenceController.shared.container
            return CoreDataLocationRepository(locationPersistentContainer: container)

        case .hybrid:
            // Use Core Data implementation when available
            let container = persistentContainer ?? PersistenceController.shared.container
            return CoreDataLocationRepository(locationPersistentContainer: container)
        }
    }
    
    /// Creates an ItemTagsRepository based on current mode
    static func createItemTagsRepository() -> ItemTagsRepository {
        // Always use mock for now since CoreDataItemTagsRepository isn't implemented yet
        // TODO: Implement CoreDataItemTagsRepository
        let repo: MockItemTagsRepository = MockItemTagsRepository()
        return repo
    }

    /// Creates a UserNotesRepository based on current mode
    static func createUserNotesRepository() -> UserNotesRepository {
        switch mode {
        case .mock:
            // Use mock for testing - explicit type annotation to avoid ambiguity
            let repo: MockUserNotesRepository = MockUserNotesRepository()
            return repo

        case .coreData:
            // Use Core Data implementation for production
            let container = persistentContainer ?? PersistenceController.shared.container
            return CoreDataUserNotesRepository(userNotesPersistentContainer: container)

        case .hybrid:
            // Use Core Data implementation when available
            let container = persistentContainer ?? PersistenceController.shared.container
            return CoreDataUserNotesRepository(userNotesPersistentContainer: container)
        }
    }

    /// Creates a ShoppingListRepository based on current mode
    static func createShoppingListRepository() -> ShoppingListRepository {
        switch mode {
        case .mock:
            // Use mock for testing - explicit type annotation to avoid ambiguity
            let repo: MockShoppingListRepository = MockShoppingListRepository()
            return repo

        case .coreData:
            // Use Core Data implementation for production
            let container = persistentContainer ?? PersistenceController.shared.container
            return CoreDataShoppingListRepository(persistentContainer: container)

        case .hybrid:
            // Use Core Data implementation when available
            let container = persistentContainer ?? PersistenceController.shared.container
            return CoreDataShoppingListRepository(persistentContainer: container)
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
    
    /// Configure factory for testing with isolated Core Data
    static func configureForTestingWithCoreData() {
        mode = .coreData
        // Use an isolated test container
        persistentContainer = PersistenceController.createTestController().container
    }
    
    /// Configure factory for production with Core Data
    static func configureForProduction() {
        mode = .coreData
        // Always use the shared production container
        persistentContainer = PersistenceController.shared.container
    }
    
    /// Configure for production and ensure initial data is loaded
    static func configureForProductionWithInitialData() async throws {
        configureForProduction()
        
        // Check if we need to load initial data
        let catalogService = createCatalogService()
        let existingItems = try await catalogService.getAllGlassItems()
        
        if existingItems.isEmpty {
            print("🔄 Loading initial data for production...")
            
            // Use mock data loader temporarily since JSON files aren't in bundle
            let mockDataLoader = MockJSONDataLoader()
            mockDataLoader.testDataMode = .medium  // Use more test data
            
            let dataLoadingService = GlassItemDataLoadingService(
                catalogService: catalogService,
                jsonLoader: mockDataLoader
            )
            let result = try await dataLoadingService.loadGlassItemsFromJSON(options: .default)
            print("🔄 Initial data loaded: \(result.itemsCreated) items created, \(result.itemsFailed) failed")
        }
    }
    
    /// Configure factory for development with hybrid approach
    static func configureForDevelopment() {
        mode = .hybrid
    }
    
    /// Configure with custom persistent container
    static func configure(persistentContainer: NSPersistentContainer) {
        self.persistentContainer = persistentContainer
    }
    
    /// Reset to default production configuration
    static func resetToProduction() {
        mode = .coreData
        persistentContainer = PersistenceController.shared.container
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
 let item = GlassItemModel(natural_key: "bullseye-clear", description: "Clear Glass")
 try await catalogService.createGlassItem(item)
 
 // Add inventory
 let inventoryService = RepositoryFactory.createInventoryTrackingService()
 let inventory = InventoryModel(itemNaturalKey: "bullseye-clear", quantity: 10.0, type: "rod", location: "shelf-1")
 try await inventoryService.inventoryRepository.createInventory(inventory)
 ```
*/
