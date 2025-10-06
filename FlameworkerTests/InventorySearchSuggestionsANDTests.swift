//
//  InventorySearchSuggestionsANDTests.swift
//  FlameworkerTests
//
//  Verifies AND logic with quoted phrases for InventorySearchSuggestions
//

import Testing
import CoreData
@testable import Flameworker

@Suite("InventorySearchSuggestions AND Matching")
struct InventorySearchSuggestionsANDTests {
    
    @Test("Matches item when all terms satisfied including quoted phrase")
    func testANDMatchingWithQuotedPhrase() async throws {
        let controller = PersistenceController.createTestController()
        let context = controller.container.viewContext
        
        guard let catalogEntity = NSEntityDescription.entity(forEntityName: "CatalogItem", in: context) else {
            Issue.record("CatalogItem entity not found in test context")
            return
        }
        
        let matching = CatalogItem(entity: catalogEntity, insertInto: context)
        matching.setValue("Chocolate Crayon", forKey: "name")
        matching.setValue("RED-001", forKey: "code")
        matching.setValue("RED-001", forKey: "id")
        matching.setValue("GA", forKey: "manufacturer")
        
        let partial = CatalogItem(entity: catalogEntity, insertInto: context)
        partial.setValue("Chocolate Crayon", forKey: "name")
        partial.setValue("BLU-002", forKey: "code")
        partial.setValue("BLU-002", forKey: "id")
        partial.setValue("GA", forKey: "manufacturer")
        
        let nonMatching = CatalogItem(entity: catalogEntity, insertInto: context)
        nonMatching.setValue("Ocean Mist", forKey: "name")
        nonMatching.setValue("BLU-003", forKey: "code")
        nonMatching.setValue("BLU-003", forKey: "id")
        nonMatching.setValue("GA", forKey: "manufacturer")
        
        let results = InventorySearchSuggestions.suggestedCatalogItems(
            query: "\"chocolate crayon\" red",
            inventoryItems: [],
            catalogItems: [matching, partial, nonMatching]
        )
        
        let ids = Set(results.map { $0.objectID })
        #expect(ids.contains(matching.objectID))
        #expect(!ids.contains(partial.objectID), "Should exclude items that don't satisfy all AND terms")
        #expect(!ids.contains(nonMatching.objectID))
    }
    
    @Test("Returns empty for empty or whitespace-only query")
    func testEmptyQueryReturnsEmpty() async throws {
        let controller = PersistenceController.createTestController()
        let context = controller.container.viewContext
        
        guard let catalogEntity = NSEntityDescription.entity(forEntityName: "CatalogItem", in: context) else {
            Issue.record("CatalogItem entity not found in test context")
            return
        }
        
        let item = CatalogItem(entity: catalogEntity, insertInto: context)
        item.setValue("Sample", forKey: "name")
        item.setValue("CODE-001", forKey: "code")
        item.setValue("CODE-001", forKey: "id")
        item.setValue("GA", forKey: "manufacturer")
        
        let emptyResults = InventorySearchSuggestions.suggestedCatalogItems(
            query: "",
            inventoryItems: [],
            catalogItems: [item]
        )
        #expect(emptyResults.isEmpty)
        
        let whitespaceResults = InventorySearchSuggestions.suggestedCatalogItems(
            query: "   ",
            inventoryItems: [],
            catalogItems: [item]
        )
        #expect(whitespaceResults.isEmpty)
    }
    
    @Test("Matches by tags and synonyms with AND logic")
    func testMatchesByTagsAndSynonyms() async throws {
        let controller = PersistenceController.createTestController()
        let context = controller.container.viewContext
        
        guard let catalogEntity = NSEntityDescription.entity(forEntityName: "CatalogItem", in: context) else {
            Issue.record("CatalogItem entity not found in test context")
            return
        }
        
        // Item that has both a matching tag and synonym
        let both = CatalogItem(entity: catalogEntity, insertInto: context)
        both.setValue("Chocolate Crayon", forKey: "name")
        both.setValue("RED-007", forKey: "code")
        both.setValue("RED-007", forKey: "id")
        both.setValue("GA", forKey: "manufacturer")
        both.setValue("reactive, crayon", forKey: "tags")
        both.setValue("choco, brown", forKey: "synonyms")
        
        // Item with only tag match
        let onlyTag = CatalogItem(entity: catalogEntity, insertInto: context)
        onlyTag.setValue("Some Color", forKey: "name")
        onlyTag.setValue("BLU-010", forKey: "code")
        onlyTag.setValue("BLU-010", forKey: "id")
        onlyTag.setValue("GA", forKey: "manufacturer")
        onlyTag.setValue("reactive", forKey: "tags")
        onlyTag.setValue("", forKey: "synonyms")
        
        // Item with only synonym match
        let onlySyn = CatalogItem(entity: catalogEntity, insertInto: context)
        onlySyn.setValue("Another Color", forKey: "name")
        onlySyn.setValue("GRN-020", forKey: "code")
        onlySyn.setValue("GRN-020", forKey: "id")
        onlySyn.setValue("GA", forKey: "manufacturer")
        onlySyn.setValue("opaque", forKey: "tags")
        onlySyn.setValue("choco", forKey: "synonyms")
        
        // Query requires both terms (AND): one from tags and one from synonyms
        let results = InventorySearchSuggestions.suggestedCatalogItems(
            query: "reactive choco",
            inventoryItems: [],
            catalogItems: [both, onlyTag, onlySyn]
        )
        
        let ids = Set(results.map { $0.objectID })
        #expect(ids.contains(both.objectID), "Item with both tag and synonym should match")
        #expect(!ids.contains(onlyTag.objectID), "Item with only tag should not match AND query")
        #expect(!ids.contains(onlySyn.objectID), "Item with only synonym should not match AND query")
    }
}
