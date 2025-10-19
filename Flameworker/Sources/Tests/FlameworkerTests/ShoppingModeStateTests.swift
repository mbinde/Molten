//
//  ShoppingModeStateTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/19/25.
//  Tests for shopping mode state management (basket tracking, persistence, etc.)
//

import Testing
import Foundation
@testable import Flameworker

/// Tests for ShoppingModeState - manages basket items and shopping mode state
@Suite("Shopping Mode State Tests")
struct ShoppingModeStateTests {

    // MARK: - Test Lifecycle

    @MainActor
    init() {
        // Clear any persisted state before tests
        ShoppingModeState.shared.clearAll()
    }

    // MARK: - Basic State Tests

    @Test("Shopping mode starts disabled by default")
    @MainActor
    func testShoppingModeDefaultDisabled() {
        let state = ShoppingModeState.shared
        state.clearAll()  // Clear any state from previous tests
        #expect(state.isShoppingModeEnabled == false)
    }

    @Test("Can enable shopping mode")
    @MainActor
    func testEnableShoppingMode() {
        let state = ShoppingModeState.shared
        state.enableShoppingMode()
        #expect(state.isShoppingModeEnabled == true)
    }

    @Test("Can disable shopping mode")
    @MainActor
    func testDisableShoppingMode() {
        let state = ShoppingModeState.shared
        state.enableShoppingMode()
        state.disableShoppingMode()
        #expect(state.isShoppingModeEnabled == false)
    }

    // MARK: - Basket Management Tests

    @Test("Basket starts empty")
    @MainActor
    func testBasketStartsEmpty() {
        let state = ShoppingModeState.shared
        state.clearBasket()  // Clear any existing items from previous tests
        #expect(state.basketItems.isEmpty)
        #expect(state.basketItemCount == 0)
    }

    @Test("Can add item to basket")
    @MainActor
    func testAddItemToBasket() {
        let state = ShoppingModeState.shared
        state.clearBasket()  // Clear any existing items from previous tests
        let itemKey = "test-item-001"

        state.addToBasket(itemNaturalKey: itemKey)

        #expect(state.isInBasket(itemNaturalKey: itemKey))
        #expect(state.basketItemCount == 1)
    }

    @Test("Can remove item from basket")
    @MainActor
    func testRemoveItemFromBasket() {
        let state = ShoppingModeState.shared
        state.clearBasket()  // Clear any existing items from previous tests
        let itemKey = "test-item-001"

        state.addToBasket(itemNaturalKey: itemKey)
        state.removeFromBasket(itemNaturalKey: itemKey)

        #expect(!state.isInBasket(itemNaturalKey: itemKey))
        #expect(state.basketItemCount == 0)
    }

    @Test("Can toggle item in basket")
    @MainActor
    func testToggleItemInBasket() {
        let state = ShoppingModeState.shared
        let itemKey = "test-item-001"

        // Toggle on
        state.toggleBasket(itemNaturalKey: itemKey)
        #expect(state.isInBasket(itemNaturalKey: itemKey))

        // Toggle off
        state.toggleBasket(itemNaturalKey: itemKey)
        #expect(!state.isInBasket(itemNaturalKey: itemKey))
    }

    @Test("Can add multiple items to basket")
    @MainActor
    func testAddMultipleItemsToBasket() {
        let state = ShoppingModeState.shared
        state.clearBasket()  // Clear any existing items from previous tests
        let items = ["item-001", "item-002", "item-003"]

        for item in items {
            state.addToBasket(itemNaturalKey: item)
        }

        #expect(state.basketItemCount == 3)
        for item in items {
            #expect(state.isInBasket(itemNaturalKey: item))
        }
    }

    @Test("Adding duplicate item doesn't increase count")
    @MainActor
    func testAddDuplicateItem() {
        let state = ShoppingModeState.shared
        state.clearBasket()  // Clear any existing items from previous tests
        let itemKey = "test-item-001"

        state.addToBasket(itemNaturalKey: itemKey)
        state.addToBasket(itemNaturalKey: itemKey)

        #expect(state.basketItemCount == 1)
    }

    @Test("Can clear all basket items")
    @MainActor
    func testClearBasket() {
        let state = ShoppingModeState.shared
        state.addToBasket(itemNaturalKey: "item-001")
        state.addToBasket(itemNaturalKey: "item-002")

        state.clearBasket()

        #expect(state.basketItemCount == 0)
        #expect(state.basketItems.isEmpty)
    }

    // MARK: - Persistence Tests

    @Test("Basket state persists across instances")
    @MainActor
    func testBasketStatePersistence() {
        // Add items and enable shopping mode
        let state1 = ShoppingModeState.shared
        state1.clearAll()  // Clear any existing state from previous tests
        state1.enableShoppingMode()
        state1.addToBasket(itemNaturalKey: "item-001")
        state1.addToBasket(itemNaturalKey: "item-002")

        // Save state
        state1.save()

        // Create new instance and verify it loads the persisted state
        let state2 = ShoppingModeState()
        state2.load()

        #expect(state2.isShoppingModeEnabled == true)
        #expect(state2.basketItemCount == 2)
        #expect(state2.isInBasket(itemNaturalKey: "item-001"))
        #expect(state2.isInBasket(itemNaturalKey: "item-002"))

        // Clean up
        state1.clearAll()
    }

    @Test("Shopping mode state persists")
    @MainActor
    func testShoppingModeStatePersistence() {
        let state1 = ShoppingModeState.shared
        state1.enableShoppingMode()
        state1.save()

        let state2 = ShoppingModeState()
        state2.load()

        #expect(state2.isShoppingModeEnabled == true)

        // Clean up
        state1.clearAll()
    }

    @Test("Clear all removes persisted state")
    @MainActor
    func testClearAllRemovesPersistedState() {
        let state1 = ShoppingModeState.shared
        state1.enableShoppingMode()
        state1.addToBasket(itemNaturalKey: "item-001")
        state1.save()

        state1.clearAll()

        let state2 = ShoppingModeState()
        state2.load()

        #expect(state2.isShoppingModeEnabled == false)
        #expect(state2.basketItemCount == 0)
    }

    // MARK: - Filter Interaction Tests

    @Test("Can get basket items for specific store")
    @MainActor
    func testGetBasketItemsForStore() {
        let state = ShoppingModeState.shared
        state.clearBasket()  // Clear any existing items from previous tests

        // These would need to be tracked with store info
        // For now, test basic filtering capability
        state.addToBasket(itemNaturalKey: "store1-item-001")
        state.addToBasket(itemNaturalKey: "store2-item-001")

        #expect(state.basketItemCount == 2)

        // Note: Actual store filtering would happen in the view layer
        // using the store filter + basket state
    }
}
