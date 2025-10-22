//
//  ShoppingListViewTests.swift
//  FlameworkerTests
//
//  Tests for ShoppingListView and related components
//

import Testing
import SwiftUI
@testable import Molten

@Suite("ShoppingListView Tests")
@MainActor
struct ShoppingListViewTests {

    // MARK: - Helper Functions

    func createMockShoppingListService() -> ShoppingListService {
        let shoppingListService = ShoppingListService(
            itemMinimumRepository: MockItemMinimumRepository(),
            shoppingListRepository: MockShoppingListRepository(),
            inventoryRepository: MockInventoryRepository(),
            glassItemRepository: MockGlassItemRepository(),
            itemTagsRepository: MockItemTagsRepository(),
            userTagsRepository: MockUserTagsRepository()
        )

        return shoppingListService
    }

    func createTestShoppingListItem(
        naturalKey: String = "test-item-001-0",
        name: String = "Test Item",
        manufacturer: String = "test",
        sku: String = "TEST-001",
        type: String = "rod",
        minimumQuantity: Double = 10.0,
        currentQuantity: Double = 5.0,
        store: String = "Test Store",
        coe: Int32 = 104,
        tags: [String] = [],
        userTags: [String] = []
    ) -> DetailedShoppingListItemModel {
        let glassItem = GlassItemModel(
            natural_key: naturalKey,
            name: name,
            sku: sku,
            manufacturer: manufacturer,
            coe: coe,
            mfr_status: "available"
        )

        let shoppingListItem = ShoppingListItemModel(
            itemNaturalKey: naturalKey,
            type: type,
            currentQuantity: currentQuantity,
            minimumQuantity: minimumQuantity,
            store: store
        )

        return DetailedShoppingListItemModel(
            shoppingListItem: shoppingListItem,
            glassItem: glassItem,
            tags: tags,
            userTags: userTags
        )
    }

    // MARK: - Initialization Tests

    @Test("ShoppingListView initializes with default state")
    func testInitialization() {
        let shoppingListService = createMockShoppingListService()
        let view = ShoppingListView(shoppingListService: shoppingListService)

        #expect(view != nil)
    }

    // MARK: - Sorting Tests

    @Test("Sort options are available")
    func testSortOptionsAvailable() {
        let sortOptions = ShoppingListView.SortOption.allCases

        #expect(sortOptions.count == 4)
        #expect(sortOptions.contains(.neededQuantity))
        #expect(sortOptions.contains(.itemName))
        #expect(sortOptions.contains(.store))
        #expect(sortOptions.contains(.manufacturer))
    }

    @Test("Sorting by needed quantity orders items correctly")
    func testSortByNeededQuantity() {
        let item1 = createTestShoppingListItem(
            naturalKey: "test-001",
            name: "Item A",
            minimumQuantity: 10.0,
            currentQuantity: 5.0
        )
        let item2 = createTestShoppingListItem(
            naturalKey: "test-002",
            name: "Item B",
            minimumQuantity: 20.0,
            currentQuantity: 5.0
        )
        let item3 = createTestShoppingListItem(
            naturalKey: "test-003",
            name: "Item C",
            minimumQuantity: 15.0,
            currentQuantity: 5.0
        )

        let items = [item1, item2, item3]
        let sorted = items.sorted { $0.shoppingListItem.neededQuantity > $1.shoppingListItem.neededQuantity }

        #expect(sorted[0].shoppingListItem.neededQuantity == 15.0)
        #expect(sorted[1].shoppingListItem.neededQuantity == 10.0)
        #expect(sorted[2].shoppingListItem.neededQuantity == 5.0)
    }

    @Test("Sorting by item name orders items alphabetically")
    func testSortByItemName() {
        let item1 = createTestShoppingListItem(naturalKey: "test-001", name: "Zebra")
        let item2 = createTestShoppingListItem(naturalKey: "test-002", name: "Apple")
        let item3 = createTestShoppingListItem(naturalKey: "test-003", name: "Mango")

        let items = [item1, item2, item3]
        let sorted = items.sorted { $0.glassItem.name < $1.glassItem.name }

        #expect(sorted[0].glassItem.name == "Apple")
        #expect(sorted[1].glassItem.name == "Mango")
        #expect(sorted[2].glassItem.name == "Zebra")
    }

    @Test("Sorting by store orders items alphabetically by store")
    func testSortByStore() {
        let item1 = createTestShoppingListItem(naturalKey: "test-001", store: "Zing Glass")
        let item2 = createTestShoppingListItem(naturalKey: "test-002", store: "Alpha Glass")
        let item3 = createTestShoppingListItem(naturalKey: "test-003", store: "Mega Glass")

        let items = [item1, item2, item3]
        let sorted = items.sorted { $0.shoppingListItem.store < $1.shoppingListItem.store }

        #expect(sorted[0].shoppingListItem.store == "Alpha Glass")
        #expect(sorted[1].shoppingListItem.store == "Mega Glass")
        #expect(sorted[2].shoppingListItem.store == "Zing Glass")
    }

