//
//  AppDependencies.swift
//  Molten
//
//  Created by Assistant on 2025-11-10.
//  Replaces RepositoryFactory static methods with proper dependency injection
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
        if persistenceController.localContext == nil || persistenceController.cloudContext == nil {
            // Need to initialize - use a semaphore to wait for async init
            let semaphore = DispatchSemaphore(value: 0)
            Task.detached {
                await PersistenceController.shared.initialize()
                semaphore.signal()
            }
            _ = semaphore.wait(timeout: .now() + .seconds(30))
        }

        guard let localContext = persistenceController.localContext,
              let cloudContext = persistenceController.cloudContext else {
            fatalError("Persistence controller failed to initialize after 30 seconds")
        }

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
        self.itemMinimumRepository = MockItemMinimumRepository() // TODO: Implement Core Data version
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

        // Create services
        self.inventoryTrackingService = InventoryTrackingService(
            glassItemRepository: glassItemRepository,
            inventoryRepository: inventoryRepository,
            itemTagsRepository: itemTagsRepository
        )

        self.catalogService = CatalogService(
            glassItemRepository: glassItemRepository,
            coatingItemRepository: coatingItemRepository,
            toolItemRepository: toolItemRepository,
            inventoryTrackingService: inventoryTrackingService,
            itemMinimumRepository: itemMinimumRepository,
            itemTagsRepository: itemTagsRepository,
            userTagsRepository: userTagsRepository
        )

        self.shoppingListService = ShoppingListService(
            itemMinimumRepository: itemMinimumRepository,
            shoppingListRepository: shoppingListRepository,
            inventoryRepository: inventoryRepository,
            glassItemRepository: glassItemRepository,
            itemTagsRepository: itemTagsRepository,
            userTagsRepository: userTagsRepository
        )

        self.projectService = ProjectService(
            projectRepository: projectRepository,
            logbookRepository: logbookRepository,
            userTagsRepository: userTagsRepository
        )

        self.purchaseRecordService = PurchaseRecordService(
            repository: purchaseRecordRepository
        )

        self.kilnScheduleService = KilnScheduleService(
            repository: kilnScheduleRepository
        )

        self.glassItemDataLoadingService = GlassItemDataLoadingService(
            catalogService: catalogService,
            jsonLoader: JSONDataLoader(),
            catalogStorageService: try? CatalogStorageService()
        )

        self.recipeService = RecipeService(
            repository: recipeRepository
        )

        self.unifiedLocationService = UnifiedLocationService(
            repository: unifiedLocationRepository
        )

        self.entitlementService = EntitlementService(tier: .free)
        self.subscriptionService = RevenueCatSubscriptionService()
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

        // Create services with mocks
        self.inventoryTrackingService = InventoryTrackingService(
            glassItemRepository: glassItemRepository,
            inventoryRepository: inventoryRepository,
            itemTagsRepository: itemTagsRepository
        )

        self.catalogService = CatalogService(
            glassItemRepository: glassItemRepository,
            coatingItemRepository: coatingItemRepository,
            toolItemRepository: toolItemRepository,
            inventoryTrackingService: inventoryTrackingService,
            itemMinimumRepository: itemMinimumRepository,
            itemTagsRepository: itemTagsRepository,
            userTagsRepository: userTagsRepository
        )

        self.shoppingListService = ShoppingListService(
            itemMinimumRepository: itemMinimumRepository,
            shoppingListRepository: shoppingListRepository,
            inventoryRepository: inventoryRepository,
            glassItemRepository: glassItemRepository,
            itemTagsRepository: itemTagsRepository,
            userTagsRepository: userTagsRepository
        )

        self.projectService = ProjectService(
            projectRepository: projectRepository,
            logbookRepository: logbookRepository,
            userTagsRepository: userTagsRepository
        )

        self.purchaseRecordService = PurchaseRecordService(
            repository: purchaseRecordRepository
        )

        self.kilnScheduleService = KilnScheduleService(
            repository: kilnScheduleRepository
        )

        self.glassItemDataLoadingService = GlassItemDataLoadingService(
            catalogService: catalogService,
            jsonLoader: MockJSONDataLoader()
        )

        self.recipeService = RecipeService(
            repository: recipeRepository
        )

        self.unifiedLocationService = UnifiedLocationService(
            repository: unifiedLocationRepository
        )

        self.entitlementService = EntitlementService(tier: .free)
        self.subscriptionService = MockSubscriptionService(hasProAccess: false)
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

        // Load pinned SSL certificate from bundle
        guard let certURL = Bundle.main.url(forResource: "moltenglass-cert", withExtension: "der"),
              let certData = try? Data(contentsOf: certURL) else {
            fatalError("Missing moltenglass-cert.der - required for secure inventory sharing")
        }

        let apiClient = InventorySharingAPIClient(
            baseURL: URL(string: "https://moltenglass.app/api")!,
            pinnedCertificates: [certData]
        )

        let sharingService = InventorySharingService(apiClient: apiClient)
        let coordinator = InventorySharingCoordinator(sharingService: sharingService)
        let manager = InventorySharingManager(coordinator: coordinator)

        _inventorySharingManager = manager
        return manager
    }
}

// MARK: - Environment Key

struct AppDependenciesKey: EnvironmentKey {
    static let defaultValue: AppDependencies = {
        // Check if running tests - if so, use test dependencies by default
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        if isRunningTests {
            return AppDependencies(forTesting: true)
        } else {
            return AppDependencies()
        }
    }()
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
