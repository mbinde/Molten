//
//  GlassItemRepositoryTests.swift
//  MoltenTests
//
//  Created by Assistant on 10/14/25.
//

import Testing
import Foundation
@testable import Flameworker

@Suite("GlassItem Repository Tests")
struct GlassItemRepositoryTests {
    
    // MARK: - Test Setup Helpers
    
    private func createTestRepository() -> MockGlassItemRepository {
        let repository = MockGlassItemRepository()
        repository.simulateLatency = false // Disable for fast tests
        repository.shouldRandomlyFail = false // Disable for predictable tests
        return repository
    }
    
    private func createSampleGlassItem() -> GlassItemModel {
        return GlassItemModel(
            naturalKey: "cim-874-0",
            name: "Adamantium",
            sku: "874",
            manufacturer: "cim",
            mfrNotes: "A brown gray color",
            coe: 104,
            url: "https://creationismessy.com/color.aspx?id=60",
            mfrStatus: "available"
        )
    }
    
    // MARK: - Basic CRUD Tests
    
    @Test("Create and fetch glass item")
    func createAndFetchGlassItem() async throws {
        let repository = createTestRepository()
        let item = createSampleGlassItem()
        
        // Create item
        let createdItem = try await repository.createItem(item)
        #expect(createdItem.naturalKey == item.naturalKey)
        #expect(createdItem.name == item.name)
        #expect(createdItem.uri == "moltenglass:item?cim-874-0")
        
        // Fetch item by natural key
        let fetchedItem = try await repository.fetchItem(byNaturalKey: "cim-874-0")
        #expect(fetchedItem != nil)
        #expect(fetchedItem?.naturalKey == "cim-874-0")
        #expect(fetchedItem?.name == "Adamantium")
        #expect(fetchedItem?.coe == 104)
    }
    