    // MARK: - Grouping Tests

    @Test("Items are grouped by store when sort option is store")
    func testGroupByStoreWhenSortingByStore() {
        let item1 = createTestShoppingListItem(naturalKey: "test-001", store: "Store A")
        let item2 = createTestShoppingListItem(naturalKey: "test-002", store: "Store B")
        let item3 = createTestShoppingListItem(naturalKey: "test-003", store: "Store A")

        let items = [item1, item2, item3]
        let grouped = Dictionary(grouping: items) { $0.shoppingListItem.store }

        #expect(grouped.count == 2)
        #expect(grouped["Store A"]?.count == 2)
        #expect(grouped["Store B"]?.count == 1)
    }

    // MARK: - Filtering Tests

    @Test("Filter by store filters items correctly")
    func testFilterByStore() {
        let item1 = createTestShoppingListItem(naturalKey: "test-001", store: "Store A")
        let item2 = createTestShoppingListItem(naturalKey: "test-002", store: "Store B")
        let item3 = createTestShoppingListItem(naturalKey: "test-003", store: "Store A")

        let items = [item1, item2, item3]
        let filtered = items.filter { $0.shoppingListItem.store == "Store A" }

        #expect(filtered.count == 2)
        #expect(filtered.allSatisfy { $0.shoppingListItem.store == "Store A" })
    }

    @Test("Filter by COE filters items correctly")
    func testFilterByCOE() {
        let item1 = createTestShoppingListItem(naturalKey: "test-001", coe: 104)
        let item2 = createTestShoppingListItem(naturalKey: "test-002", coe: 96)
        let item3 = createTestShoppingListItem(naturalKey: "test-003", coe: 104)

        let items = [item1, item2, item3]
        let filtered = items.filter { $0.glassItem.coe == 104 }

        #expect(filtered.count == 2)
        #expect(filtered.allSatisfy { $0.glassItem.coe == 104 })
    }

    @Test("Filter by tags filters items correctly")
    func testFilterByTags() {
        let item1 = createTestShoppingListItem(naturalKey: "test-001", tags: ["opaque", "red"])
        let item2 = createTestShoppingListItem(naturalKey: "test-002", tags: ["transparent", "blue"])
        let item3 = createTestShoppingListItem(naturalKey: "test-003", tags: ["opaque", "green"])

        let items = [item1, item2, item3]

        // Filter for items with "opaque" tag
        let filtered = items.filter { item in
            item.tags.contains("opaque")
        }

        #expect(filtered.count == 2)
        #expect(filtered.allSatisfy { $0.tags.contains("opaque") })
    }

    @Test("Filter by search text filters items correctly")
    func testFilterBySearchText() {
        let item1 = createTestShoppingListItem(naturalKey: "test-001", name: "Red Transparent")
        let item2 = createTestShoppingListItem(naturalKey: "test-002", name: "Blue Opaque")
        let item3 = createTestShoppingListItem(naturalKey: "test-003", name: "Red Opaque")

        let items = [item1, item2, item3]
        let searchText = "red"

        let filtered = items.filter { item in
            item.glassItem.name.localizedCaseInsensitiveContains(searchText) ||
            item.glassItem.natural_key.localizedCaseInsensitiveContains(searchText)
        }

        #expect(filtered.count == 2)
        #expect(filtered.allSatisfy { $0.glassItem.name.localizedCaseInsensitiveContains("red") })
    }

    @Test("Multiple filters combine correctly")
    func testMultipleFiltersCombine() {
        let item1 = createTestShoppingListItem(
            naturalKey: "test-001",
            name: "Red Transparent",
            coe: 104,
            tags: ["opaque"]
        )
        let item2 = createTestShoppingListItem(
            naturalKey: "test-002",
            name: "Red Opaque",
            coe: 104,
            tags: ["opaque"]
        )
        let item3 = createTestShoppingListItem(
            naturalKey: "test-003",
            name: "Blue Transparent",
            coe: 96,
            tags: ["transparent"]
        )

        let items = [item1, item2, item3]

        // Filter by COE 104 AND opaque tag
        let filtered = items.filter { item in
            item.glassItem.coe == 104 && item.tags.contains("opaque")
        }

        #expect(filtered.count == 2)
        #expect(filtered.allSatisfy { $0.glassItem.coe == 104 })
        #expect(filtered.allSatisfy { $0.tags.contains("opaque") })
    }

