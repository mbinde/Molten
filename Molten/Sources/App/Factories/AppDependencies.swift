//
//  AppDependencies.swift
//  Molten
//
//  Created by Assistant on 2025-11-10.
//  Provides application-wide dependency injection for all services and repositories
//

import Foundation
import CoreData
import SwiftUI

/// Application-wide dependency container
/// Created once at app startup, provides all services and repositories
/// Thread-safe via MainActor isolation
@MainActor
@Observable
class AppDependencies {

    // MARK: - Shared Instance

    /// Shared instance that automatically detects test vs production environment
    /// - In tests: Uses mock repositories
    /// - In production: Uses Core Data repositories
    static let shared: AppDependencies = {
        if isRunningInTestBundle() {
            return AppDependencies(forTesting: true)
        } else {
            return AppDependencies()
        }
    }()

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
                return true
            }
        }

        // Also check if the main bundle is a test bundle
        if let mainBundleId = Bundle.main.bundleIdentifier, mainBundleId.contains("Tests") {
            return true
        }

        // Check for XCTest framework presence
        return NSClassFromString("XCTestCase") != nil
    }

    // MARK: - Core Dependencies

    let persistenceController: PersistenceController
    let mode: RepositoryMode

    // MARK: - Repositories

    let glassItemRepository: GlassItemRepository
    let coatingItemRepository: CoatingItemRepository
    let toolItemRepository: ToolItemRepository
    let inventoryRepository: InventoryRepository
    let locationRepository: LocationRepository
    let itemTagsRepository: ItemTagsRepository
    let userTagsRepository: UserTagsRepository
    let userNotesRepository: UserNotesRepository
    let shoppingListRepository: ShoppingListRepository
    let itemMinimumRepository: ItemMinimumRepository
    let projectRepository: ProjectRepository
    let logbookRepository: LogbookRepository
    let purchaseRecordRepository: PurchaseRecordRepository
    let projectImageRepository: ProjectImageRepository
    let kilnScheduleRepository: KilnScheduleRepository
    let recipeRepository: RecipeRepository
    let unifiedLocationRepository: UnifiedLocationRepository
    #if canImport(UIKit)
    let userImageRepository: UserImageRepository
    #endif

    // MARK: - Services

    let inventoryTrackingService: InventoryTrackingService
    let catalogService: CatalogService
    let shoppingListService: ShoppingListService
    let projectService: ProjectService
    let purchaseRecordService: PurchaseRecordService
    let kilnScheduleService: KilnScheduleService
    let glassItemDataLoadingService: GlassItemDataLoadingService
    let recipeService: RecipeService
    let unifiedLocationService: UnifiedLocationService
    let entitlementService: EntitlementService
    let subscriptionService: SubscriptionServiceProtocol

    // Background services (created lazily)
    private var _catalogUpdateService: CatalogUpdateService?
    private var _backgroundUpdateService: BackgroundUpdateService?
    private var _dataExportService: DataExportService?
    private var _inventorySharingManager: InventorySharingManager?

    // MARK: - Initialization

    /// Initialize with production configuration (Core Data)
    /// Initializes PersistenceController if needed
    init() {
        self.mode = .coreData
        self.persistenceController = PersistenceController.shared

        // Initialize persistence controller if not already initialized
        // This blocks until Core Data is ready, but only on first init
        if !persistenceController.isReady {
            // Need to initialize - use a semaphore to wait for async init
            let semaphore = DispatchSemaphore(value: 0)
            Task.detached {
                await PersistenceController.shared.initialize()
                semaphore.signal()
            }
            let result = semaphore.wait(timeout: .now() + .seconds(30))

            // If initialization timed out, we cannot safely continue
            if result == .timedOut {
                fatalError("Core Data initialization timed out after 30 seconds. Cannot proceed without valid persistence layer.")
            }

            // Verify initialization actually succeeded
            guard persistenceController.isReady else {
                fatalError("Core Data initialization completed but persistence controller is not ready. Check initialization logic.")
            }
        }

        // Access contexts directly - they will fatalError if initialization failed
        let localContext = persistenceController.localContext
        let cloudContext = persistenceController.cloudContext

        // Create repositories (catalog data from local store, user data from cloud store)
        self.glassItemRepository = CoreDataGlassItemRepository(context: localContext)
        self.coatingItemRepository = CoreDataCoatingItemRepository(persistentContainer: persistenceController.container)
        self.toolItemRepository = CoreDataToolItemRepository(context: localContext)
        self.inventoryRepository = CoreDataInventoryRepository(context: cloudContext)
        self.locationRepository = CoreDataLocationRepository(context: cloudContext)
        self.itemTagsRepository = CoreDataItemTagsRepository(context: localContext)
        self.userTagsRepository = CoreDataUserTagsRepository(context: cloudContext)
        self.userNotesRepository = CoreDataUserNotesRepository(context: cloudContext)
        self.shoppingListRepository = CoreDataShoppingListRepository(context: cloudContext)
        self.itemMinimumRepository = CoreDataItemMinimumRepository(context: cloudContext)
        self.projectRepository = CoreDataProjectRepository(context: cloudContext)
        self.logbookRepository = CoreDataLogbookRepository(context: cloudContext)
        self.purchaseRecordRepository = CoreDataPurchaseRecordRepository(context: cloudContext)
        self.projectImageRepository = CoreDataProjectImageRepository(context: cloudContext)
        self.kilnScheduleRepository = CoreDataKilnScheduleRepository(context: cloudContext)
        self.recipeRepository = CoreDataRecipeRepository(context: cloudContext)
        self.unifiedLocationRepository = CoreDataUnifiedLocationRepository(persistenceController: persistenceController)
        #if canImport(UIKit)
        self.userImageRepository = CoreDataUserImageRepository(context: cloudContext)
        #endif

        // Create services (using helper to avoid duplication)
        (
            self.inventoryTrackingService,
            self.catalogService,
            self.shoppingListService,
            self.projectService,
            self.purchaseRecordService,
            self.kilnScheduleService,
            self.recipeService,
            self.unifiedLocationService,
            self.entitlementService,
            self.glassItemDataLoadingService,
            self.subscriptionService
        ) = Self.setupServices(
            glassItemRepository: glassItemRepository,
            coatingItemRepository: coatingItemRepository,
            toolItemRepository: toolItemRepository,
            inventoryRepository: inventoryRepository,
            itemTagsRepository: itemTagsRepository,
            userTagsRepository: userTagsRepository,
            itemMinimumRepository: itemMinimumRepository,
            shoppingListRepository: shoppingListRepository,
            projectRepository: projectRepository,
            logbookRepository: logbookRepository,
            purchaseRecordRepository: purchaseRecordRepository,
            kilnScheduleRepository: kilnScheduleRepository,
            recipeRepository: recipeRepository,
            unifiedLocationRepository: unifiedLocationRepository,
            jsonLoader: JSONDataLoader(),
            catalogStorageService: try? CatalogStorageService(),
            subscriptionService: RevenueCatSubscriptionService()
        )
    }

    /// Initialize with testing configuration (mocks)
    init(forTesting: Bool) {
        guard forTesting else {
            fatalError("Use init() for production, init(forTesting: true) for tests")
        }

        self.mode = .mock
        self.persistenceController = PersistenceController.preview

        // Create mock repositories
        self.glassItemRepository = MockGlassItemRepository()
        self.coatingItemRepository = MockCoatingItemRepository()
        self.toolItemRepository = MockToolItemRepository()
        self.inventoryRepository = MockInventoryRepository()
        self.locationRepository = MockLocationRepository()
        self.itemTagsRepository = MockItemTagsRepository()
        self.userTagsRepository = MockUserTagsRepository()
        self.userNotesRepository = MockUserNotesRepository()
        self.shoppingListRepository = MockShoppingListRepository()
        self.itemMinimumRepository = MockItemMinimumRepository()
        self.projectRepository = MockProjectRepository()
        self.logbookRepository = MockLogbookRepository()
        self.purchaseRecordRepository = MockPurchaseRecordRepository()
        self.projectImageRepository = MockProjectImageRepository()
        self.kilnScheduleRepository = MockKilnScheduleRepository()
        self.recipeRepository = MockRecipeRepository()
        self.unifiedLocationRepository = MockUnifiedLocationRepository()
        #if canImport(UIKit)
        self.userImageRepository = MockUserImageRepository()
        #endif

        // Create services (using helper to avoid duplication)
        (
            self.inventoryTrackingService,
            self.catalogService,
            self.shoppingListService,
            self.projectService,
            self.purchaseRecordService,
            self.kilnScheduleService,
            self.recipeService,
            self.unifiedLocationService,
            self.entitlementService,
            self.glassItemDataLoadingService,
            self.subscriptionService
        ) = Self.setupServices(
            glassItemRepository: glassItemRepository,
            coatingItemRepository: coatingItemRepository,
            toolItemRepository: toolItemRepository,
            inventoryRepository: inventoryRepository,
            itemTagsRepository: itemTagsRepository,
            userTagsRepository: userTagsRepository,
            itemMinimumRepository: itemMinimumRepository,
            shoppingListRepository: shoppingListRepository,
            projectRepository: projectRepository,
            logbookRepository: logbookRepository,
            purchaseRecordRepository: purchaseRecordRepository,
            kilnScheduleRepository: kilnScheduleRepository,
            recipeRepository: recipeRepository,
            unifiedLocationRepository: unifiedLocationRepository,
            jsonLoader: MockJSONDataLoader(),
            catalogStorageService: nil as CatalogStorageService?,  // No storage service for tests
            subscriptionService: MockSubscriptionService(hasProAccess: false)
        )
    }

    // MARK: - Service Setup Helper

    /// Create all services with the provided repositories
    /// This eliminates duplication between production and test inits
    private static func setupServices(
        glassItemRepository: GlassItemRepository,
        coatingItemRepository: CoatingItemRepository,
        toolItemRepository: ToolItemRepository,
        inventoryRepository: InventoryRepository,
        itemTagsRepository: ItemTagsRepository,
        userTagsRepository: UserTagsRepository,
        itemMinimumRepository: ItemMinimumRepository,
        shoppingListRepository: ShoppingListRepository,
        projectRepository: ProjectRepository,
        logbookRepository: LogbookRepository,
        purchaseRecordRepository: PurchaseRecordRepository,
        kilnScheduleRepository: KilnScheduleRepository,
        recipeRepository: RecipeRepository,
        unifiedLocationRepository: UnifiedLocationRepository,
        jsonLoader: JSONDataLoading,
        catalogStorageService: CatalogStorageService?,
        subscriptionService: SubscriptionServiceProtocol
    ) -> (
        InventoryTrackingService,
        CatalogService,
        ShoppingListService,
        ProjectService,
        PurchaseRecordService,
        KilnScheduleService,
        RecipeService,
        UnifiedLocationService,
        EntitlementService,
        GlassItemDataLoadingService,
        SubscriptionServiceProtocol
    ) {
        // Create inventory tracking service first (needed by catalog service)
        let inventoryTrackingService = InventoryTrackingService(
            glassItemRepository: glassItemRepository,
            inventoryRepository: inventoryRepository,
            itemTagsRepository: itemTagsRepository
        )

        // Create catalog service (depends on inventory tracking service)
        let catalogService = CatalogService(
            glassItemRepository: glassItemRepository,
            coatingItemRepository: coatingItemRepository,
            toolItemRepository: toolItemRepository,
            inventoryTrackingService: inventoryTrackingService,
            itemMinimumRepository: itemMinimumRepository,
            itemTagsRepository: itemTagsRepository,
            userTagsRepository: userTagsRepository
        )

        // Create shopping list service
        let shoppingListService = ShoppingListService(
            itemMinimumRepository: itemMinimumRepository,
            shoppingListRepository: shoppingListRepository,
            inventoryRepository: inventoryRepository,
            glassItemRepository: glassItemRepository,
            itemTagsRepository: itemTagsRepository,
            userTagsRepository: userTagsRepository
        )

        // Create project service
        let projectService = ProjectService(
            projectRepository: projectRepository,
            logbookRepository: logbookRepository,
            userTagsRepository: userTagsRepository
        )

        // Create purchase record service
        let purchaseRecordService = PurchaseRecordService(
            repository: purchaseRecordRepository
        )

        // Create kiln schedule service
        let kilnScheduleService = KilnScheduleService(
            repository: kilnScheduleRepository
        )

        // Create recipe service
        let recipeService = RecipeService(
            repository: recipeRepository
        )

        // Create unified location service
        let unifiedLocationService = UnifiedLocationService(
            repository: unifiedLocationRepository
        )

        // Create entitlement service
        let entitlementService = EntitlementService()

        // Create glass item data loading service
        let glassItemDataLoadingService = GlassItemDataLoadingService(
            catalogService: catalogService,
            jsonLoader: jsonLoader,
            catalogStorageService: catalogStorageService
        )

        return (
            inventoryTrackingService,
            catalogService,
            shoppingListService,
            projectService,
            purchaseRecordService,
            kilnScheduleService,
            recipeService,
            unifiedLocationService,
            entitlementService,
            glassItemDataLoadingService,
            subscriptionService
        )
    }

    // MARK: - Lazy Services

    /// Catalog update service (created lazily)
    var catalogUpdateService: CatalogUpdateService {
        if let service = _catalogUpdateService {
            return service
        }
        let service = CatalogUpdateService(
            apiClient: CatalogAPIClient(),
            storageService: try! CatalogStorageService(),
            dataLoadingService: glassItemDataLoadingService,
            networkMonitor: NetworkMonitor.shared
        )
        _catalogUpdateService = service
        return service
    }

    /// Background update service (created lazily)
    var backgroundUpdateService: BackgroundUpdateService {
        if let service = _backgroundUpdateService {
            return service
        }
        let service = BackgroundUpdateService(
            updateService: catalogUpdateService,
            networkMonitor: NetworkMonitor.shared
        )
        _backgroundUpdateService = service
        return service
    }

    /// Data export service (created lazily)
    var dataExportService: DataExportService {
        if let service = _dataExportService {
            return service
        }
        let service = DataExportService(
            catalogService: catalogService,
            inventoryService: inventoryTrackingService,
            projectRepository: projectRepository,
            logbookRepository: logbookRepository,
            purchaseRecordRepository: purchaseRecordRepository,
            userImageRepository: userImageRepository,
            userNotesRepository: userNotesRepository
        )
        _dataExportService = service
        return service
    }

    /// Inventory sharing manager (created lazily)
    var inventorySharingManager: InventorySharingManager {
        if let manager = _inventorySharingManager {
            return manager
        }

        // Use the convenience init which handles all the setup
        let manager = InventorySharingManager(deps: self)

        _inventorySharingManager = manager
        return manager
    }
}

// MARK: - Environment Key

struct AppDependenciesKey: EnvironmentKey {
    /// Default value uses AppDependencies.shared which auto-detects test environment
    static let defaultValue: AppDependencies = AppDependencies.shared
}

extension EnvironmentValues {
    var appDependencies: AppDependencies {
        get { self[AppDependenciesKey.self] }
        set { self[AppDependenciesKey.self] = newValue }
    }
}

// MARK: - Repository Mode

enum RepositoryMode: Sendable, Equatable {
    case mock
    case coreData
}