    @Test("Create item with duplicate natural key should fail")
    func createItemWithDuplicateNaturalKey() async throws {
        let repository = createTestRepository()
        let item = createSampleGlassItem()
        
        // Create first item
        _ = try await repository.createItem(item)
        
        // Attempt to create duplicate should throw
        await #expect(throws: MockRepositoryError.self) {
            _ = try await repository.createItem(item)
        }
    }
    
    @Test("Update existing glass item")
    func updateExistingGlassItem() async throws {
        let repository = createTestRepository()
        let item = createSampleGlassItem()
        
        // Create item
        _ = try await repository.createItem(item)
        
        // Update item
        let updatedItem = GlassItemModel(
            naturalKey: "cim-874-0",
            name: "Adamantium Updated",
            sku: "874",
            manufacturer: "cim",
            mfrNotes: "Updated brown gray color",
            coe: 104,
            url: "https://creationismessy.com/color.aspx?id=60",
            mfrStatus: "discontinued"
        )
        
        let result = try await repository.updateItem(updatedItem)
        #expect(result.name == "Adamantium Updated")
        #expect(result.mfrNotes == "Updated brown gray color")
        #expect(result.mfrStatus == "discontinued")
        
        // Verify update persisted
        let fetchedItem = try await repository.fetchItem(byNaturalKey: "cim-874-0")
        #expect(fetchedItem?.name == "Adamantium Updated")
        #expect(fetchedItem?.mfrStatus == "discontinued")
    }
    
    @Test("Delete glass item")
    func deleteGlassItem() async throws {
        let repository = createTestRepository()
        let item = createSampleGlassItem()
        
        // Create item
        _ = try await repository.createItem(item)
        
        // Verify item exists
        let fetchedBefore = try await repository.fetchItem(byNaturalKey: "cim-874-0")
        #expect(fetchedBefore != nil)
        
        // Delete item
        try await repository.deleteItem(naturalKey: "cim-874-0")
        
        // Verify item is deleted
        let fetchedAfter = try await repository.fetchItem(byNaturalKey: "cim-874-0")
        #expect(fetchedAfter == nil)
    }
    
    @Test("Create multiple items")
    func createMultipleItems() async throws {
        let repository = createTestRepository()
        
        let items = [
            GlassItemModel(
                naturalKey: "cim-874-0",
                name: "Adamantium",
                sku: "874",
                manufacturer: "cim",
                coe: 104,
                mfrStatus: "available"
            ),
            GlassItemModel(
                naturalKey: "bullseye-001-0",
                name: "Clear",
                sku: "001",
                manufacturer: "bullseye",
                coe: 90,
                mfrStatus: "available"
            ),
            GlassItemModel(
                naturalKey: "spectrum-96-0",
                name: "White Opaque",
                sku: "96",
                manufacturer: "spectrum",
                coe: 96,
                mfrStatus: "available"
            )
        ]
        
        let createdItems = try await repository.createItems(items)
        #expect(createdItems.count == 3)
        
        // Verify all items were created
        let allItems = try await repository.fetchItems(matching: nil as NSPredicate?)
        #expect(allItems.count == 3)
    }
    
    // MARK: - Search and Filter Tests
    
    @Test("Search items by text")
    func searchItemsByText() async throws {
        let repository = createTestRepository()
        try await repository.populateWithTestData()
        
        // Search by name
        let nameResults = try await repository.searchItems(text: "Adamantium")
        #expect(nameResults.count == 1)
        #expect(nameResults.first?.name == "Adamantium")
        
        // Search by manufacturer
        let mfrResults = try await repository.searchItems(text: "bullseye")
        #expect(mfrResults.count == 1)
        #expect(mfrResults.first?.manufacturer == "bullseye")
        
        // Search by notes
        let notesResults = try await repository.searchItems(text: "brown")
        #expect(notesResults.count == 1)
        #expect(notesResults.first?.mfrNotes?.contains("brown") == true)
        
        // Empty search should return all items
        let allResults = try await repository.searchItems(text: "")
        #expect(allResults.count == 3)
    }
    
    @Test("Fetch items by manufacturer")
    func fetchItemsByManufacturer() async throws {
        let repository = createTestRepository()
        try await repository.populateWithTestData()
        
        let cimItems = try await repository.fetchItems(byManufacturer: "cim")
        #expect(cimItems.count == 1)
        #expect(cimItems.first?.manufacturer == "cim")
        
        let bullseyeItems = try await repository.fetchItems(byManufacturer: "bullseye")
        #expect(bullseyeItems.count == 1)
        #expect(bullseyeItems.first?.manufacturer == "bullseye")
        
        let nonExistentItems = try await repository.fetchItems(byManufacturer: "nonexistent")
        #expect(nonExistentItems.count == 0)
    }
    
    @Test("Fetch items by COE")
    func fetchItemsByCOE() async throws {
        let repository = createTestRepository()
        try await repository.populateWithTestData()
        
        let coe90Items = try await repository.fetchItems(byCOE: 90)
        #expect(coe90Items.count == 1)
        #expect(coe90Items.first?.coe == 90)
        
        let coe104Items = try await repository.fetchItems(byCOE: 104)
        #expect(coe104Items.count == 1)
        #expect(coe104Items.first?.coe == 104)
        
        let nonExistentCOE = try await repository.fetchItems(byCOE: 999)
        #expect(nonExistentCOE.count == 0)
    }
    
    // MARK: - Business Query Tests
    
    @Test("Get distinct manufacturers")
    func getDistinctManufacturers() async throws {
        let repository = createTestRepository()
        try await repository.populateWithTestData()
        
        let manufacturers = try await repository.getDistinctManufacturers()
        #expect(manufacturers.count == 3)
        #expect(manufacturers.contains("cim"))
        #expect(manufacturers.contains("bullseye"))
        #expect(manufacturers.contains("spectrum"))
        
        // Should be sorted
        #expect(manufacturers == ["bullseye", "cim", "spectrum"])
    }
    
    @Test("Get distinct COE values")
    func getDistinctCOEValues() async throws {
        let repository = createTestRepository()
        try await repository.populateWithTestData()
        
        let coeValues = try await repository.getDistinctCOEValues()
        #expect(coeValues.count == 3)
        #expect(coeValues.contains(90))
        #expect(coeValues.contains(96))
        #expect(coeValues.contains(104))
        
        // Should be sorted
        #expect(coeValues == [90, 96, 104])
    }
    
    @Test("Natural key existence check")
    func naturalKeyExistenceCheck() async throws {
        let repository = createTestRepository()
        let item = createSampleGlassItem()
        
        // Should not exist initially
        let existsBefore = try await repository.naturalKeyExists("cim-874-0")
        #expect(existsBefore == false)
        
        // Create item
        _ = try await repository.createItem(item)
        
        // Should exist now
        let existsAfter = try await repository.naturalKeyExists("cim-874-0")
        #expect(existsAfter == true)
    }
    
    @Test("Generate next natural key")
    func generateNextNaturalKey() async throws {
        let repository = createTestRepository()
        
        // First key should be sequence 0
        let firstKey = try await repository.generateNextNaturalKey(
            manufacturer: "cim", 
            sku: "874"
        )
        #expect(firstKey == "cim-874-0")
        
        // Create item with first key
        let item = GlassItemModel(
            naturalKey: firstKey,
            name: "Test Item",
            sku: "874",
            manufacturer: "cim",
            coe: 104,
            mfrStatus: "available"
        )
        _ = try await repository.createItem(item)
        
        // Next key should be sequence 1
        let secondKey = try await repository.generateNextNaturalKey(
            manufacturer: "cim", 
            sku: "874"
        )
        #expect(secondKey == "cim-874-1")
    }
    
    // MARK: - Natural Key Helper Tests
    
    @Test("Parse natural key")
    func parseNaturalKey() async throws {
        let parsed = GlassItemModel.parseNaturalKey("cim-874-0")
        #expect(parsed?.manufacturer == "cim")
        #expect(parsed?.sku == "874")
        #expect(parsed?.sequence == 0)
        
        // Invalid format should return nil
        let invalid = GlassItemModel.parseNaturalKey("invalid-format")
        #expect(invalid == nil)
    }
    
    @Test("Create natural key from components")
    func createNaturalKeyFromComponents() async throws {
        let naturalKey = GlassItemModel.createNaturalKey(
            manufacturer: "cim", 
            sku: "874", 
            sequence: 2
        )
        #expect(naturalKey == "cim-874-2")
        
        // Default sequence should be 0
        let defaultSequence = GlassItemModel.createNaturalKey(
            manufacturer: "bullseye", 
            sku: "001", 
            sequence: 0
        )
        #expect(defaultSequence == "bullseye-001-0")
    }
}
