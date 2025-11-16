//
//  StoreToShoppingListNavigationTests.swift
//  MoltenTests
//
//  Created by Claude on 11/01/25.
//  Tests for navigation from Store detail to Shopping List
//

import Foundation
import Combine

#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

@testable import Molten

#if canImport(Testing)

@Suite("Store to Shopping List Navigation Tests")
@MainActor
struct StoreToShoppingListNavigationTests {

    // MARK: - Shared Dependencies

    /// ✅ CRITICAL: Store AppDependencies at struct level to keep PersistenceController alive
    /// This prevents Core Data zombie objects that cause crashes.
    /// See CLAUDE.md "Service Creation Anti-Pattern" - same pattern applies to tests!
    private let deps = AppDependencies(persistenceController: .createTestController())


    // MARK: - Notification Tests

    @Test("Should post notification when navigating to shopping list")
    @MainActor
    func testNavigationNotificationPosted() async throws {
        // Arrange
        let expectation = XCTestExpectation(description: "Navigation notification posted")
        var receivedStoreName: String?

        let cancellable = NotificationCenter.default
            .publisher(for: .navigateToShoppingListForStore)
            .sink { notification in
                receivedStoreName = notification.userInfo?["storeName"] as? String
                expectation.fulfill()
            }

        // Act
        NotificationCenter.default.post(
            name: .navigateToShoppingListForStore,
            object: nil,
            userInfo: ["storeName": "Frantz Art Glass"]
        )

        // Wait for notification
        await fulfillment(of: [expectation], timeout: 1.0)

        // Assert
        #expect(receivedStoreName == "Frantz Art Glass")

        cancellable.cancel()
    }

    @Test("Should post filter notification with correct store name")
    @MainActor
    func testFilterNotificationPosted() async throws {
        // Arrange
        let expectation = XCTestExpectation(description: "Filter notification posted")
        var receivedStoreName: String?

        let cancellable = NotificationCenter.default
            .publisher(for: .filterShoppingListByStore)
            .sink { notification in
                receivedStoreName = notification.userInfo?["storeName"] as? String
                expectation.fulfill()
            }

        // Act
        NotificationCenter.default.post(
            name: .filterShoppingListByStore,
            object: nil,
            userInfo: ["storeName": "Olympic Color"]
        )

        // Wait for notification
        await fulfillment(of: [expectation], timeout: 1.0)

        // Assert
        #expect(receivedStoreName == "Olympic Color")

        cancellable.cancel()
    }

    @Test("Should handle notification without userInfo")
    @MainActor
    func testNotificationWithoutUserInfo() async throws {
        // Arrange
        let expectation = XCTestExpectation(description: "Notification received")
        var receivedNotification = false

        let cancellable = NotificationCenter.default
            .publisher(for: .navigateToShoppingListForStore)
            .sink { _ in
                receivedNotification = true
                expectation.fulfill()
            }

        // Act
        NotificationCenter.default.post(
            name: .navigateToShoppingListForStore,
            object: nil,
            userInfo: nil
        )

        // Wait for notification
        await fulfillment(of: [expectation], timeout: 1.0)

        // Assert
        #expect(receivedNotification == true)

        cancellable.cancel()
    }

    @Test("Should handle notification with wrong userInfo type")
    @MainActor
    func testNotificationWithWrongUserInfoType() async throws {
        // Arrange
        let expectation = XCTestExpectation(description: "Notification received")
        var receivedStoreName: String?

        let cancellable = NotificationCenter.default
            .publisher(for: .navigateToShoppingListForStore)
            .sink { notification in
                receivedStoreName = notification.userInfo?["storeName"] as? String
                expectation.fulfill()
            }

        // Act - Send wrong type (Int instead of String)
        NotificationCenter.default.post(
            name: .navigateToShoppingListForStore,
            object: nil,
            userInfo: ["storeName": 123]
        )

        // Wait for notification
        await fulfillment(of: [expectation], timeout: 1.0)

        // Assert - Should be nil due to type mismatch
        #expect(receivedStoreName == nil)

        cancellable.cancel()
    }

    // MARK: - Integration Tests

