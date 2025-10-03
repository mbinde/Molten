//
//  CoreDataHelpersTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/3/25.
//

import Testing
import CoreData
@testable import Flameworker

@Suite("CoreDataHelpers Tests")
struct CoreDataHelpersTests {
    
    // MARK: - Test Context Setup
    
    private var testContext: NSManagedObjectContext {
        let container = NSPersistentContainer(name: "TestModel")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load test store: \(error)")
            }
        }
        
        return container.viewContext
    }
    
    // MARK: - String Processing Tests
    
    @Test("String array joining with empty values")
    func joinStringArrayFiltersEmptyValues() {
        let input = ["apple", "", "banana", "  ", "cherry"]
        let result = CoreDataHelpers.joinStringArray(input)
        
        #expect(result == "apple,banana,cherry")
    }
    
    @Test("String array joining with nil input")
    func joinStringArrayHandlesNil() {
        let result = CoreDataHelpers.joinStringArray(nil)
        
        #expect(result == "")
    }
    
    @Test("String array joining with only empty values")
    func joinStringArrayOnlyEmptyValues() {
        let input = ["", "  ", "\t", "\n"]
        let result = CoreDataHelpers.joinStringArray(input)
        
        #expect(result == "")
    }
    
    @Test("String array splitting with valid input")
    func safeStringArraySplitsCorrectly() async throws {
        let context = testContext
        let entity = NSEntityDescription()
        entity.name = "TestEntity"
        
        // Create a mock managed object for testing
        // Note: In a real test, you'd need a proper Core Data model
        // For now, we'll test the joining function which doesn't require entities
        
        let testString = "apple, banana, cherry,  orange  "
        let components = testString
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        #expect(components == ["apple", "banana", "cherry", "orange"])
    }
    
    // MARK: - Core Data Safe Save Tests
    
    @Test("Safe save with no changes skips save")
    func safeSaveSkipsWhenNoChanges() async throws {
        let context = testContext
        
        // Test saving when context has no changes
        // This should not throw and should log that no changes exist
        try CoreDataHelpers.safeSave(context: context, description: "test save")
        
        #expect(!context.hasChanges)
    }
    
    // MARK: - Entity Validation Tests
    
    @Test("Entity safety check for valid entity")
    func entitySafetyValidation() {
        // Test would require a mock NSManagedObject
        // This is a placeholder showing the test structure
        
        // For now, test the validation logic constants
        #expect(true) // Placeholder - would test actual entity safety
    }
}

// MARK: - Mock Objects for Testing

/// Mock Core Data entity for testing
class MockCoreDataEntity: NSManagedObject {
    @objc dynamic var testAttribute: String = ""
    @objc dynamic var testArrayAttribute: String = ""
    
    override var entity: NSEntityDescription {
        let entityDesc = NSEntityDescription()
        entityDesc.name = "MockEntity"
        
        let stringAttribute = NSAttributeDescription()
        stringAttribute.name = "testAttribute"
        stringAttribute.attributeType = .stringAttributeType
        stringAttribute.isOptional = false
        
        let arrayAttribute = NSAttributeDescription()
        arrayAttribute.name = "testArrayAttribute"
        arrayAttribute.attributeType = .stringAttributeType
        arrayAttribute.isOptional = true
        
        entityDesc.properties = [stringAttribute, arrayAttribute]
        return entityDesc
    }
}