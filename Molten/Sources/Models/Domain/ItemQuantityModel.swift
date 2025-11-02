//
//  ItemQuantityModel.swift
//  Molten
//
//  Created by Assistant on 11/02/25.
//  Shared protocol for quantity-tracking models (inventory and shopping list)
//

import Foundation

/// Protocol for models that track quantities of glass items
///
/// This protocol abstracts the common pattern of "tracking a quantity of a glass item"
/// which applies to both:
/// - Inventory: "I have X rods of this glass"
/// - Shopping List: "I want X rods of this glass"
///
/// The semantic difference (have vs want) is captured by domain-specific fields
/// and the context in which the model is used.
protocol ItemQuantityModel: Identifiable, Equatable, Hashable, Sendable where ID == UUID {
    // MARK: - Core Fields (100% shared)

    /// Unique identifier for this quantity record
    var id: UUID { get }

    /// Reference to the glass item being tracked
    var item_stable_id: String { get }

    /// Quantity of the item
    var quantity: Double { get }

    /// Type/form of the glass (rod, frit, tube, etc.)
    /// Note: Optional in shopping list, required in inventory
    var type: String? { get }

    /// Optional subtype (e.g., "clear" for tube type)
    var subtype: String? { get }

    /// Optional sub-subtype for further categorization
    var subsubtype: String? { get }

    /// Date this record was added
    var dateAdded: Date { get }

    // MARK: - Business Logic (shared behavior)

    /// Check if quantity is valid (greater than 0)
    var hasValidQuantity: Bool { get }

    /// Get formatted quantity string (e.g., "5" or "2.5")
    var formattedQuantity: String { get }

    /// Validate that the item has required data
    var isValid: Bool { get }

    /// Get validation errors if any
    var validationErrors: [String] { get }

    /// Get a copy with updated quantity
    func withQuantity(_ newQuantity: Double) -> Self

    /// Check if this item matches search text
    func matchesSearchText(_ searchText: String) -> Bool
}

// MARK: - Default Implementations

extension ItemQuantityModel {
    /// Default: quantity is valid if greater than 0
    var hasValidQuantity: Bool {
        return quantity > 0
    }

    /// Default: format quantity with appropriate decimal places
    var formattedQuantity: String {
        if quantity.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", quantity)
        } else {
            return String(format: "%.2f", quantity)
        }
    }

    /// Default: valid if has item reference and positive quantity
    var isValid: Bool {
        return !item_stable_id.isEmpty && quantity > 0
    }

    /// Default: basic validation errors
    var validationErrors: [String] {
        var errors: [String] = []

        if item_stable_id.isEmpty {
            errors.append("Item stable ID is required")
        }

        if quantity <= 0 {
            errors.append("Quantity must be greater than 0")
        }

        return errors
    }

    /// Default: match on item stable ID
    func matchesSearchText(_ searchText: String) -> Bool {
        let lowercaseSearch = searchText.lowercased()
        return item_stable_id.lowercased().contains(lowercaseSearch)
    }
}

// MARK: - Type Utilities

extension ItemQuantityModel {
    /// Get non-optional type string (returns empty string if nil)
    var typeOrEmpty: String {
        return type ?? ""
    }

    /// Get full type path (type/subtype/subsubtype)
    var fullTypePath: String {
        guard let baseType = type else { return "" }

        var path = baseType
        if let sub = subtype {
            path += "/\(sub)"
            if let subsub = subsubtype {
                path += "/\(subsub)"
            }
        }
        return path
    }

    /// Check if this item has a specific type
    func hasType(_ typeName: String) -> Bool {
        return type?.lowercased() == typeName.lowercased()
    }
}
