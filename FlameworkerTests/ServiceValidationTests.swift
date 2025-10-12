//
//  ServiceValidationTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/11/25.
//

import Foundation
import CoreData

@testable import Flameworker

// Standard test framework imports pattern - use in all test files
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

#if canImport(Testing)

@Suite("Service Validation Tests", .serialized) 
struct ServiceValidationTests {
    
    // Use completely isolated test context for reliability
    private func createCompletelyIsolatedTestContext() throws -> (controller: PersistenceController, context: NSManagedObjectContext) {
        let testController = PersistenceController.createTestController()
        let context = testController.container.viewContext
        
        // Verify context is completely clean
        let fetchRequest = NSFetchRequest<CatalogItem>(entityName: "CatalogItem")
        let existingCount = try context.count(for: fetchRequest)
        
        if existingCount != 0 {
            print("⚠️ Test context not clean, found \(existingCount) existing items - cleaning up")
            let existingItems = try context.fetch(fetchRequest)
            for item in existingItems {
                context.delete(item)
            }
            try context.save()
        }
        
        return (testController, context)
    }
    
    // Helper to create test entity safely using KVC (matches ServiceValidation approach)
    private func createTestEntity(in context: NSManagedObjectContext, name: String? = nil, code: String? = nil, manufacturer: String? = nil) -> NSManagedObject {
        let service = BaseCoreDataService<CatalogItem>(entityName: "CatalogItem")
        let entity = service.create(in: context)
        
        // Use setValue to match how ServiceValidation accesses these fields
        if let name = name {
            entity.setValue(name, forKey: "name")
        }
        if let code = code {
            entity.setValue(code, forKey: "code") 
        }
        if let manufacturer = manufacturer {
            entity.setValue(manufacturer, forKey: "manufacturer")
        }
        
        return entity
    }
    
    @Test("Should validate required fields before save")
    func testPreSaveValidationRequiredFields() throws {
        // Arrange - Use completely isolated context
        let (testController, context) = try createCompletelyIsolatedTestContext()
        
        // Create entity with missing required field using consistent KVC approach
        let item = createTestEntity(in: context, name: "Test Item", code: "TEST-001")
        // Intentionally leaving manufacturer as nil
        
        // Act & Assert
        let validationResult = ServiceValidation.validateBeforeSave(entity: item)
        
        #expect(!validationResult.isValid, "Validation should fail for missing required field")
        #expect(!validationResult.errors.isEmpty, "Should have validation errors")
        #expect(validationResult.errors.contains { $0.contains("manufacturer") && $0.contains("required") }, 
                "Should report missing manufacturer as required field error")
        
        // Keep reference to test controller to prevent deallocation
        _ = testController
    }
    
    @Test("Should pass validation for entity with all required fields")
    func testPreSaveValidationSuccess() throws {
        // Arrange - Use completely isolated context
        let (testController, context) = try createCompletelyIsolatedTestContext()
        
        // Create entity with all required fields using consistent approach
        let item = createTestEntity(in: context, name: "Valid Test Item", code: "VALID-001", manufacturer: "Test Manufacturer")
        
        // Act
        let validationResult = ServiceValidation.validateBeforeSave(entity: item)
        
        // Assert
        #expect(validationResult.isValid, "Validation should pass for complete entity")
        #expect(validationResult.errors.isEmpty, "Should have no validation errors")
        
        // Keep reference to test controller to prevent deallocation
        _ = testController
    }
    
    @Test("Should validate multiple missing fields")
    func testPreSaveValidationMultipleErrors() throws {
        // Arrange - Use completely isolated context
        let (testController, context) = try createCompletelyIsolatedTestContext()
        
        // Create entity with multiple missing fields (all nil)
        let item = createTestEntity(in: context)
        
        // Act
        let validationResult = ServiceValidation.validateBeforeSave(entity: item)
        
        // Assert
        #expect(!validationResult.isValid, "Validation should fail for multiple missing fields")
        #expect(validationResult.errors.count >= 2, "Should have at least 2 validation errors")
        #expect(validationResult.errors.contains { $0.contains("name") }, "Should report missing name")
        #expect(validationResult.errors.contains { $0.contains("code") }, "Should report missing code") 
        #expect(validationResult.errors.contains { $0.contains("manufacturer") }, "Should report missing manufacturer")
        
        // Keep reference to test controller to prevent deallocation
        _ = testController
    }
}

#endif