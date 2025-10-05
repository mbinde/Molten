import XCTest
import CoreData
@testable import YourAppModule // Replace with your actual module name
import Testing

final class InventorySearchSuggestionsTests: XCTestCase {
    
    // MARK: - Helpers
    
    private func makeTestContext() -> NSManagedObjectContext {
        let modelURL = Bundle.main.url(forResource: "YourModelName", withExtension: "momd")! // Replace with your model file name
        let mom = NSManagedObjectModel(contentsOf: modelURL)!
        let psc = NSPersistentStoreCoordinator(managedObjectModel: mom)
        try! psc.addPersistentStore(ofType: NSInMemoryStoreType,
                                    configurationName: nil,
                                    at: nil,
                                    options: nil)
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = psc
        return context
    }
    
    private func createCatalogItem(
        context: NSManagedObjectContext,
        name: String,
        code: String,
        id: String,
        manufacturerShortName: String? = nil,
        manufacturerFullName: String? = nil,
        tags: [String]? = nil,
        synonyms: [String]? = nil
    ) -> CatalogItem {
        let item = NSEntityDescription.insertNewObject(forEntityName: "CatalogItem", into: context) as! CatalogItem
        item.name = name
        item.code = code
        item.id = id
        if let shortName = manufacturerShortName {
            item.manufacturerShortName = shortName
        }
        if let fullName = manufacturerFullName {
            item.manufacturerFullName = fullName
        }
        if let tags = tags {
            item.tags = tags
        }
        if let synonyms = synonyms {
            item.synonyms = synonyms
        }
        return item
    }
    
    private func createInventoryItem(
        context: NSManagedObjectContext,
        catalogItemCode: String? = nil,
        catalogItemID: String? = nil,
        catalogItemPrefixedCode: String? = nil
    ) -> InventoryItem {
        let item = NSEntityDescription.insertNewObject(forEntityName: "InventoryItem", into: context) as! InventoryItem
        if let code = catalogItemCode {
            item.catalogItemCode = code
        }
        if let id = catalogItemID {
            item.catalogItemID = id
        }
        if let prefixedCode = catalogItemPrefixedCode {
            item.catalogItemPrefixedCode = prefixedCode
        }
        return item
    }
    
    // MARK: - Tests
    
    func testSuggestedCatalogItems_byName() throws {
        let context = makeTestContext()
        
        let item1 = createCatalogItem(context: context, name: "Super Widget", code: "SW-001", id: "1001")
        let item2 = createCatalogItem(context: context, name: "Mega Gadget", code: "MG-002", id: "1002")
        
        let results = InventorySearchSuggestions.suggestedCatalogItems(for: "Super", in: context)
        
        XCTAssertTrue(results.contains(where: { $0.objectID == item1.objectID }))
        XCTAssertFalse(results.contains(where: { $0.objectID == item2.objectID }))
    }
    
    func testSuggestedCatalogItems_byCode() throws {
        let context = makeTestContext()
        
        let item1 = createCatalogItem(context: context, name: "Widget", code: "W-123", id: "2001")
        let item2 = createCatalogItem(context: context, name: "Gadget", code: "G-456", id: "2002")
        
        let results = InventorySearchSuggestions.suggestedCatalogItems(for: "W-123", in: context)
        
        XCTAssertTrue(results.contains(where: { $0.objectID == item1.objectID }))
        XCTAssertFalse(results.contains(where: { $0.objectID == item2.objectID }))
    }
    
    func testSuggestedCatalogItems_byID() throws {
        let context = makeTestContext()
        
        let item1 = createCatalogItem(context: context, name: "Alpha", code: "A-111", id: "3001")
        let item2 = createCatalogItem(context: context, name: "Beta", code: "B-222", id: "3002")
        
        let results = InventorySearchSuggestions.suggestedCatalogItems(for: "3002", in: context)
        
        XCTAssertTrue(results.contains(where: { $0.objectID == item2.objectID }))
        XCTAssertFalse(results.contains(where: { $0.objectID == item1.objectID }))
    }
    
    func testSuggestedCatalogItems_matchManufacturerShortName() throws {
        let context = makeTestContext()
        
        let item1 = createCatalogItem(
            context: context,
            name: "Flux Capacitor",
            code: "FC-777",
            id: "4001",
            manufacturerShortName: "FluxCo"
        )
        let item2 = createCatalogItem(
            context: context,
            name: "Time Circuit",
            code: "TC-888",
            id: "4002",
            manufacturerShortName: "TimeInc"
        )
        
        let results = InventorySearchSuggestions.suggestedCatalogItems(for: "FluxCo", in: context)
        
        XCTAssertTrue(results.contains(where: { $0.objectID == item1.objectID }))
        XCTAssertFalse(results.contains(where: { $0.objectID == item2.objectID }))
    }
    
