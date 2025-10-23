//
//  ItemShoppingModel.swift
//  Flameworker
//
//  Created by Assistant on 10/16/25.
//

import Foundation

/// Business model for shopping list items with validation and business logic
/// Maps to ItemShopping Core Data entity
nonisolated struct ItemShoppingModel: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    let item_stable_id: String
    let quantity: Double
    let store: String?
    let type: String?
    let subtype: String?
    let subsubtype: String?
    let dateAdded: Date

    /// Initialize with business logic validation
    nonisolated init(
        id: UUID = UUID(),
        item_stable_id: String,
        quantity: Double,
        store: String? = nil,
        type: String? = nil,
        subtype: String? = nil,
        subsubtype: String? = nil,
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.item_stable_id = item_stable_id.trimmingCharacters(in: .whitespacesAndNewlines)
        self.quantity = max(0, quantity) // Ensure non-negative
        self.store = store?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.type = type?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.subtype = subtype?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.subsubtype = subsubtype?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.dateAdded = dateAdded
    }

    // MARK: - Business Logic

    /// Check if this item is for a specific store
    nonisolated func isForStore(_ storeName: String) -> Bool {
        guard let store = store else { return false }
        return store.lowercased() == storeName.lowercased()
    }

    /// Check if this item matches search text
    nonisolated func matchesSearchText(_ searchText: String) -> Bool {
        let lowercaseSearch = searchText.lowercased()
        return item_stable_id.lowercased().contains(lowercaseSearch) ||
               store?.lowercased().contains(lowercaseSearch) == true
    }

    /// Get a copy with updated quantity
    nonisolated func withQuantity(_ newQuantity: Double) -> ItemShoppingModel {
        return ItemShoppingModel(
            id: id,
            item_stable_id: item_stable_id,
            quantity: max(0, newQuantity),
            store: store,
            type: type,
            subtype: subtype,
            subsubtype: subsubtype,
            dateAdded: dateAdded
        )
    }

    /// Get a copy with updated store
    nonisolated func withStore(_ newStore: String?) -> ItemShoppingModel {
        return ItemShoppingModel(
            id: id,
            item_stable_id: item_stable_id,
            quantity: quantity,
            store: newStore,
            type: type,
            subtype: subtype,
            subsubtype: subsubtype,
            dateAdded: dateAdded
        )
    }

    /// Check if quantity is valid (greater than 0)
    nonisolated var hasValidQuantity: Bool {
        return quantity > 0
    }

    /// Get formatted quantity string
    nonisolated var formattedQuantity: String {
        if quantity.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", quantity)
        } else {
            return String(format: "%.2f", quantity)
        }
    }

    /// Compare items for changes (useful for updates)
    nonisolated static func hasChanges(existing: ItemShoppingModel, new: ItemShoppingModel) -> Bool {
        return existing.item_stable_id != new.item_stable_id ||
               existing.quantity != new.quantity ||
               existing.store != new.store
    }

    // MARK: - Validation

    /// Validate that the shopping list item has required data
    nonisolated var isValid: Bool {
        return !item_stable_id.isEmpty && quantity > 0
    }

    /// Get validation errors if any
    nonisolated var validationErrors: [String] {
        var errors: [String] = []

        if item_stable_id.isEmpty {
            errors.append("Item natural key is required")
        }

        if quantity <= 0 {
            errors.append("Quantity must be greater than 0")
        }

        return errors
    }
}

// MARK: - Helper Extensions

extension ItemShoppingModel {
    /// Create shopping list item from a dictionary (useful for JSON parsing)
    nonisolated static func from(dictionary: [String: Any]) -> ItemShoppingModel? {
        guard let item_stable_id = dictionary["item_stable_id"] as? String,
              let quantity = dictionary["quantity"] as? Double else {
            return nil
        }

        let id: UUID
        if let idString = dictionary["id"] as? String, let uuid = UUID(uuidString: idString) {
            id = uuid
        } else {
            id = UUID()
        }

        let store = dictionary["store"] as? String
        let type = dictionary["type"] as? String
        let subtype = dictionary["subtype"] as? String
        let subsubtype = dictionary["subsubtype"] as? String

        let dateAdded: Date
        if let timestamp = dictionary["dateAdded"] as? TimeInterval {
            dateAdded = Date(timeIntervalSince1970: timestamp)
        } else {
            dateAdded = Date()
        }

        return ItemShoppingModel(
            id: id,
            item_stable_id: item_stable_id,
            quantity: quantity,
            store: store,
            type: type,
            subtype: subtype,
            subsubtype: subsubtype,
            dateAdded: dateAdded
        )
    }

    /// Convert to dictionary (useful for storage or API calls)
    nonisolated func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id.uuidString,
            "item_stable_id": item_stable_id,
            "quantity": quantity,
            "dateAdded": dateAdded.timeIntervalSince1970
        ]

        if let store = store {
            dict["store"] = store
        }
        if let type = type {
            dict["type"] = type
        }
        if let subtype = subtype {
            dict["subtype"] = subtype
        }
        if let subsubtype = subsubtype {
            dict["subsubtype"] = subsubtype
        }

        return dict
    }
}

// MARK: - Common Store Names

extension ItemShoppingModel {
    /// Common store names for convenience
    enum CommonStore {
        nonisolated static let frantzArtGlass = "Frantz Art Glass"
        nonisolated static let olympicColor = "Olympic Color"
        nonisolated static let bullseyeGlass = "Bullseye Glass Co"
        nonisolated static let glassAlchemy = "Glass Alchemy"
        nonisolated static let northstarGlassworks = "Northstar Glassworks"
        nonisolated static let online = "Online"
        nonisolated static let local = "Local"

        nonisolated static let allCommonStores = [
            frantzArtGlass,
            olympicColor,
            bullseyeGlass,
            glassAlchemy,
            northstarGlassworks,
            online,
            local
        ]
    }
}
