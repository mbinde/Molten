//
//  ItemShoppingModel.swift
//  Flameworker
//
//  Created by Assistant on 10/16/25.
//

import Foundation

/// Business model for shopping list items with validation and business logic
/// Maps to ItemShopping Core Data entity
struct ItemShoppingModel: Identifiable, Equatable, Codable {
    let id: UUID
    let item_natural_key: String
    let quantity: Double
    let store: String?
    let type: String?
    let subtype: String?
    let subsubtype: String?
    let dateAdded: Date

    /// Initialize with business logic validation
    nonisolated init(
        id: UUID = UUID(),
        item_natural_key: String,
        quantity: Double,
        store: String? = nil,
        type: String? = nil,
        subtype: String? = nil,
        subsubtype: String? = nil,
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.item_natural_key = item_natural_key.trimmingCharacters(in: .whitespacesAndNewlines)
        self.quantity = max(0, quantity) // Ensure non-negative
        self.store = store?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.type = type?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.subtype = subtype?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.subsubtype = subsubtype?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.dateAdded = dateAdded
    }

    // MARK: - Business Logic

    /// Check if this item is for a specific store
    func isForStore(_ storeName: String) -> Bool {
        guard let store = store else { return false }
        return store.lowercased() == storeName.lowercased()
    }

    /// Check if this item matches search text
    func matchesSearchText(_ searchText: String) -> Bool {
        let lowercaseSearch = searchText.lowercased()
        return item_natural_key.lowercased().contains(lowercaseSearch) ||
               store?.lowercased().contains(lowercaseSearch) == true
    }

    /// Get a copy with updated quantity
    nonisolated func withQuantity(_ newQuantity: Double) -> ItemShoppingModel {
        return ItemShoppingModel(
            id: id,
            item_natural_key: item_natural_key,
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
            item_natural_key: item_natural_key,
            quantity: quantity,
            store: newStore,
            type: type,
            subtype: subtype,
            subsubtype: subsubtype,
            dateAdded: dateAdded
        )
    }

    /// Check if quantity is valid (greater than 0)
    var hasValidQuantity: Bool {
        return quantity > 0
    }

    /// Get formatted quantity string
    var formattedQuantity: String {
        if quantity.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", quantity)
        } else {
            return String(format: "%.2f", quantity)
        }
    }

    /// Compare items for changes (useful for updates)
    static func hasChanges(existing: ItemShoppingModel, new: ItemShoppingModel) -> Bool {
        return existing.item_natural_key != new.item_natural_key ||
               existing.quantity != new.quantity ||
               existing.store != new.store
    }

    // MARK: - Validation

    /// Validate that the shopping list item has required data
    nonisolated var isValid: Bool {
        return !item_natural_key.isEmpty && quantity > 0
    }

    /// Get validation errors if any
    nonisolated var validationErrors: [String] {
        var errors: [String] = []

        if item_natural_key.isEmpty {
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
    static func from(dictionary: [String: Any]) -> ItemShoppingModel? {
        guard let item_natural_key = dictionary["item_natural_key"] as? String,
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
            item_natural_key: item_natural_key,
            quantity: quantity,
            store: store,
            type: type,
            subtype: subtype,
            subsubtype: subsubtype,
            dateAdded: dateAdded
        )
    }

    /// Convert to dictionary (useful for storage or API calls)
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id.uuidString,
            "item_natural_key": item_natural_key,
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
        static let frantzArtGlass = "Frantz Art Glass"
        static let olympicColor = "Olympic Color"
        static let bullseyeGlass = "Bullseye Glass Co"
        static let glassAlchemy = "Glass Alchemy"
        static let northstarGlassworks = "Northstar Glassworks"
        static let online = "Online"
        static let local = "Local"

        static let allCommonStores = [
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
