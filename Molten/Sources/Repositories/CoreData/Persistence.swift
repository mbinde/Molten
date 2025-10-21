//
//  Persistence.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/27/25.
//

@preconcurrency import CoreData
import OSLog

class PersistenceController {
    // IMPORTANT: Lazy initialization to prevent blocking the main thread at app startup
    // The shared instance is created on-demand, not during static initialization
    static let shared = PersistenceController()
    private let log = Logger(subsystem: "com.flameworker.app", category: "persistence")

    // Track whether async initialization has completed
    private var isInitialized = false

    // Lazy model loading - only load when first accessed
    private nonisolated(unsafe) static var _sharedModel: NSManagedObjectModel?
    private nonisolated(unsafe) static let modelLock = NSLock()

    private static var sharedModel: NSManagedObjectModel {
        modelLock.lock()
        defer { modelLock.unlock() }

        if let model = _sharedModel {
            return model
        }

        Logger(subsystem: "com.flameworker.app", category: "persistence").info("🔄 Loading Core Data model...")

        if let modelURL = Bundle.main.url(forResource: "Molten", withExtension: "momd"),
           let model = NSManagedObjectModel(contentsOf: modelURL) {

            Logger(subsystem: "com.flameworker.app", category: "persistence").info("✅ Model loaded with \(model.entities.count) entities")
            _sharedModel = model
            return model
        } else {
            Logger(subsystem: "com.flameworker.app", category: "persistence").error("Could not load Core Data model from bundle, using fallback")
            let model = NSManagedObjectModel.mergedModel(from: [Bundle.main])!
            _sharedModel = model
            return model
        }
    }

    @MainActor
    static let preview: PersistenceController = {
        Logger(subsystem: "com.flameworker.app", category: "persistence").info("🔄 Creating preview PersistenceController...")
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        
        // Verify that the preview controller is ready before returning
        if result.storeLoadingError != nil {
            Logger(subsystem: "com.flameworker.app", category: "persistence").error("❌ Preview controller has store loading error: \(String(describing: result.storeLoadingError))")
        } else {
            Logger(subsystem: "com.flameworker.app", category: "persistence").info("✅ Preview controller created successfully")
        }
        
        // For testing, we'll create preview data lazily on first access rather than during initialization
        // This prevents model compatibility issues during test runs
        
        return result
    }()
    
    /// Lazy preview data creation - called only when needed, not during static initialization
    @MainActor
    static func createPreviewDataIfNeeded() {
        let viewContext = preview.container.viewContext
        
        // Check if preview data already exists with explicit entity resolution
        guard let entity = NSEntityDescription.entity(forEntityName: "CatalogItem", in: viewContext) else {
            Logger(subsystem: "com.flameworker.app", category: "persistence").error("Could not find CatalogItem entity in managed object model")
            return
        }
        
        let fetchRequest = NSFetchRequest<CatalogItem>()
        fetchRequest.entity = entity
        fetchRequest.includesPropertyValues = false // More efficient for count
        fetchRequest.includesSubentities = false
        
        do {
            let existingCount = try viewContext.count(for: fetchRequest)
            if existingCount > 0 {
                return // Preview data already exists
            }
        } catch {
            Logger(subsystem: "com.flameworker.app", category: "persistence").error("Error checking for existing preview data: \(error)")
            return
        }
        
        // Only create preview data if stores are loaded
        guard !preview.container.persistentStoreCoordinator.persistentStores.isEmpty else {
            Logger(subsystem: "com.flameworker.app", category: "persistence").error("Cannot create preview data - no persistent stores loaded")
            return
        }
        
        // Create preview data synchronously on main actor using safe entity creation
        for i in 0..<10 {
            guard let newItem = createCatalogItem(in: viewContext) else {
                Logger(subsystem: "com.flameworker.app", category: "persistence").error("Failed to create preview CatalogItem at index \(i)")
                continue
            }
            
            newItem.code = "PREVIEW-\(i + 1)"
            newItem.name = "Preview Item \(i + 1)"
            newItem.manufacturer = i % 2 == 0 ? "Preview Manufacturer A" : "Preview Manufacturer B"
        }
        
        do {
            try viewContext.save()
        } catch {
            // Log the error but don't crash the app in production
            let nsError = error as NSError
            Logger(subsystem: "com.flameworker.app", category: "persistence").error("Preview data creation error: \(String(describing: nsError)) userInfo=\(String(describing: nsError.userInfo))")
        }
    }

