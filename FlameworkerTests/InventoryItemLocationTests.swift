//
//  InventoryItemLocationTests.swift
//  Flameworker
//
//  Created by Assistant on 10/4/25.
//

import Testing
import CoreData
@testable import Flameworker

@Suite("InventoryItem Location Tests")
struct InventoryItemLocationTests {
    
    @Test("InventoryItem should have location property")
    func testInventoryItemHasLocationProperty() async throws {
        // Arrange
        let testController = PersistenceController.createTestController()
        let context = testController.container.viewContext
        
        // Act & Assert
        await MainActor.run {
            // Check if InventoryItem entity exists and has location attribute
            if let inventoryEntity = NSEntityDescription.entity(forEntityName: "InventoryItem", in: context) {
                let locationAttribute = inventoryEntity.attributesByName["location"]
                #expect(locationAttribute != nil, "InventoryItem should have a location attribute")
                #expect(locationAttribute?.attributeType == .stringAttributeType, "Location should be a String attribute")
                #expect(locationAttribute?.isOptional == true, "Location should be optional")
            } else {
                Issue.record("InventoryItem entity not found in Core Data model")
            }
        }
    }
    
    @Test("InventoryItem location should be settable and retrievable")
    func testInventoryItemLocationSetAndGet() async throws {
        // Arrange
        let testController = PersistenceController.createTestController()
        let context = testController.container.viewContext
        let testLocation = "Workshop Shelf A"
        
        // Act & Assert
        await MainActor.run {
            if let inventoryEntity = NSEntityDescription.entity(forEntityName: "InventoryItem", in: context) {
                let inventoryItem = NSManagedObject(entity: inventoryEntity, insertInto: context)
                
                // Set basic required properties
                inventoryItem.setValue("test-id", forKey: "id")
                inventoryItem.setValue("TEST-001", forKey: "catalog_code")
                inventoryItem.setValue(10.0, forKey: "count")
                inventoryItem.setValue(InventoryItemType.sell.rawValue, forKey: "type")
                
                // Set location
                inventoryItem.setValue(testLocation, forKey: "location")
                
                do {
                    try context.save()
                    
                    // Verify location was saved
                    let savedLocation = inventoryItem.value(forKey: "location") as? String
                    #expect(savedLocation == testLocation, "Location should be saved and retrievable")
                    
                } catch {
                    Issue.record("Failed to save inventory item with location: \(error)")
                }
            } else {
                Issue.record("InventoryItem entity not found")
            }
        }
    }
    
    @Test("LocationService should provide auto-complete suggestions based on search text")
    func testLocationServiceAutoComplete() async throws {
        // Arrange
        let testController = PersistenceController.createTestController()
        let context = testController.container.viewContext
        
        // Act & Assert
        await MainActor.run {
            if let inventoryEntity = NSEntityDescription.entity(forEntityName: "InventoryItem", in: context) {
                // Create test items with various locations
                let locations = ["Workshop Shelf A", "Workshop Shelf B", "Storage Room 1", "Storage Room 2", "Office Cabinet"]
                
                for (index, location) in locations.enumerated() {
                    let item = NSManagedObject(entity: inventoryEntity, insertInto: context)
                    item.setValue("autocomplete-\(index)", forKey: "id")
                    item.setValue("AUTO-\(index)", forKey: "catalog_code")
                    item.setValue(Double(index + 1), forKey: "count")
                    item.setValue(InventoryItemType.inventory.rawValue, forKey: "type")
                    item.setValue(location, forKey: "location")
                }
                
                do {
                    try context.save()
                    
                    // Test LocationService auto-complete functionality
                    let locationService = LocationService.shared
                    
                    // Test searching for "workshop"
                    let workshopResults = locationService.getLocationSuggestions(matching: "workshop", from: context)
                    #expect(workshopResults.count == 2, "Should find 2 workshop locations")
                    #expect(workshopResults.contains("Workshop Shelf A"), "Should include Workshop Shelf A")
                    #expect(workshopResults.contains("Workshop Shelf B"), "Should include Workshop Shelf B")
                    
                    // Test searching for "storage"
                    let storageResults = locationService.getLocationSuggestions(matching: "storage", from: context)
                    #expect(storageResults.count == 2, "Should find 2 storage locations")
                    
                    // Test empty search (should return all locations)
                    let allResults = locationService.getLocationSuggestions(matching: "", from: context)
                    #expect(allResults.count == 5, "Should return all 5 unique locations")
                    
                } catch {
                    Issue.record("Failed to save test inventory items for auto-complete: \(error)")
                }
            } else {
                Issue.record("InventoryItem entity not found")
            }
        }
    }
}