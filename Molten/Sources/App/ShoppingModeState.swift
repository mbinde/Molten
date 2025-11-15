//
//  ShoppingModeState.swift
//  Flameworker
//
//  Created by Assistant on 10/19/25.
//  Manages shopping mode state and basket items with persistence
//

import Foundation
import Combine

/// Manages shopping mode state and tracks which items are in the user's basket
/// Persists state to UserDefaults so basket survives app restarts
@MainActor
class ShoppingModeState: ObservableObject {
    static let shared = ShoppingModeState()

    // MARK: - Published Properties

    /// Whether shopping mode is currently active
    @Published private(set) var isShoppingModeEnabled: Bool = false

    /// Set of item natural keys that are currently in the basket
    @Published private(set) var basketItems: Set<String> = []

    // MARK: - Computed Properties

    /// Number of items in the basket
    var basketItemCount: Int {
        basketItems.count
    }

    /// Whether the basket has any items
    var hasItemsInBasket: Bool {
        !basketItems.isEmpty
    }

    // MARK: - UserDefaults Keys

    private let shoppingModeEnabledKey = "com.motleywoods.molten.shoppingMode.enabled"
    private let basketItemsKey = "com.motleywoods.molten.shoppingMode.basketItems"

    // MARK: - Initialization

    init() {
        load()
    }

    // MARK: - Shopping Mode Control

    /// Enable shopping mode
    func enableShoppingMode() {
        isShoppingModeEnabled = true
        save()
    }

    /// Disable shopping mode
    func disableShoppingMode() {
        isShoppingModeEnabled = false
        save()
    }

    /// Toggle shopping mode on/off
    func toggleShoppingMode() {
        isShoppingModeEnabled.toggle()
        save()
    }

    // MARK: - Basket Management

    /// Check if an item is in the basket
    func isInBasket(item_stable_id: String) -> Bool {
        basketItems.contains(item_stable_id)
    }

    /// Add an item to the basket
    func addToBasket(item_stable_id: String) {
        basketItems.insert(item_stable_id)
        save()
    }

    /// Remove an item from the basket
    func removeFromBasket(item_stable_id: String) {
        basketItems.remove(item_stable_id)
        save()
    }

    /// Toggle an item in/out of the basket
    func toggleBasket(item_stable_id: String) {
        if basketItems.contains(item_stable_id) {
            basketItems.remove(item_stable_id)
        } else {
            basketItems.insert(item_stable_id)
        }
        save()
    }

    /// Clear all items from the basket
    func clearBasket() {
        basketItems.removeAll()
        save()
    }

    /// Get basket items filtered by store (for use with store filter)
    func getBasketItems(for store: String?, allItems: [String: String]) -> Set<String> {
        guard let store = store else {
            return basketItems
        }

        // Filter basket items to only include those from the specified store
        return basketItems.filter { itemKey in
            allItems[itemKey] == store
        }
    }

    // MARK: - Persistence

    /// Save current state to UserDefaults
    func save() {
        UserDefaults.standard.set(isShoppingModeEnabled, forKey: shoppingModeEnabledKey)
        UserDefaults.standard.set(Array(basketItems), forKey: basketItemsKey)
    }

    /// Load state from UserDefaults
    func load() {
        isShoppingModeEnabled = UserDefaults.standard.bool(forKey: shoppingModeEnabledKey)

        if let savedBasketItems = UserDefaults.standard.array(forKey: basketItemsKey) as? [String] {
            basketItems = Set(savedBasketItems)
        }
    }

    /// Clear all state (both in-memory and persisted)
    func clearAll() {
        isShoppingModeEnabled = false
        basketItems.removeAll()
        UserDefaults.standard.removeObject(forKey: shoppingModeEnabledKey)
        UserDefaults.standard.removeObject(forKey: basketItemsKey)
    }
}
