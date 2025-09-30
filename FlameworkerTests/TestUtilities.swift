//
//  TestUtilities.swift
//  FlameworkerTests
//
//  Created by Melissa Binde on 9/29/25.
//  Copyright © 2025 Motley Woods. All rights reserved.
//

import CoreData
import Foundation
@testable import Flameworker

/// Shared test utilities for Core Data testing across all test suites
struct TestUtilities {
    
    /// Dummy class to help with bundle identification
    private class BundleHelper {}
    
    /// Creates a completely isolated and unique Core Data context for testing
    /// Uses NSPersistentContainer instead of CloudKit to avoid configuration conflicts
    /// Each context gets a unique identifier to prevent cross-test contamination
    static func createIsolatedContext(for testSuite: String = "TestSuite") -> NSManagedObjectContext {
        // Use NSPersistentContainer instead of NSPersistentCloudKitContainer for testing
        // This avoids CloudKit-specific configuration issues
        let container = NSPersistentContainer(name: "Flameworker")
        
        // Create unique in-memory store for each test with a unique identifier
        let uniqueId = UUID().uuidString
        let timestamp = Date().timeIntervalSince1970
        
        let storeDescription = NSPersistentStoreDescription()
        storeDescription.type = NSInMemoryStoreType
        // Use a unique identifier that includes test suite name, timestamp, and UUID
        storeDescription.url = URL(string: "memory://\(testSuite)-\(timestamp)-\(uniqueId)")
        storeDescription.shouldAddStoreAsynchronously = false
        
        // Ensure the store is completely isolated
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        container.persistentStoreDescriptions = [storeDescription]
        
        // Load stores synchronously
        let expectation = DispatchSemaphore(value: 0)
        var loadError: Error?
        
        container.loadPersistentStores { _, error in
            loadError = error
            expectation.signal()
        }
        
        expectation.wait()
        
        if let error = loadError {
            print("Test store load error for \(testSuite): \(error)")
            fatalError("Failed to create test context for \(testSuite): \(error)")
        }
        
        let context = container.viewContext
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        
        // Store the container reference and metadata to prevent deallocation
        context.userInfo["testContainer"] = container
        context.userInfo["testSuite"] = testSuite
        context.userInfo["testId"] = uniqueId
        context.userInfo["timestamp"] = timestamp
        
        return context
    }
    
    /// Safely tears down a test context to prevent memory leaks
    static func tearDownContext(_ context: NSManagedObjectContext) {
        // Reset the context
        context.reset()
        
        // Remove the container reference from userInfo
        if let container = context.userInfo["testContainer"] as? NSPersistentContainer {
            // Unload persistent stores
            for store in container.persistentStoreCoordinator.persistentStores {
                try? container.persistentStoreCoordinator.remove(store)
            }
        }
        
        // Clear userInfo
        context.userInfo.removeAllObjects()
    }
    
    /// Creates a test-specific PersistenceController for testing
    static func createTestPersistenceController() -> PersistenceController {
        return PersistenceController(inMemory: true)
    }
    
    /// Creates empty JSON data for testing
    static func createEmptyJSONData() -> Data {
        return "[]".data(using: .utf8)!
    }
    
    /// Creates sample catalog JSON data for testing
    static func createSampleCatalogJSONData() -> Data {
        let json = """
        [
            {
                "code": "TEST-001",
                "name": "Test Glass Rod",
                "manufacturer": "Test Manufacturer"
            },
            {
                "code": "TEST-002", 
                "name": "Test Glass Frit",
                "manufacturer": "Another Manufacturer"
            }
        ]
        """
        return json.data(using: .utf8)!
    }
    
    /// Alternative context creation method with even more aggressive isolation
    /// Use this if the standard method still causes conflicts
    static func createHyperIsolatedContext(for testSuite: String = "TestSuite") -> NSManagedObjectContext {
        let contextId = "\(testSuite)-\(UUID().uuidString)-\(Date().timeIntervalSince1970)"
        print("Creating hyper-isolated context: \(contextId)")
        
        // Create a completely separate coordinator for each test
        guard let modelURL = Bundle.main.url(forResource: "Flameworker", withExtension: "momd") ??
                Bundle(for: BundleHelper.self).url(forResource: "Flameworker", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Could not load Core Data model for testing")
        }
        
        // Create separate coordinator instance
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        
        // Add in-memory store with unique identifier
        do {
            try coordinator.addPersistentStore(
                ofType: NSInMemoryStoreType,
                configurationName: nil,
                at: nil,
                options: [
                    "TestContextId": contextId,
                    NSPersistentHistoryTrackingKey: false,
                    NSPersistentStoreRemoteChangeNotificationPostOptionKey: false
                ]
            )
        } catch {
            fatalError("Failed to add persistent store for \(contextId): \(error)")
        }
        
        // Create context with the isolated coordinator
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Store metadata
        context.userInfo["testSuite"] = testSuite
        context.userInfo["contextId"] = contextId
        context.userInfo["coordinator"] = coordinator
        
        print("Successfully created hyper-isolated context: \(contextId)")
        return context
    }
    
    /// Tears down hyper-isolated context
    static func tearDownHyperIsolatedContext(_ context: NSManagedObjectContext) {
        let contextId = context.userInfo["contextId"] as? String ?? "unknown"
        print("Tearing down hyper-isolated context: \(contextId)")
        
        context.reset()
        
        if let coordinator = context.userInfo["coordinator"] as? NSPersistentStoreCoordinator {
            for store in coordinator.persistentStores {
                try? coordinator.remove(store)
            }
        }
        
        context.userInfo.removeAllObjects()
        context.persistentStoreCoordinator = nil
        
        print("Hyper-isolated context teardown complete: \(contextId)")
    }
}