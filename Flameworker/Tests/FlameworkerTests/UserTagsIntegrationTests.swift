//
//  UserTagsIntegrationTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/17/25.
//

import Testing
@testable import Flameworker

/// Tests for user tags integration across views and services
/// Verifies that user tags are properly displayed alongside manufacturer tags
struct UserTagsIntegrationTests {

    // MARK: - Model Tests

    @Test("CompleteInventoryItemModel combines manufacturer and user tags correctly")
    func testCompleteInventoryItemAllTags() async throws {
        // Test that allTags property merges and deduplicates tags correctly
        let glassItem = GlassItemModel(
            natural_key: "test-item-001",
            name: "Test Item",
            sku: "TEST-001",
            manufacturer: "test",
            coe: 96,
            mfr_status: "available"
        )

        let item = CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: [],
            tags: ["blue", "transparent", "rod"],  // Manufacturer tags
            userTags: ["favorite", "blue", "project-A"],  // User tags (with duplicate "blue")
            locations: []
        )

        // Verify allTags combines both and removes duplicates
        #expect(item.allTags.contains("blue"))
        #expect(item.allTags.contains("transparent"))
        #expect(item.allTags.contains("rod"))
        #expect(item.allTags.contains("favorite"))
        #expect(item.allTags.contains("project-A"))

        // Verify "blue" appears only once (deduplicated)
        #expect(item.allTags.filter { $0 == "blue" }.count == 1)

        // Verify tags are sorted
        #expect(item.allTags == item.allTags.sorted())
    }

    @Test("DetailedShoppingListItemModel combines manufacturer and user tags correctly")
    func testShoppingListItemAllTags() async throws {
        // Test that shopping list items properly combine tags
        let glassItem = GlassItemModel(
            natural_key: "test-item-002",
            name: "Shopping Test Item",
            sku: "TEST-002",
            manufacturer: "test",
            coe: 104,
            mfr_status: "available"
        )

        let shoppingListItem = ShoppingListItemModel(
            itemNaturalKey: "test-item-002",
            type: "rod",
            currentQuantity: 5.0,
            minimumQuantity: 10.0,
            store: "Test Store"
        )

        let item = DetailedShoppingListItemModel(
            shoppingListItem: shoppingListItem,
            glassItem: glassItem,
            tags: ["clear", "rod"],  // Manufacturer tags
            userTags: ["urgent", "clear"]  // User tags (with duplicate "clear")
        )

        // Verify allTags combines both and removes duplicates
        #expect(item.allTags.contains("clear"))
        #expect(item.allTags.contains("rod"))
        #expect(item.allTags.contains("urgent"))

        // Verify "clear" appears only once
        #expect(item.allTags.filter { $0 == "clear" }.count == 1)
    }

    // MARK: - Service Integration Tests

    @Test("CatalogService fetches both manufacturer and user tags")
    func testCatalogServiceFetchesBothTagTypes() async throws {
        // Setup
        RepositoryFactory.configureForTesting()
        let catalogService = RepositoryFactory.createCatalogService()

        // TODO: Add test data with both manufacturer and user tags
        // TODO: Call getAllGlassItems() and verify both tag types are included
        // TODO: Verify allTags property works correctly
    }

    @Test("ShoppingListService includes user tags in shopping lists")
    func testShoppingListServiceIncludesUserTags() async throws {
        // Setup
        RepositoryFactory.configureForTesting()
        let shoppingListService = RepositoryFactory.createShoppingListService()

        // TODO: Add test data with user tags
        // TODO: Generate shopping list
        // TODO: Verify user tags are included in DetailedShoppingListItemModel
        // TODO: Verify allTags property works correctly
    }

    // MARK: - View Integration Tests

    @Test("CatalogView filters items using both manufacturer and user tags")
    func testCatalogViewTagFiltering() async throws {
        // TODO: Test that CatalogView's tag filtering works with user tags
        // TODO: Verify allAvailableTags includes both types
        // TODO: Verify filtering by user tag shows correct items
    }

    @Test("InventoryView displays user tags in item rows")
    func testInventoryViewDisplaysUserTags() async throws {
        // TODO: Test that InventoryItemRow displays allTags instead of just tags
        // TODO: Verify user tags appear in the tag chips
    }

    @Test("ShoppingListView displays user tags in item rows")
    func testShoppingListViewDisplaysUserTags() async throws {
        // TODO: Test that ShoppingListRowView displays allTags
        // TODO: Verify user tags appear alongside manufacturer tags
    }

    @Test("TagSelectionSheet shows visual distinction for user tags")
    func testTagSelectionSheetVisualDistinction() async throws {
        // TODO: Test that user tags are visually distinguished in the filter UI
        // TODO: Verify purple color and person icon for user tags
    }

    // MARK: - Batch Fetching Tests

    @Test("CatalogService batch fetches user tags efficiently")
    func testBatchFetchingUserTags() async throws {
        // Setup
        RepositoryFactory.configureForTesting()
        let catalogService = RepositoryFactory.createCatalogService()

        // TODO: Test that getAllGlassItems() uses fetchTagsForItems for batch fetching
        // TODO: Verify performance - should not make N+1 queries
    }
}
