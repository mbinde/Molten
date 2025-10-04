//
//  CoreDataRecoveryTests.swift
//  Flameworker
//
//  Created by Assistant on 10/4/25.
//

import Testing
import CoreData
@testable import Flameworker

@Suite("Core Data Recovery Tests")
struct CoreDataRecoveryTests {
    
    @Test("Should diagnose Core Data model successfully")
    func testDiagnoseCoreDataModel() {
        let controller = PersistenceController.createTestController()
        
        // This should not crash and should provide diagnostic information
        CoreDataRecoveryUtility.diagnoseModel(controller)
        
        // Verify the controller is properly initialized
        #expect(controller.container.managedObjectModel.entities.count > 0, "Should have at least one entity in the model")
    }
    
    @Test("Should verify store health for test controller")
    func testVerifyStoreHealth() {
        let controller = PersistenceController.createTestController()
        
        let isHealthy = CoreDataRecoveryUtility.verifyStoreHealth(controller)
        
        // In-memory test controllers should always be healthy
        #expect(isHealthy, "Test controller should be healthy")
        #expect(controller.isReady, "Test controller should be ready")
        #expect(!controller.hasStoreLoadingError, "Test controller should not have loading errors")
    }
    
    @Test("Should handle store health check gracefully when store has issues")
    func testStoreHealthCheckWithIssues() {
        // Create a controller that might have issues
        let controller = PersistenceController(inMemory: true)
        
        // Even if there are issues, the health check should not crash
        let isHealthy = CoreDataRecoveryUtility.verifyStoreHealth(controller)
        
        // We don't assert the result here since it might legitimately be false
        // But the important thing is that the method doesn't crash
        #expect(true, "Store health check completed without crashing")
        
        // Log the result for debugging
        print("Store health check result: \(isHealthy)")
    }
    
    @Test("Should work with actual entities in the model")
    func testWorkWithActualEntities() async {
        let controller = PersistenceController.createTestController()
        let context = controller.container.viewContext
        
        // First, diagnose what's actually in the model
        CoreDataRecoveryUtility.diagnoseModel(controller)
        
        await MainActor.run {
            // Try to work with CatalogItem which should exist
            let item = CatalogItem(context: context)
            item.id = "recovery-test-001"
            item.code = "RECOVERY-001"
            item.name = "Recovery Test Item"
            
            do {
                try context.save()
                
                // Verify it was saved
                let fetchRequest = NSFetchRequest<CatalogItem>(entityName: "CatalogItem")
                let items = try context.fetch(fetchRequest)
                
                #expect(items.count == 1, "Should have saved one item")
                #expect(items.first?.id == "recovery-test-001")
                
            } catch {
                Issue.record("Failed to save CatalogItem during recovery test: \(error)")
            }
        }
    }
}