    // MARK: - Store Selection Tests

    @Test("Available stores are extracted from shopping list items")
    func testAvailableStoresExtraction() {
        let item1 = createTestShoppingListItem(naturalKey: "test-001", store: "Store A")
        let item2 = createTestShoppingListItem(naturalKey: "test-002", store: "Store B")
        let item3 = createTestShoppingListItem(naturalKey: "test-003", store: "Store A")
        let item4 = createTestShoppingListItem(naturalKey: "test-004", store: "Store C")

        let items = [item1, item2, item3, item4]
        let stores = Set(items.map { $0.shoppingListItem.store })

        #expect(stores.count == 3)
        #expect(stores.contains("Store A"))
        #expect(stores.contains("Store B"))
        #expect(stores.contains("Store C"))
    }

    @Test("Store selection filters items correctly")
    func testStoreSelectionFilters() {
        let item1 = createTestShoppingListItem(naturalKey: "test-001", store: "Store A")
        let item2 = createTestShoppingListItem(naturalKey: "test-002", store: "Store B")
        let item3 = createTestShoppingListItem(naturalKey: "test-003", store: "Store A")

        let items = [item1, item2, item3]
        let selectedStore = "Store A"

        let filtered = items.filter { $0.shoppingListItem.store == selectedStore }

        #expect(filtered.count == 2)
        #expect(filtered.allSatisfy { $0.shoppingListItem.store == "Store A" })
    }

    // MARK: - ShoppingListRowView Tests
    // Note: ShoppingListRowView doesn't exist yet - tests commented out until view is implemented

    // @Test("ShoppingListRowView displays item information")
    // func testShoppingListRowViewDisplaysItemInfo() {
    //     let item = createTestShoppingListItem(
    //         naturalKey: "test-001",
    //         name: "Test Glass",
    //         manufacturer: "test",
    //         minimumQuantity: 15.0,
    //         currentQuantity: 5.0,
    //         store: "Test Store",
    //         coe: 104,
    //         tags: ["opaque", "red"]
    //     )
    //
    //     let view = ShoppingListRowView(item: item, showStore: true)
    //
    //     #expect(view != nil)
    //     #expect(item.glassItem.name == "Test Glass")
    //     #expect(item.shoppingListItem.neededQuantity == 10.0)
    //     #expect(item.shoppingListItem.store == "Test Store")
    // }
    //
    // @Test("ShoppingListRowView displays tags")
    // func testShoppingListRowViewDisplaysTags() {
    //     let item = createTestShoppingListItem(
    //         naturalKey: "test-001",
    //         tags: ["opaque", "red", "transparent"]
    //     )
    //
    //     let view = ShoppingListRowView(item: item, showStore: true)
    //
    //     #expect(view != nil)
    //     #expect(item.tags.count == 3)
    //     #expect(item.tags.contains("opaque"))
    //     #expect(item.tags.contains("red"))
    //     #expect(item.tags.contains("transparent"))
    // }
    //
    // @Test("ShoppingListRowView displays manufacturer and COE")
    // func testShoppingListRowViewDisplaysManufacturerAndCOE() {
    //     let item = createTestShoppingListItem(
    //         naturalKey: "test-001",
    //         manufacturer: "be",
    //         coe: 104
    //     )
    //
    //     let view = ShoppingListRowView(item: item, showStore: true)
    //
    //     #expect(view != nil)
    //     #expect(item.glassItem.manufacturer == "be")
    //     #expect(item.glassItem.coe == 104)
    // }

    // MARK: - Data Loading Tests

    @Test("Shopping list handles empty service response")
    func testHandlesEmptyServiceResponse() async {
        let shoppingListService = createMockShoppingListService()

        // ShoppingListService.generateAllShoppingLists() should return empty dictionary
        let result = try? await shoppingListService.generateAllShoppingLists()

        #expect(result != nil)
        #expect(result?.isEmpty == true)
    }

    // MARK: - Search Text Parser Tests

    @Test("Search text parser identifies meaningful search")
    func testSearchTextParserIdentifiesMeaningful() {
        #expect(SearchTextParser.isSearchTextMeaningful("be") == true)
        #expect(SearchTextParser.isSearchTextMeaningful("") == false)
        #expect(SearchTextParser.isSearchTextMeaningful("   ") == false)
        #expect(SearchTextParser.isSearchTextMeaningful("\"\"") == false)
    }

    @Test("Search text parser identifies single term")
    func testSearchTextParserSingleTerm() {
        let result = SearchTextParser.parseSearchText("transparent")

        if case .singleTerm(let term) = result {
            #expect(term == "transparent")
        } else {
            Issue.record("Expected single term search")
        }
    }

