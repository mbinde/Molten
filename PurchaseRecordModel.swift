//
//  PurchaseRecordModel.swift
//  Flameworker
//
//  Created by Assistant on 10/12/25.
//

import Foundation

/// Simple data model for purchase records, following repository pattern
struct PurchaseRecordModel: Identifiable, Equatable, Codable {
    let id: String
    let supplier: String
    let price: Double
    let dateAdded: Date
    let notes: String?
    
    init(
        id: String = UUID().uuidString,
        supplier: String,
        price: Double,
        dateAdded: Date = Date(),
        notes: String? = nil
    ) {
        self.id = id
        self.supplier = supplier
        self.price = price
        self.dateAdded = dateAdded
        self.notes = notes
    }
}

// MARK: - Business Logic Extensions

extension PurchaseRecordModel {
    /// Display name combining supplier and price
    var displayName: String {
        return "\(supplier) - $\(String(format: "%.2f", price))"
    }
    
    /// Check if record matches search text
    func matchesSearchText(_ searchText: String) -> Bool {
        let lowercaseSearch = searchText.lowercased()
        return supplier.lowercased().contains(lowercaseSearch) ||
               (notes?.lowercased().contains(lowercaseSearch) ?? false)
    }
    
    /// Formatted price string
    var formattedPrice: String {
        return String(format: "$%.2f", price)
    }
    
    /// Check if record falls within date range
    func isWithinDateRange(from startDate: Date, to endDate: Date) -> Bool {
        return dateAdded >= startDate && dateAdded <= endDate
    }
    
    /// Determine if this record has changes compared to another
    static func hasChanges(existing: PurchaseRecordModel, new: PurchaseRecordModel) -> Bool {
        return existing.supplier != new.supplier ||
               existing.price != new.price ||
               existing.notes != new.notes
    }
}