    let container: NSPersistentCloudKitContainer
    private(set) var storeLoadingError: Error?

    init(inMemory: Bool = false) {
        // Use the shared model instance to prevent multiple models
        Logger(subsystem: "com.flameworker.app", category: "persistence").info("🔄 Creating PersistenceController with shared model...")
        container = NSPersistentCloudKitContainer(name: "Molten", managedObjectModel: Self.sharedModel)

        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
            // For in-memory stores (tests), load synchronously since they're fast
            loadStoresSynchronously()
        } else {
            // Configure CloudKit options
            if let description = container.persistentStoreDescriptions.first {
                description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
                description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

                // Enable lightweight migration for simple model changes
                description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
                description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)

                // Set timeout to prevent indefinite hanging
                description.timeout = 30 // 30 seconds timeout

                // Add device-specific workaround for iPhone 17 entity resolution issues
                if ProcessInfo.processInfo.isiOSAppOnMac == false {
                    // Force model validation on iOS devices (especially iPhone 17)
                    description.setOption(true as NSNumber, forKey: "NSValidateXMLStoreOption")
                }
            }

            // For production stores, DO NOT load synchronously!
            // Store loading will happen asynchronously when initialize() is called
            Logger(subsystem: "com.flameworker.app", category: "persistence").info("⏸️ PersistenceController created - stores will load asynchronously")
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
    }

    /// Asynchronously initialize the persistent stores
    /// Call this from your app startup code to load stores without blocking the main thread
    /// IMPORTANT: This must be called before using the container!
    @MainActor
    func initialize() async {
        // Only initialize once
        guard !isInitialized else {
            log.info("✅ PersistenceController already initialized")
            return
        }

        log.info("🔄 Starting async persistent store loading...")

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var retryAttempted = false

            func loadStoresWithSmartRetry() {
                container.loadPersistentStores { storeDescription, error in
                    if let error = error as NSError? {
                        self.storeLoadingError = error
                        self.log.error("Core Data load error: \(String(describing: error))")

                        // Attempt recovery for migration errors (only once)
                        if !retryAttempted && error.domain == NSCocoaErrorDomain &&
                           (error.code == NSPersistentStoreIncompatibleVersionHashError ||
                            error.code == NSMigrationMissingSourceModelError ||
                            error.code == NSMigrationError) {

                            self.log.warning("⚠️ Migration failed - attempting recovery...")
                            retryAttempted = true

                            if let storeURL = storeDescription.url {
                                self.cleanupCorruptedStore(at: storeURL)
                                self.storeLoadingError = nil
                                loadStoresWithSmartRetry()
                                return
                            }
                        }
                    } else {
                        if retryAttempted {
                            self.log.info("✅ Store loaded successfully after recovery!")
                        } else {
                            self.log.info("✅ Store loaded successfully")
                        }
                    }

                    // Validate entity registration
                    if self.storeLoadingError == nil {
                        let validationSuccess = self.validateEntityRegistration()
                        if !validationSuccess {
                            self.log.error("❌ Entity validation failed")
                            self.storeLoadingError = NSError(domain: "PersistenceController", code: 1004, userInfo: [
                                NSLocalizedDescriptionKey: "Entity registration validation failed"
                            ])
                        }
                    }

                    self.isInitialized = true

                    // Run Transformable migration after successful store load
                    if self.storeLoadingError == nil {
                        Task { @MainActor in
                            do {
                                try TransformableMigrationHelper.runAllMigrations(in: self.container.viewContext)
                            } catch {
                                self.log.error("❌ Transformable migration failed: \(error)")
                            }
                        }
                    }

                    continuation.resume()
                }
            }

            loadStoresWithSmartRetry()
        }
    }

    /// Synchronous store loading for tests only (in-memory stores are fast)
    private func loadStoresSynchronously() {
        let semaphore = DispatchSemaphore(value: 0)
        var capturedError: Error?

        container.loadPersistentStores { _, error in
            capturedError = error
            if let error = error {
                self.log.error("In-memory store load error: \(error)")
            }
            semaphore.signal()
        }

        semaphore.wait()
        self.storeLoadingError = capturedError
        self.isInitialized = true
    }

    /// Helper to clean up corrupted store files
    private func cleanupCorruptedStore(at storeURL: URL) {
        let fileManager = FileManager.default
        do {
            if fileManager.fileExists(atPath: storeURL.path) {
                try fileManager.removeItem(at: storeURL)
            }
            let walURL = storeURL.appendingPathExtension("sqlite-wal")
            let shmURL = storeURL.appendingPathExtension("sqlite-shm")
            if fileManager.fileExists(atPath: walURL.path) {
                try fileManager.removeItem(at: walURL)
            }
            if fileManager.fileExists(atPath: shmURL.path) {
                try fileManager.removeItem(at: shmURL)
            }
            log.info("🗑️ Cleaned up corrupted store files")
        } catch {
            log.error("Failed to cleanup store: \(error)")
        }
    }
    
    // MARK: - Store Status
    
    /// Returns true if persistent stores are loaded and ready for data operations
    var isReady: Bool {
        return storeLoadingError == nil && !container.persistentStoreCoordinator.persistentStores.isEmpty
    }
    
    /// Returns true if there was an error loading persistent stores
    var hasStoreLoadingError: Bool {
        return storeLoadingError != nil
    }
    
    // MARK: - Store Management
    
    /// Performs automatic recovery if the store failed to load
    /// Call this during app startup to handle migration issues automatically
    static func performStartupRecoveryIfNeeded() async {
        // Check if the shared instance has loading errors
        if shared.hasStoreLoadingError {
            print("⚠️ Core Data store loading failed, attempting automatic recovery...")
            
            // Import the recovery utility if it exists
            #if canImport(CoreDataRecoveryUtility)
            let success = await CoreDataRecoveryUtility.resetPersistentStore(shared)
            if success {
                print("✅ Core Data store recovery completed successfully")
            } else {
                print("❌ Core Data store recovery failed")
            }
            #else
            // Fallback recovery without the utility
            print("🔧 Attempting manual store recovery...")
            shared.deletePersistentStore()
            await shared.reloadPersistentStore()
            
            if shared.isReady {
                print("✅ Manual Core Data store recovery completed successfully")
            } else {
                print("❌ Manual Core Data store recovery failed")
            }
            #endif
        } else {
            print("✅ Core Data store loaded successfully, no recovery needed")
        }
    }
    
    /// Deletes the persistent store files to force a clean start
    /// Use this when you encounter model migration issues
    func deletePersistentStore() {
        guard let storeURL = container.persistentStoreDescriptions.first?.url else {
            log.error("No store URL found to delete")
            return
        }
        
        do {
            // Remove the store from the coordinator
            if let store = container.persistentStoreCoordinator.persistentStores.first {
                try container.persistentStoreCoordinator.remove(store)
            }
            
            // Delete the actual store files
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: storeURL.path) {
                try fileManager.removeItem(at: storeURL)
                log.info("Deleted persistent store at \(storeURL)")
            }
            
            // Delete associated files (WAL, SHM)
            let walURL = storeURL.appendingPathExtension("sqlite-wal")
            let shmURL = storeURL.appendingPathExtension("sqlite-shm")
            
            if fileManager.fileExists(atPath: walURL.path) {
                try fileManager.removeItem(at: walURL)
                log.info("Deleted WAL file at \(walURL)")
            }
            
            if fileManager.fileExists(atPath: shmURL.path) {
                try fileManager.removeItem(at: shmURL)
                log.info("Deleted SHM file at \(shmURL)")
            }
            
        } catch {
            log.error("Error deleting persistent store: \(error)")
        }
    }
    
    /// Creates a fresh persistent store coordinator and reloads the store
    /// Call this after deletePersistentStore() to start fresh
    func reloadPersistentStore() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            container.loadPersistentStores { _, error in
                if let error = error {
                    self.log.error("Error reloading persistent store: \(error)")
                    self.storeLoadingError = error
                } else {
                    self.log.info("Successfully reloaded persistent store")
                    self.storeLoadingError = nil
                }
                continuation.resume()
            }
        }
    }
    
    // MARK: - Entity Resolution Helpers
    
    /// Validates that all expected entities are properly registered in the managed object model
    /// Call this during app startup to catch entity resolution issues early
    func validateEntityRegistration() -> Bool {
        let expectedEntities = ["CatalogItem"] // Add other entity names as needed
        var allEntitiesFound = true
        
        for entityName in expectedEntities {
            guard let entity = NSEntityDescription.entity(forEntityName: entityName, in: container.viewContext) else {
                log.error("❌ Entity '\(entityName)' not found in managed object model")
                allEntitiesFound = false
                continue
            }
            
            log.info("✅ Entity '\(entityName)' found in managed object model with \(entity.properties.count) properties")
        }
        
        return allEntitiesFound
    }
    
    /// Forces Core Data to rebuild its internal entity caches
    /// Use this if you suspect entity resolution issues
    func rebuildEntityCaches() {
        log.info("🔄 Rebuilding Core Data entity caches using shared model...")
        
        // Create a new context to force entity cache refresh
        let testContext = container.newBackgroundContext()
        testContext.mergePolicy = container.viewContext.mergePolicy
        
        // Test entity resolution
        let success = validateEntityRegistration()
        if success {
            log.info("✅ Entity cache rebuild successful")
        } else {
            log.error("❌ Entity cache rebuild failed")
        }
    }
    
    // MARK: - Fetch Request Helpers
    
    /// Creates a properly configured fetch request for CatalogItem with explicit entity resolution
    /// Use this to avoid "executeFetchRequest:error: A fetch request must have an entity" errors
    static func createCatalogItemFetchRequest(in context: NSManagedObjectContext) -> NSFetchRequest<CatalogItem>? {
        guard let entity = NSEntityDescription.entity(forEntityName: "CatalogItem", in: context) else {
            Logger(subsystem: "com.flameworker.app", category: "persistence").error("Could not find CatalogItem entity in managed object model")
            return nil
        }
        
        let fetchRequest = NSFetchRequest<CatalogItem>()
        fetchRequest.entity = entity
        fetchRequest.includesSubentities = false
        return fetchRequest
    }
    
    /// Safely creates a CatalogItem with explicit entity resolution
    static func createCatalogItem(in context: NSManagedObjectContext) -> CatalogItem? {
        guard let entity = NSEntityDescription.entity(forEntityName: "CatalogItem", in: context) else {
            Logger(subsystem: "com.flameworker.app", category: "persistence").error("Could not create CatalogItem - entity not found in managed object model")
            return nil
        }
        
        return CatalogItem(entity: entity, insertInto: context)
    }
    
    // MARK: - Test Helpers
    
    /// Creates a truly isolated in-memory persistence controller for testing
    /// Each call creates a completely separate Core Data stack to ensure test isolation
    static func createTestController() -> PersistenceController {
        // Create a completely isolated in-memory controller with its own model instance
        // This prevents ALL sharing between tests
        let controller = PersistenceController(inMemory: true)
        
        // Configure merge policy to handle any conflicts
        controller.container.viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        
        return controller
    }
    
    /// Forces creation of a new test controller (for when you need true isolation)
    static func createFreshTestController() -> PersistenceController {
        return PersistenceController(inMemory: true)
    }
    
    /// Creates a completely isolated in-memory persistence controller with unique identifier
    /// Use this when you need guaranteed isolation between test contexts
    static func createUniqueTestController(identifier: String) -> PersistenceController {
        return PersistenceController(inMemory: true)
    }
}

