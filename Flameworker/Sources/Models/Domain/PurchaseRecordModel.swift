//
//  PurchaseRecordModel.swift
//  Flameworker
//
//  Created by Repository Pattern Migration on 10/12/25.
//  Updated for new purchase record structure on 10/19/25.
//

import Foundation

/// Business model for purchase records (a purchase event/trip)
struct PurchaseRecordModel: Identifiable, Equatable, Codable {
    let id: UUID
    let supplier: String
    let datePurchased: Date
    let dateAdded: Date
    let subtotal: Decimal?
    let tax: Decimal?
    let shipping: Decimal?
    let currency: String
    let notes: String?
    let items: [PurchaseRecordItemModel]

    /// Initialize with business logic validation
    init(
        id: UUID = UUID(),
        supplier: String,
        datePurchased: Date = Date(),
        dateAdded: Date = Date(),
        subtotal: Decimal? = nil,
        tax: Decimal? = nil,
        shipping: Decimal? = nil,
        currency: String = "USD",
        notes: String? = nil,
        items: [PurchaseRecordItemModel] = []
    ) {
        self.id = id
        self.supplier = supplier.trimmingCharacters(in: .whitespacesAndNewlines)
        self.datePurchased = datePurchased
        self.dateAdded = dateAdded
        self.subtotal = subtotal
        self.tax = tax
        self.shipping = shipping
        self.currency = currency
        self.notes = notes?.isEmpty == true ? nil : notes
        self.items = items
    }

    // MARK: - Business Logic

    /// Total price (computed from subtotal + tax + shipping, or nil if not tracked)
    var totalPrice: Decimal? {
        let sub = subtotal ?? 0
        let t = tax ?? 0
        let ship = shipping ?? 0

        // Only return total if at least one component is present
        if subtotal != nil || tax != nil || shipping != nil {
            return sub + t + ship
        }
        return nil
    }

    /// Display name combining supplier and date
    var displayName: String {
        return "\(supplier) - \(formattedDate)"
    }

    /// Check if record matches search text
    func matchesSearchText(_ searchText: String) -> Bool {
        let lowercaseSearch = searchText.lowercased()
        return supplier.lowercased().contains(lowercaseSearch) ||
               (notes?.lowercased().contains(lowercaseSearch) ?? false)
    }

    /// Formatted total price for display
    var formattedPrice: String? {
        guard let total = totalPrice else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: total as NSDecimalNumber)
    }

    /// Formatted date for display
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: datePurchased)
    }

    /// Check if record has notes
    var hasNotes: Bool {
        return notes?.isEmpty == false
    }

    /// Check if record falls within date range
    func isWithinDateRange(from startDate: Date, to endDate: Date) -> Bool {
        return datePurchased >= startDate && datePurchased <= endDate
    }

    /// Total number of items in purchase
    var itemCount: Int {
        return items.count
    }

    /// Check if purchase has price information
    var hasPriceInfo: Bool {
        return subtotal != nil || tax != nil || shipping != nil
    }

    // MARK: - Validation

    /// Validate that the record has required data
    var isValid: Bool {
        return !supplier.isEmpty
    }

    /// Get validation errors if any
    var validationErrors: [String] {
        var errors: [String] = []

        if supplier.isEmpty {
            errors.append("Supplier name is required")
        }

        // Validate all items
        for (index, item) in items.enumerated() {
            if !item.isValid {
                errors.append("Item at index \(index) is invalid: \(item.validationErrors.joined(separator: ", "))")
            }
        }

        return errors
    }
}

/// Business model for individual items in a purchase record
struct PurchaseRecordItemModel: Identifiable, Equatable, Codable {
    let id: UUID
    let itemNaturalKey: String
    let type: String
    let subtype: String?
    let subsubtype: String?
    let quantity: Double
    let totalPrice: Decimal?
    let orderIndex: Int32

    /// Initialize with business logic validation
    init(
        id: UUID = UUID(),
        itemNaturalKey: String,
        type: String,
        subtype: String? = nil,
        subsubtype: String? = nil,
        quantity: Double,
        totalPrice: Decimal? = nil,
        orderIndex: Int32 = 0
    ) {
        self.id = id
        self.itemNaturalKey = itemNaturalKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.type = type
        self.subtype = subtype?.isEmpty == true ? nil : subtype
        self.subsubtype = subsubtype?.isEmpty == true ? nil : subsubtype
        self.quantity = quantity
        self.totalPrice = totalPrice
        self.orderIndex = orderIndex
    }

    // MARK: - Business Logic

    /// Full type string for display (e.g., "rod", "frit - coarse")
    var fullTypeDescription: String {
        var parts = [type]
        if let sub = subtype {
            parts.append(sub)
        }
        if let subsub = subsubtype {
            parts.append(subsub)
        }
        return parts.joined(separator: " - ")
    }

    /// Formatted quantity with unit
    var formattedQuantity: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        let qtyStr = formatter.string(from: NSNumber(value: quantity)) ?? "\(quantity)"
        return "\(qtyStr) \(type)"
    }

    /// Formatted price for display
    func formattedPrice(currency: String = "USD") -> String? {
        guard let price = totalPrice else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: price as NSDecimalNumber)
    }

    // MARK: - Validation

    /// Validate that the item has required data
    var isValid: Bool {
        return !itemNaturalKey.isEmpty && !type.isEmpty && quantity > 0
    }

    /// Get validation errors if any
    var validationErrors: [String] {
        var errors: [String] = []

        if itemNaturalKey.isEmpty {
            errors.append("Item natural key is required")
        }

        if type.isEmpty {
            errors.append("Type is required")
        }

        if quantity <= 0 {
            errors.append("Quantity must be greater than 0")
        }

        return errors
    }
}

// MARK: - Helper Extensions

extension PurchaseRecordModel {
    /// Create a purchase record from checkout items
    static func fromCheckout(
        supplier: String,
        items: [(itemNaturalKey: String, type: String, quantity: Double)],
        subtotal: Decimal? = nil,
        tax: Decimal? = nil,
        shipping: Decimal? = nil,
        notes: String? = nil
    ) -> PurchaseRecordModel {
        let purchaseItems = items.enumerated().map { index, item in
            PurchaseRecordItemModel(
                itemNaturalKey: item.itemNaturalKey,
                type: item.type,
                quantity: item.quantity,
                orderIndex: Int32(index)
            )
        }

        return PurchaseRecordModel(
            supplier: supplier,
            subtotal: subtotal,
            tax: tax,
            shipping: shipping,
            notes: notes,
            items: purchaseItems
        )
    }
}
