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
        
        // Create preview data on background queue to avoid blocking main thread
        Task.detached {
            await MainActor.run {
                for i in 0..<10 {
                    let newItem = CatalogItem(context: viewContext)
                    newItem.code = "PREVIEW-\(i + 1)"
                    newItem.name = "Preview Item \(i + 1)"
                    newItem.manufacturer = i % 2 == 0 ? "Preview Manufacturer A" : "Preview Manufacturer B"
          //          newItem.price = Double.random(in: 10...100)
                }
                do {
                    try viewContext.save()
                } catch {
                    // Log the error but don't crash the app in production
                    let nsError = error as NSError
                    Logger.persistence.error("Preview data creation error: \(String(describing: nsError)) userInfo=\(String(describing: nsError.userInfo))")
                }
            }
        }
        return result
    }()

    let container: NSPersistentCloudKitContainer

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
        var loadError: Error?
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            loadError = error
            if let error = error as NSError? {
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
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        // Prefer store changes when conflicts occur to avoid save failures in merges
        container.viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
    }
}