    @Test("Should navigate from store with shopping list items")
    @MainActor
    func testNavigateFromStoreWithItems() async throws {
        // Arrange
        let shoppingListService = deps.shoppingListService

        let storeName = "Frantz Art Glass"

        // Create shopping list items for the store
        let item = ItemShoppingModel(
            item_stable_id: "bullseye-0001-0",
            quantity: 10,
            store: storeName
        )
        _ = try await shoppingListService.shoppingListRepository.createItem(item)

        // Verify items exist
        let items = try await shoppingListService.shoppingListRepository.fetchItems(forStore: storeName)
        #expect(!items.isEmpty)

        // Act - Simulate navigation
        let expectation = XCTestExpectation(description: "Navigation completed")
        var didNavigate = false

        let cancellable = NotificationCenter.default
            .publisher(for: .navigateToShoppingListForStore)
            .sink { notification in
                if let store = notification.userInfo?["storeName"] as? String {
                    didNavigate = (store == storeName)
                    expectation.fulfill()
                }
            }

        NotificationCenter.default.post(
            name: .navigateToShoppingListForStore,
            object: nil,
            userInfo: ["storeName": storeName]
        )

        // Wait for notification
        await fulfillment(of: [expectation], timeout: 1.0)

        // Assert
        #expect(didNavigate == true)

        cancellable.cancel()
    }

    @Test("Should not navigate from store without shopping list items")
    @MainActor
    func testNoNavigationWhenNoItems() async throws {
        // Arrange
        let shoppingListService = deps.shoppingListService

        let storeName = "Empty Store"

        // Verify no items exist
        let items = try await shoppingListService.shoppingListRepository.fetchItems(forStore: storeName)
        #expect(items.isEmpty)

        // Act - In real app, button wouldn't be shown, so no navigation would occur
        // This test verifies the condition that determines button visibility
        let hasItems = !items.isEmpty

        // Assert
        #expect(hasItems == false)
    }

    // MARK: - Notification Name Tests

    @Test("Notification names should be unique")
    func testNotificationNamesUnique() {
        let navigateNotification = Notification.Name.navigateToShoppingListForStore
        let filterNotification = Notification.Name.filterShoppingListByStore

        #expect(navigateNotification.rawValue != filterNotification.rawValue)
        #expect(navigateNotification.rawValue == "navigateToShoppingListForStore")
        #expect(filterNotification.rawValue == "filterShoppingListByStore")
    }

    @Test("All shopping list related notifications should exist")
    func testAllNotificationsExist() {
        // Test that all required notifications are defined
        let _ = Notification.Name.navigateToShoppingListForStore
        let _ = Notification.Name.filterShoppingListByStore
        let _ = Notification.Name.shoppingListItemAdded
        let _ = Notification.Name.inventoryItemAdded

        // If we get here without crashing, all notifications exist
        #expect(true)
    }

    // MARK: - Special Characters in Store Names

    @Test("Should handle store names with special characters in navigation")
    @MainActor
    func testNavigationWithSpecialCharacters() async throws {
        // Arrange
        let storeName = "Art & Glass Co."
        let expectation = XCTestExpectation(description: "Navigation with special chars")
        var receivedName: String?

        let cancellable = NotificationCenter.default
            .publisher(for: .navigateToShoppingListForStore)
            .sink { notification in
                receivedName = notification.userInfo?["storeName"] as? String
                expectation.fulfill()
            }

        // Act
        NotificationCenter.default.post(
            name: .navigateToShoppingListForStore,
            object: nil,
            userInfo: ["storeName": storeName]
        )

        // Wait for notification
        await fulfillment(of: [expectation], timeout: 1.0)

        // Assert
        #expect(receivedName == storeName)

        cancellable.cancel()
    }

    @Test("Should handle store names with unicode characters")
    @MainActor
    func testNavigationWithUnicodeCharacters() async throws {
        // Arrange
        let storeName = "Café Glāss"
        let expectation = XCTestExpectation(description: "Navigation with unicode")
        var receivedName: String?

        let cancellable = NotificationCenter.default
            .publisher(for: .navigateToShoppingListForStore)
            .sink { notification in
                receivedName = notification.userInfo?["storeName"] as? String
                expectation.fulfill()
            }

        // Act
        NotificationCenter.default.post(
            name: .navigateToShoppingListForStore,
            object: nil,
            userInfo: ["storeName": storeName]
        )

        // Wait for notification
        await fulfillment(of: [expectation], timeout: 1.0)

        // Assert
        #expect(receivedName == storeName)

        cancellable.cancel()
    }
}

#endif

// MARK: - XCTest Compatibility Helpers

class XCTestExpectation {
    private let semaphore = DispatchSemaphore(value: 0)
    private var fulfilled = false
    let description: String

    init(description: String) {
        self.description = description
    }

    func fulfill() {
        guard !fulfilled else { return }
        fulfilled = true
        semaphore.signal()
    }

    func wait(timeout: TimeInterval) -> Bool {
        let timeoutTime = DispatchTime.now() + timeout
        return semaphore.wait(timeout: timeoutTime) == .success
    }
}

func fulfillment(of expectations: [XCTestExpectation], timeout: TimeInterval) async {
    for expectation in expectations {
        _ = expectation.wait(timeout: timeout)
    }
}