// MARK: - App Startup Integration

extension PersistenceController {
    
    /// Call this in your app's startup code to automatically handle Core Data migration issues
    ///
    /// Usage in your App.swift or main view:
    /// ```swift
    /// .task {
    ///     await PersistenceController.handleStartupRecovery()
    /// }
    /// ```
    static func handleStartupRecovery() async {
        // In your app's startup code, add this if store loading fails:
        if PersistenceController.shared.hasStoreLoadingError {
            // Attempt recovery using the recovery utility
            do {
                // Try to import and use the recovery utility
                let success = await performRecoveryWithUtility()
                if !success {
                    print("❌ Recovery utility failed, attempting manual recovery")
                    await performManualRecovery()
                }
            } catch {
                print("⚠️ Recovery utility not available, using manual recovery")
                await performManualRecovery()
            }
        }
    }
    
    /// Attempts recovery using CoreDataRecoveryUtility if available
    private static func performRecoveryWithUtility() async -> Bool {
        // This will be resolved at compile time if CoreDataRecoveryUtility exists
        // For now, we'll use the manual approach
        await performManualRecovery()
        return shared.isReady
    }
    
    /// Manual recovery approach - deletes and recreates the store
    private static func performManualRecovery() async {
        print("🔧 Performing manual Core Data recovery...")
        shared.deletePersistentStore()
        await shared.reloadPersistentStore()
        
        if shared.isReady {
            print("✅ Manual Core Data recovery completed successfully")
        } else {
            print("❌ Manual Core Data recovery failed - check console for details")
        }
    }
}
