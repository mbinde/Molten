//
//  FetchRequestBuilderTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/11/25.
//

import Foundation
import CoreData
@testable import Flameworker

#if canImport(Testing)
import Testing

@Suite("FetchRequestBuilder Tests", .serialized)
struct FetchRequestBuilderTests {
    
    // Helper to create test data with proper validation and cleanup
    private func createTestCatalogItems(in context: NSManagedObjectContext) throws {
        print("🔧 Creating test catalog items...")
        
        // First, completely clear any existing entities to start fresh
        let clearFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "CatalogItem")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: clearFetchRequest)
        do {
            try context.execute(deleteRequest)
            try context.save()
            print("  🧹 Cleared existing entities")
        } catch {
            print("  ⚠️ Could not clear existing entities: \(error)")
        }
        
        // Get entity description
        guard let entity = NSEntityDescription.entity(forEntityName: "CatalogItem", in: context) else {
            print("  ❌ Could not find CatalogItem entity!")
            throw NSError(domain: "TestSetup", code: 1, userInfo: [:])
        }
        
        print("  🔧 Creating fresh test entities...")
        
        let testItemData = [
            ("Red Glass Rod", "RGR-001", "Bullseye Glass"),
            ("Blue Glass Sheet", "BGS-002", "Spectrum Glass"), 
            ("Green Glass Frit", "GGF-003", "Bullseye Glass"),
            ("Clear Glass Rod", "CGR-004", "Spectrum Glass")
        ]
        
        var createdEntities: [NSManagedObject] = []
        
        for (index, (name, code, manufacturer)) in testItemData.enumerated() {
            print("  🔧 Creating entity \(index + 1)...")
            
            // Create new entity
            let item = NSManagedObject(entity: entity, insertInto: context)
            
            // Set values using setValue
            item.setValue(name, forKey: "name")
            item.setValue(code, forKey: "code")
            item.setValue(manufacturer, forKey: "manufacturer")
            
            // Verify they were set correctly
            let finalName = item.value(forKey: "name") as? String
            let finalCode = item.value(forKey: "code") as? String
            let finalManufacturer = item.value(forKey: "manufacturer") as? String
            
            print("  📋 Entity \(index + 1): name='\(finalName ?? "nil")' code='\(finalCode ?? "nil")' mfg='\(finalManufacturer ?? "nil")'")
            
            if finalName != name || finalCode != code || finalManufacturer != manufacturer {
                print("  ❌ CRITICAL: Properties not set correctly!")
                context.delete(item)
                throw NSError(domain: "TestSetup", code: 2, userInfo: [:])
            }
            
            createdEntities.append(item)
            print("  ✅ Entity \(index + 1) created successfully")
        }
        
        // Save all entities
        print("  💾 Attempting to save \(createdEntities.count) entities...")
        do {
            try context.save()
            print("  ✅ Save successful!")
        } catch {
            print("  ❌ Save failed: \(error)")
            throw error
        }
        
        print("  ✅ Test data creation completed successfully")
    }
    
    @Test("Should build compound AND predicate")
    func testCompoundAndPredicate() throws {
        let (testController, context) = try SharedTestUtilities.getCleanTestController()
        try createTestCatalogItems(in: context)
        
        let builder = FetchRequestBuilder<CatalogItem>(entityName: "CatalogItem")
        
        let results = try builder
            .where(NSPredicate(format: "name CONTAINS[cd] %@", "Glass"))
            .and(NSPredicate(format: "manufacturer == %@", "Bullseye Glass"))
            .execute(in: context)
        
        #expect(results.count == 2, "Should find 2 Bullseye glass items")
        let names = results.compactMap { $0.name }
        #expect(names.contains("Red Glass Rod"), "Should contain Red Glass Rod")
        #expect(names.contains("Green Glass Frit"), "Should contain Green Glass Frit")
        
        _ = testController
    }
    
    @Test("Should build compound OR predicate")
    func testCompoundOrPredicate() throws {
        let (testController, context) = try SharedTestUtilities.getCleanTestController()
        try createTestCatalogItems(in: context)
        
        let builder = FetchRequestBuilder<CatalogItem>(entityName: "CatalogItem")
        
        let results = try builder
            .where(NSPredicate(format: "name CONTAINS[cd] %@", "Red"))
            .or(NSPredicate(format: "name CONTAINS[cd] %@", "Blue"))
            .execute(in: context)
        
        #expect(results.count == 2, "Should find 2 items (Red or Blue)")
        let names = results.compactMap { $0.name }
        #expect(names.contains("Red Glass Rod"), "Should contain Red Glass Rod")
        #expect(names.contains("Blue Glass Sheet"), "Should contain Blue Glass Sheet")
        
        _ = testController
    }
    
    @Test("Should get distinct values with filtering")
    func testDistinctValuesWithFiltering() throws {
        let (testController, context) = try SharedTestUtilities.getCleanTestController()
        try createTestCatalogItems(in: context)
        
        let builder = FetchRequestBuilder<CatalogItem>(entityName: "CatalogItem")
        
        let allRods = try builder
            .where(NSPredicate(format: "name CONTAINS[cd] %@", "Rod"))
            .execute(in: context)
        
        print("🔍 Debug: Found \(allRods.count) Rod items:")
        for rod in allRods {
            print("  - \(rod.name ?? "nil") by \(rod.manufacturer ?? "nil")")
        }
        
        let distinctManufacturers = try builder
            .where(NSPredicate(format: "name CONTAINS[cd] %@", "Rod"))
            .distinct(keyPath: "manufacturer", in: context)
        
        print("🔍 Debug: Distinct manufacturers: \(distinctManufacturers)")
        
        #expect(distinctManufacturers.count == 2, "Should have 2 distinct manufacturers for Rod items")
        #expect(distinctManufacturers.contains("Bullseye Glass"), "Should contain Bullseye Glass")
        #expect(distinctManufacturers.contains("Spectrum Glass"), "Should contain Spectrum Glass")
        
        _ = testController
    }
}

#endif