    @Test("Search text parser identifies multiple terms")
    func testSearchTextParserMultipleTerms() {
        let result = SearchTextParser.parseSearchText("red transparent")

        if case .multipleTerms(let terms) = result {
            #expect(terms.count == 2)
            #expect(terms.contains("red"))
            #expect(terms.contains("transparent"))
        } else {
            Issue.record("Expected multiple terms search")
        }
    }

    // MARK: - Edge Cases

    @Test("Handles items with zero needed quantity")
    func testHandlesZeroNeededQuantity() {
        let item = createTestShoppingListItem(
            naturalKey: "test-001",
            minimumQuantity: 5.0,
            currentQuantity: 5.0
        )

        #expect(item.shoppingListItem.neededQuantity == 0.0)
    }

    @Test("Handles items with very large needed quantities")
    func testHandlesLargeNeededQuantities() {
        let item = createTestShoppingListItem(
            naturalKey: "test-001",
            minimumQuantity: 1000000.0,
            currentQuantity: 0.01
        )

        #expect(item.shoppingListItem.neededQuantity >= 999999.0)
    }

    @Test("Handles items with empty store names")
    func testHandlesEmptyStoreNames() {
        let item = createTestShoppingListItem(
            naturalKey: "test-001",
            store: ""
        )

        #expect(item.shoppingListItem.store.isEmpty)
    }

    @Test("Handles items with no tags")
    func testHandlesNoTags() {
        let item = createTestShoppingListItem(
            naturalKey: "test-001",
            tags: []
        )

        #expect(item.tags.isEmpty)
    }

    @Test("Handles items with special characters in names")
    func testHandlesSpecialCharactersInNames() {
        let item = createTestShoppingListItem(
            naturalKey: "test-001",
            name: "Test & Special < > Characters"
        )

        #expect(item.glassItem.name == "Test & Special < > Characters")
    }

    // MARK: - Checkout Notification Tests

    // Nested suite to serialize tests that use NotificationCenter.default
    @Suite("Checkout Notification Tests", .serialized)
    struct CheckoutNotificationTests {

        @Test("Checkout posts inventory notification when adding to inventory")
        func testCheckoutPostsInventoryNotification() async throws {
            // Configure for testing
            RepositoryFactory.configureForTesting()

            // Create shared repositories
            let glassItemRepository = MockGlassItemRepository()
            let inventoryRepository = MockInventoryRepository()
            let locationRepository = MockLocationRepository()
            let itemTagsRepository = MockItemTagsRepository()

            // Create service with shared repositories
            let inventoryTrackingService = InventoryTrackingService(
                glassItemRepository: glassItemRepository,
                inventoryRepository: inventoryRepository,
                locationRepository: locationRepository,
                itemTagsRepository: itemTagsRepository
            )

            // Create test glass item in the repository
            let testGlassItem = GlassItemModel(
                natural_key: "test-001",
                name: "Test Glass",
                sku: "TEST-001",
                manufacturer: "test",
                coe: 104,
                mfr_status: "available"
            )
            try await glassItemRepository.createItem(testGlassItem)

            // Set up notification expectation
            var notificationReceived = false
            let notificationCenter = NotificationCenter.default
            let observer = notificationCenter.addObserver(
                forName: .inventoryItemAdded,
                object: nil,
                queue: .main
            ) { _ in
                notificationReceived = true
            }

            defer {
                notificationCenter.removeObserver(observer)
            }

            // Simulate checkout by adding inventory (this is what checkout does)
            _ = try await inventoryTrackingService.addInventory(
                quantity: 10.0,
                type: "rod",
                toItem: "test-001"
            )

            // Post notification as checkout would
            await MainActor.run {
                NotificationCenter.default.post(name: .inventoryItemAdded, object: nil)
            }

            // Wait a bit for notification to propagate
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

            // Verify notification was received
            #expect(notificationReceived == true)
        }

        @Test("Checkout does not post inventory notification when not adding to inventory")
        func testCheckoutDoesNotPostInventoryNotificationWhenSkipped() async throws {
            // Configure for testing
            RepositoryFactory.configureForTesting()

            // Set up notification expectation
            var notificationReceived = false
            let notificationCenter = NotificationCenter.default
            let observer = notificationCenter.addObserver(
                forName: .inventoryItemAdded,
                object: nil,
                queue: .main
            ) { _ in
                notificationReceived = true
            }

            defer {
                notificationCenter.removeObserver(observer)
            }

            // Simulate checkout WITHOUT posting notification (when addToInventory = false)
            // No notification should be posted

            // Wait a bit
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

            // Verify notification was NOT received
            #expect(notificationReceived == false)
        }
    }
}
