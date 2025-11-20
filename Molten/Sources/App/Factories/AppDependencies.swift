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
    /// - In tests: Uses in-memory Core Data (isolated per-test instances)
    /// - In production: Uses persistent Core Data repositories
    static let shared: AppDependencies = {
        if isRunningInTestBundle() {
            // Tests get a fresh in-memory Core Data controller (isolated)
            return AppDependencies(persistenceController: .createTestController())
        } else {
            // Production uses the shared persistent controller
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

    /// ✅ CRITICAL: Store the PersistenceController to prevent Core Data zombie crashes
    /// The controller owns the NSManagedObjectModel and must stay alive for contexts to work.
    let persistenceController: PersistenceController
    let mode: RepositoryMode

    /// Store contexts extracted from persistenceController
    /// These maintain strong references to contexts which in turn reference the model
    private let localContext: NSManagedObjectContext
    private let cloudContext: NSManagedObjectContext

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
    let ratingRepository: RatingRepository
    #if os(iOS)
    let userImageRepository: UserImageRepository
    #endif

    // MARK: - Services

    public let loggingService: LoggingService
    let inventoryTrackingService: InventoryTrackingService
    let catalogService: CatalogService
    let shoppingListService: ShoppingListService
    let projectService: ProjectService
    let purchaseRecordService: PurchaseRecordService
    let kilnScheduleService: KilnScheduleService
    let recipeService: RecipeService
    let unifiedLocationService: UnifiedLocationService
    let entitlementService: EntitlementService
    let subscriptionService: SubscriptionServiceProtocol
    let ratingService: RatingService

    // Background services (created lazily)
    private var _catalogUpdateService: CatalogUpdateService?
    private var _backgroundUpdateService: BackgroundUpdateService?
    private var _dataExportService: DataExportService?
    private var _inventorySharingManager: InventorySharingManager?

    // MARK: - Initialization

    /// Initialize with custom or default persistence controller
    /// - Parameter persistenceController: Optional persistence controller (defaults to shared production controller)
    init(persistenceController: PersistenceController = PersistenceController.shared) {
        self.persistenceController = persistenceController

        // Determine mode based on whether this is in-memory or persistent
        // In-memory stores use /dev/null paths (either "/dev/null" for single store or "/dev/null/local", "/dev/null/cloud" for two-store)
        let isInMemory = persistenceController.container.persistentStoreDescriptions.first?.url?.path.contains("/dev/null") ?? false
        self.mode = isInMemory ? .mock : .coreData

        // Initialize persistence controller if not already initialized (production only)
        if self.mode == .coreData && !persistenceController.isReady {
            print("🔧 AppDependencies: Core Data not ready, starting initialization...")
            // Need to initialize - use a semaphore to wait for async init
            let semaphore = DispatchSemaphore(value: 0)
            Task.detached(priority: .userInitiated) {
                print("🔧 AppDependencies: Task.detached started")
                print("🔧 AppDependencies: About to access PersistenceController.shared")
                let controller = PersistenceController.shared
                print("🔧 AppDependencies: Got controller, about to call initialize()")
                await controller.initialize()
                print("🔧 AppDependencies: initialize() completed, signaling semaphore")
                semaphore.signal()
            }
            print("🔧 AppDependencies: Waiting for semaphore...")
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

        // Extract and store contexts from persistenceController
        // Both persistenceController AND contexts are retained to ensure model stays alive
        self.localContext = persistenceController.localContext
        self.cloudContext = persistenceController.cloudContext

        // Create repositories (catalog data from bundled SQLite, user data from cloud store)
        // Both production and tests use SQLite for catalog data (read-only)
        if self.mode == .mock {
            // Tests: Use bundled SQLite database directly (no Documents copy)
            guard let bundlePath = Bundle.main.path(forResource: "catalog", ofType: "sqlite") else {
                fatalError("Test mode requires bundled catalog.sqlite")
            }
            let testDbManager = TestCatalogDatabaseManager(databasePath: bundlePath)
            try! testDbManager.initialize()

            self.glassItemRepository = SQLiteGlassItemRepository(databaseManager: testDbManager)
            self.itemTagsRepository = SQLiteItemTagsRepository(databaseManager: testDbManager)
            self.coatingItemRepository = SQLiteCoatingItemRepository(databaseManager: testDbManager)
            self.toolItemRepository = SQLiteToolItemRepository(databaseManager: testDbManager)
        } else {
            // Production: Use CatalogDatabaseManager (copies to Documents, handles OTA updates)
            self.glassItemRepository = SQLiteGlassItemRepository(databaseManager: CatalogDatabaseManager.shared)
            self.itemTagsRepository = SQLiteItemTagsRepository(databaseManager: CatalogDatabaseManager.shared)
            self.coatingItemRepository = SQLiteCoatingItemRepository(databaseManager: CatalogDatabaseManager.shared)
            self.toolItemRepository = SQLiteToolItemRepository(databaseManager: CatalogDatabaseManager.shared)
        }
        self.inventoryRepository = CoreDataInventoryRepository(context: self.cloudContext)
        self.locationRepository = CoreDataLocationRepository(context: self.cloudContext)
        self.userTagsRepository = CoreDataUserTagsRepository(context: self.cloudContext)
        self.userNotesRepository = CoreDataUserNotesRepository(context: self.cloudContext)
        self.shoppingListRepository = CoreDataShoppingListRepository(context: self.cloudContext)
        self.itemMinimumRepository = CoreDataItemMinimumRepository(context: self.cloudContext)
        self.projectRepository = CoreDataProjectRepository(context: self.cloudContext)
        self.logbookRepository = CoreDataLogbookRepository(context: self.cloudContext)
        self.purchaseRecordRepository = CoreDataPurchaseRecordRepository(context: self.cloudContext)
        self.projectImageRepository = CoreDataProjectImageRepository(context: self.cloudContext)
        self.kilnScheduleRepository = CoreDataKilnScheduleRepository(context: self.cloudContext)
        self.recipeRepository = CoreDataRecipeRepository(context: self.cloudContext)
        self.unifiedLocationRepository = CoreDataUnifiedLocationRepository(persistenceController: persistenceController)
        self.ratingRepository = CoreDataRatingRepository(localContext: self.localContext, cloudContext: self.cloudContext)
        #if os(iOS)
        self.userImageRepository = CoreDataUserImageRepository(context: self.cloudContext)
        #endif

        // Create logging service first (needed by other services)
        self.loggingService = Self.createLoggingService(isTestMode: self.mode == .mock)

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
            self.subscriptionService,
            self.ratingService
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
            ratingRepository: ratingRepository,
            subscriptionService: RevenueCatSubscriptionService(),
            loggingService: self.loggingService
        )
    }

    // MARK: - Service Setup Helper

    /// Create logging service with appropriate backends
    /// - Parameter isTestMode: Whether running in test mode (uses MockLogger instead of Sentry)
    private static func createLoggingService(isTestMode: Bool) -> LoggingService {
        if isTestMode {
            // In test mode, use mock logger only
            let mockLogger = MockLogger()
            return LoggingService(
                backends: [mockLogger],
                minimumLocalLevel: .debug,
                minimumRemoteLevel: .error
            )
        } else {
            // In production, configure Sentry
            // Sentry DSN is not a secret - it's safe to commit
            // See: https://docs.sentry.io/product/sentry-basics/dsn-explainer/

            // Option 1: Hardcode (simplest)
            let sentryDSN = "https://9656fde5615b69579eb41101834237b6@o4510371843932160.ingest.us.sentry.io/4510371846356992"

            // Option 2: Read from Info.plist (if you prefer)
            // Add <key>SentryDSN</key><string>your-dsn</string> to Info.plist
            // let sentryDSN = Bundle.main.infoDictionary?["SentryDSN"] as? String ?? ""

            // Option 3: Environment variable (fallback for CI/CD)
            // let sentryDSN = ProcessInfo.processInfo.environment["SENTRY_DSN"] ?? "https://your-dsn..."

            var backends: [LoggerBackend] = []

            // Only add Sentry if DSN is configured
            if !sentryDSN.isEmpty && !sentryDSN.contains("your-dsn") {
                let sentryLogger = SentryLogger(
                    dsn: sentryDSN,
                    environment: SentryEnvironment.current,
                    maxBreadcrumbs: 100
                )
                backends.append(sentryLogger)
            }

            return LoggingService(
                backends: backends,
                minimumLocalLevel: .debug,     // Log everything locally
                minimumRemoteLevel: .error     // Only send errors/critical to Sentry
            )
        }
    }

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
        ratingRepository: RatingRepository,
        subscriptionService: SubscriptionServiceProtocol,
        loggingService: LoggingService
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
        SubscriptionServiceProtocol,
        RatingService
    ) {
        // Create inventory tracking service first (needed by catalog service)
        let inventoryTrackingService = InventoryTrackingService(
            glassItemRepository: glassItemRepository,
            inventoryRepository: inventoryRepository,
            itemTagsRepository: itemTagsRepository
        )

        // Create rating service (needed by catalog service)
        let ratingService = RatingService(repository: ratingRepository, logger: loggingService)

        // Create catalog service (depends on inventory tracking service and rating service)
        let catalogService = CatalogService(
            glassItemRepository: glassItemRepository,
            coatingItemRepository: coatingItemRepository,
            toolItemRepository: toolItemRepository,
            inventoryTrackingService: inventoryTrackingService,
            itemMinimumRepository: itemMinimumRepository,
            itemTagsRepository: itemTagsRepository,
            userTagsRepository: userTagsRepository,
            ratingService: ratingService
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
            subscriptionService,
            ratingService
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
            databaseManager: CatalogDatabaseManager.shared,
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
        #if os(iOS)
        let service = DataExportService(
            catalogService: catalogService,
            inventoryService: inventoryTrackingService,
            projectRepository: projectRepository,
            logbookRepository: logbookRepository,
            purchaseRecordRepository: purchaseRecordRepository,
            userNotesRepository: userNotesRepository,
            userImageRepository: userImageRepository
        )
        #else
        let service = DataExportService(
            catalogService: catalogService,
            inventoryService: inventoryTrackingService,
            projectRepository: projectRepository,
            logbookRepository: logbookRepository,
            purchaseRecordRepository: purchaseRecordRepository,
            userNotesRepository: userNotesRepository
        )
        #endif
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
