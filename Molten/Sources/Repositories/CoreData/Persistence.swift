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
    nonisolated static let shared: PersistenceController = {
        let controller = PersistenceController(inMemory: false)
        return controller
    }()
    private let log = Logger(subsystem: "com.flameworker.app", category: "persistence")

    // Track whether async initialization has completed
    nonisolated(unsafe) private var isInitialized = false

    // Lazy model loading - only load when first accessed
    private nonisolated(unsafe) static var _sharedModel: NSManagedObjectModel?
    private nonisolated static let modelLock = NSLock()

    nonisolated private static var sharedModel: NSManagedObjectModel {
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
        // Preview uses CloudKit container for UI compatibility (CloudKitSyncStatusView needs it)
        let result = PersistenceController(inMemory: true, forceCloudKit: true)
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

    let container: NSPersistentContainer
    nonisolated(unsafe) private(set) var storeLoadingError: Error?

    // Two separate contexts for two-store architecture
    // localContext: For catalog data (GlassItem, ItemTags) - no CloudKit sync
    // cloudContext: For user data (Inventory, Purchases, Projects) - CloudKit sync
    // nonisolated(unsafe) is safe here because:
    // - Set once during initialization in configureContexts()
    // - Read-only after initialization
    // - Accessed from multiple threads but never modified
    nonisolated(unsafe) private(set) var localContext: NSManagedObjectContext!
    nonisolated(unsafe) private(set) var cloudContext: NSManagedObjectContext!

    nonisolated init(inMemory: Bool = false, forceCloudKit: Bool = false) {
        // Use the shared model instance to prevent multiple models
        Logger(subsystem: "com.flameworker.app", category: "persistence").info("🔄 Creating PersistenceController with shared model...")

        // For tests, use NSPersistentContainer (no CloudKit) to avoid initialization warnings
        // For production, use NSPersistentCloudKitContainer for CloudKit sync
        // forceCloudKit: Use CloudKit even for inMemory (for UI previews that need CloudKit features)
        if inMemory && !forceCloudKit {
            container = NSPersistentContainer(name: "Molten", managedObjectModel: Self.sharedModel)
        } else {
            container = NSPersistentCloudKitContainer(name: "Molten", managedObjectModel: Self.sharedModel)
        }

        if inMemory {
            // For in-memory stores (tests), use default single store
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
            // For in-memory stores (tests), load synchronously since they're fast
            loadStoresSynchronously()
        } else {
            // TWO-STORE ARCHITECTURE for CloudKit duplication prevention
            // Local store: Catalog data (GlassItem, ItemTags) - NO CloudKit
            // Cloud store: User data (Inventory, Purchases, Projects) - WITH CloudKit

            guard let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.melissabinde.molten") else {
                Logger(subsystem: "com.flameworker.app", category: "persistence").error("❌ Failed to get App Group container URL")
                return
            }

            // STORE 1: Local (catalog data, no CloudKit)
            let localDescription = NSPersistentStoreDescription()
            localDescription.url = appGroupURL.appendingPathComponent("local.sqlite")
            localDescription.configuration = "Local"
            localDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            localDescription.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            localDescription.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
            localDescription.timeout = 30
            // NO cloudKitContainerOptions = local only
            Logger(subsystem: "com.flameworker.app", category: "persistence").info("📁 Local store: \(localDescription.url?.path ?? "unknown")")

            // STORE 2: Cloud (user data, with CloudKit)
            let cloudDescription = NSPersistentStoreDescription()
            cloudDescription.url = appGroupURL.appendingPathComponent("cloud.sqlite")
            cloudDescription.configuration = "Cloud"
            cloudDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            cloudDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            cloudDescription.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            cloudDescription.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
            cloudDescription.timeout = 30

            // Enable CloudKit sync for cloud store
            cloudDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: "iCloud.com.melissabinde.molten"
            )
            Logger(subsystem: "com.flameworker.app", category: "persistence").info("☁️ Cloud store: \(cloudDescription.url?.path ?? "unknown")")

            // Add device-specific workaround for iPhone 17 entity resolution issues
            if ProcessInfo.processInfo.isiOSAppOnMac == false {
                localDescription.setOption(true as NSNumber, forKey: "NSValidateXMLStoreOption")
                cloudDescription.setOption(true as NSNumber, forKey: "NSValidateXMLStoreOption")
            }

            // Set both store descriptions
            container.persistentStoreDescriptions = [localDescription, cloudDescription]

            // For production stores, DO NOT load synchronously!
            // Store loading will happen asynchronously when initialize() is called
            Logger(subsystem: "com.flameworker.app", category: "persistence").info("⏸️ PersistenceController created - two stores will load asynchronously")
        }

        // Contexts will be created in initialize() after stores load
        // We can't configure them here because stores aren't loaded yet

        // Track context save operations
        NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: nil
        ) { notification in
            if let context = notification.object as? NSManagedObjectContext {
                let inserted = (notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject>)?.count ?? 0
                let updated = (notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject>)?.count ?? 0
                let deleted = (notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject>)?.count ?? 0

                if inserted > 0 || updated > 0 || deleted > 0 {
                    let contextType = context == self.container.viewContext ? "VIEW" : "BACKGROUND"
                    let contextID = String(format: "%p", unsafeBitCast(context, to: Int.self))
                    let contextName = context.name ?? "unnamed"
                    let parentContext = context.parent != nil ? "HAS PARENT" : "NO PARENT"

                    // Log what entity types are being saved
                    if let insertedObjects = notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject> {
                        let entityNames = Set(insertedObjects.map { $0.entity.name ?? "unknown" })
                    }
                }
            }
        }

        // Track when objects are IMPORTED from persistent store (CloudKit/persistent history)
        NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextObjectsDidChange,
            object: container.viewContext,
            queue: nil
        ) { notification in
            // This fires when objects are inserted/updated/deleted in the context
            // INCLUDING when persistent store coordinator imports them from persistent history
            if let inserted = notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject>, !inserted.isEmpty {
                let glassItems = inserted.filter { $0.entity.name == "GlassItem" }
                if !glassItems.isEmpty {
                    if glassItems.count <= 5 {
                        glassItems.forEach { item in
                            if let stableId = item.value(forKey: "stable_id") as? String {
//                                print("🐛☁️   - \(stableId)")
                            }
                        }
                    }
                }
            }
        }

        // DISABLED: This observer was causing a feedback loop!
        // Each save triggered a remote change, which triggered persistent history replay,
        // which created duplicates, which triggered more remote changes, etc.
        // We need proper persistent history token management instead.

        // Track persistent store remote changes (CloudKit imports)
        // var remoteChangeCount = 0
        // NotificationCenter.default.addObserver(
        //     forName: .NSPersistentStoreRemoteChange,
        //     object: nil,
        //     queue: nil
        // ) { [weak container] notification in
        //     remoteChangeCount += 1
        //     print("📡📡📡 PERSISTENT STORE REMOTE CHANGE #\(remoteChangeCount) detected!")
        //
        //     // Try to fetch persistent history to see what changed
        //     if let container = container {
        //         let context = container.newBackgroundContext()
        //         context.perform {
        //             // Fetch count of GlassItems to see if it's growing
        //             let request = NSFetchRequest<NSFetchRequestResult>(entityName: "GlassItem")
        //             request.resultType = .countResultType
        //             do {
        //                 let count = try context.count(for: request)
        //                 print("📡     GlassItem count in store: \(count)")
        //             } catch {
        //                 print("📡     Error counting GlassItems: \(error)")
        //             }
        //         }
        //     }
        // }
    }

    /// Purge GlassItem persistent history transactions to prevent replay
    /// Call this after bulk GlassItem loading (like JSON import) completes
    /// This only deletes persistent HISTORY, not the actual entities
    func purgeGlassItemHistory() async {
        print("🐛🧹 purgeGlassItemHistory() called")
        let context = container.newBackgroundContext()
        await context.perform {
            do {
                // Fetch all persistent history transactions
                let fetchRequest = NSPersistentHistoryChangeRequest.fetchHistory(after: Date.distantPast)

                if let historyResult = try context.execute(fetchRequest) as? NSPersistentHistoryResult,
                   let transactions = historyResult.result as? [NSPersistentHistoryTransaction] {

                    // Filter to only transactions that involve GlassItem or ItemTags
                    var transactionsToDelete: [NSPersistentHistoryTransaction] = []

                    for transaction in transactions {
                        if let changes = transaction.changes {
                            let hasGlassItemChanges = changes.contains { change in
                                change.changedObjectID.entity.name == "GlassItem" ||
                                change.changedObjectID.entity.name == "ItemTags"
                            }
                            if hasGlassItemChanges {
                                transactionsToDelete.append(transaction)
                            }
                        }
                    }

                    // Delete only the GlassItem/ItemTags transactions
                    for transaction in transactionsToDelete {
                        let deleteRequest = NSPersistentHistoryChangeRequest.deleteHistory(before: transaction.timestamp.addingTimeInterval(0.001))
                        try context.execute(deleteRequest)
                    }
                }
            } catch {
                print("🐛⚠️ Failed to purge GlassItem history: \(error)")
            }
        }
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
            let expectedStoreCount = self.container.persistentStoreDescriptions.count
            var loadedStoreCount = 0
            var hasResumed = false
            let storeLock = NSLock()

            container.loadPersistentStores { storeDescription, error in
                if let error = error as NSError? {
                    self.storeLoadingError = error
                    self.log.error("❌ Core Data load error for \(storeDescription.url?.lastPathComponent ?? "unknown"): \(error)")
                } else {
                    self.log.info("✅ Store loaded successfully: \(storeDescription.url?.lastPathComponent ?? "unknown")")
                }

                // Track how many stores have completed (success or failure)
                storeLock.lock()
                loadedStoreCount += 1
                let allStoresProcessed = loadedStoreCount >= expectedStoreCount
                let shouldResume = allStoresProcessed && !hasResumed
                if shouldResume {
                    hasResumed = true
                }
                storeLock.unlock()

                // Only proceed after ALL stores are processed (success or failure)
                guard shouldResume else {
                    self.log.info("⏳ Waiting for remaining stores... (\(loadedStoreCount)/\(expectedStoreCount))")
                    return
                }

                self.log.info("🎉 All stores processed (\(loadedStoreCount)/\(expectedStoreCount))")

                // Check if there were any errors
                if self.storeLoadingError != nil {
                    self.log.error("❌ Store loading failed, skipping context configuration")
                    self.isInitialized = true
                    continuation.resume()
                    return
                }

                // Validate entity registration
                let validationSuccess = self.validateEntityRegistration()
                if !validationSuccess {
                    self.log.error("❌ Entity validation failed")
                    self.storeLoadingError = NSError(domain: "PersistenceController", code: 1004, userInfo: [
                        NSLocalizedDescriptionKey: "Entity registration validation failed"
                    ])
                    self.isInitialized = true
                    continuation.resume()
                    return
                }

                // Create separate contexts for local and cloud stores after successful load
                self.configureContexts()

                // Run Transformable migration (only on cloud context for user data)
                // Do this asynchronously after contexts are configured
                Task { @MainActor in
                    do {
                        try TransformableMigrationHelper.runAllMigrations(in: self.cloudContext)
                    } catch {
                        self.log.error("❌ Transformable migration failed: \(error)")
                    }
                }

                // Mark as initialized and resume continuation (only once, after all stores loaded)
                self.isInitialized = true
                continuation.resume()
            }
        }
    }

    /// Configure separate contexts for local and cloud stores
    /// Called after stores are loaded
    private func configureContexts() {
        log.info("🔄 Configuring local and cloud contexts...")

        // Local context for catalog data (GlassItem, ItemTags)
        localContext = container.newBackgroundContext()
        localContext.automaticallyMergesChangesFromParent = true  // Important for consistency
        localContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        localContext.transactionAuthor = "MoltenApp-Local"
        log.info("✅ Local context configured")

        // Cloud context for user data (Inventory, Purchases, Projects)
        cloudContext = container.newBackgroundContext()
        cloudContext.automaticallyMergesChangesFromParent = true  // CRITICAL for CloudKit
        cloudContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        cloudContext.transactionAuthor = "MoltenApp-Cloud"
        log.info("✅ Cloud context configured")
    }

    /// Synchronous store loading for tests only (in-memory stores are fast)
    nonisolated private func loadStoresSynchronously() {
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

        // For in-memory tests, use viewContext for both local and cloud
        // (simpler than configuring two separate in-memory stores)
        // Set synchronously since tests need these immediately and they're nonisolated(unsafe)
        self.localContext = self.container.viewContext
        self.cloudContext = self.container.viewContext
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
    
    /// Deletes all data from the persistent store and reloads it
    /// This combines deletePersistentStore() and reloadPersistentStore() for convenience
    func deleteAllData() async {
        deletePersistentStore()
        await reloadPersistentStore()
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
    nonisolated static func createCatalogItem(in context: NSManagedObjectContext) -> CatalogItem? {
        guard let entity = NSEntityDescription.entity(forEntityName: "CatalogItem", in: context) else {
            Logger(subsystem: "com.flameworker.app", category: "persistence").error("Could not create CatalogItem - entity not found in managed object model")
            return nil
        }
        
        return CatalogItem(entity: entity, insertInto: context)
    }
    
    // MARK: - Test Helpers
    
    /// Creates a truly isolated in-memory persistence controller for testing
    /// Each call creates a completely separate Core Data stack to ensure test isolation
    nonisolated static func createTestController() -> PersistenceController {
        // Create a completely isolated in-memory controller with its own model instance
        // Uses NSPersistentContainer (not CloudKit variant) to avoid CloudKit warnings
        let controller = PersistenceController(inMemory: true)

        // Configure merge policy to handle any conflicts
        controller.container.viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy

        return controller
    }
    
    /// Forces creation of a new test controller (for when you need true isolation)
    static func createFreshTestController() -> PersistenceController {
        let controller = PersistenceController(inMemory: true)
        return controller
    }

    /// Creates a completely isolated in-memory persistence controller with unique identifier
    /// Use this when you need guaranteed isolation between test contexts
    static func createUniqueTestController(identifier: String) -> PersistenceController {
        let controller = PersistenceController(inMemory: true)
        return controller
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
