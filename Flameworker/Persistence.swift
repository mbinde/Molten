//
//  Persistence.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/27/25.
//

import CoreData
import OSLog

struct PersistenceController {
    static let shared = PersistenceController()
    private let log = Logger.persistence

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        
        // For testing, we'll create preview data lazily on first access rather than during initialization
        // This prevents model compatibility issues during test runs
        
        return result
    }()
    
    /// Lazy preview data creation - called only when needed, not during static initialization
    @MainActor
    static func createPreviewDataIfNeeded() {
        let viewContext = preview.container.viewContext
        
        // Check if preview data already exists
        let fetchRequest = NSFetchRequest<CatalogItem>(entityName: "CatalogItem")
        do {
            let existingCount = try viewContext.count(for: fetchRequest)
            if existingCount > 0 {
                return // Preview data already exists
            }
        } catch {
            Logger.persistence.error("Error checking for existing preview data: \(error)")
            return
        }
        
        // Only create preview data if stores are loaded
        guard !preview.container.persistentStoreCoordinator.persistentStores.isEmpty else {
            Logger.persistence.error("Cannot create preview data - no persistent stores loaded")
            return
        }
        
        // Create preview data synchronously on main actor
        for i in 0..<10 {
            let newItem = CatalogItem(context: viewContext)
            newItem.code = "PREVIEW-\(i + 1)"
            newItem.name = "Preview Item \(i + 1)"
            newItem.manufacturer = i % 2 == 0 ? "Preview Manufacturer A" : "Preview Manufacturer B"
        }
        
        do {
            try viewContext.save()
        } catch {
            // Log the error but don't crash the app in production
            let nsError = error as NSError
            Logger.persistence.error("Preview data creation error: \(String(describing: nsError)) userInfo=\(String(describing: nsError.userInfo))")
        }
    }

    let container: NSPersistentCloudKitContainer
    private(set) var storeLoadingError: Error?

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "Flameworker")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Configure CloudKit options to prevent hanging
            if let description = container.persistentStoreDescriptions.first {
                description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
                description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
                
                // Set timeout to prevent indefinite hanging
                description.timeout = 30 // 30 seconds timeout
            }
        }
        
        // Use a semaphore to ensure we don't hang indefinitely
        let semaphore = DispatchSemaphore(value: 0)
        
        // Use a variable to capture store loading error
        var capturedError: Error?
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Capture the store loading error
                capturedError = error
                
                // Log the error but don't crash the app in production
                Logger.persistence.error("Core Data load error: \(String(describing: error)) userInfo=\(String(describing: error.userInfo))")
                
                // In a production app, you might want to:
                // 1. Show an alert to the user
                // 2. Attempt to recover
                // 3. Report to crash analytics
                // 4. Fall back to a different data source
            }
            semaphore.signal()
        })
        
        // Wait with timeout to prevent indefinite hanging
        let timeout = DispatchTime.now() + .seconds(45)
        if semaphore.wait(timeout: timeout) == .timedOut {
            Logger.persistence.error("Core Data store loading timed out after 45 seconds")
            capturedError = NSError(domain: "PersistenceController", code: 1003, userInfo: [
                NSLocalizedDescriptionKey: "Core Data store loading timed out"
            ])
        }
        
        // Store the error for later reference
        self.storeLoadingError = capturedError
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        // Prefer store changes when conflicts occur to avoid save failures in merges
        container.viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
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
    
    // MARK: - Test Helpers
    
    /// Creates an isolated in-memory persistence controller for testing
    /// This avoids conflicts with shared preview data and prevents model incompatibility issues
    static func createTestController() -> PersistenceController {
        return PersistenceController(inMemory: true)
    }
}
