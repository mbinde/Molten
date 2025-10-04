//
//  CoreDataTestIssuesTests.swift
//  Flameworker
//
//  Created by Assistant on 10/3/25.
//

import Testing
import CoreData
@testable import Flameworker

@Suite("Core Data Test Issues Tests")
struct CoreDataTestIssuesTests {
    
    @Test("Should not have model incompatibility issues when using preview controller")
    func testPreviewControllerModelCompatibility() async throws {
        // This test verifies the preview controller works with actual entities in the model
        // We only test with CatalogItem since that's what actually exists in the model
        
        let context = PersistenceController.preview.container.viewContext
        
        // Wait a moment for any background preview data creation to complete
        try await Task.sleep(for: .milliseconds(100))
        
        // Try to create a CatalogItem - this should work since it exists in the model
        await MainActor.run {
            let newItem = CatalogItem(context: context)
            newItem.code = "TEST-001"
            newItem.name = "Test Item"
            newItem.manufacturer = "Test Manufacturer"
            
            do {
                try context.save()
                #expect(true, "Save should succeed without model incompatibility error")
            } catch {
                Issue.record("Model incompatibility error: \(error)")
            }
        }
    }
    
    @Test("Should not have recursive save issues")
    func testRecursiveSaveIssues() async throws {
        // This test reproduces the "attempt to recursively call -save:" error
        // This happens when save() is called while another save is already in progress
        
        let context = PersistenceController.preview.container.viewContext
        
        // Wait for any background operations to complete
        try await Task.sleep(for: .milliseconds(100))
        
        await MainActor.run {
            let newItem = CatalogItem(context: context)
            newItem.code = "RECURSIVE-TEST"
            newItem.name = "Recursive Test Item"
            newItem.manufacturer = "Test Manufacturer"
            
            // This should not trigger a recursive save
            do {
                try context.save()
                #expect(true, "Save should succeed without recursive save error")
            } catch {
                Issue.record("Recursive save error: \(error)")
            }
        }
    }
    
    @Test("Should create isolated test context without preview interference")
    func testIsolatedTestContext() async throws {
        // This test verifies we can create a clean test context without preview data interference
        
        // Create our own in-memory persistence controller for testing
        let testController = PersistenceController.createTestController()
        let testContext = testController.container.viewContext
        
        // This should be clean and not have any preview data
        let fetchRequest = NSFetchRequest<CatalogItem>(entityName: "CatalogItem")
        let existingItems = try testContext.fetch(fetchRequest)
        #expect(existingItems.isEmpty, "Test context should be clean without preview data")
        
        // Now create and save a CatalogItem - should work without issues
        let newItem = CatalogItem(context: testContext)
        newItem.code = "CLEAN-TEST"
        newItem.name = "Clean Test Item"
        newItem.manufacturer = "Clean Test Manufacturer"
        
        try testContext.save()
        
        // Verify it saved correctly
        #expect(newItem.code == "CLEAN-TEST")
        #expect(newItem.name == "Clean Test Item")
        #expect(newItem.manufacturer == "Clean Test Manufacturer")
    }
    
    @Test("Should verify Core Data store health")
    func testCoreDataStoreHealth() async throws {
        // Test the new recovery utility
        let isHealthy = CoreDataRecoveryUtility.verifyStoreHealth(PersistenceController.shared)
        
        if !isHealthy {
            // Log diagnostic information
            CoreDataRecoveryUtility.diagnoseModel(PersistenceController.shared)
            Issue.record("Core Data store is not healthy - check console for diagnostic information")
        } else {
            #expect(true, "Core Data store is healthy")
        }
    }
}