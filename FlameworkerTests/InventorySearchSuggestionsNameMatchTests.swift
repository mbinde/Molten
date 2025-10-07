//  InventorySearchSuggestionsNameMatchTests.swift - DISABLED
//  FlameworkerTests
//
//  DISABLED: Core Data entity creation causing crashes and hanging
//  Status: COMPLETELY DISABLED - DO NOT IMPORT Testing
//  Verifies name-based matching for InventorySearchSuggestions

// CRITICAL: DO NOT UNCOMMENT THE IMPORT BELOW - CAUSES TEST HANGING
// import Testing

/* ========================================================================
   FILE STATUS: COMPLETELY DISABLED - DO NOT RE-ENABLE
   REASON: Creates CatalogItem entities with createTestController causing hangs
   ISSUE: Core Data entity creation and setValue operations in test methods
   SOLUTION NEEDED: Replace with mock catalog objects following safety guidelines
   ======================================================================== */
/*
import CoreData
@testable import Flameworker

@Suite("InventorySearchSuggestions Name Matching")
struct InventorySearchSuggestionsNameMatchTests {
    
    @Test("suggestedCatalogItems matches by name contains query")
    func testNameMatching() async throws {
        // Arrange: create isolated Core Data context
        let controller = PersistenceController.createTestController()
        let context = controller.container.viewContext
        
        // Ensure we can get the CatalogItem entity description
        guard let catalogEntity = NSEntityDescription.entity(forEntityName: "CatalogItem", in: context) else {
            Issue.record("CatalogItem entity not found in test context")
            return
        }
        
        // Create a matching catalog item (name contains 'Crayon')
        let matching = CatalogItem(entity: catalogEntity, insertInto: context)
        matching.setValue("Crayon Blue", forKey: "name")
        matching.setValue("CB-001", forKey: "code")
        matching.setValue("CB-001", forKey: "id")
        matching.setValue("EF", forKey: "manufacturer")
        
        // Create a non-matching catalog item
        let nonMatching = CatalogItem(entity: catalogEntity, insertInto: context)
        nonMatching.setValue("Ocean Mist", forKey: "name")
        nonMatching.setValue("OM-002", forKey: "code")
        nonMatching.setValue("OM-002", forKey: "id")
        nonMatching.setValue("EF", forKey: "manufacturer")
        
        let catalog = [matching, nonMatching]
        let inventory: [InventoryItem] = [] // No exclusions
        
        // Act: perform suggestion search
        let results = InventorySearchSuggestions.suggestedCatalogItems(
            query: "crayon",
            inventoryItems: inventory,
            catalogItems: catalog
        )
        
        // Assert: results include the matching item and exclude the non-matching item
        let resultIDs = Set(results.map { $0.objectID })
        #expect(resultIDs.contains(matching.objectID), "Should include item whose name contains 'crayon'")
        #expect(!resultIDs.contains(nonMatching.objectID), "Should not include item whose name does not contain 'crayon'")
    }
}
*/
