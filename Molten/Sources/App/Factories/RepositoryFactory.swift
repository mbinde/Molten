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

    // MARK: - Mock Repository Singletons (for testing)
    /// Cached mock repositories to ensure consistent state across test service creation
    nonisolated(unsafe) private static var mockGlassItemRepo: MockGlassItemRepository? = nil
    nonisolated(unsafe) private static var mockInventoryRepo: MockInventoryRepository? = nil
    nonisolated(unsafe) private static var mockLocationRepo: MockLocationRepository? = nil
    nonisolated(unsafe) private static var mockItemTagsRepo: MockItemTagsRepository? = nil
    nonisolated(unsafe) private static var mockUserTagsRepo: MockUserTagsRepository? = nil
    nonisolated(unsafe) private static var mockUserNotesRepo: MockUserNotesRepository? = nil
    nonisolated(unsafe) private static var mockShoppingListRepo: MockShoppingListRepository? = nil
    nonisolated(unsafe) private static var mockProjectRepo: MockProjectRepository? = nil
    nonisolated(unsafe) private static var mockLogbookRepo: MockLogbookRepository? = nil
    nonisolated(unsafe) private static var mockPurchaseRecordRepo: MockPurchaseRecordRepository? = nil
    nonisolated(unsafe) private static var mockProjectImageRepo: MockProjectImageRepository? = nil
    nonisolated(unsafe) private static var mockStoreRepo: MockStoreRepository? = nil
    nonisolated(unsafe) private static var mockKilnScheduleRepo: MockKilnScheduleRepository? = nil
    #if canImport(UIKit)
    nonisolated(unsafe) private static var mockUserImageRepo: MockUserImageRepository? = nil
    #endif

    /// Test controller for isolated testing (when configureForTestingWithCoreData is used)
    nonisolated(unsafe) private static var testController: PersistenceController? = nil

    /// Helper to get shared controller without autoclosure issues
    nonisolated private static func getSharedController() -> PersistenceController {
        // If we have a test controller, use it instead of shared
        if let testController = testController {
            return testController
        }
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
            // Return cached instance to ensure consistency across service creation
            if let cached = mockGlassItemRepo {
                return cached
            }
            let repo = MockGlassItemRepository()
            mockGlassItemRepo = repo
            return repo

        case .coreData:
            // GlassItem is catalog data → use localContext
            let controller = getSharedController()
            guard let context = controller.localContext else {
                fatalError("localContext not initialized - call PersistenceController.shared.initialize() first")
            }
            return CoreDataGlassItemRepository(context: context)

        case .hybrid:
            // GlassItem is catalog data → use localContext
            let controller = getSharedController()
            guard let context = controller.localContext else {
                fatalError("localContext not initialized - call PersistenceController.shared.initialize() first")
            }
            return CoreDataGlassItemRepository(context: context)
        }
    }
    
    /// Creates an InventoryRepository based on current mode
    nonisolated static func createInventoryRepository() -> InventoryRepository {
        switch mode {
        case .mock:
            // Return cached instance to ensure consistency
            if let cached = mockInventoryRepo {
                return cached
            }
            let repo = MockInventoryRepository()
            mockInventoryRepo = repo
            return repo

        case .coreData:
            let controller = getSharedController()
            guard let context = controller.localContext else {
                fatalError("cloudContext not initialized")
            }
            return CoreDataInventoryRepository(context: context)

        case .hybrid:
            let controller = getSharedController()
            guard let context = controller.cloudContext else {
                fatalError("cloudContext not initialized")
            }
            return CoreDataInventoryRepository(context: context)
        }
    }
    
    /// Creates a LocationRepository based on current mode
    nonisolated static func createLocationRepository() -> LocationRepository {
        switch mode {
        case .mock:
            // Return cached instance to ensure consistency
            if let cached = mockLocationRepo {
                return cached
            }
            let repo = MockLocationRepository()
            mockLocationRepo = repo
            return repo

        case .coreData:
            let controller = getSharedController()
            guard let context = controller.cloudContext else {
                fatalError("cloudContext not initialized")
            }
            return CoreDataLocationRepository(context: context)

        case .hybrid:
            let controller = getSharedController()
            guard let context = controller.cloudContext else {
                fatalError("cloudContext not initialized")
            }
            return CoreDataLocationRepository(context: context)
        }
    }
    
    /// Creates an ItemTagsRepository based on current mode
    nonisolated static func createItemTagsRepository() -> ItemTagsRepository {
        switch mode {
        case .mock:
            // Return cached instance to ensure consistency
            if let cached = mockItemTagsRepo {
                return cached
            }
            let repo = MockItemTagsRepository()
            mockItemTagsRepo = repo
            return repo

        case .coreData:
            let controller = getSharedController()
            guard let context = controller.localContext else {
                fatalError("localContext not initialized")
            }
            return CoreDataItemTagsRepository(context: context)

        case .hybrid:
            let controller = getSharedController()
            guard let context = controller.localContext else {
                fatalError("cloudContext not initialized")
            }
            return CoreDataItemTagsRepository(context: context)
        }
    }

    /// Creates a UserTagsRepository based on current mode
    nonisolated static func createUserTagsRepository() -> UserTagsRepository {
        switch mode {
        case .mock:
            // Return cached instance to ensure consistency
            if let cached = mockUserTagsRepo {
                return cached
            }
            let repo = MockUserTagsRepository()
            mockUserTagsRepo = repo
            return repo

        case .coreData:
            let controller = getSharedController()
            guard let context = controller.cloudContext else {
                fatalError("cloudContext not initialized")
            }
            return CoreDataUserTagsRepository(context: context)

        case .hybrid:
            let controller = getSharedController()
            guard let context = controller.cloudContext else {
                fatalError("cloudContext not initialized")
            }
            return CoreDataUserTagsRepository(context: context)
        }
    }

    /// Creates a UserNotesRepository based on current mode
    nonisolated static func createUserNotesRepository() -> UserNotesRepository {
        switch mode {
        case .mock:
            // Return cached instance to ensure consistency
            if let cached = mockUserNotesRepo {
                return cached
            }
            let repo = MockUserNotesRepository()
            mockUserNotesRepo = repo
            return repo

        case .coreData:
            let controller = getSharedController()
            guard let context = controller.cloudContext else {
                fatalError("cloudContext not initialized")
            }
            return CoreDataUserNotesRepository(context: context)

        case .hybrid:
            let controller = getSharedController()
            guard let context = controller.cloudContext else {
                fatalError("cloudContext not initialized")
            }
            return CoreDataUserNotesRepository(context: context)
        }
    }

    /// Creates a ShoppingListRepository based on current mode
    nonisolated static func createShoppingListRepository() -> ShoppingListRepository {
        switch mode {
        case .mock:
            // Return cached instance to ensure consistency
            if let cached = mockShoppingListRepo {
                return cached
            }
            let repo = MockShoppingListRepository()
            mockShoppingListRepo = repo
            return repo

        case .coreData:
            let controller = getSharedController()
            guard let context = controller.cloudContext else {
                fatalError("cloudContext not initialized")
            }
            return CoreDataShoppingListRepository(context: context)

        case .hybrid:
            let controller = getSharedController()
            guard let context = controller.cloudContext else {
                fatalError("cloudContext not initialized")
            }
            return CoreDataShoppingListRepository(context: context)
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
            // Return cached instance to ensure consistency
            if let cached = mockUserImageRepo {
                return cached
            }
            let repo = MockUserImageRepository()
            mockUserImageRepo = repo
            return repo

        case .coreData:
            let controller = getSharedController()
            guard let context = controller.cloudContext else {
                fatalError("cloudContext not initialized")
            }
            return CoreDataUserImageRepository(context: context)

        case .hybrid:
            let controller = getSharedController()
            guard let context = controller.cloudContext else {
                fatalError("cloudContext not initialized")
            }
            return CoreDataUserImageRepository(context: context)
        }
    }
    #endif

    /// Creates a ProjectRepository based on current mode
    nonisolated static func createProjectRepository() -> ProjectRepository {
        switch mode {
        case .mock:
            // Return cached instance to ensure consistency
            if let cached = mockProjectRepo {
                return cached
            }
            let repo = MockProjectRepository()
            mockProjectRepo = repo
            return repo

        case .coreData:
            let controller = getSharedController()
            guard let context = controller.cloudContext else {
                fatalError("cloudContext not initialized")
            }
            return CoreDataProjectRepository(context: context)

        case .hybrid:
            let controller = getSharedController()
            guard let context = controller.cloudContext else {
                fatalError("cloudContext not initialized")
            }
            return CoreDataProjectRepository(context: context)
        }
    }

    /// Creates a LogbookRepository based on current mode
    nonisolated static func createLogbookRepository() -> LogbookRepository {
        switch mode {
        case .mock:
            // Return cached instance to ensure consistency
            if let cached = mockLogbookRepo {
                return cached
            }
            let repo = MockLogbookRepository()
            mockLogbookRepo = repo
            return repo

        case .coreData:
            let controller = getSharedController()
            guard let context = controller.cloudContext else {
                fatalError("cloudContext not initialized")
            }
            return CoreDataLogbookRepository(context: context)

        case .hybrid:
            let controller = getSharedController()
            guard let context = controller.cloudContext else {
                fatalError("cloudContext not initialized")
            }
            return CoreDataLogbookRepository(context: context)
        }
    }

    /// Creates a PurchaseRecordRepository based on current mode
    nonisolated static func createPurchaseRecordRepository() -> PurchaseRecordRepository {
        switch mode {
        case .mock:
            // Return cached instance to ensure consistency
            if let cached = mockPurchaseRecordRepo {
                return cached
            }
            let repo = MockPurchaseRecordRepository()
            mockPurchaseRecordRepo = repo
            return repo

        case .coreData:
            let controller = getSharedController()
            guard let context = controller.cloudContext else {
                fatalError("cloudContext not initialized")
            }
            return CoreDataPurchaseRecordRepository(context: context)

        case .hybrid:
            let controller = getSharedController()
            guard let context = controller.cloudContext else {
                fatalError("cloudContext not initialized")
            }
            return CoreDataPurchaseRecordRepository(context: context)
        }
    }

    /// Creates a ProjectImageRepository based on current mode
    nonisolated static func createProjectImageRepository() -> ProjectImageRepository {
        switch mode {
        case .mock:
            // Return cached instance to ensure consistency
            if let cached = mockProjectImageRepo {
                return cached
            }
            let repo = MockProjectImageRepository()
            mockProjectImageRepo = repo
            return repo

        case .coreData:
            let controller = getSharedController()
            guard let context = controller.cloudContext else {
                fatalError("cloudContext not initialized")
            }
            return CoreDataProjectImageRepository(context: context)

        case .hybrid:
            let controller = getSharedController()
            guard let context = controller.cloudContext else {
                fatalError("cloudContext not initialized")
            }
            return CoreDataProjectImageRepository(context: context)
        }
    }

    /// Creates a StoreRepository based on current mode
    nonisolated static func createStoreRepository() -> StoreRepository {
        switch mode {
        case .mock:
            // Return cached instance to ensure consistency
            if let cached = mockStoreRepo {
                return cached
            }
            let repo = MockStoreRepository()
            mockStoreRepo = repo
            return repo

        case .coreData:
            let controller = getSharedController()
            guard let context = controller.cloudContext else {
                fatalError("cloudContext not initialized")
            }
            return CoreDataStoreRepository(context: context)

        case .hybrid:
            let controller = getSharedController()
            guard let context = controller.cloudContext else {
                fatalError("cloudContext not initialized")
            }
            return CoreDataStoreRepository(context: context)
        }
    }

    /// Creates a KilnScheduleRepository based on current mode
    nonisolated static func createKilnScheduleRepository() -> KilnScheduleRepository {
        switch mode {
        case .mock:
            // Return cached instance to ensure consistency
            if let cached = mockKilnScheduleRepo {
                return cached
            }
            let repo = MockKilnScheduleRepository()
            mockKilnScheduleRepo = repo
            return repo

        case .coreData:
            let controller = getSharedController()
            guard let context = controller.cloudContext else {
                fatalError("cloudContext not initialized")
            }
            return CoreDataKilnScheduleRepository(context: context)

        case .hybrid:
            let controller = getSharedController()
            guard let context = controller.cloudContext else {
                fatalError("cloudContext not initialized")
            }
            return CoreDataKilnScheduleRepository(context: context)
        }
    }

    // MARK: - Service Creation (Convenience)
    
    /// Creates a complete InventoryTrackingService with all dependencies
    nonisolated static func createInventoryTrackingService() -> InventoryTrackingService {
        return InventoryTrackingService(
            glassItemRepository: createGlassItemRepository(),
            inventoryRepository: createInventoryRepository(),
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
            logbookRepository: createLogbookRepository(),
            userTagsRepository: createUserTagsRepository()
        )
    }

    /// Creates a PurchaseRecordService with all dependencies
    nonisolated static func createPurchaseRecordService() -> PurchaseRecordService {
        return PurchaseRecordService(
            repository: createPurchaseRecordRepository()
        )
    }

    /// Creates a StoreService with all dependencies
    nonisolated static func createStoreService() -> StoreService {
        return StoreService(
            repository: createStoreRepository()
        )
    }

    /// Creates a KilnScheduleService with all dependencies
    nonisolated static func createKilnScheduleService() -> KilnScheduleService {
        return KilnScheduleService(
            repository: createKilnScheduleRepository()
        )
    }

    /// Creates an EntitlementService for subscription management
    /// TODO: Integrate with StoreKit to determine actual subscription tier
    /// For now, defaults to free tier
    @MainActor
    static func createEntitlementService() -> EntitlementService {
        // In production, this should query StoreKit for actual subscription status
        // For now, always default to free tier
        return EntitlementService(tier: .free)
    }

    /// Creates a DataExportService with all dependencies
    @MainActor
    static func createDataExportService() -> DataExportService {
        return DataExportService(
            catalogService: createCatalogService(),
            inventoryService: createInventoryTrackingService(),
            projectRepository: createProjectRepository(),
            logbookRepository: createLogbookRepository(),
            purchaseRecordRepository: createPurchaseRecordRepository(),
            userImageRepository: createUserImageRepository(),
            userNotesRepository: createUserNotesRepository()
        )
    }

    // MARK: - Configuration Helpers
    
    /// Configure factory for testing with all mocks
    nonisolated static func configureForTesting() {
        mode = .mock
        // Clear all cached mock repositories to ensure clean state for each test
        // Setting to nil causes new instances to be created on next access
        mockGlassItemRepo = nil
        mockInventoryRepo = nil
        mockLocationRepo = nil
        mockItemTagsRepo = nil
        mockUserTagsRepo = nil
        mockUserNotesRepo = nil
        mockShoppingListRepo = nil
        mockProjectRepo = nil
        mockLogbookRepo = nil
        mockPurchaseRecordRepo = nil
        mockProjectImageRepo = nil
        mockStoreRepo = nil
        mockKilnScheduleRepo = nil
        #if canImport(UIKit)
        mockUserImageRepo = nil
        #endif
    }
    
    /// Configure factory for testing with isolated Core Data
    nonisolated static func configureForTestingWithCoreData() {
        mode = .coreData
        // Use an isolated test controller
        let controller = PersistenceController.createTestController()
        testController = controller
        persistentContainer = controller.container
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
 let inventory = InventoryModel(item_stable_id: "bullseye-clear", quantity: 10.0, type: "rod", location: "shelf-1")
 try await inventoryService.inventoryRepository.createInventory(inventory)
 ```
*/
