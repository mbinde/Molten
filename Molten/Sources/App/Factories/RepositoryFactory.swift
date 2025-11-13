//
//  RepositoryFactory.swift
//  Flameworker
//
//  Created by Assistant on 10/14/25.
//

import Foundation
import CoreData
import OSLog

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
    nonisolated(unsafe) private static var mockUnifiedLocationRepo: MockUnifiedLocationRepository? = nil
    nonisolated(unsafe) private static var mockKilnScheduleRepo: MockKilnScheduleRepository? = nil
    nonisolated(unsafe) private static var mockRecipeRepo: MockRecipeRepository? = nil
    nonisolated(unsafe) private static var mockToolItemRepo: MockToolItemRepository? = nil
    nonisolated(unsafe) private static var mockCoatingItemRepo: MockCoatingItemRepository? = nil
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

        case .coreData, .hybrid:
            // GlassItem is catalog data → use bundled SQLite database
            return SQLiteGlassItemRepository()
        }
    }

    /// Creates a ToolItemRepository based on current mode
    nonisolated static func createToolItemRepository() -> ToolItemRepository {
        switch mode {
        case .mock:
            // Return cached instance to ensure consistency across service creation
            if let cached = mockToolItemRepo {
                return cached
            }
            let repo = MockToolItemRepository()
            mockToolItemRepo = repo
            return repo

        case .coreData:
            // ToolItem is catalog data → use localContext (same as GlassItem)
            let controller = getSharedController()
            guard let context = controller.localContext else {
                fatalError("localContext not initialized - call PersistenceController.shared.initialize() first")
            }
            return CoreDataToolItemRepository(context: context)

        case .hybrid:
            // ToolItem is catalog data → use localContext
            let controller = getSharedController()
            guard let context = controller.localContext else {
                fatalError("localContext not initialized - call PersistenceController.shared.initialize() first")
            }
            return CoreDataToolItemRepository(context: context)
        }
    }

    /// Creates a CoatingItemRepository based on current mode
    nonisolated static func createCoatingItemRepository() -> CoatingItemRepository {
        switch mode {
        case .mock:
            // Return cached instance to ensure consistency across service creation
            if let cached = mockCoatingItemRepo {
                return cached
            }
            let repo = MockCoatingItemRepository()
            mockCoatingItemRepo = repo
            return repo

        case .coreData:
            // CoatingItem is catalog data → use localContext (same as GlassItem)
            let controller = getSharedController()
            guard let context = controller.localContext else {
                fatalError("localContext not initialized - call PersistenceController.shared.initialize() first")
            }
            return CoreDataCoatingItemRepository(persistentContainer: controller.container)

        case .hybrid:
            // CoatingItem is catalog data → use localContext
            let controller = getSharedController()
            guard let context = controller.localContext else {
                fatalError("localContext not initialized - call PersistenceController.shared.initialize() first")
            }
            return CoreDataCoatingItemRepository(persistentContainer: controller.container)
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

    /// Creates a RecipeRepository based on current mode
    /// Note: Uses cloudContext because recipes are user-created data that syncs via CloudKit
    nonisolated static func createRecipeRepository() -> RecipeRepository {
        switch mode {
        case .mock:
            // Return cached instance to ensure consistency
            if let cached = mockRecipeRepo {
                return cached
            }
            let repo = MockRecipeRepository()
            mockRecipeRepo = repo
            return repo

        case .coreData:
            let controller = getSharedController()
            guard let context = controller.cloudContext else {
                fatalError("cloudContext not initialized")
            }
            return CoreDataRecipeRepository(context: context)

        case .hybrid:
            let controller = getSharedController()
            guard let context = controller.cloudContext else {
                fatalError("cloudContext not initialized")
            }
            return CoreDataRecipeRepository(context: context)
        }
    }

    /// Creates a UnifiedLocationRepository based on current mode
    /// Note: Uses localContext because locations are loaded from JSON (non-CloudKit syncing)
    nonisolated static func createUnifiedLocationRepository() -> UnifiedLocationRepository {
        switch mode {
        case .mock:
            // Return cached instance to ensure consistency
            if let cached = mockUnifiedLocationRepo {
                return cached
            }
            let repo = MockUnifiedLocationRepository()
            mockUnifiedLocationRepo = repo
            return repo

        case .coreData:
            let controller = getSharedController()
            return CoreDataUnifiedLocationRepository(persistenceController: controller)

        case .hybrid:
            let controller = getSharedController()
            return CoreDataUnifiedLocationRepository(persistenceController: controller)
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
            coatingItemRepository: createCoatingItemRepository(),
            toolItemRepository: createToolItemRepository(),
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

    /// Creates a KilnScheduleService with all dependencies
    nonisolated static func createKilnScheduleService() -> KilnScheduleService {
        return KilnScheduleService(
            repository: createKilnScheduleRepository()
        )
    }

    /// Creates a GlassItemDataLoadingService with all dependencies
    /// Includes CatalogStorageService for OTA catalog support
    nonisolated static func createGlassItemDataLoadingService() -> GlassItemDataLoadingService {
        return GlassItemDataLoadingService(
            catalogService: createCatalogService(),
            jsonLoader: JSONDataLoader(),
            catalogStorageService: try? CatalogStorageService()
        )
    }

    /// Creates a CatalogUpdateService with all dependencies
    /// Note: This is a @MainActor class, so must be called from main thread
    @MainActor
    static func createCatalogUpdateService() -> CatalogUpdateService {
        return CatalogUpdateService(
            apiClient: CatalogAPIClient(),
            storageService: try! CatalogStorageService(),
            dataLoadingService: createGlassItemDataLoadingService(),
            networkMonitor: NetworkMonitor.shared
        )
    }

    /// Creates a BackgroundUpdateService for automatic update checks
    /// Note: This is a @MainActor class, so must be called from main thread
    @MainActor
    static func createBackgroundUpdateService() -> BackgroundUpdateService {
        return BackgroundUpdateService(
            updateService: createCatalogUpdateService(),
            networkMonitor: NetworkMonitor.shared
        )
    }

    /// Creates a RecipeService with all dependencies
    nonisolated static func createRecipeService() -> RecipeService {
        return RecipeService(
            repository: createRecipeRepository()
        )
    }

    /// Creates a UnifiedLocationService with all dependencies
    nonisolated static func createUnifiedLocationService() -> UnifiedLocationService {
        return UnifiedLocationService(
            repository: createUnifiedLocationRepository()
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

    /// Creates a SubscriptionService based on current mode
    @MainActor
    static func createSubscriptionService() -> SubscriptionServiceProtocol {
        print("🏭 [RepositoryFactory] createSubscriptionService() called with mode: \(mode)")
        switch mode {
        case .mock, .hybrid:
            // Testing/development: Use mock with no Pro access by default
            print("🏭 [RepositoryFactory] Creating MockSubscriptionService")
            return MockSubscriptionService(hasProAccess: false)

        case .coreData:
            // Production: Use RevenueCat
            print("🏭 [RepositoryFactory] Creating RevenueCatSubscriptionService")
            return RevenueCatSubscriptionService()
        }
    }

    /// Creates a SubscriptionService with Pro access enabled (for testing Pro features)
    @MainActor
    static func createSubscriptionServiceWithProAccess() -> SubscriptionServiceProtocol {
        return MockSubscriptionService(hasProAccess: true)
    }

    /// Creates an InventorySharingManager for sharing inventory with friends
    @MainActor
    static func createInventorySharingManager() -> InventorySharingManager {
        // Load pinned SSL certificate from bundle
        guard let certURL = Bundle.main.url(forResource: "moltenglass-cert", withExtension: "der"),
              let certData = try? Data(contentsOf: certURL) else {
            fatalError("Missing moltenglass-cert.der - required for secure inventory sharing")
        }

        // Create API client with production URL and certificate pinning
        let apiClient = InventorySharingAPIClient(
            baseURL: URL(string: "https://moltenglass.app/api")!,
            pinnedCertificates: [certData]
        )

        // Create service with custom API client
        let sharingService = InventorySharingService(apiClient: apiClient)

        // Create coordinator and manager
        let coordinator = InventorySharingCoordinator(sharingService: sharingService)
        return InventorySharingManager(coordinator: coordinator)
    }

    // MARK: - Configuration Helpers

    /// Detect if we're running in a test bundle (not production code)
    private nonisolated static func isRunningInTestBundle() -> Bool {
        // Check if XCTest bundle is loaded
        let testBundleIdentifiers = [
            "MoltenTests",
            "RepositoryTests",
            "ViewModelTests",
            "PerformanceTests",
            "MoltenUITests"
        ]

        // Check if any test bundle is in the loaded bundles
        for bundle in Bundle.allBundles {
            if let bundleId = bundle.bundleIdentifier,
               testBundleIdentifiers.contains(where: { bundleId.contains($0) }) {
                print("🧪 isRunningInTestBundle: Found test bundle: \(bundleId)")
                return true
            }
        }

        // Also check if the main bundle is a test bundle
        if let mainBundleId = Bundle.main.bundleIdentifier {
            print("🧪 isRunningInTestBundle: Main bundle ID: \(mainBundleId)")
            if mainBundleId.contains("Tests") {
                print("🧪 isRunningInTestBundle: Main bundle contains 'Tests'")
                return true
            }
        }

        // Check for XCTest framework presence
        let hasXCTest = NSClassFromString("XCTestCase") != nil
        print("🧪 isRunningInTestBundle: XCTestCase present: \(hasXCTest)")

        if !hasXCTest {
            print("🧪 isRunningInTestBundle: NOT in test bundle - will crash if configureForTesting() called")
        }

        return hasXCTest
    }

    /// Configure factory for testing with all mocks
    /// ⚠️ CRITICAL: This should ONLY be called from test code!
    /// Runtime assertion will fail if called from production code.
    nonisolated static func configureForTesting() {
        // CRITICAL SAFETY CHECK: Prevent accidental use in production code
        guard isRunningInTestBundle() else {
            let errorMessage = """
            🚨 CRITICAL ERROR: configureForTesting() called outside of test context!

            This will put the ENTIRE app in mock mode and prevent real data from being saved.

            If you're seeing this in production code:
            - Replace with: RepositoryFactory.configureForProduction()

            If you're seeing this in test code:
            - Make sure your test file is added to the correct test target
            - Check that the test bundle identifier contains 'Tests'

            Call stack:
            """

            // Print detailed error with call stack
            print(errorMessage)
            Thread.callStackSymbols.forEach { print($0) }

            // Crash in debug builds, log error in release
            #if DEBUG
            fatalError(errorMessage)
            #else
            print("⚠️ WARNING: Ignoring configureForTesting() call in production - using production mode instead")
            configureForProduction()
            return
            #endif
        }

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
        mockUnifiedLocationRepo = nil
        mockKilnScheduleRepo = nil
        mockRecipeRepo = nil
        mockToolItemRepo = nil
        mockCoatingItemRepo = nil
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

    /// Configure factory for testing with a specific Core Data test controller
    /// Use this when you need to set up or clear data in the controller before using it
    nonisolated static func configureForTestingWithCoreData(controller: PersistenceController) {
        mode = .coreData
        testController = controller
        persistentContainer = controller.container
    }

    /// Configure factory for production with Core Data
    nonisolated static func configureForProduction() {
        mode = .coreData
        // Always use the shared production container
        let controller = getSharedController()

        // Ensure the controller is initialized before accessing its contexts
        // Production controllers load asynchronously, so we need to wait
        let semaphore = DispatchSemaphore(value: 0)
        Task.detached {
            await controller.initialize()
            semaphore.signal()
        }

        // Wait up to 10 seconds for initialization
        // CloudKit might fail in simulator (no iCloud account), but Core Data still works
        let timeout = DispatchTime.now() + .seconds(10)
        if semaphore.wait(timeout: timeout) == .timedOut {
            Logger(subsystem: "com.MotleyWoods.Molten", category: "RepositoryFactory")
                .warning("Timed out waiting for PersistenceController initialization - CloudKit may not be available")
        }

        persistentContainer = controller.container
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
    
    /// Configure with custom persistence controller (for testing)
    nonisolated static func configure(testController controller: PersistenceController) {
        testController = controller
        persistentContainer = controller.container
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
