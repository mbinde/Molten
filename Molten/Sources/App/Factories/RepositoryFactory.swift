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
nonisolated struct RepositoryFactory {
    
    // MARK: - Configuration
    
    /// Environment setting to control repository implementation
    enum RepositoryMode: Sendable, Equatable {
        case mock      // Use mock implementations (for testing/development)
        case coreData  // Use Core Data implementations (production)
        case hybrid    // Mix of implementations based on availability
    }
    
    /// Current repository mode - defaults to mock for safety (tests won't pollute production data)
    /// Production code should explicitly call configureForProduction()
    /// DO NOT CHANGE THIS -- solve production another way, we really don't want to pollute our tests with core data
    nonisolated(unsafe) static var mode: RepositoryMode = .mock

    /// Persistent container for Core Data repositories
    /// IMPORTANT: Made optional and lazy to prevent automatic initialization of getSharedController()
    /// This prevents Core Data from initializing during unit test startup
    nonisolated(unsafe) static var persistentContainer: NSPersistentContainer? = nil

    /// Helper to get shared controller without autoclosure issues
    nonisolated private static func getSharedController() -> PersistenceController {
        return PersistenceController.shared
    }

    /// Helper to get container without autoclosure issues
    nonisolated private static func getContainer() -> NSPersistentContainer {
        if let container = persistentContainer {
            return container
        }
        return getSharedController().container
    }

    // MARK: - Repository Creation
    
    /// Creates a GlassItemRepository based on current mode
    nonisolated static func createGlassItemRepository() -> GlassItemRepository {
        switch mode {
        case .mock:
            // Create mock with explicit type annotation to avoid ambiguity
            let repo: MockGlassItemRepository = MockGlassItemRepository()
            return repo

        case .coreData:
            // Use the new CoreDataGlassItemRepository
            // Get or initialize the persistent container
            let container: NSPersistentContainer
            if let pc = persistentContainer {
                container = pc
            } else {
                container = getSharedController().container
            }
            return CoreDataGlassItemRepository(persistentContainer: container)

        case .hybrid:
            // Use Core Data implementation when available
            let container: NSPersistentContainer
            if let pc = persistentContainer {
                container = pc
            } else {
                container = getSharedController().container
            }
            return CoreDataGlassItemRepository(persistentContainer: container)
        }
    }
    
    /// Creates an InventoryRepository based on current mode
    nonisolated static func createInventoryRepository() -> InventoryRepository {
        switch mode {
        case .mock:
            // Use mock for testing - explicit type annotation to avoid ambiguity
            let repo: MockInventoryRepository = MockInventoryRepository()
            return repo

        case .coreData:
            // Use Core Data implementation for production
            let container = getContainer()
            return CoreDataInventoryRepository(persistentContainer: container)

        case .hybrid:
            // Use Core Data implementation when available
            let container = getContainer()
            return CoreDataInventoryRepository(persistentContainer: container)
        }
    }
    
    /// Creates a LocationRepository based on current mode
    nonisolated static func createLocationRepository() -> LocationRepository {
        switch mode {
        case .mock:
            // Use mock for testing - explicit type annotation to avoid ambiguity
            let repo: MockLocationRepository = MockLocationRepository()
            return repo

        case .coreData:
            // Use Core Data implementation for production
            let container = getContainer()
            return CoreDataLocationRepository(locationPersistentContainer: container)

        case .hybrid:
            // Use Core Data implementation when available
            let container = getContainer()
            return CoreDataLocationRepository(locationPersistentContainer: container)
        }
    }
    
    /// Creates an ItemTagsRepository based on current mode
    nonisolated static func createItemTagsRepository() -> ItemTagsRepository {
        switch mode {
        case .mock:
            // Use mock for testing - explicit type annotation to avoid ambiguity
            let repo: MockItemTagsRepository = MockItemTagsRepository()
            return repo

        case .coreData:
            // Use Core Data implementation for production
            let container = getContainer()
            return CoreDataItemTagsRepository(itemTagsPersistentContainer: container)

        case .hybrid:
            // Use Core Data implementation when available
            let container = getContainer()
            return CoreDataItemTagsRepository(itemTagsPersistentContainer: container)
        }
    }

    /// Creates a UserTagsRepository based on current mode
    nonisolated static func createUserTagsRepository() -> UserTagsRepository {
        switch mode {
        case .mock:
            // Use mock for testing - explicit type annotation to avoid ambiguity
            let repo: MockUserTagsRepository = MockUserTagsRepository()
            return repo

        case .coreData:
            // Use Core Data implementation for production
            let container = getContainer()
            return CoreDataUserTagsRepository(userTagsPersistentContainer: container)

        case .hybrid:
            // Use Core Data implementation when available
            let container = getContainer()
            return CoreDataUserTagsRepository(userTagsPersistentContainer: container)
        }
    }

    /// Creates a UserNotesRepository based on current mode
    nonisolated static func createUserNotesRepository() -> UserNotesRepository {
        switch mode {
        case .mock:
            // Use mock for testing - explicit type annotation to avoid ambiguity
            let repo: MockUserNotesRepository = MockUserNotesRepository()
            return repo

        case .coreData:
            // Use Core Data implementation for production
            let container = getContainer()
            return CoreDataUserNotesRepository(userNotesPersistentContainer: container)

        case .hybrid:
            // Use Core Data implementation when available
            let container = getContainer()
            return CoreDataUserNotesRepository(userNotesPersistentContainer: container)
        }
    }

    /// Creates a ShoppingListRepository based on current mode
    nonisolated static func createShoppingListRepository() -> ShoppingListRepository {
        switch mode {
        case .mock:
            // Use mock for testing - explicit type annotation to avoid ambiguity
            let repo: MockShoppingListRepository = MockShoppingListRepository()
            return repo

        case .coreData:
            // Use Core Data implementation for production
            let container = getContainer()
            return CoreDataShoppingListRepository(persistentContainer: container)

        case .hybrid:
            // Use Core Data implementation when available
            let container = getContainer()
            return CoreDataShoppingListRepository(persistentContainer: container)
        }
    }

    /// Creates an ItemMinimumRepository based on current mode
    nonisolated static func createItemMinimumRepository() -> ItemMinimumRepository {
        switch mode {
        case .mock:
            // Use mock for testing - explicit type annotation to avoid ambiguity
            let repo: MockItemMinimumRepository = MockItemMinimumRepository()
            return repo

        case .coreData:
            // TODO: Implement CoreDataItemMinimumRepository when needed
            // For now, use mock for all modes since Core Data implementation doesn't exist yet
            let repo: MockItemMinimumRepository = MockItemMinimumRepository()
            return repo

        case .hybrid:
            // Use mock until Core Data implementation is available
            let repo: MockItemMinimumRepository = MockItemMinimumRepository()
            return repo
        }
    }

    #if canImport(UIKit)
    /// Creates a UserImageRepository based on current mode
    nonisolated static func createUserImageRepository() -> UserImageRepository {
        switch mode {
        case .mock:
            // Use mock for testing - explicit type annotation to avoid ambiguity
            let repo: MockUserImageRepository = MockUserImageRepository()
            return repo

        case .coreData:
            // Use Core Data implementation with CloudKit sync
            let container = getContainer()
            let repo: CoreDataUserImageRepository = CoreDataUserImageRepository(context: container.viewContext)
            return repo

        case .hybrid:
            // Use Core Data implementation when available
            let container = getContainer()
            let repo: CoreDataUserImageRepository = CoreDataUserImageRepository(context: container.viewContext)
            return repo
        }
    }
    #endif

    /// Creates a ProjectRepository based on current mode
    nonisolated static func createProjectRepository() -> ProjectRepository {
        switch mode {
        case .mock:
            // Use mock for testing - explicit type annotation to avoid ambiguity
            let repo: MockProjectRepository = MockProjectRepository()
            return repo

        case .coreData:
            // Use Core Data implementation for production
            return CoreDataProjectRepository(persistenceController: getSharedController())

        case .hybrid:
            // Use Core Data implementation when available
            return CoreDataProjectRepository(persistenceController: getSharedController())
        }
    }

    /// Creates a LogbookRepository based on current mode
    nonisolated static func createLogbookRepository() -> LogbookRepository {
        switch mode {
        case .mock:
            // Use mock for testing - explicit type annotation to avoid ambiguity
            let repo: MockLogbookRepository = MockLogbookRepository()
            return repo

        case .coreData:
            // Use Core Data implementation for production
            let container = getContainer()
            return CoreDataLogbookRepository(context: container.viewContext)

        case .hybrid:
            // Use Core Data implementation when available
            let container = getContainer()
            return CoreDataLogbookRepository(context: container.viewContext)
        }
    }

    /// Creates a PurchaseRecordRepository based on current mode
    nonisolated static func createPurchaseRecordRepository() -> PurchaseRecordRepository {
        switch mode {
        case .mock:
            // Use mock for testing - explicit type annotation to avoid ambiguity
            let repo: MockPurchaseRecordRepository = MockPurchaseRecordRepository()
            return repo

        case .coreData:
            // Use Core Data implementation for production
            return CoreDataPurchaseRecordRepository(persistenceController: getSharedController())

        case .hybrid:
            // Use Core Data implementation when available
            return CoreDataPurchaseRecordRepository(persistenceController: getSharedController())
        }
    }

    /// Creates a ProjectImageRepository based on current mode
    nonisolated static func createProjectImageRepository() -> ProjectImageRepository {
        switch mode {
        case .mock:
            // Use mock for testing - explicit type annotation to avoid ambiguity
            let repo: MockProjectImageRepository = MockProjectImageRepository()
            return repo

        case .coreData:
            // Use Core Data implementation for production
            let container = getContainer()
            return CoreDataProjectImageRepository(context: container.viewContext)

        case .hybrid:
            // Use Core Data implementation when available
            let container = getContainer()
            return CoreDataProjectImageRepository(context: container.viewContext)
        }
    }

    // MARK: - Service Creation (Convenience)
    
    /// Creates a complete InventoryTrackingService with all dependencies
    nonisolated static func createInventoryTrackingService() -> InventoryTrackingService {
        return InventoryTrackingService(
            glassItemRepository: createGlassItemRepository(),
            inventoryRepository: createInventoryRepository(),
            locationRepository: createLocationRepository(),
            itemTagsRepository: createItemTagsRepository()
        )
    }
    
    /// Creates a CatalogService with core functionality (shopping list features disabled)
    nonisolated static func createCatalogService() -> CatalogService {
        // Create a temporary ShoppingListService for CatalogService dependency
        // TODO: Refactor CatalogService to not require ShoppingListService
        let tempShoppingListService = ShoppingListService(
            itemMinimumRepository: MockItemMinimumRepository(),
            shoppingListRepository: createShoppingListRepository(),
            inventoryRepository: createInventoryRepository(),
            glassItemRepository: createGlassItemRepository(),
            itemTagsRepository: createItemTagsRepository(),
            userTagsRepository: createUserTagsRepository()
        )

        return CatalogService(
            glassItemRepository: createGlassItemRepository(),
            inventoryTrackingService: createInventoryTrackingService(),
            shoppingListService: tempShoppingListService,
            itemTagsRepository: createItemTagsRepository(),
            userTagsRepository: createUserTagsRepository()
        )
    }

    /// Creates a ShoppingListService with all dependencies
    nonisolated static func createShoppingListService() -> ShoppingListService {
        return ShoppingListService(
            itemMinimumRepository: createItemMinimumRepository(),
            shoppingListRepository: createShoppingListRepository(),
            inventoryRepository: createInventoryRepository(),
            glassItemRepository: createGlassItemRepository(),
            itemTagsRepository: createItemTagsRepository(),
            userTagsRepository: createUserTagsRepository()
        )
    }

    /// Creates a ProjectService with all dependencies
    nonisolated static func createProjectService() -> ProjectService {
        return ProjectService(
            projectRepository: createProjectRepository(),
            logbookRepository: createLogbookRepository()
        )
    }

    /// Creates a PurchaseRecordService with all dependencies
    nonisolated static func createPurchaseRecordService() -> PurchaseRecordService {
        return PurchaseRecordService(
            repository: createPurchaseRecordRepository()
        )
    }

    // MARK: - Configuration Helpers
    
    /// Configure factory for testing with all mocks
    nonisolated static func configureForTesting() {
        mode = .mock
    }
    
    /// Configure factory for testing with isolated Core Data
    nonisolated static func configureForTestingWithCoreData() {
        mode = .coreData
        // Use an isolated test container
        persistentContainer = PersistenceController.createTestController().container
    }
    
    /// Configure factory for production with Core Data
    nonisolated static func configureForProduction() {
        mode = .coreData
        // Always use the shared production container
        persistentContainer = getSharedController().container
    }
    
    /// Configure for production and ensure initial data is loaded
    nonisolated static func configureForProductionWithInitialData() async throws {
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
    nonisolated static func configureForDevelopment() {
        mode = .hybrid
    }
    
    /// Configure with custom persistent container
    nonisolated static func configure(persistentContainer: NSPersistentContainer) {
        self.persistentContainer = persistentContainer
    }
    
    /// Reset to default production configuration
    nonisolated static func resetToProduction() {
        mode = .coreData
        persistentContainer = getSharedController().container
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
