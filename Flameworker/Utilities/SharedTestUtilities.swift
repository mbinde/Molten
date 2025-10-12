//
//  SharedTestUtilities.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/11/25.
//

import Foundation
import CoreData
@testable import Flameworker

#if canImport(Testing)
import Testing
#endif

/// Shared test utilities to prevent Core Data stack exhaustion across all test files
class SharedTestUtilities {
    
    // Track total controllers created to prevent unlimited creation
    private static var totalControllersCreated = 0
    private static let maxTotalControllers = 20
    private static let poolLock = NSLock()
    
    /// Get a completely fresh test controller for each test - NO POOLING
    /// This eliminates all sharing and recursive save issues
    static func getCleanTestController() throws -> (controller: PersistenceController, context: NSManagedObjectContext) {
        poolLock.lock()
        defer { poolLock.unlock() }
        
        print("🔧 Creating FRESH test controller (no pooling)...")
        print("📊 Total controllers created so far: \(totalControllersCreated)/\(maxTotalControllers)")
        
        // Safety limit to prevent unlimited creation
        guard totalControllersCreated < maxTotalControllers else {
            print("  ❌ CRITICAL: Too many test controllers created (\(totalControllersCreated))")
            struct TooManyControllersError: Error {
                let message = "Too many test controllers created. Consider running fewer tests at once."
            }
            throw TooManyControllersError()
        }
        
        // Create a completely fresh controller for this test
        let newController = PersistenceController.createTestController()
        let context = newController.container.viewContext
        
        totalControllersCreated += 1
        print("  ✅ Created fresh controller \(totalControllersCreated): \(ObjectIdentifier(newController))")
        
        return (newController, context)
    }
    
    /// Reset the controller count (for use between test suites)
    static func resetControllerCount() {
        poolLock.lock()
        defer { poolLock.unlock() }
        
        print("🔄 Resetting controller count...")
        totalControllersCreated = 0
        print("✅ Controller count reset complete")
    }
    
    /// Get statistics for debugging
    static func getStats() -> String {
        poolLock.lock()
        defer { poolLock.unlock() }
        
        return "Controllers created: \(totalControllersCreated)/\(maxTotalControllers)"
    }
}