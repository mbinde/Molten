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
        // This test reproduces the "model configuration incompatible" error
        // Error: "The model configuration used to open the store is incompatible with the one that was used to create the store."
        
        // The issue is likely that PersistenceController.preview creates entities during initialization
        // which can cause model configuration conflicts in tests
        
        let context = PersistenceController.preview.container.viewContext
        
        // Wait a moment for any background preview data creation to complete
        try await Task.sleep(for: .milliseconds(100))
        
        // Try to create a PurchaseRecord - this should not fail with model incompatibility
        await MainActor.run {
            let newRecord = PurchaseRecord(context: context)
            newRecord.setString("Test Supplier", forKey: "supplier")
            newRecord.setDouble(100.0, forKey: "price")
            
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
            let newRecord = PurchaseRecord(context: context)
            newRecord.setString("Test Supplier", forKey: "supplier")
            newRecord.setDouble(50.0, forKey: "price")
            newRecord.setValue(Int16(1), forKey: "type")
            newRecord.setValue(Int16(2), forKey: "units")
            
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
        
        // Now create and save a PurchaseRecord - should work without issues
        let newRecord = PurchaseRecord(context: testContext)
        newRecord.setString("Clean Test Supplier", forKey: "supplier")
        newRecord.setDouble(75.0, forKey: "price")
        
        try testContext.save()
        
        // Verify it saved correctly
        #expect(newRecord.value(forKey: "supplier") as? String == "Clean Test Supplier")
        #expect(newRecord.value(forKey: "price") as? Double == 75.0)
    }
}