    func testSuggestedCatalogItems_matchManufacturerFullName() throws {
        let context = makeTestContext()
        
        let item1 = createCatalogItem(
            context: context,
            name: "Flux Capacitor",
            code: "FC-777",
            id: "5001",
            manufacturerFullName: "Flux Corporation"
        )
        let item2 = createCatalogItem(
            context: context,
            name: "Time Circuit",
            code: "TC-888",
            id: "5002",
            manufacturerFullName: "Time Incorporated"
        )
        
        let results = InventorySearchSuggestions.suggestedCatalogItems(for: "Flux Corporation", in: context)
        
        XCTAssertTrue(results.contains(where: { $0.objectID == item1.objectID }))
        XCTAssertFalse(results.contains(where: { $0.objectID == item2.objectID }))
    }
    
    func testSuggestedCatalogItems_matchTagsAndSynonyms() throws {
        let context = makeTestContext()
        
        let item1 = createCatalogItem(
            context: context,
            name: "Turbo Engine",
            code: "TE-123",
            id: "6001",
            tags: ["engine", "turbo", "performance"],
            synonyms: ["boost", "power"]
        )
        let item2 = createCatalogItem(
            context: context,
            name: "Standard Engine",
            code: "SE-456",
            id: "6002",
            tags: ["engine", "standard"],
            synonyms: ["normal"]
        )
        
        let resultsTag = InventorySearchSuggestions.suggestedCatalogItems(for: "performance", in: context)
        XCTAssertTrue(resultsTag.contains(where: { $0.objectID == item1.objectID }))
        XCTAssertFalse(resultsTag.contains(where: { $0.objectID == item2.objectID }))
        
        let resultsSynonym = InventorySearchSuggestions.suggestedCatalogItems(for: "boost", in: context)
        XCTAssertTrue(resultsSynonym.contains(where: { $0.objectID == item1.objectID }))
        XCTAssertFalse(resultsSynonym.contains(where: { $0.objectID == item2.objectID }))
    }
    
    func testSuggestedCatalogItems_matchManufacturerPrefixedCodes() throws {
        let context = makeTestContext()
        
        let item1 = createCatalogItem(
            context: context,
            name: "Efficient Filter",
            code: "204",
            id: "7001",
            manufacturerShortName: "EFF"
        )
        let item2 = createCatalogItem(
            context: context,
            name: "Premium Filter",
            code: "305",
            id: "7002",
            manufacturerShortName: "PRM"
        )
        
        let results = InventorySearchSuggestions.suggestedCatalogItems(for: "EFF-204", in: context)
        
        XCTAssertTrue(results.contains(where: { $0.objectID == item1.objectID }))
        XCTAssertFalse(results.contains(where: { $0.objectID == item2.objectID }))
    }
    
    func testSuggestedCatalogItems_excludesItemsAlreadyInInventory_fullCode() throws {
        let context = makeTestContext()
        
        let catalogItem = createCatalogItem(context: context, name: "Widget Pro", code: "WP-999", id: "8001")
        _ = createInventoryItem(context: context, catalogItemCode: "WP-999")
        
        let results = InventorySearchSuggestions.suggestedCatalogItems(for: "WP-999", in: context)
        
        XCTAssertFalse(results.contains(where: { $0.objectID == catalogItem.objectID }))
    }
    
    func testSuggestedCatalogItems_excludesItemsAlreadyInInventory_id() throws {
        let context = makeTestContext()
        
        let catalogItem = createCatalogItem(context: context, name: "Gadget Max", code: "GM-888", id: "9001")
        _ = createInventoryItem(context: context, catalogItemID: "9001")
        
        let results = InventorySearchSuggestions.suggestedCatalogItems(for: "9001", in: context)
        
        XCTAssertFalse(results.contains(where: { $0.objectID == catalogItem.objectID }))
    }
    
    func testSuggestedCatalogItems_excludesItemsAlreadyInInventory_prefixedVsBaseCode() throws {
        let context = makeTestContext()
        
        let catalogItem = createCatalogItem(
            context: context,
            name: "Filter Deluxe",
            code: "204",
            id: "10001",
            manufacturerShortName: "EFF"
        )
        _ = createInventoryItem(context: context, catalogItemPrefixedCode: "EFF-204")
        
        let results = InventorySearchSuggestions.suggestedCatalogItems(for: "204", in: context)
        
        XCTAssertFalse(results.contains(where: { $0.objectID == catalogItem.objectID }))
    }
}
